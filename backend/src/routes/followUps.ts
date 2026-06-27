import { Router } from 'express';
import { z } from 'zod';
import type { SupabaseClient } from '@supabase/supabase-js';
import { requireAuth } from '../middleware/requireAuth';
import { syncContactStatus } from '../services/followUps';

const router = Router();
router.use(requireAuth);

// Mutable fields a follow-up PUT may touch. Prevents mass-assignment of
// ownership/foreign-key columns (contact_id, event_id, user_id, id).
const followUpUpdateSchema = z.object({
  summary: z.string().trim().max(2000).optional(),
  details: z.any().optional(),
  interaction_type: z.string().trim().max(50).optional(),
  interaction_date: z.string().optional(),
}).strict();

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

async function ownsInteraction(db: SupabaseClient, userId: string, interactionId: string): Promise<boolean> {
  const { data } = await db
    .from('interactions')
    .select('contact_id, contacts!inner(user_id)')
    .eq('id', interactionId)
    .is('deleted_at', null)
    .maybeSingle();
  if (!data) return false;
  const contact = (data as any).contacts;
  return Array.isArray(contact)
    ? contact.some((c: any) => c.user_id === userId)
    : contact?.user_id === userId;
}

// GET /api/follow-ups            -> global pool, collapsed to one entry per contact
// GET /api/follow-ups?event_id=X -> flat list of records tagged to event X
//
// Reads the unified follow_ups table. Each record is (contact, event); a contact
// may have several. The home view collapses them to one row per contact (the
// most-urgent status wins) with the per-event breakdown nested under `records`.
//
// status buckets in the response (back-compat with the existing client):
//   not_contacted = 'new'      (just scanned, not yet engaged)
//   needs_followup = 'pending' (follow-up owed)
//   followed_up    = 'done'
//   skipped        = 'skipped' (only surfaced on the event view)
router.get('/', async (req, res, next) => {
  try {
    const supabase = req.supabase!;
    const { event_id } = req.query;
    const userId = req.user!.id;

    let fq = supabase
      .from('follow_ups')
      .select(`
        id, contact_id, event_id, status, channel, last_interaction_at, done_at, updated_at,
        contact:contacts!inner(*, company:companies(*)),
        event:events(id, name)
      `)
      .eq('user_id', userId)
      .is('deleted_at', null)
      .is('contact.deleted_at', null);

    if (event_id) fq = fq.eq('event_id', event_id);

    const { data: rows, error } = await fq.order('updated_at', { ascending: false });
    if (error) return res.status(400).json({ error: error.message });

    // Status ordering for "most urgent wins" when collapsing per contact.
    const rank: Record<string, number> = { pending: 3, new: 2, skipped: 1, done: 0 };

    // Attach the most-recent interaction summary per (contact, event) so each
    // follow-up record can show its last interaction detail. One batched query
    // over the involved contacts, reduced to the latest summary per key.
    const contactIds = [...new Set((rows || []).map((r: any) => r.contact_id))];
    const latestByKey = new Map<string, { summary: string | null; note: string | null; type: string | null; date: string | null }>();
    if (contactIds.length > 0) {
      let iq = supabase
        .from('interactions')
        .select('contact_id, event_id, summary, interaction_type, interaction_date, details')
        .in('contact_id', contactIds)
        .is('deleted_at', null)
        .order('interaction_date', { ascending: false });
      if (event_id) iq = iq.eq('event_id', event_id);
      const { data: ints } = await iq;
      // key = `${contact_id}|${event_id ?? ''}`. Rows are date-desc, so the
      // first one seen for a key is the latest — keep it, ignore the rest.
      for (const i of ints || []) {
        const key = `${i.contact_id}|${i.event_id ?? ''}`;
        if (!latestByKey.has(key)) {
          const note = typeof i.details?.note === 'string' ? i.details.note.trim() : '';
          latestByKey.set(key, {
            summary: i.summary ?? null,
            note: note || null,
            type: i.interaction_type ?? null,
            date: i.interaction_date ?? null,
          });
        }
      }
    }

    // Shape a single follow_up row into the contact-centric object the client
    // renders, carrying follow-up fields onto the contact for back-compat.
    const shape = (r: any) => {
      const last = latestByKey.get(`${r.contact_id}|${r.event_id ?? ''}`);
      const eventName = r.event?.name ?? null;
      // The event name is already shown as its own label on the card, so don't
      // repeat it in the subtitle. Prefer the user's note; otherwise fall back
      // to the interaction summary with a trailing " at {event}" stripped off.
      let subtitle = last?.summary ?? null;
      if (last?.note) {
        subtitle = last.note;
      } else if (subtitle && eventName && subtitle.endsWith(` at ${eventName}`)) {
        subtitle = subtitle.slice(0, subtitle.length - ` at ${eventName}`.length);
      }
      return {
        ...r.contact,
        follow_up_id: r.id,
        follow_up_status: r.status,
        event_id: r.event_id,
        event_name: eventName,
        channel: r.channel,
        last_interaction: r.last_interaction_at,
        last_interaction_summary: subtitle,
        last_interaction_type: last?.type ?? null,
        last_interaction_date: last?.date ?? r.last_interaction_at,
        done_at: r.done_at,
      };
    };

    if (event_id) {
      // Event view: flat, one card per record.
      const bucket = { not_contacted: [] as any[], followed_up: [] as any[], needs_followup: [] as any[], skipped: [] as any[] };
      (rows || []).forEach((r: any) => {
        const c = shape(r);
        if (r.status === 'done') bucket.followed_up.push(c);
        else if (r.status === 'pending') bucket.needs_followup.push(c);
        else if (r.status === 'skipped') bucket.skipped.push(c);
        else bucket.not_contacted.push(c);
      });
      return res.json({ data: bucket });
    }

    // Home view: collapse to one entry per contact. The winning record (highest
    // rank) drives the card's status; every record is kept under `records` so
    // the UI can expand the per-event breakdown.
    const byContact = new Map<string, { best: any; records: any[] }>();
    (rows || []).forEach((r: any) => {
      const entry = byContact.get(r.contact_id) ?? { best: null, records: [] };
      entry.records.push(shape(r));
      if (!entry.best || rank[r.status] > rank[entry.best.status]) entry.best = r;
      byContact.set(r.contact_id, entry);
    });

    const categorized = { not_contacted: [] as any[], followed_up: [] as any[], needs_followup: [] as any[], skipped: [] as any[] };
    for (const { best, records } of byContact.values()) {
      const card = { ...shape(best), records };
      if (best.status === 'done') categorized.followed_up.push(card);
      else if (best.status === 'pending') categorized.needs_followup.push(card);
      else if (best.status === 'skipped') categorized.skipped.push(card);
      else categorized.not_contacted.push(card);
    }

    res.json({ data: categorized });
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch follow-ups' });
  }
});

// Mutate a follow-up record's status directly. Used by the home screen's
// "Followed Up" / "Undo" and the Skipped section. Body: { status, event_id? }.
// Without event_id, applies to ALL of the contact's records (the collapsed-home
// case) so the card flips as a unit.
router.patch('/contact/:contactId', async (req, res) => {
  try {
    const supabase = req.supabase!;
    const userId = req.user!.id;
    const { contactId } = req.params;
    const parsed = z.object({
      status: z.enum(['new', 'pending', 'done', 'skipped']),
      event_id: z.string().uuid().nullable().optional(),
    }).safeParse(req.body);
    if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });

    const { status } = parsed.data;
    const now = new Date().toISOString();
    let q = supabase
      .from('follow_ups')
      .update({ status, done_at: status === 'done' ? now : null })
      .eq('user_id', userId)
      .eq('contact_id', contactId)
      .is('deleted_at', null);

    if (parsed.data.event_id !== undefined) {
      q = parsed.data.event_id === null ? q.is('event_id', null) : q.eq('event_id', parsed.data.event_id);
    }

    const { error } = await q;
    if (error) return res.status(400).json({ error: error.message });

    // Undo (→ pending): remove the follow-up-completion interaction(s) that were
    // logged when the user marked this done, so the timeline no longer shows a
    // "Followed up via …" entry for a follow-up that's no longer done. Scoped to
    // the same (contact, event) and only the flagged completion logs.
    if (status === 'pending') {
      let del = supabase
        .from('interactions')
        .update({ deleted_at: now })
        .eq('user_id', userId)
        .eq('contact_id', contactId)
        .is('deleted_at', null)
        .eq('details->>follow_up_log', 'true');
      if (parsed.data.event_id !== undefined) {
        del = parsed.data.event_id === null ? del.is('event_id', null) : del.eq('event_id', parsed.data.event_id);
      }
      await del;
    }

    await syncContactStatus(supabase, userId, contactId);
    res.json({ message: 'Follow-up updated' });
  } catch (error) {
    res.status(500).json({ error: 'Failed to update follow-up' });
  }
});

router.post('/', async (req, res, next) => {
  try {
    const supabase = req.supabase!;
    const body = req.body;

    if (body.contact_id && !(await ownsContact(supabase, req.user!.id, body.contact_id))) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const { data, error } = await supabase
      .from('interactions')
      .insert({
        contact_id: body.contact_id,
        interaction_type: 'email',
        interaction_date: new Date().toISOString(),
        summary: body.summary || 'Follow-up email',
        details: body.details,
        user_id: req.user!.id,
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
    const supabase = req.supabase!;
    const { id } = req.params;

    if (!(await ownsInteraction(supabase, req.user!.id, id))) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const parsed = followUpUpdateSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: parsed.error.flatten() });
    }

    const { data, error } = await supabase
      .from('interactions')
      .update(parsed.data)
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
    const supabase = req.supabase!;
    const { id } = req.params;

    if (!(await ownsInteraction(supabase, req.user!.id, id))) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const { error } = await supabase
      .from('interactions')
      .update({ deleted_at: new Date().toISOString() })
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
