import { Router } from 'express';
import { supabase } from '../config/supabase';

const router = Router();

async function ownsContact(userId: string, contactId: string): Promise<boolean> {
  const { data } = await supabase
    .from('contacts')
    .select('id')
    .eq('id', contactId)
    .eq('user_id', userId)
    .maybeSingle();
  return data !== null;
}

router.post('/', async (req, res, next) => {
  try {
    const { contact_id, file_url, file_name, file_type } = req.body;

    if (contact_id && !(await ownsContact(req.user!.id, contact_id))) {
      return res.status(403).json({ error: 'Forbidden' });
    }

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

    if (!(await ownsContact(req.user!.id, contact_id as string))) {
      return res.status(403).json({ error: 'Forbidden' });
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
