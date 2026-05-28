import { Router } from 'express';
import { supabase } from '../config/supabase';

const router = Router();

router.post('/', async (req, res, next) => {
  try {
    const { contact_id, file_url, file_name, file_type } = req.body;

    const { data, error } = await supabase
      .from('attachments')
      .insert({
        contact_id,
        file_url,
        file_name,
        file_type
      })
      .select()
      .single();

    if (error) {
      return res.status(500).json({ error: 'Failed to save attachment' });
    }

    res.json({ data });
  } catch (error) {
    console.error('Attachments error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/', async (req, res, next) => {
  try {
    const { contact_id } = req.query;

    if (!contact_id) {
      return res.status(400).json({ error: 'Contact ID required' });
    }

    const { data, error } = await supabase
      .from('attachments')
      .select('*')
      .eq('contact_id', contact_id)
      .order('created_at', { ascending: false });

    if (error) {
      return res.status(500).json({ error: 'Failed to fetch attachments' });
    }

    res.json({ data });
  } catch (error) {
    res.status(500).json({ error: 'Internal server error' });
  }
});

export default router;
