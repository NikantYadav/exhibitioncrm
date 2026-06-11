import { Router } from 'express';
import { supabase } from '../config/supabase';
import { requireAuth } from '../middleware/requireAuth';

const router = Router();

router.use(requireAuth);

// POST /api/interactions
router.post('/', async (req, res, next) => {
  try {
    const { contact_id, event_id, interaction_type, summary, interaction_date, details } = req.body;

    if (!contact_id) {
      return res.status(400).json({ error: 'contact_id is required' });
    }

    const { data, error } = await supabase
      .from('interactions')
      .insert({
        contact_id,
        ...(event_id ? { event_id } : {}),
        interaction_type: interaction_type || 'manual',
        summary: summary || '',
        interaction_date: interaction_date || new Date().toISOString(),
        details: details || {},
      })
      .select()
      .single();

    if (error) throw error;

    res.json({ data });
  } catch (err) {
    next(err);
  }
});

// PATCH /api/interactions/:id — used to update transcript after background processing
router.patch('/:id', async (req, res, next) => {
  try {
    const { id } = req.params;
    const updates = req.body;

    const { data, error } = await supabase
      .from('interactions')
      .update(updates)
      .eq('id', id)
      .select()
      .single();

    if (error) throw error;

    res.json({ data });
  } catch (err) {
    next(err);
  }
});

export default router;
