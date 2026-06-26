import { Router } from 'express';
import { z } from 'zod';
import type { SupabaseClient } from '@supabase/supabase-js';
import { requireAuth } from '../middleware/requireAuth';

const uuidSchema = z.string().uuid();

const interactionCreateSchema = z.object({
  contact_id: uuidSchema,
  event_id: uuidSchema.optional(),
  interaction_type: z.enum(['manual', 'email', 'call', 'meeting', 'capture', 'event_link', 'note', 'voice_note', 'document_upload']).optional(),
  summary: z.string().trim().max(5000).optional(),
  interaction_date: z.string().datetime().optional(),
  details: z.record(z.unknown()).optional(),
});

const interactionPatchSchema = z.object({
  summary: z.string().trim().max(5000).optional(),
  interaction_date: z.string().datetime().optional(),
  details: z.record(z.unknown()).optional(),
  interaction_type: z.enum(['manual', 'email', 'call', 'meeting', 'capture', 'event_link', 'note', 'voice_note', 'document_upload']).optional(),
});

const router = Router();

router.use(requireAuth);

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

// POST /api/interactions
router.post('/', async (req, res, next) => {
  try {
    const supabase = req.supabase!;
    const parsed = interactionCreateSchema.safeParse(req.body);
    if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });
    const { contact_id, event_id, interaction_type, summary, interaction_date, details } = parsed.data;

    if (!(await ownsContact(supabase, req.user!.id, contact_id))) {
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
    const supabase = req.supabase!;
    const parsedId = uuidSchema.safeParse(req.params.id);
    if (!parsedId.success) return res.status(400).json({ error: 'Invalid interaction id' });

    const parsedBody = interactionPatchSchema.safeParse(req.body);
    if (!parsedBody.success) return res.status(400).json({ error: parsedBody.error.flatten() });

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

    if (existing.contact_id && !(await ownsContact(supabase, req.user!.id, existing.contact_id))) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const { data, error } = await supabase
      .from('interactions')
      .update(parsedBody.data)
      .eq('id', id)
      .select()
      .single();

    if (error) throw error;

    res.json({ data });
  } catch (err) {
    next(err);
  }
});

// DELETE /api/interactions/:id — soft-delete. Used to drop a voice-note
// interaction when transcription finds no speech (nothing worth keeping).
router.delete('/:id', async (req, res, next) => {
  try {
    const supabase = req.supabase!;
    const parsedId = uuidSchema.safeParse(req.params.id);
    if (!parsedId.success) return res.status(400).json({ error: 'Invalid interaction id' });

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

    if (existing.contact_id && !(await ownsContact(supabase, req.user!.id, existing.contact_id))) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const { error } = await supabase
      .from('interactions')
      .update({ deleted_at: new Date().toISOString() })
      .eq('id', id);

    if (error) throw error;

    res.json({ success: true });
  } catch (err) {
    next(err);
  }
});

export default router;
