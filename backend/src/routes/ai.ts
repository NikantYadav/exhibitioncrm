import { Router } from 'express';
import { litellm } from '../services/litellm-service';

const router = Router();

// POST /api/ai/analyze-card
router.post('/analyze-card', async (req, res, next) => {
  try {
    const supabase = req.supabase!;
    const image: string | undefined = req.body?.image ?? req.body?.imageData;

    if (!image) {
      return res.status(400).json({ error: 'Image is required' });
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
      6. Capture ALL other text/details visible on the card that don't fit the standard fields
         (e.g. fax numbers, multiple phones, social handles, departments, taglines, office locations,
         certifications, QR code URLs, alternate emails, etc.) in the "scanned_details" object as
         key-value pairs. Use short descriptive keys. If nothing extra, return an empty object {}.
    `;

    const schema = `{
      "first_name": "string",
      "last_name": "string",
      "name": "string (full name)",
      "company": "string",
      "email": "string",
      "phone": "string",
      "job_title": "string",
      "website": "string",
      "address": "string",
      "scanned_details": "object — all extra fields from the card that don't fit above"
    }`;

    const result = await litellm.analyzeImage<any>(image, prompt, schema);

    res.json({ data: result });
  } catch (error: any) {
    console.error('AI Analysis Error:', error);
    res.status(500).json({ error: error.message || 'Failed to process capture' });
  }
});

// POST /api/ai/transcribe
router.post('/transcribe', async (req, res, next) => {
  try {
    const supabase = req.supabase!;
    const { audio_data } = req.body;

    if (!audio_data) {
      return res.status(400).json({ error: 'Audio data is required' });
    }

    const transcript = await litellm.transcribeAudio(audio_data);

    res.json({ transcript });
  } catch (error: any) {
    console.error('Transcription error:', error);
    res.status(500).json({ error: error.message || 'Failed to transcribe audio' });
  }
});

export default router;
