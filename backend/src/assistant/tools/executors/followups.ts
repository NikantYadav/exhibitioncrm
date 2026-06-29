import { z } from 'zod';
import { supabase as supabaseAdmin } from '../../../config/supabase';
import { toIso } from '../validation';
import { resolveContactId, resolveEventId } from '../resolvers';
import { upsertFollowUp, syncContactStatus } from '../../../services/followUps';

export async function execLogInteraction(args: Record<string, unknown>, userId: string) {
  const a = z.object({
    contact_id: z.string().uuid().optional(),
    contact_name: z.string().trim().optional(),
    event_id: z.string().uuid().optional(),
    event_name: z.string().trim().optional(),
    interaction_type: z.enum(['call', 'meeting', 'note', 'manual', 'email']).optional(),
    summary: z.string().trim().max(5000).optional(),
    interaction_date: z.any().optional(),
  }).refine((v) => !!(v.contact_id || v.contact_name), {
    message: 'Either contact_id or contact_name is required.',
  }).parse(args);

  const contactId = await resolveContactId(a, userId);
  const eventId = (a.event_id || a.event_name)
    ? await resolveEventId({ event_id: a.event_id, event_name: a.event_name }, userId)
    : null;

  const interactionType = a.interaction_type ?? 'note';
  const { data, error } = await supabaseAdmin
    .from('interactions')
    .insert({
      contact_id: contactId,
      ...(eventId ? { event_id: eventId } : {}),
      interaction_type: interactionType,
      summary: a.summary ?? '',
      interaction_date: a.interaction_date ? toIso(a.interaction_date, 'interaction_date') : new Date().toISOString(),
      details: {},
      user_id: userId,
    })
    .select('*').single();
  if (error) throw new Error(error.message);

  // Promote the follow-up to pending (reopening done/skipped). 'capture' is not a
  // follow-up-worthy touch, but it isn't an option here, so every logged
  // interaction counts. Best-effort: never fail the log on a follow-up hiccup.
  try {
    await upsertFollowUp(supabaseAdmin, userId, {
      contactId,
      eventId,
      seedStatus: 'pending',
      touchInteraction: true,
    });
  } catch (e) {
    console.error('[assistant] follow_up upsert (log_interaction) failed:', e);
  }

  return data;
}

// Mirrors PATCH /api/follow-ups/contact/:contactId. With an event, scopes to that
// (contact, event) record; without one, applies to ALL the contact's records.
// On reopen (-> pending) it removes the follow-up-completion interaction logs, as
// the route does, then syncs the legacy contacts.follow_up_status.
export async function execSetFollowUpStatus(args: Record<string, unknown>, userId: string) {
  const a = z.object({
    contact_id: z.string().uuid().optional(),
    contact_name: z.string().trim().optional(),
    event_id: z.string().uuid().optional(),
    event_name: z.string().trim().optional(),
    status: z.enum(['new', 'pending', 'done', 'skipped']),
  }).refine((v) => !!(v.contact_id || v.contact_name), {
    message: 'Either contact_id or contact_name is required.',
  }).parse(args);

  const contactId = await resolveContactId(a, userId);
  const scoped = !!(a.event_id || a.event_name);
  const eventId = scoped
    ? await resolveEventId({ event_id: a.event_id, event_name: a.event_name }, userId)
    : null;

  const now = new Date().toISOString();
  let q = supabaseAdmin
    .from('follow_ups')
    .update({ status: a.status, done_at: a.status === 'done' ? now : null })
    .eq('user_id', userId)
    .eq('contact_id', contactId)
    .is('deleted_at', null);
  if (scoped) q = q.eq('event_id', eventId as string);
  const { error } = await q;
  if (error) throw new Error(error.message);

  if (a.status === 'pending') {
    let del = supabaseAdmin
      .from('interactions')
      .update({ deleted_at: now })
      .eq('user_id', userId)
      .eq('contact_id', contactId)
      .is('deleted_at', null)
      .eq('details->>follow_up_log', 'true');
    if (scoped) del = del.eq('event_id', eventId as string);
    await del;
  }

  await syncContactStatus(supabaseAdmin, userId, contactId);
  return { contact_id: contactId, event_id: eventId, status: a.status, scope: scoped ? 'event' : 'all' };
}

// Mirrors PATCH /api/follow-ups/contact/:contactId/priority. With an event_id it
// flips the per-event follow_ups.is_priority; without one it flips the global
// contacts.is_priority (the app's split priority model).
export async function execSetFollowUpPriority(args: Record<string, unknown>, userId: string) {
  const a = z.object({
    contact_id: z.string().uuid().optional(),
    contact_name: z.string().trim().optional(),
    event_id: z.string().uuid().optional(),
    event_name: z.string().trim().optional(),
    is_priority: z.boolean(),
  }).refine((v) => !!(v.contact_id || v.contact_name), {
    message: 'Either contact_id or contact_name is required.',
  }).parse(args);

  const contactId = await resolveContactId(a, userId);
  const scoped = !!(a.event_id || a.event_name);
  const now = new Date().toISOString();

  if (scoped) {
    const eventId = await resolveEventId({ event_id: a.event_id, event_name: a.event_name }, userId);
    const { error } = await supabaseAdmin
      .from('follow_ups')
      .update({ is_priority: a.is_priority, updated_at: now })
      .eq('user_id', userId)
      .eq('contact_id', contactId)
      .eq('event_id', eventId)
      .is('deleted_at', null);
    if (error) throw new Error(error.message);
    return { contact_id: contactId, event_id: eventId, is_priority: a.is_priority, scope: 'event' };
  }

  const { error } = await supabaseAdmin
    .from('contacts')
    .update({ is_priority: a.is_priority, updated_at: now })
    .eq('user_id', userId)
    .eq('id', contactId);
  if (error) throw new Error(error.message);
  return { contact_id: contactId, is_priority: a.is_priority, scope: 'global' };
}

// Ownership guards for directly-supplied UUIDs. resolveContactId/resolveEventId
// short-circuit and return a provided id WITHOUT verifying ownership (lookups by
// *name* are user-scoped, but a raw id is trusted). For INSERT paths that stamp
// these as foreign keys, an unowned id would link another user's record, so the
// insert path must verify ownership explicitly — same guard execCreateContact
// already applies to event_id. (DELETE/UPDATE paths are safe instead via a final

export async function execGetPriorities(userId: string) {
  const { data, error } = await supabaseAdmin
    .from('follow_ups')
    .select('contact_id, contacts!inner(id)')
    .eq('user_id', userId)
    .in('status', ['new', 'pending'])
    .is('deleted_at', null)
    .is('contacts.deleted_at', null);
  if (error) throw new Error(error.message);
  const followUpsDue = new Set((data ?? []).map((r: any) => r.contact_id)).size;
  return { follow_ups_due: followUpsDue };
}
