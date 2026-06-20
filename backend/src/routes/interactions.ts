import { Router } from 'express';
import { supabase } from '../config/supabase';
import { requireAuth } from '../middleware/requireAuth';

const router = Router();

router.use(requireAuth);

async function ownsContact(userId: string, contactId: string): Promise<boolean> {
  const { data } = await supabase
    .from('contacts')
    .select('id')
    .eq('id', contactId)
    .eq('user_id', userId)
    .is('deleted_at', null)
    .maybeSingle();
  return data !== null;
}

// POST /api/interactions
router.post('/', async (req, res, next) => {
  try {
    const { contact_id, event_id, interaction_type, summary, interaction_date, details } = req.body;

    if (!contact_id) {
      return res.status(400).json({ error: 'contact_id is required' });
    }

    if (!(await ownsContact(req.user!.id, contact_id))) {
      return res.status(403).json({ error: 'Forbidden' });
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
        user_id: req.user!.id,
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

    // Verify the interaction belongs to the user via its contact.
    const { data: existing } = await supabase
      .from('interactions')
      .select('contact_id')
      .eq('id', id)
      .is('deleted_at', null)
      .maybeSingle();

    if (!existing) {
      return res.status(404).json({ error: 'Interaction not found' });
    }

    if (existing.contact_id && !(await ownsContact(req.user!.id, existing.contact_id))) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const { data, error } = await supabase
      .from('interactions')
      .update(req.body)
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
