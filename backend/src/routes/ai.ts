import { Router } from 'express';
import { litellm } from '../services/litellm-service';
import { decodeAndValidateImage, ImageValidationError } from '../utils/imageValidation';
import {
  checkScopedRateLimit,
  IMAGE_UPLOAD_SCOPE,
  IMAGE_UPLOAD_MAX,
  IMAGE_UPLOAD_WINDOW_MS,
} from '../utils/rateLimit';

const router = Router();

// POST /api/ai/analyze-card
router.post('/analyze-card', async (req, res, next) => {
  try {
    const supabase = req.supabase!;
    const image: string | undefined = req.body?.image ?? req.body?.imageData;

    if (!image) {
      return res.status(400).json({ error: 'Image is required' });
    }

    // Throttle per user before doing any expensive work (storage + paid vision).
    const limit = await checkScopedRateLimit(
      req.user!.id, IMAGE_UPLOAD_SCOPE, IMAGE_UPLOAD_MAX, IMAGE_UPLOAD_WINDOW_MS,
    );
    if (!limit.ok) {
      res.setHeader('Retry-After', String(limit.retryAfterSeconds));
      return res.status(429).json({ error: 'Too many image requests. Please slow down.' });
    }

    // Validate before spending a (paid) vision call. Rejects oversized payloads
    // and anything that isn't a real JPEG/PNG/WebP — sniffed from the bytes,
    // not the client-claimed type (which is trivially spoofed).
    try {
      decodeAndValidateImage(image);
    } catch (e) {
      if (e instanceof ImageValidationError) {
        return res.status(400).json({ error: e.message });
      }
      throw e;
    }

    const prompt = `
      You are an expert at extracting professional information from photos.
      Analyze the attached image (which could be a business card, event badge, or document) and extract the contact information.

      Strict Guidelines:
      1. Identify the person's name, company, and job title from the text profile.
      2. For emails, ensure you include the domain (e.g., .com, .net) correctly.
      3. If the image is a badge, the most prominent name is usually the person.
      4. If a field is not present, return null.
      5. Return ONLY a valid JSON object.
      6. CRITICAL: Every piece of text on the card must be captured somewhere — nothing should
         be left out. Read the card top to bottom, left to right. Text that maps to a standard
         field above goes ONLY in that field. ALL remaining text MUST go into the
         "scanned_details" object — do NOT duplicate name, company, job_title, email, or the
         primary phone there.
      7. The ONLY standard fields are: first_name, last_name, name, company, email, phone,
         job_title. EVERYTHING ELSE on the card goes into "scanned_details" — this explicitly
         includes the WEBSITE and the ADDRESS (there is no dedicated field for them), as well
         as: P.O. box, fax, every additional phone number, extra emails, social handles,
         departments, taglines, office/branch locations, certifications, license numbers,
         QR code URLs, working hours, and account numbers.
      8. If there are MULTIPLE phone numbers, put the primary one in "phone" and every
         additional number in "scanned_details" (e.g. "mobile", "fax", "india_phone"). The
         same applies to extra emails — primary in "email", the rest in "scanned_details".
      9. Structure "scanned_details" properly: use clear, descriptive snake_case keys
         (e.g. "website", "address", "po_box", "fax", "mobile", "tagline") mapped to their
         exact values. Do not dump raw unlabeled text — give every value a meaningful key.
         Only return an empty object {} if there is no extra text beyond the standard fields.
    `;

    const schema = `{
      "first_name": "string",
      "last_name": "string",
      "name": "string (full name)",
      "company": "string",
      "email": "string",
      "phone": "string",
      "job_title": "string",
      "scanned_details": "object — every other field from the card (website, address, fax, extra phones/emails, etc.)"
    }`;

    const result = await litellm.analyzeImage<any>(image, prompt, schema);

    res.json({ data: result });
  } catch (error: any) {
    console.error('AI Analysis Error:', error);
    res.status(500).json({ error: error.message || 'Failed to process capture' });
  }
});

// Lightweight silence gate. Compressed speech (AAC/Opus) carries far more bytes
// per second than near-silence, so a low bytes-per-second ratio means the clip
// almost certainly contains no speech. This runs before the (paid) Gemini call
// so we never transcribe — or pay to hallucinate text for — a silent recording.
//
// Thresholds are deliberately conservative (well below real-speech bitrates) to
// avoid rejecting genuine but quiet/short speech. Decoded byte size is derived
// from the base64 length; duration comes from the client recorder.
const SILENCE_BYTES_PER_SECOND = 900; // speech is typically 4000+; silence ~1000-1500
const ABSOLUTE_MIN_BYTES = 3072;      // anything smaller can't hold real speech

function decodedByteLength(base64Audio: string): number {
  const data = base64Audio.includes(',') ? base64Audio.split(',')[1] : base64Audio;
  // Each 4 base64 chars -> 3 bytes, minus padding.
  const len = data.length;
  const padding = data.endsWith('==') ? 2 : data.endsWith('=') ? 1 : 0;
  return Math.floor((len * 3) / 4) - padding;
}

function looksSilent(base64Audio: string, durationSeconds?: number): boolean {
  const bytes = decodedByteLength(base64Audio);
  const bytesPerSecond =
    durationSeconds && durationSeconds > 0 ? Math.round(bytes / durationSeconds) : null;

  let silent = false;
  let reason = 'speech';
  if (bytes < ABSOLUTE_MIN_BYTES) {
    silent = true;
    reason = 'below-min-bytes';
  } else if (bytesPerSecond !== null && bytesPerSecond < SILENCE_BYTES_PER_SECOND) {
    silent = true;
    reason = 'low-bitrate';
  }

  // Calibration log: tune SILENCE_BYTES_PER_SECOND from real traffic by comparing
  // bytesPerSecond for clips you know contain speech vs. silence.
  console.log(
    `[transcribe] silence-gate bytes=${bytes} duration=${durationSeconds ?? 'n/a'}s ` +
    `bytesPerSecond=${bytesPerSecond ?? 'n/a'} threshold=${SILENCE_BYTES_PER_SECOND} ` +
    `decision=${silent ? 'SILENT' : 'transcribe'} reason=${reason}`
  );

  return silent;
}

// POST /api/ai/transcribe
router.post('/transcribe', async (req, res, next) => {
  try {
    const supabase = req.supabase!;
    const { audio_data, duration_seconds } = req.body;

    if (!audio_data) {
      return res.status(400).json({ error: 'Audio data is required' });
    }

    // Server-side silence gate: skip the model call for recordings that are too
    // quiet/small to contain speech. Returning an empty transcript matches the
    // NO_SPEECH path so clients handle it uniformly.
    if (looksSilent(audio_data, Number(duration_seconds) || undefined)) {
      return res.json({ transcript: '' });
    }

    const transcript = await litellm.transcribeAudio(audio_data);

    res.json({ transcript });
  } catch (error: any) {
    console.error('Transcription error:', error);
    res.status(500).json({ error: error.message || 'Failed to transcribe audio' });
  }
});

export default router;
