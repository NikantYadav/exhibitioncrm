import { Router } from 'express';
import { supabase } from '../config/supabase';
import { AIService } from '../config/ai';

const router = Router();

// POST /api/emails/draft
router.post('/draft', async (req, res, next) => {
  try {
    const { contact_id, event_id, email_type, custom_context } = req.body;

    if (!contact_id || !email_type) {
      return res.status(400).json({ error: 'contact_id and email_type are required' });
    }

    // Fetch contact with company
    const { data: contact } = await supabase
      .from('contacts')
      .select('*, company:companies(*)')
      .eq('id', contact_id)
      .single();

    if (!contact) {
      return res.status(404).json({ error: 'Contact not found' });
    }

    // Fetch event if provided
    let event = null;
    if (event_id) {
      const { data } = await supabase
        .from('events')
        .select('*')
        .eq('id', event_id)
        .single();
      event = data;
    }

    // Fetch notes for context
    const { data: notes } = await supabase
      .from('notes')
      .select('*')
      .eq('contact_id', contact_id)
      .order('created_at', { ascending: false })
      .limit(5);

    // Generate email using AI
    const prompt = `Generate a professional ${email_type} email for:
Contact: ${contact.first_name} ${contact.last_name || ''}
Company: ${contact.company?.name || 'Unknown'}
Job Title: ${contact.job_title || 'Unknown'}
${event ? `Event: ${event.name}` : ''}
${custom_context ? `Additional Context: ${custom_context}` : ''}
${notes && notes.length > 0 ? `Notes: ${notes.map(n => n.content).join('; ')}` : ''}

Return JSON with "subject" and "body" fields.`;

    const emailDraft = await AIService.extractStructuredData<{ subject: string; body: string }>(
      prompt,
      '{ "subject": "string", "body": "string" }'
    );

    // Save draft to database
    const { data: savedDraft, error } = await supabase
      .from('email_drafts')
      .insert({
        contact_id,
        event_id,
        email_type,
        subject: emailDraft.subject,
        body: emailDraft.body,
        status: 'draft',
      })
      .select()
      .single();

    if (error) {
      console.error('Save draft error:', error);
    }

    res.json({
      data: emailDraft,
      draft_id: savedDraft?.id,
      message: 'Email draft generated successfully',
    });
  } catch (error) {
    console.error('Email generation error:', error);
    res.status(500).json({ error: 'Failed to generate email' });
  }
});

// POST /api/emails/improve
router.post('/improve', async (req, res, next) => {
  try {
    const { text, instructions } = req.body;

    if (!text) {
      return res.status(400).json({ error: 'Original text is required' });
    }

    const prompt = `Improve this email text:
${text}

${instructions ? `Instructions: ${instructions}` : 'Make it more professional and engaging.'}

Return the improved version.`;

    const result = await AIService.generateCompletion([
      { role: 'system', content: 'You are an expert email writer.' },
      { role: 'user', content: prompt }
    ]);

    res.json({
      data: { improved_text: result },
      message: 'Email draft improved successfully',
    });
  } catch (error) {
    console.error('Email refinement error:', error);
    res.status(500).json({ error: 'Failed to refine email' });
  }
});

// DELETE /api/emails/drafts/:id
router.delete('/drafts/:id', async (req, res, next) => {
  try {
    const { id } = req.params;

    const { error } = await supabase
      .from('email_drafts')
      .delete()
      .eq('id', id);

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    res.json({ message: 'Draft deleted successfully' });
  } catch (error) {
    res.status(500).json({ error: 'Failed to delete draft' });
  }
});

export default router;
