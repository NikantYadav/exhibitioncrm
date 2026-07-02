import { Router } from 'express';
import { sentryLog } from '../config/sentry';
import { litellm } from '../services/litellm-service';
import { supabase as supabaseAdmin } from '../config/supabase';
import { decodeAndValidateImage, ImageValidationError } from '../utils/imageValidation';
import { compressImage } from '../utils/imageCompression';
import { upsertFollowUp } from '../services/followUps';
import {
  checkScopedRateLimit,
  IMAGE_UPLOAD_SCOPE,
  IMAGE_UPLOAD_MAX,
  IMAGE_UPLOAD_WINDOW_MS,
} from '../utils/rateLimit';

const router = Router();

const CARD_BUCKET = 'contact-cards';

// Decode + validate the client-supplied image string and upload it to the
// private contact-cards bucket. Path is prefixed with the owner's user id so
// storage RLS enforces per-user isolation, and the object key is the
// server-generated capture id (never client-controlled), so path traversal is
// impossible. The stored content-type is the SNIFFED type, never the
// client-claimed one — so the bucket can never serve HTML/SVG/script.
//
// Returns the storage path on success, or null if there is no image to store.
// Throws ImageValidationError for malformed/disallowed input (caller returns 4xx).
async function uploadCardImage(
  image: string,
  userId: string,
  captureId: string,
): Promise<string | null> {
  // Already-stored references are passed through untouched by the caller.
  if (image.startsWith('http')) return null;

  const decoded = decodeAndValidateImage(image);

  // Re-encode to a capped-dimension WebP before storing — cuts Storage bytes
  // ~60-80% vs. the raw camera/gallery output with no visible quality loss.
  // Best-effort: if re-encoding fails for any reason, fall back to the
  // original validated buffer/type rather than failing the upload.
  let buffer = decoded.buffer;
  let type = decoded.type;
  try {
    const compressed = await compressImage(decoded.buffer);
    buffer = compressed.buffer;
    type = compressed.type;
  } catch (err) {
    console.error('Card image compression failed, storing original:', err);
  }

  const path = `${userId}/${captureId}.${type.ext}`;

  // Cost-instrumentation: avg_card_MB for INFRASTRUCTURE_ANALYSIS.md's
  // GB_files driver. Logs BOTH the raw client-supplied size (what the camera/
  // gallery actually produced, pre-compression) and the stored size (post
  // compressImage()) so the Sentry data answers "what do we receive" and
  // "what do we actually bill for" separately.
  void sentryLog('card_image_size', {
    raw_bytes: decoded.buffer.length,
    stored_bytes: buffer.length,
    raw_mime: decoded.type.mime,
    stored_mime: type.mime,
    compressed: buffer !== decoded.buffer,
  });

  const { error } = await supabaseAdmin.storage
    .from(CARD_BUCKET)
    .upload(path, buffer, {
      contentType: type.mime,
      upsert: true,
    });

  if (error) {
    console.error('Card image upload failed:', error.message);
    return null;
  }
  return path;
}

// POST /api/captures/voice-transcribe
router.post('/voice-transcribe', async (req, res, next) => {
  try {
    const supabase = req.supabase!;
    const { audio_data } = req.body;
    if (!audio_data) {
      return res.status(400).json({ error: 'audio_data is required' });
    }
    const transcript = await litellm.transcribeAudio(audio_data);
    res.json({ transcript });
  } catch (error) {
    console.error('Transcription error:', error);
    res.status(500).json({ error: 'Failed to transcribe audio' });
  }
});

router.get('/', async (req, res, next) => {
  try {
    const supabase = req.supabase!;
    const { event_id } = req.query;
    const userId = req.user!.id;

    let query = supabase
      .from('captures')
      .select('*')
      .eq('user_id', userId)
      .is('deleted_at', null);

    if (event_id) {
      query = query.eq('event_id', event_id);
    }

    const { data, error } = await query.order('created_at', { ascending: false });

    if (error) {
      return res.status(500).json({ error: 'Failed to fetch captures' });
    }

    res.json({ data });
  } catch (error) {
    console.error('Fetch error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/', async (req, res, next) => {
  try {
    const supabase = req.supabase!;
    const { image, capture_type, event_id, extracted_data, raw_text, meeting_context } = req.body;
    const idempotencyKey = req.headers['idempotency-key'] as string | undefined;
    const userId = req.user!.id;

    const type = capture_type || 'card_scan';

    // Throttle image uploads per user (shared budget with analyze-card). Only
    // image-bearing captures count; manual/voice captures are exempt.
    if ((type === 'card_scan' || type === 'file_scan') && image) {
      const limit = await checkScopedRateLimit(
        userId, IMAGE_UPLOAD_SCOPE, IMAGE_UPLOAD_MAX, IMAGE_UPLOAD_WINDOW_MS,
      );
      if (!limit.ok) {
        res.setHeader('Retry-After', String(limit.retryAfterSeconds));
        return res.status(429).json({ error: 'Too many image uploads. Please slow down.' });
      }
    }

    if (type === 'card_scan' || type === 'file_scan') {
      if (!image) {
        return res.status(400).json({ error: 'Image is required for card_scan and file_scan capture types' });
      }
    } else if (type === 'voice') {
      if (!raw_text) {
        return res.status(400).json({ error: 'raw_text (transcription) is required for voice captures' });
      }
    } else if (type === 'manual') {
      if (!extracted_data || !extracted_data.name) {
        return res.status(400).json({ error: 'extracted_data with at least a name is required for manual captures' });
      }
    }

    // Ownership: a capture may reference an event_id, but RLS on `captures`
    // only checks the row's own user_id — it does NOT stop a caller from
    // attaching their capture to another tenant's event. Verify ownership of
    // the referenced event explicitly before writing the foreign key.
    if (event_id) {
      const { data: ownedEvent } = await supabase
        .from('events')
        .select('id')
        .eq('id', event_id)
        .eq('user_id', userId)
        .is('deleted_at', null)
        .maybeSingle();
      if (!ownedEvent) {
        return res.status(403).json({ error: 'Forbidden' });
      }
    }

    // Idempotency: if a capture with this client_op_id already exists, return it.
    if (idempotencyKey) {
      const { data: existing } = await supabase
        .from('captures')
        .select()
        .eq('client_op_id', idempotencyKey)
        .eq('user_id', userId)
        .is('deleted_at', null)
        .maybeSingle();
      if (existing) {
        return res.json({ data: existing });
      }
    }

    // Create capture record
    const { data: capture, error } = await supabase
      .from('captures')
      .insert({
        user_id: userId,
        capture_type: type,
        event_id: event_id || null,
        image_url: image,
        raw_data: { ocr_text: raw_text || '' },
        extracted_data: extracted_data || {},
        status: 'completed',
        ...(idempotencyKey ? { client_op_id: idempotencyKey } : {}),
      })
      .select()
      .single();

    if (error) {
      console.error('Database error:', error);
      return res.status(500).json({ error: 'Failed to save capture' });
    }

    // For scans/uploads, move the base64 image out of the DB row and into the
    // private contact-cards bucket; store the storage path instead. If upload
    // fails we keep going (capture/contact still created, just without a card).
    let cardPath: string | null = null;
    if ((type === 'card_scan' || type === 'file_scan') && image) {
      try {
        cardPath = await uploadCardImage(image, userId, capture.id);
      } catch (e) {
        if (e instanceof ImageValidationError) {
          // Reject the whole request for malformed/disallowed images, and roll
          // back the just-created capture so we don't leave an orphan row.
          await supabase.from('captures').delete().eq('id', capture.id);
          return res.status(400).json({ error: e.message });
        }
        throw e;
      }
      if (cardPath) {
        await supabase
          .from('captures')
          .update({ image_url: cardPath })
          .eq('id', capture.id);
      }
    }

    // Try to create a contact from extracted data
    let contactId = null;
    const hasContactData = extracted_data && (extracted_data.first_name || extracted_data.name || extracted_data.email);

    if (!hasContactData) {
      return res.status(422).json({ error: 'Failed to find relevant data in the capture. Please try again with a clearer image.' });
    }

    try {
      const firstName = extracted_data.first_name || extracted_data.name?.split(' ')[0] || 'Unknown';
      const lastName = extracted_data.last_name || extracted_data.name?.split(' ').slice(1).join(' ') || '';

      // Fetch event name
      let eventName: string | null = null;
      if (event_id) {
        const { data: eventData } = await supabase
          .from('events')
          .select('name')
          .eq('id', event_id)
          .eq('user_id', req.user!.id)
          .is('deleted_at', null)
          .single();
        if (eventData) eventName = eventData.name;
      } else if (meeting_context?.trim()) {
        eventName = meeting_context.trim();
      }

      // Check if company exists, create if not. Companies are an admin-managed
      // shared resource (the `companies` table has no INSERT policy for the
      // user-scoped client), so the find-or-create runs through supabaseAdmin.
      let companyId = null;
      if (extracted_data.company) {
        const { data: existingCompany } = await supabaseAdmin
          .from('companies')
          .select('id')
          .ilike('name', extracted_data.company)
          .single();

        if (existingCompany) {
          companyId = existingCompany.id;
        } else {
          const { data: newCompany, error: companyError } = await supabaseAdmin
            .from('companies')
            .insert({ name: extracted_data.company })
            .select('id')
            .single();

          if (companyError || !newCompany) {
            console.error('Failed to create company:', extracted_data.company, companyError);
          } else {
            companyId = newCompany.id;
          }
        }
      }

      // Collect extra scanned fields not mapped to standard columns
      const scannedDetails = extracted_data.scanned_details && Object.keys(extracted_data.scanned_details).length > 0
        ? extracted_data.scanned_details
        : null;

      // Create contact
      const { data: contact, error: contactError } = await supabase
        .from('contacts')
        .insert({
          user_id: userId,
          first_name: firstName,
          last_name: lastName,
          email: extracted_data.email || null,
          phone: extracted_data.phone || null,
          job_title: extracted_data.job_title || extracted_data.title || null,
          linkedin_url: extracted_data.linkedin_url || null,
          company_id: companyId,
          follow_up_status: 'not_contacted',
          is_priority: extracted_data.is_priority === true,
          ...(scannedDetails ? { scanned_details: scannedDetails } : {}),
        })
        .select()
        .single();

      if (!contactError && contact) {
        contactId = contact.id;

        // Link capture to contact
        await supabase
          .from('captures')
          .update({ contact_id: contact.id })
          .eq('id', capture.id);

        // Create interaction history
        const humanCaptureType = type
          .replace(/_/g, ' ')
          .split(' ')
          .map((w: string) => w.charAt(0).toUpperCase() + w.slice(1))
          .join(' ');

        const captureDate = new Date().toISOString();

        const summary = eventName
          ? `Captured via ${humanCaptureType} at ${eventName}`
          : `Captured via ${humanCaptureType}`;

        await supabase
          .from('interactions')
          .insert({
            contact_id: contact.id,
            event_id: event_id || null,
            interaction_type: 'capture',
            interaction_date: captureDate,
            summary,
            details: {
              source: capture_type,
              note: raw_text?.trim() || null,
              event_name: eventName,
              image_url: cardPath || image
            },
            user_id: userId,
          });

        // Follow-up trigger #1: a scanned/added contact seeds a 'new' record,
        // keyed to the event it was captured at (or general if none). A capture
        // is not itself a follow-up-worthy interaction, so it stays 'new' until
        // a real interaction or target check-off promotes it to 'pending'.
        try {
          await upsertFollowUp(supabase, userId, {
            contactId: contact.id,
            eventId: event_id || null,
            seedStatus: 'new',
            // Per-event priority only when captured at an event; the contact's
            // global is_priority above covers the no-event case.
            isPriority: event_id ? extracted_data.is_priority === true : undefined,
          });
        } catch (e) {
          console.error('follow_up upsert (capture) failed:', e);
        }

        // Link to target companies
        if (event_id && companyId) {
          const { data: targetMatch } = await supabase
            .from('target_companies')
            .select('id')
            .eq('event_id', event_id)
            .eq('company_id', companyId)
            .is('deleted_at', null)
            .single();

          if (targetMatch) {
            await supabase
              .from('target_companies')
              .update({
                status: 'contacted',
                updated_at: new Date().toISOString()
              })
              .eq('id', targetMatch.id);

            console.log(`Auto-linked capture to target company: ${targetMatch.id}`);
          }
        }
      } else if (contactError) {
        console.error('Contact creation error details:', contactError);
        throw contactError;
      }
    } catch (contactError) {
      console.error('Contact creation error:', contactError);
      return res.status(500).json({ error: 'Failed to create contact from capture data. Please try again.' });
    }

    res.json({
      data: capture,
      contact_id: contactId,
      message: 'Lead captured and contact linked successfully',
    });
  } catch (error) {
    console.error('Capture error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// DELETE /api/captures/:id
router.delete('/:id', async (req, res, next) => {
  try {
    const supabase = req.supabase!;
    const { error } = await supabase
      .from('captures')
      .update({ deleted_at: new Date().toISOString() })
      .eq('id', req.params.id)
      .eq('user_id', req.user!.id);

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    res.json({ message: 'Capture deleted successfully' });
  } catch (error) {
    res.status(500).json({ error: 'Failed to delete capture' });
  }
});

export default router;
