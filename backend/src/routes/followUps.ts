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
    .maybeSingle();
  return data !== null;
}

async function ownsInteraction(userId: string, interactionId: string): Promise<boolean> {
  const { data } = await supabase
    .from('interactions')
    .select('contact_id, contacts!inner(user_id)')
    .eq('id', interactionId)
    .maybeSingle();
  if (!data) return false;
  const contact = (data as any).contacts;
  return Array.isArray(contact)
    ? contact.some((c: any) => c.user_id === userId)
    : contact?.user_id === userId;
}

router.get('/', async (req, res, next) => {
  try {
    const { event_id, status } = req.query;
    const userId = req.user!.id;

    let query;

    if (event_id) {
      query = supabase
        .from('contacts')
        .select(`
          *,
          company:companies(*),
          interactions!inner(id, event_id, interaction_type, interaction_date),
          notes(id, event_id, created_at),
          email_drafts(*)
        `)
        .eq('user_id', userId)
        .eq('interactions.event_id', event_id);
    } else {
      query = supabase
        .from('contacts')
        .select(`
          *,
          company:companies(*),
          interactions(id, interaction_type, event_id, interaction_date),
          notes(id, event_id, created_at),
          email_drafts(*)
        `)
        .eq('user_id', userId);
    }

    const { data: contacts, error } = await query.order('created_at', { ascending: false });

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    const categorized = {
      not_contacted: [] as any[],
      followed_up: [] as any[],
      needs_followup: [] as any[]
    };

    contacts?.forEach(contact => {
      const drafts = contact.email_drafts || [];
      const sentDrafts = drafts.filter((d: any) =>
        d.status === 'sent' && (!event_id || d.event_id === event_id)
      );

      const interactionList = (contact.interactions as any[]) || [];
      const noteList = (contact.notes as any[]) || [];

      const dates: string[] = [];
      interactionList.forEach((i: any) => i.interaction_date && dates.push(i.interaction_date));
      noteList.forEach((n: any) => n.created_at && dates.push(n.created_at));
      sentDrafts.forEach((d: any) => d.sent_at && dates.push(d.sent_at));

      const lastInteraction = dates.length > 0
        ? dates.reduce((latest, current) => {
            return new Date(current) > new Date(latest) ? current : latest;
          })
        : null;

      (contact as any).last_interaction = lastInteraction;

      const interactionCount = interactionList.length + noteList.length;

      if (contact.follow_up_status) {
        if (contact.follow_up_status === 'followed_up') categorized.followed_up.push(contact);
        else if (contact.follow_up_status === 'needs_followup' || contact.follow_up_status === 'needs_follow_up') categorized.needs_followup.push(contact);
        else categorized.not_contacted.push(contact);
      } else if (sentDrafts.length > 0) {
        categorized.followed_up.push(contact);
      } else if (interactionCount > 0) {
        categorized.needs_followup.push(contact);
      } else {
        categorized.not_contacted.push(contact);
      }
    });

    res.json({ data: categorized });
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch follow-ups' });
  }
});

router.post('/', async (req, res, next) => {
  try {
    const body = req.body;

    if (body.contact_id && !(await ownsContact(req.user!.id, body.contact_id))) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const { data, error } = await supabase
      .from('interactions')
      .insert({
        contact_id: body.contact_id,
        interaction_type: 'email',
        interaction_date: new Date().toISOString(),
        summary: body.summary || 'Follow-up email',
        details: body.details
      })
      .select()
      .single();

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    res.json({ data });
  } catch (error) {
    res.status(500).json({ error: 'Failed to create follow-up' });
  }
});

router.put('/:id', async (req, res, next) => {
  try {
    const { id } = req.params;

    if (!(await ownsInteraction(req.user!.id, id))) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const { data, error } = await supabase
      .from('interactions')
      .update(req.body)
      .eq('id', id)
      .select()
      .single();

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    res.json({ data });
  } catch (error) {
    res.status(500).json({ error: 'Failed to update follow-up' });
  }
});

router.delete('/:id', async (req, res, next) => {
  try {
    const { id } = req.params;

    if (!(await ownsInteraction(req.user!.id, id))) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const { error } = await supabase
      .from('interactions')
      .delete()
      .eq('id', id);

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    res.json({ message: 'Follow-up deleted successfully' });
  } catch (error) {
    res.status(500).json({ error: 'Failed to delete follow-up' });
  }
});

export default router;
