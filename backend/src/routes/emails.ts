import { Router } from 'express';
import { supabase } from '../config/supabase';
import { AIService } from '../config/ai';
import { requireAuth } from '../middleware/requireAuth';

const router = Router();
router.use(requireAuth);

// POST /api/emails/draft
router.post('/draft', async (req, res, next) => {
  try {
    const { contact_id, event_id, email_type, custom_context } = req.body;

    if (!contact_id || !email_type) {
      return res.status(400).json({ error: 'contact_id and email_type are required' });
    }

    const userId = req.user!.id;

    // Fetch contact with company — scoped to this user
    const { data: contact } = await supabase
      .from('contacts')
      .select('*, company:companies(*)')
      .eq('id', contact_id)
      .eq('user_id', userId)
      .is('deleted_at', null)
      .single();

    if (!contact) {
      return res.status(404).json({ error: 'Contact not found' });
    }

    // Fetch event if provided — scoped to this user
    let event = null;
    if (event_id) {
      const { data } = await supabase
        .from('events')
        .select('*')
        .eq('id', event_id)
        .eq('user_id', userId)
        .is('deleted_at', null)
        .single();
      event = data;
    }

    const { data: userProfile } = await supabase
      .from('user_profiles')
      .select('name, designation, products_services, value_proposition, additional_context, ai_tone')
      .eq('user_id', userId)
      .maybeSingle();

    const tone = userProfile?.ai_tone ?? 'professional';
    const senderLines = [
      userProfile?.name        && `Sender name: ${userProfile.name}`,
      userProfile?.designation && `Sender role: ${userProfile.designation}`,
      userProfile?.products_services  && `Products/Services: ${userProfile.products_services}`,
      userProfile?.value_proposition  && `Value proposition: ${userProfile.value_proposition}`,
      userProfile?.additional_context && `Additional context: ${userProfile.additional_context}`,
    ].filter(Boolean).join('\n');

    const prompt = `Generate a ${tone} ${email_type} email.

Recipient:
- Name: ${contact.first_name} ${contact.last_name || ''}
- Company: ${contact.company?.name || 'Unknown'}
- Job Title: ${contact.job_title || 'Unknown'}
${event ? `- Met at event: ${event.name}` : ''}
${custom_context ? `- Extra context: ${custom_context}` : ''}

${senderLines ? `About the sender (you are writing on their behalf):\n${senderLines}` : ''}

Write a natural, personalised email that reflects the sender's voice and offering. Return JSON with "subject" and "body" fields.`;

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
        user_id: userId,
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

    const { data: improveProfile } = await supabase
      .from('user_profiles')
      .select('ai_tone, name, designation')
      .eq('user_id', req.user!.id)
      .maybeSingle();
    const improveTone = improveProfile?.ai_tone ?? 'professional';

    const result = await AIService.generateCompletion([
      { role: 'system', content: `You are an expert email writer. Write in a ${improveTone} tone${improveProfile?.name ? ` on behalf of ${improveProfile.name}${improveProfile.designation ? `, ${improveProfile.designation}` : ''}` : ''}.` },
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

    // Verify ownership via the linked contact.
    const { data: draft } = await supabase
      .from('email_drafts')
      .select('contact_id, contacts!inner(user_id)')
      .eq('id', id)
      .is('deleted_at', null)
      .maybeSingle();

    if (!draft) {
      return res.status(404).json({ error: 'Draft not found' });
    }

    const contact = (draft as any).contacts;
    const contactUserId = Array.isArray(contact) ? contact[0]?.user_id : contact?.user_id;
    if (contactUserId !== req.user!.id) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const { error } = await supabase
      .from('email_drafts')
      .update({ deleted_at: new Date().toISOString() })
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
