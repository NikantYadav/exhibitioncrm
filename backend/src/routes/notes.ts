import { Router } from 'express';
import { supabase } from '../config/supabase';

const router = Router();

router.post('/', async (req, res, next) => {
  try {
    const body = req.body;
    const noteData = { ...body };

    if (body.note_type === 'voice' && body.audio_data) {
      noteData.source_url = body.audio_data;
      delete noteData.audio_data;
    }

    const { data: note, error } = await supabase
      .from('notes')
      .insert(noteData)
      .select()
      .single();

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    // Trigger intelligent status analysis for text notes
    if (note.contact_id && note.content && note.note_type === 'text') {
      // Background analysis - don't await to avoid blocking response
      const backendUrl = process.env.BACKEND_URL || 'http://localhost:3001';
      fetch(`${backendUrl}/api/ai/analyze-note`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          noteId: note.id,
          contactId: note.contact_id,
          content: note.content
        })
      }).catch(err => console.error('Background note analysis failed:', err));
    }

    res.json({ data: note });
  } catch (error) {
    res.status(500).json({ error: 'Failed to create note' });
  }
});

router.patch('/:id', async (req, res, next) => {
  try {
    const { id, ...updateData } = req.body;

    if (!id && !req.params.id) {
      return res.status(400).json({ error: 'Note ID required' });
    }

    const noteId = id || req.params.id;

    const { data: note, error } = await supabase
      .from('notes')
      .update(updateData)
      .eq('id', noteId)
      .select()
      .single();

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    // Trigger intelligent status analysis for updated notes with content
    if (note.contact_id && note.content) {
      const backendUrl = process.env.BACKEND_URL || 'http://localhost:3001';
      fetch(`${backendUrl}/api/ai/analyze-note`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          noteId: note.id,
          contactId: note.contact_id,
          content: note.content
        })
      }).catch(err => console.error('Background note analysis failed:', err));
    }

    res.json({ data: note });
  } catch (error) {
    res.status(500).json({ error: 'Failed to update note' });
  }
});

router.delete('/:id', async (req, res, next) => {
  try {
    const { id } = req.params;

    const { error } = await supabase
      .from('notes')
      .delete()
      .eq('id', id);

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: 'Failed to delete note' });
  }
});

export default router;
