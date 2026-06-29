import { z } from 'zod';
import { supabase as supabaseAdmin } from '../../../config/supabase';
import { stripImmutable, toIso, timeOfDay, assertTimeRange } from '../validation';
import { resolveEventId, assertOwnsEvent } from '../resolvers';

export async function execCreateEvent(args: Record<string, unknown>, userId: string) {
  const a = z.object({
    name: z.string().trim().min(1),
    location: z.string().trim().optional(),
    start_date: z.any(),
    end_date: z.any().optional(),
    start_time: timeOfDay.optional(),
    end_time: timeOfDay.optional(),
    event_type: z.string().trim().optional(),
  }).parse(args);

  const startIso = toIso(a.start_date, 'start_date');
  assertTimeRange(a.start_time, a.end_time);

  if (new Date(startIso) < new Date()) {
    throw new Error('Event start date cannot be in the past.');
  }

  // Deduplicate: return existing event if same name + start_date already exists for this user
  const { data: existing } = await supabaseAdmin
    .from('events')
    .select('*')
    .eq('user_id', userId)
    .ilike('name', a.name)
    .eq('start_date', startIso)
    .is('deleted_at', null)
    .maybeSingle();
  if (existing) return existing;

  // Generic copy of plain column values (Plan B); the date fields need ISO
  // conversion so they're handled explicitly. Adding a new event column then
  // means only adding it to the Zod schema above.
  const DATE_KEYS = new Set(['start_date', 'end_date']);
  const insert: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(a)) {
    if (v === undefined || DATE_KEYS.has(k)) continue;
    insert[k] = v;
  }
  const { data, error } = await supabaseAdmin.from('events').insert({
    ...stripImmutable(insert),
    start_date: startIso,
    end_date: a.end_date ? toIso(a.end_date, 'end_date') : null,
    user_id: userId,
  }).select('*').single();
  if (error) throw new Error(error.message);
  return data;
}

export async function execUpdateEvent(args: Record<string, unknown>, userId: string) {
  const a = z.object({
    event_id: z.string().uuid().optional(),
    event_name: z.string().trim().optional(),
    name: z.string().trim().optional(),
    location: z.string().trim().optional(),
    start_date: z.any().optional(),
    end_date: z.any().optional(),
    start_time: timeOfDay.optional(),
    end_time: timeOfDay.optional(),
    event_type: z.string().trim().optional(),
  }).refine((v) => !!(v.event_id || v.event_name), {
    message: 'Either event_id or event_name is required.',
  }).parse(args);

  // Validate the time pair when both are supplied in this update.
  if (a.start_time !== undefined && a.end_time !== undefined) {
    assertTimeRange(a.start_time, a.end_time);
  }

  const eventId = await resolveEventId(a, userId);

  // Generic copy of provided values; resolver keys and date fields (which need
  // ISO conversion + validation) are handled separately below.
  const RESOLVER_KEYS = new Set(['event_id', 'event_name', 'start_date', 'end_date']);
  const raw: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(a)) {
    if (v === undefined || RESOLVER_KEYS.has(k)) continue;
    raw[k] = v;
  }
  if (a.start_date !== undefined) {
    const startIso = toIso(a.start_date, 'start_date');
    if (new Date(startIso) < new Date()) throw new Error('Event start date cannot be in the past.');
    raw.start_date = startIso;
  }
  if (a.end_date !== undefined) raw.end_date = toIso(a.end_date, 'end_date');

  const update = stripImmutable(raw);
  if (Object.keys(update).length === 0) throw new Error('No valid fields to update');

  const { data, error } = await supabaseAdmin.from('events').update(update).eq('id', eventId).eq('user_id', userId).is('deleted_at', null).select('*').maybeSingle();
  if (error) throw new Error(error.message);
  if (!data) throw new Error('Event not found or access denied');
  return data;
}

export async function execGetEventFollowups(args: Record<string, unknown>, userId: string) {
  const a = z.object({
    event_id: z.string().uuid().optional(),
    event_name: z.string().trim().optional(),
    follow_up_status: z.enum(['not_contacted', 'contacted', 'needs_followup', 'ignore']).optional(),
  }).refine((v) => !!(v.event_id || v.event_name), {
    message: 'Either event_id or event_name is required.',
  }).parse(args);

  const eventId = await resolveEventId(a, userId);

  let query = supabaseAdmin
    .from('contact_events')
    .select(`
      contact_id,
      contacts!inner (
        id, first_name, last_name, email, phone, job_title, company_id,
        follow_up_status, last_contacted_at, notes, scanned_details
      )
    `)
    .eq('event_id', eventId)
    .is('deleted_at', null);

  const { data, error } = await query;
  if (error) throw new Error(error.message);

  const rows = (data ?? []).map((row: any) => row.contacts).filter(Boolean);

  const filtered = a.follow_up_status
    ? rows.filter((c: any) => c.follow_up_status === a.follow_up_status)
    : rows;

  return { event_id: eventId, follow_up_status_filter: a.follow_up_status ?? null, count: filtered.length, contacts: filtered };
}

export async function execSetEventGoal(args: Record<string, unknown>, userId: string) {
  const a = z.object({
    event_id: z.string().uuid().optional(),
    event_name: z.string().trim().optional(),
    label: z.string().trim().min(1).max(200),
    total: z.number().int().min(0).max(10000).optional(),
    current: z.number().int().min(0).max(100000).optional(),
  }).refine((v) => !!(v.event_id || v.event_name), {
    message: 'Either event_id or event_name is required.',
  }).parse(args);

  const eventId = await resolveEventId(a, userId);
  if (a.event_id) await assertOwnsEvent(eventId, userId);
  const now = new Date().toISOString();

  // Update an existing goal with the same label on this event, else insert.
  const { data: existing } = await supabaseAdmin
    .from('event_goals').select('id')
    .eq('event_id', eventId).eq('user_id', userId)
    .ilike('label', a.label).is('deleted_at', null).maybeSingle();

  if (existing) {
    const update: Record<string, unknown> = { label: a.label, updated_at: now };
    if (a.total !== undefined) update.total = a.total;
    if (a.current !== undefined) update.current = a.current;
    const { data, error } = await supabaseAdmin
      .from('event_goals').update(update).eq('id', existing.id).eq('user_id', userId)
      .select('*').single();
    if (error) throw new Error(error.message);
    return { success: true, updated: true, ...data, message: 'Event goal updated.' };
  }

  const { data, error } = await supabaseAdmin
    .from('event_goals')
    .insert({ event_id: eventId, label: a.label, total: a.total ?? 1, current: a.current ?? 0, user_id: userId })
    .select('*').single();
  if (error) throw new Error(error.message);
  return { success: true, ...data, message: 'Event goal created.' };
}
