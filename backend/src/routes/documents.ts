import { Router } from 'express';
import type { SupabaseClient } from '@supabase/supabase-js';
import { AIService } from '../config/ai';

const router = Router();

async function ownsContact(db: SupabaseClient, userId: string, contactId: string): Promise<boolean> {
  const { data } = await db
    .from('contacts')
    .select('id')
    .eq('id', contactId)
    .eq('user_id', userId)
    .is('deleted_at', null)
    .maybeSingle();
  return data !== null;
}

router.post('/', async (req, res, next) => {
  try {
    const supabase = req.supabase!;
    const { contact_id, name, file_url, description } = req.body;

    if (contact_id && !(await ownsContact(supabase, req.user!.id, contact_id))) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    // Save document record
    const { data: doc, error } = await supabase
      .from('contact_documents')
      .insert({
        contact_id,
        name,
        file_url,
        description,
        file_type: 'pdf'
      })
      .select()
      .single();

    if (error) {
      console.error('Doc save error:', error);
      return res.status(500).json({ error: 'Failed to save document' });
    }

    // Generate summary (simplified)
    const summary = `Document: ${name}`;

    // Update doc with summary
    await supabase
      .from('contact_documents')
      .update({ summary })
      .eq('id', doc.id);

    // Log interaction
    await supabase.from('interactions').insert({
      contact_id,
      interaction_type: 'document_upload',
      summary: `Shared Document: ${name}`,
      details: {
        document_id: doc.id,
        file_url
      },
      user_id: req.user!.id,
    });

    res.json({ success: true, document: { ...doc, summary } });
  } catch (error) {
    console.error('Documents API error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/', async (req, res, next) => {
  try {
    const supabase = req.supabase!;
    const { contact_id } = req.query;

    if (!contact_id) {
      return res.status(400).json({ error: 'Contact ID required' });
    }

    if (!(await ownsContact(supabase, req.user!.id, contact_id as string))) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const { data: documents, error } = await supabase
      .from('contact_documents')
      .select('*')
      .eq('contact_id', contact_id)
      .order('created_at', { ascending: false });

    if (error) {
      return res.status(500).json({ error: 'Failed to fetch' });
    }

    res.json({ documents });
  } catch (error) {
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /api/documents/summarize
router.post('/summarize', async (req, res, next) => {
  try {
    const supabase = req.supabase!;
    const { document_id, content } = req.body;

    if (!content) {
      return res.status(400).json({ error: 'Content required' });
    }

    // Verify ownership when a document_id is provided.
    if (document_id) {
      const { data: doc } = await supabase
        .from('contact_documents')
        .select('contact_id')
        .eq('id', document_id)
        .maybeSingle();

      if (!doc) {
        return res.status(404).json({ error: 'Document not found' });
      }

      if (doc.contact_id && !(await ownsContact(supabase, req.user!.id, doc.contact_id))) {
        return res.status(403).json({ error: 'Forbidden' });
      }
    }

    const prompt = `Summarize this document in 2-3 sentences:\n\n${content}`;

    const summary = await AIService.generateCompletion([
      { role: 'system', content: 'You are a document summarization assistant.' },
      { role: 'user', content: prompt }
    ]);

    if (document_id) {
      await supabase
        .from('contact_documents')
        .update({ summary })
        .eq('id', document_id);
    }

    res.json({ success: true, summary });
  } catch (error) {
    console.error('Summarize error:', error);
    res.status(500).json({ error: 'Failed to summarize document' });
  }
});

export default router;
