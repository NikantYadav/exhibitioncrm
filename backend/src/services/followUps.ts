import type { SupabaseClient } from '@supabase/supabase-js';

// ---------------------------------------------------------------------------
// Unified follow-up engine.
//
// Every follow-up record is keyed on (user_id, contact_id, event_id), with
// event_id = null meaning "general" (no event, e.g. a coffee chat). All three
// product triggers funnel through the single `upsertFollowUp` helper so the
// dedup rule lives in exactly one place:
//
//   1. Contact scanned/added            -> ensure(status: 'new')
//   2. Interaction logged with contact  -> touch(status: 'pending')
//   3. Target checked off at an event   -> touch(status: 'pending')
//
// Dedup: whichever trigger fires first creates the row; later triggers update
// that same row (status promotion + last_interaction_at) instead of inserting
// a duplicate. The DB unique constraint (NULLS NOT DISTINCT) backstops races.
// ---------------------------------------------------------------------------

export type FollowUpStatus = 'new' | 'pending' | 'done' | 'skipped';

// Status promotion rules. A trigger may only move a record "forward" along the
// engagement axis; it must never silently downgrade. `done` reopens to
// `pending` when fresh activity (an interaction) arrives — a product decision:
// new activity means there is something new to follow up on.
//
// `seed` = the status this trigger wants to set.
// Returns the status the record should end up at given its current value.
function resolveStatus(current: FollowUpStatus, seed: FollowUpStatus): FollowUpStatus {
  // 'new' only ever seeds a brand-new row; it never downgrades an existing one.
  if (seed === 'new') return current;

  if (seed === 'pending') {
    // Interaction/target activity. Reopen done & skipped back to pending;
    // a row already pending or new becomes pending.
    return 'pending';
  }

  // Explicit done/skipped seeds (manual actions) win outright.
  return seed;
}

// Map the contact's BEST follow-up status (across all their records) onto the
// legacy `contacts.follow_up_status` column, which still drives the contact-
// detail status chip and the Contacts-screen filter. Derivation: done if any
// record is done, else needs_followup if any is pending, else not_contacted.
// Keeps the per-contact at-a-glance view consistent with the queues.
export async function syncContactStatus(
  db: SupabaseClient,
  userId: string,
  contactId: string,
): Promise<void> {
  const { data: rows } = await db
    .from('follow_ups')
    .select('status')
    .eq('user_id', userId)
    .eq('contact_id', contactId)
    .is('deleted_at', null);

  const statuses = new Set((rows ?? []).map((r: any) => r.status));
  let legacy: string;
  if (statuses.has('done')) legacy = 'contacted';
  else if (statuses.has('pending')) legacy = 'needs_followup';
  else legacy = 'not_contacted'; // new / skipped / none

  await db
    .from('contacts')
    .update({ follow_up_status: legacy, updated_at: new Date().toISOString() })
    .eq('id', contactId)
    .eq('user_id', userId);
}

interface UpsertArgs {
  contactId: string;
  eventId?: string | null;
  /** Status this trigger wants. Subject to resolveStatus promotion rules. */
  seedStatus: FollowUpStatus;
  /** When true (interaction/target triggers), bump last_interaction_at to now. */
  touchInteraction?: boolean;
  channel?: string;
}

/**
 * Idempotent upsert of the follow-up record for (user, contact, event).
 * Safe to call on every trigger; never creates duplicates. Best-effort: callers
 * treat follow-up bookkeeping as a side effect and should not fail the primary
 * operation if this throws (wrap in try/catch at the call site).
 */
export async function upsertFollowUp(
  db: SupabaseClient,
  userId: string,
  args: UpsertArgs,
): Promise<void> {
  const eventId = args.eventId ?? null;
  const now = new Date().toISOString();

  // Read the existing row (the unique key is (user, contact, event)). Use
  // `is`/`eq` to handle the nullable event_id correctly.
  let q = db
    .from('follow_ups')
    .select('id, status, deleted_at')
    .eq('user_id', userId)
    .eq('contact_id', args.contactId);
  q = eventId === null ? q.is('event_id', null) : q.eq('event_id', eventId);
  const { data: existing } = await q.maybeSingle();

  if (existing) {
    const current = (existing.deleted_at ? 'new' : existing.status) as FollowUpStatus;
    const next = resolveStatus(current, args.seedStatus);

    const update: Record<string, unknown> = {
      status: next,
      updated_at: now,
      deleted_at: null, // resurrect a tombstoned row if the contact re-engages
    };
    if (args.touchInteraction) update.last_interaction_at = now;
    if (args.channel) update.channel = args.channel;
    if (next === 'done') update.done_at = now;
    else update.done_at = null;

    await db.from('follow_ups').update(update).eq('id', existing.id);
    await syncContactStatus(db, userId, args.contactId);
    return;
  }

  // No row yet — insert. On a unique-violation race (two triggers at once),
  // fall back to a re-read + update so the record is never duplicated.
  const insert: Record<string, unknown> = {
    user_id: userId,
    contact_id: args.contactId,
    event_id: eventId,
    status: args.seedStatus,
    channel: args.channel ?? 'email',
    last_interaction_at: args.touchInteraction ? now : null,
  };
  const { error } = await db.from('follow_ups').insert(insert);
  if (error && error.code === '23505') {
    // Lost the race; the row now exists — promote it.
    await upsertFollowUp(db, userId, args);
  } else if (error) {
    throw error;
  } else {
    await syncContactStatus(db, userId, args.contactId);
  }
}

/**
 * Force a specific (contact, event) follow-up record to an explicit status —
 * used by manual actions (send/skip/unskip on the event queue) that override the
 * promotion rules. Creates the record if it doesn't exist yet (e.g. a target
 * being sent before any follow-up row was seeded).
 */
export async function setEventFollowUpStatus(
  db: SupabaseClient,
  userId: string,
  contactId: string,
  eventId: string,
  status: FollowUpStatus,
): Promise<void> {
  const now = new Date().toISOString();
  const { data: existing } = await db
    .from('follow_ups')
    .select('id')
    .eq('user_id', userId)
    .eq('contact_id', contactId)
    .eq('event_id', eventId)
    .maybeSingle();

  if (existing) {
    await db
      .from('follow_ups')
      .update({ status, deleted_at: null, done_at: status === 'done' ? now : null })
      .eq('id', existing.id);
    await syncContactStatus(db, userId, contactId);
    return;
  }

  const { error } = await db.from('follow_ups').insert({
    user_id: userId,
    contact_id: contactId,
    event_id: eventId,
    status,
    done_at: status === 'done' ? now : null,
  });
  if (error && error.code === '23505') {
    await setEventFollowUpStatus(db, userId, contactId, eventId, status);
  } else if (error) {
    throw error;
  } else {
    await syncContactStatus(db, userId, contactId);
  }
}
