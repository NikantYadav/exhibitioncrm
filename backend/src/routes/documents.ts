import { Router } from 'express';
import { supabase } from '../config/supabase';
import { AIService } from '../config/ai';

const router = Router();

router.post('/', async (req, res, next) => {
  try {
    const { contact_id, name, file_url, description } = req.body;

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
      }
    });

    res.json({ success: true, document: { ...doc, summary } });
  } catch (error) {
    console.error('Documents API error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/', async (req, res, next) => {
  try {
    const { contact_id } = req.query;

    if (!contact_id) {
      return res.status(400).json({ error: 'Contact ID required' });
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
    const { document_id, content } = req.body;

    if (!content) {
      return res.status(400).json({ error: 'Content required' });
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
