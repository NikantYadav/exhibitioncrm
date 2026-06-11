import { Router } from 'express';
import { supabase } from '../config/supabase';
import { litellm } from '../services/litellm-service';
import { requireAuth } from '../middleware/requireAuth';

const router = Router();

// POST /api/captures/voice-transcribe
router.post('/voice-transcribe', async (req, res, next) => {
  try {
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
    const { event_id } = req.query;

    let query = supabase
      .from('captures')
      .select('*');

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

router.post('/', requireAuth, async (req, res, next) => {
  try {
    const { image, capture_type, event_id, extracted_data, raw_text } = req.body;
    const userId = req.user!.id;

    const type = capture_type || 'card_scan';

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

    // Create capture record
    const { data: capture, error } = await supabase
      .from('captures')
      .insert({
        capture_type: type,
        event_id: event_id || null,
        image_url: image,
        raw_data: { ocr_text: raw_text || '' },
        extracted_data: extracted_data || {},
        status: 'completed',
      })
      .select()
      .single();

    if (error) {
      console.error('Database error:', error);
      return res.status(500).json({ error: 'Failed to save capture' });
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
      let eventName = 'an event';
      if (event_id) {
        const { data: eventData } = await supabase
          .from('events')
          .select('name')
          .eq('id', event_id)
          .single();
        if (eventData) eventName = eventData.name;
      }

      // Check if company exists, create if not
      let companyId = null;
      if (extracted_data.company) {
        const { data: existingCompany } = await supabase
          .from('companies')
          .select('id')
          .ilike('name', extracted_data.company)
          .single();

        if (existingCompany) {
          companyId = existingCompany.id;
        } else {
          const { data: newCompany } = await supabase
            .from('companies')
            .insert({ name: extracted_data.company })
            .select('id')
            .single();

          if (newCompany) companyId = newCompany.id;
        }
      }

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
          notes: `${raw_text}\n\n[System Note: Captured at ${eventName}]`,
          follow_up_status: 'not_contacted',
          follow_up_urgency: null
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

        await supabase
          .from('interactions')
          .insert({
            contact_id: contact.id,
            event_id: event_id || null,
            interaction_type: 'capture',
            interaction_date: captureDate,
            summary: `Captured via ${humanCaptureType} at ${eventName}`,
            details: {
              source: capture_type,
              note: raw_text?.trim() || null,
              event_name: eventName,
              image_url: image
            }
          });

        // Link to target companies
        if (event_id && companyId) {
          const { data: targetMatch } = await supabase
            .from('target_companies')
            .select('id')
            .eq('event_id', event_id)
            .eq('company_id', companyId)
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
    const { error } = await supabase
      .from('captures')
      .delete()
      .eq('id', req.params.id);

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    res.json({ message: 'Capture deleted successfully' });
  } catch (error) {
    res.status(500).json({ error: 'Failed to delete capture' });
  }
});

export default router;
