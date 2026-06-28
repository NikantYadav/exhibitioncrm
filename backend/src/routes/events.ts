import { Router, Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { LiteLLMService } from '../services/litellm-service';
import { TavilyService } from '../services/tavily-service';
import { requireAuth } from '../middleware/requireAuth';
import { supabase as supabaseAdmin } from '../config/supabase';
import { upsertFollowUp, setEventFollowUpStatus } from '../services/followUps';
import multer from 'multer';
import * as XLSX from 'xlsx';

const uuidSchema = z.string().uuid();
const isoDate = z.string().regex(/^\d{4}-\d{2}-\d{2}(T[\d:.Z+-]*)?$/, 'Invalid date format').nullable().optional();
const timeOfDay = z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/, 'Invalid time format').nullable().optional();
const optText = (max: number) => z.string().trim().max(max).optional().or(z.literal(''));

// end_time is optional, but when present must be strictly after start_time, and
// it cannot stand alone without a start_time. Enforced server-side so a crafted
// request can't store an inverted/orphan range that corrupts live resolution.
const enforceTimeRange = (
  d: { start_time?: string | null; end_time?: string | null },
  ctx: z.RefinementCtx,
) => {
  if (d.end_time != null && d.start_time == null) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      message: 'end_time requires a start_time',
      path: ['start_time'],
    });
    return;
  }
  if (d.start_time != null && d.end_time != null && d.end_time <= d.start_time) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      message: 'end_time must be after start_time',
      path: ['end_time'],
    });
  }
};

// start_time is required on create; end_time stays optional.
const eventWriteSchema = z.object({
  name: z.string().trim().min(1).max(200),
  location: optText(300),
  start_date: isoDate,
  end_date: isoDate,
  start_time: z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/, 'Invalid time format'),
  end_time: timeOfDay,
}).superRefine(enforceTimeRange);

const eventPatchSchema = z.object({
  name: z.string().trim().min(1).max(200).optional(),
  location: optText(300),
  start_date: isoDate,
  end_date: isoDate,
  start_time: timeOfDay,
  end_time: timeOfDay,
}).superRefine(enforceTimeRange);

const targetWriteSchema = z.object({
  company_id: uuidSchema,
  priority: z.enum(['high', 'medium', 'low']).optional(),
  booth_location: optText(100),
  notes: optText(2000),
  status: z.enum(['not_contacted', 'contacted', 'researched', 'met']).optional(),
  use_notes_for_briefing: z.boolean().optional(),
});

const targetPatchSchema = targetWriteSchema.partial();

const goalWriteSchema = z.object({
  label: z.string().trim().min(1).max(200),
  // total 0 = checkbox/binary goal; >=1 = counted goal
  total: z.number().int().min(0).max(10000).optional(),
});

const goalPatchSchema = z.object({
  label: z.string().trim().min(1).max(200).optional(),
  current: z.number().int().min(0).max(100000).optional(),
  total: z.number().int().min(0).max(10000).optional(),
}).refine(d => d.label !== undefined || d.current !== undefined || d.total !== undefined, {
  message: 'At least one field required',
});

const followUpActionSchema = z.object({
  action: z.enum(['send', 'skip', 'unskip']),
  subject: z.string().trim().max(300).optional(),
  body: z.string().trim().max(50000).optional(),
});

const contactEventStatusSchema = z.object({
  status: z.enum(['not_contacted', 'met', 'contacted']).optional(),
  notes: optText(5000),
  talking_points: optText(5000),
}).refine(d => d.status !== undefined || d.notes !== undefined || d.talking_points !== undefined, {
  message: 'At least one field required',
});

const router = Router();

router.use(requireAuth);

const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 5 * 1024 * 1024 } });

// Verify the event identified by :id belongs to the authenticated user.
// Runs automatically before any handler that has an :id param.
router.param('id', async (req: Request, res: Response, next: NextFunction, id: string) => {
  try {
    const supabase = req.supabase!;
    const { data: event } = await supabase
      .from('events')
      .select('id, user_id')
      .eq('id', id)
      .is('deleted_at', null)
      .maybeSingle();

    if (!event) {
      return res.status(404).json({ error: 'Event not found' });
    }

    if (event.user_id !== req.user!.id) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    next();
  } catch {
    res.status(500).json({ error: 'Failed to verify event ownership' });
  }
});

// Supabase returns timestamps as "2026-06-08 00:00:00+00" (space, no colon in offset).
// new Date() requires ISO 8601 ("T" separator, "+00:00" offset) — fix both.
const parseTs = (s: string): Date =>
  new Date(s.replace(' ', 'T').replace(/([+-]\d{2})$/, '$1:00'));

// Combines an event date (UTC midnight) with an "HH:mm" time-of-day, treating
// the stored time as UTC wall-clock on that date. Mirrors the Flutter rule.
const withTime = (date: Date, time: string): Date => {
  const [h, m] = time.split(':').map(Number);
  const d = new Date(date.getTime());
  d.setUTCHours(h, m, 0, 0);
  return d;
};

const sameDay = (a: Date, b: Date): boolean =>
  a.getUTCFullYear() === b.getUTCFullYear() &&
  a.getUTCMonth() === b.getUTCMonth() &&
  a.getUTCDate() === b.getUTCDate();

const endOfDay = (date: Date): Date => {
  const d = new Date(date.getTime());
  d.setUTCHours(23, 59, 59, 999);
  return d;
};

// The instant an event's live window ends. With an explicit end_time it's that
// time; otherwise the window runs until the next single-day event that starts
// later the same day, or end of day if none. Multi-day events run through the
// end of their end_date regardless. [allEvents] is the user's full event list,
// needed to find the next same-day event when end_time is absent.
const effectiveEnd = (event: any, allEvents: any[]): Date => {
  const start = parseTs(event.start_date);
  if (event.end_date) {
    // Multi-day: background event spanning to the end of its last day.
    return endOfDay(parseTs(event.end_date));
  }
  if (event.end_time) {
    return withTime(start, event.end_time);
  }
  // No end_time: run until the next same-day single-day event begins (ending one
  // millisecond before it, so the two windows never both contain that instant),
  // or end of day if none starts later.
  const myStart = event.start_time ? withTime(start, event.start_time) : start;
  let boundary = endOfDay(start);
  for (const other of allEvents) {
    if (other.id === event.id || other.end_date || !other.start_time) continue;
    const otherStartDate = parseTs(other.start_date);
    if (!sameDay(otherStartDate, start)) continue;
    const otherStart = withTime(otherStartDate, other.start_time);
    if (otherStart > myStart && otherStart <= boundary) {
      boundary = new Date(otherStart.getTime() - 1);
    }
  }
  return boundary;
};

// An event's committed extent for conflict checks. `start` is the start instant.
// `boundedEnd` is the hard end only when the event declares one (explicit
// end_time, or a multi-day span); it is null for an open-ended event, which has
// no fixed end — it simply runs until the next event that day, so it yields to
// later events instead of conflicting with them.
const eventExtent = (event: any): { start: Date; boundedEnd: Date | null } => {
  const startDay = parseTs(event.start_date);
  const start = event.start_time ? withTime(startDay, event.start_time) : startDay;
  let boundedEnd: Date | null = null;
  if (event.end_date) {
    boundedEnd = event.end_time
      ? withTime(parseTs(event.end_date), event.end_time)
      : endOfDay(parseTs(event.end_date));
  } else if (event.end_time) {
    boundedEnd = withTime(startDay, event.end_time);
  }
  return { start, boundedEnd };
};

// Two events conflict only when they genuinely cannot be sequenced:
//   • identical start instants (ambiguous — which is live?), or
//   • a bounded single-day event whose [start, end] strictly contains the
//     other's start.
// Multi-day events are background: a single-day event may be nested inside one,
// so multi-day spans never conflict. Two open-ended events, or an open-ended one
// followed by a later start, also don't conflict — the earlier simply runs until
// the later begins.
const isMultiDay = (e: any): boolean => e.end_date != null;

const eventsConflict = (a: any, b: any): boolean => {
  // A multi-day background never blocks (and isn't blocked by) another event.
  if (isMultiDay(a) || isMultiDay(b)) return false;
  const ea = eventExtent(a);
  const eb = eventExtent(b);
  if (ea.start.getTime() === eb.start.getTime()) return true;
  const earlier = ea.start < eb.start ? ea : eb;
  const later = ea.start < eb.start ? eb : ea;
  // Conflict only if the earlier event is bounded and its end runs past the
  // later event's start (i.e. the later start falls inside the earlier window).
  return earlier.boundedEnd != null && earlier.boundedEnd > later.start;
};

const getEventStatus = (event: any, allEvents: any[] = []): string => {
  const now = new Date();
  const start = parseTs(event.start_date);
  const rangeStart = event.start_time ? withTime(start, event.start_time) : start;
  const rangeEnd = effectiveEnd(event, allEvents);
  if (now >= rangeStart && now <= rangeEnd) return 'ongoing';
  if (now > rangeEnd) return 'completed';
  return 'upcoming';
};

// Chooses which event is "live" when several are ongoing at once (e.g. a
// single-day timed event nested inside a multi-day event). A single-day event
// whose window contains "now" is the most specific intent, so it always wins
// over a multi-day/background event; ties fall back to start_date ordering.
const pickOngoingEvent = (events: any[]): any | undefined => {
  const ongoing = events.filter(e => getEventStatus(e, events) === 'ongoing');
  if (ongoing.length === 0) return undefined;
  // Among ongoing events, a single-day (timed) event is more specific than a
  // multi-day background event. If several qualify, the one that started most
  // recently is the active window — deterministic regardless of input order.
  const effStart = (e: any): number =>
    (e.start_time ? withTime(parseTs(e.start_date), e.start_time) : parseTs(e.start_date)).getTime();
  const singleDay = ongoing.filter(e => !e.end_date);
  const pool = singleDay.length > 0 ? singleDay : ongoing;
  return pool.reduce((best, e) => (effStart(e) > effStart(best) ? e : best));
};

router.get('/', async (req, res, next) => {
  try {
    const supabase = req.supabase!;
    const userId = req.user!.id;

    const { data, error } = await supabase
      .from('events')
      .select('*')
      .eq('user_id', userId)
      .is('deleted_at', null)
      .order('start_date', { ascending: false });

    if (error) throw error;

    const updatedData = (data || []).map(event => ({
      ...event,
      status: getEventStatus(event, data || []),
    }));

    console.log(`[GET /api/events] Returning ${updatedData.length} events`);
    res.json({ data: updatedData });
  } catch (error) {
    console.error(`[GET /api/events] Error:`, error);
    next(error);
  }
});

// GET /api/events/ongoing/current
// Returns the current ongoing event if any
router.get('/ongoing/current', async (req, res, next) => {
  try {
    const supabase = req.supabase!;
    const userId = req.user!.id;
    const { data: events, error } = await supabase
      .from('events')
      .select('*')
      .eq('user_id', userId)
      .is('deleted_at', null)
      .order('start_date', { ascending: false });

    if (error) throw error;

    const ongoingEvent = pickOngoingEvent(events || []);

    if (!ongoingEvent) {
      res.status(404).json({ error: 'No ongoing event found' });
      return;
    }

    res.json({ data: { ...ongoingEvent, status: 'ongoing' } });
  } catch (error) {
    next(error);
  }
});

// GET /api/events/live-session
// Single endpoint for LiveEventProvider: finds ongoing event then returns live data + captures in parallel.
// Replaces 3 sequential calls (ongoing/current → /:id/live → /:id/captures) with one round trip.
router.get('/live-session', async (req, res, next) => {
  try {
    const supabase = req.supabase!;
    const userId = req.user!.id;

    // 1. Find ongoing event (same query as /ongoing/current)
    const { data: events, error: eventsError } = await supabase
      .from('events')
      .select('*')
      .eq('user_id', userId)
      .is('deleted_at', null)
      .order('start_date', { ascending: false });

    if (eventsError) throw eventsError;

    const ongoingEvent = pickOngoingEvent(events || []);

    if (!ongoingEvent) {
      // Also look up next upcoming event so Flutter doesn't need a second call
      const upcomingEvent = (events || []).find(event => getEventStatus(event, events || []) === 'upcoming');
      res.status(404).json({ error: 'No ongoing event found', nextEvent: upcomingEvent ? { ...upcomingEvent, status: 'upcoming' } : null });
      return;
    }

    const eventId = ongoingEvent.id;

    // 2. Fetch live data and captures in parallel
    const [
      { count: capturesCount },
      { count: targetsCount },
      { data: goalsData },
      { data: targetsRaw, error: targetsError },
      { data: contactEventRows, error: contactEventsError },
      { data: captures, error: capturesError },
      { data: companyMetRows },
    ] = await Promise.all([
      supabase.from('captures').select('*', { count: 'exact', head: true }).eq('event_id', eventId).is('deleted_at', null),
      supabase.from('target_companies').select('*', { count: 'exact', head: true }).eq('event_id', eventId).is('deleted_at', null),
      supabase.from('event_goals').select('*').eq('event_id', eventId).is('deleted_at', null).order('created_at', { ascending: true }),
      supabase
        .from('target_companies')
        .select(`id, priority, booth_location, status, company_id, talking_points, notes, use_notes_for_briefing, company:companies(id, name)`)
        .eq('event_id', eventId)
        .is('deleted_at', null)
        .limit(50),
      supabase
        .from('contact_events')
        .select(`id, contact_id, status, notes, talking_points, created_at, contact:contacts(id, first_name, last_name, job_title, company_id, deleted_at, company_name:companies(name))`)
        .eq('event_id', eventId)
        .is('deleted_at', null)
        .order('created_at', { ascending: true }),
      supabase
        .from('captures')
        // Only the columns the live "Scanned" list renders, plus the contact
        // fields it reads. Was `*, contact:contacts(*)` which pulled every
        // column of both tables over the wire. company_name is joined from
        // companies (contacts has no company_name column) and flattened below.
        .select('id, created_at, contact:contacts(id, first_name, last_name, job_title, email, phone, company_id, deleted_at, company_name:companies(name))')
        .eq('event_id', eventId)
        .is('deleted_at', null)
        .order('created_at', { ascending: false }),
      // Per-user "met" state for company targets. Separate from
      // target_companies.status so it is user-specific and never touches
      // follow-ups. RLS already scopes to the current user.
      supabase
        .from('target_company_met')
        .select('target_id, met')
        .eq('event_id', eventId),
    ]);

    if (targetsError) throw targetsError;
    if (contactEventsError) throw contactEventsError;
    if (capturesError) throw capturesError;

    const priorityOrder: Record<string, number> = { high: 0, medium: 1, low: 2 };
    const sortedTargets = (targetsRaw || []).sort((a: any, b: any) =>
      (priorityOrder[a.priority] ?? 3) - (priorityOrder[b.priority] ?? 3)
    );

    const companyMetSet = new Set(
      (companyMetRows || []).filter((r: any) => r.met).map((r: any) => r.target_id)
    );

    const priorityTargets = sortedTargets.map((target: any, index: number) => ({
      id: target.id,
      rank: index + 1,
      company_id: target.company_id ?? null,
      company_name: target.company?.name ?? '',
      booth: target.booth_location || '',
      status: target.status || 'not_contacted',
      priority: target.priority || 'medium',
      talking_points: target.talking_points || '',
      notes: target.notes || '',
      use_notes_for_briefing: target.use_notes_for_briefing ?? false,
      // Per-user met state (not the shared `status` field above).
      met: companyMetSet.has(target.id),
    }));

    // contact:contacts(...) is a left join and can't filter the embedded row's
    // deleted_at inline (PostgREST !inner+dotted filter would also drop rows whose
    // contact_id legitimately has no contact yet); drop deleted contacts here instead.
    const liveContactEventRows = (contactEventRows || []).filter((row: any) => row.contact?.deleted_at == null);

    const targetContacts = liveContactEventRows.map((row: any) => {
      const c = row.contact;
      const companyName = c?.company_name?.name ?? '';
      return {
        id: row.id,
        contact_id: row.contact_id,
        name: c ? `${c.first_name} ${c.last_name ?? ''}`.trim() : '',
        job_title: c?.job_title ?? '',
        company_name: companyName,
        status: row.status || 'not_contacted',
        notes: row.notes || '',
        talking_points: row.talking_points || '',
      };
    });

    const tc = targetsCount || 0;
    const cc = liveContactEventRows.length;
    const followUpsCount = targetContacts.filter((t: any) => t.status !== 'met').length;
    const targetReach = tc > 0 ? Math.round((cc / tc) * 100) : 0;

    res.json({
      data: {
        event: { ...ongoingEvent, status: 'ongoing' },
        liveData: {
          event: {
            id: ongoingEvent.id,
            title: ongoingEvent.name,
            venue: ongoingEvent.location || '',
          },
          stats: {
            target_reach: targetReach,
            scanned: capturesCount || 0,
            targets_left: Math.max(0, tc - cc),
            pending_follow_ups: followUpsCount,
            total_targets: tc,
          },
          goals: (goalsData || []).map((g: any) => ({ id: g.id, label: g.label, current: g.current, total: g.total })),
          targets: priorityTargets,
          target_contacts: targetContacts,
        },
        // Drop the embedded contact if it's soft-deleted; flatten the joined
        // company name ({name} -> string) to match what the live list reads
        // (contact['company_name'] as String).
        captures: (captures || []).map((c: any) => {
          const contact = c.contact;
          if (!contact || contact.deleted_at != null) return { ...c, contact: null };
          return {
            ...c,
            contact: { ...contact, company_name: contact.company_name?.name ?? '' },
          };
        }),
      },
    });
  } catch (error) {
    next(error);
  }
});

// GET /api/events/upcoming/next
// Returns the next upcoming event (soonest start_date in the future)
router.get('/upcoming/next', async (req, res, next) => {
  try {
    const supabase = req.supabase!;
    const userId = req.user!.id;
    const { data: events, error } = await supabase
      .from('events')
      .select('*')
      .eq('user_id', userId)
      .is('deleted_at', null)
      .order('start_date', { ascending: true });

    if (error) throw error;

    const upcomingEvent = (events || []).find(event => getEventStatus(event, events || []) === 'upcoming');

    if (!upcomingEvent) {
      res.status(404).json({ error: 'No upcoming event found' });
      return;
    }

    res.json({ data: { ...upcomingEvent, status: 'upcoming' } });
  } catch (error) {
    next(error);
  }
});

// GET /api/events/stats/batch?ids=id1,id2,...
// Returns stats for multiple events in one round trip.
router.get('/stats/batch', async (req, res, next) => {
  try {
    const supabase = req.supabase!;
    const userId = req.user!.id;
    const idsParam = (req.query.ids as string) || '';
    const rawIds = idsParam.split(',').map(s => s.trim()).filter(Boolean);
    // Only keep valid UUIDs to prevent injection
    const eventIds = rawIds.filter(id => uuidSchema.safeParse(id).success);

    if (eventIds.length === 0) {
      res.json({ data: {} });
      return;
    }

    // Verify all requested events belong to this user
    const { data: ownedEvents, error: ownedError } = await supabase
      .from('events')
      .select('id')
      .eq('user_id', userId)
      .is('deleted_at', null)
      .in('id', eventIds);

    if (ownedError) throw ownedError;
    const ownedIds = (ownedEvents || []).map((e: any) => e.id);
    if (ownedIds.length === 0) { res.json({ data: {} }); return; }

    // Batch queries across all events in parallel
    const [
      { data: captureRows },
      { data: contactEventRows },
      { data: targetRows },
    ] = await Promise.all([
      supabase.from('captures').select('event_id, contact_id').in('event_id', ownedIds).eq('status', 'completed').not('contact_id', 'is', null).is('deleted_at', null),
      supabase.from('contact_events').select('event_id, contact_id').in('event_id', ownedIds).is('deleted_at', null),
      supabase.from('target_companies').select('event_id').in('event_id', ownedIds).is('deleted_at', null),
    ]);

    // Group by event_id
    const capturesByEvent = new Map<string, string[]>();
    const contactEventsByEvent = new Map<string, string[]>();
    const targetCountByEvent = new Map<string, number>();

    for (const row of captureRows || []) {
      const arr = capturesByEvent.get(row.event_id) || [];
      arr.push(row.contact_id);
      capturesByEvent.set(row.event_id, arr);
    }
    for (const row of contactEventRows || []) {
      const arr = contactEventsByEvent.get(row.event_id) || [];
      arr.push(row.contact_id);
      contactEventsByEvent.set(row.event_id, arr);
    }
    for (const row of targetRows || []) {
      targetCountByEvent.set(row.event_id, (targetCountByEvent.get(row.event_id) || 0) + 1);
    }

    // Collect all unique contact IDs across all events for a single follow-up status query
    const allContactIds = Array.from(new Set([
      ...(captureRows || []).map((r: any) => r.contact_id),
      ...(contactEventRows || []).map((r: any) => r.contact_id),
    ]));

    // Per-event follow-up status from the unified table, keyed (event, contact).
    // Counts are now per-event, not global — a contact done at event A no longer
    // shows done at event B.
    const followUpStatusByEvent = new Map<string, Map<string, string>>();
    if (ownedIds.length > 0) {
      const { data: fuRows } = await supabase
        .from('follow_ups')
        .select('event_id, contact_id, status')
        .eq('user_id', req.user!.id)
        .in('event_id', ownedIds)
        .is('deleted_at', null);
      for (const r of fuRows || []) {
        if (!r.event_id) continue;
        let m = followUpStatusByEvent.get(r.event_id);
        if (!m) { m = new Map(); followUpStatusByEvent.set(r.event_id, m); }
        m.set(r.contact_id, r.status);
      }
    }

    // Build per-event stats
    const result: Record<string, any> = {};
    for (const eventId of ownedIds) {
      const ceContactIds = contactEventsByEvent.get(eventId) || [];
      const capContactIds = capturesByEvent.get(eventId) || [];
      // Include follow-up contacts in the roster: an event-tagged interaction
      // creates a follow_up without a contact_events row, and those people show
      // in the queue, so total_contacts must count them too (matches /stats).
      const fuContactIds = Array.from(followUpStatusByEvent.get(eventId)?.keys() || []);
      const uniqueContactIds = Array.from(new Set([...ceContactIds, ...capContactIds, ...fuContactIds]));
      const totalTargets = targetCountByEvent.get(eventId) || 0;
      const totalContacts = uniqueContactIds.length;

      // Count from follow_ups records only (the source of truth) so this matches
      // the single-event /stats endpoint exactly — a contact with no follow_up
      // record is not counted. Counting by membership instead made the card
      // flicker (membership-based pending, then follow_ups-based pending).
      let followUpsNeeded = 0;
      let followUpsSkipped = 0;
      let followUpsDone = 0;
      const statusMap = followUpStatusByEvent.get(eventId);
      if (statusMap) {
        for (const status of statusMap.values()) {
          if (status === 'done') followUpsDone++;
          else if (status === 'skipped') followUpsSkipped++;
          else followUpsNeeded++; // new + pending both still owe action
        }
      }

      result[eventId] = {
        total_contacts: totalContacts,
        total_targets: totalTargets,
        target_reach: totalTargets > 0 ? Math.round(totalContacts / totalTargets * 100) : 0,
        follow_ups_needed: followUpsNeeded,
        follow_ups_skipped: followUpsSkipped,
        follow_ups_done: followUpsDone,
      };
    }

    res.json({ data: result });
  } catch (error) {
    next(error);
  }
});

router.get('/:id', async (req, res, next) => {
  try {
    const supabase = req.supabase!;
    const { data: event, error } = await supabase
      .from('events')
      .select('*')
      .eq('id', req.params.id)
      .is('deleted_at', null)
      .single();

    if (error) throw error;

    if (event) {
      event.status = getEventStatus(event);
    }

    res.json({ data: event });
  } catch (error) {
    next(error);
  }
});

// True when an event's start instant is in the past. Times are stored in UTC,
// so comparing the full start instant (date + time) against `now` is timezone
// agnostic — no offset margin is needed. A small grace window absorbs clock
// skew and the few seconds between the user picking "now" and the request.
const START_GRACE_MS = 5 * 60 * 1000;
const isStartInPast = (start_date?: string | null, start_time?: string | null): boolean => {
  if (!start_date) return false;
  const startInstant = start_time
    ? withTime(parseTs(start_date), start_time)
    // Date-only (legacy / no time): treat the whole start day as valid, so only
    // a strictly earlier calendar day counts as past.
    : endOfDay(parseTs(start_date));
  return startInstant.getTime() < Date.now() - START_GRACE_MS;
};

// Returns true if [candidate] conflicts with any of the user's other events.
// [excludeId] skips the event being updated. Scoped to the authenticated user.
const hasOverlap = async (
  supabase: any,
  userId: string,
  candidate: any,
  excludeId?: string,
): Promise<boolean> => {
  const { data: existing, error } = await supabase
    .from('events')
    .select('id, start_date, end_date, start_time, end_time')
    .eq('user_id', userId)
    .is('deleted_at', null);
  if (error) throw error;
  const now = Date.now();
  return (existing || []).some((e: any) => {
    if (e.id === excludeId) return false;
    // An event already fully in the past can't conflict with a new one. Its
    // latest relevant instant is its bounded end, or end of its start day.
    const ext = eventExtent(e);
    const latest = ext.boundedEnd ?? endOfDay(parseTs(e.start_date));
    if (latest.getTime() < now) return false;
    return eventsConflict(candidate, e);
  });
};

router.post('/', async (req, res, next) => {
  try {
    const supabase = req.supabase!;
    const parsedBody = eventWriteSchema.safeParse(req.body);
    if (!parsedBody.success) return res.status(400).json({ error: parsedBody.error.flatten() });

    const { name, location, start_date, end_date, start_time, end_time } = parsedBody.data;

    if (isStartInPast(start_date, start_time)) {
      return res.status(400).json({ error: 'Event start date cannot be in the past.' });
    }

    if (await hasOverlap(supabase, req.user!.id, { start_date, end_date, start_time, end_time })) {
      return res.status(409).json({ error: 'This event overlaps another event. Choose a non-overlapping time.' });
    }

    const { data, error } = await supabase
      .from('events')
      .insert({ user_id: req.user!.id, name, location, start_date, end_date, start_time, end_time })
      .select()
      .single();

    if (error) throw error;

    res.json({ data: { ...data, status: getEventStatus(data) }, message: 'Event created successfully' });
  } catch (error) {
    next(error);
  }
});

router.patch('/:id', async (req, res, next) => {
  try {
    const supabase = req.supabase!;
    const parsedBody = eventPatchSchema.safeParse(req.body);
    if (!parsedBody.success) return res.status(400).json({ error: parsedBody.error.flatten() });

    const updates = parsedBody.data;

    // Merge the partial update onto the current row, then validate the resulting
    // start instant and ensure the window doesn't overlap another event.
    if (updates.start_date !== undefined || updates.end_date !== undefined ||
        updates.start_time !== undefined || updates.end_time !== undefined) {
      const { data: current, error: curErr } = await supabase
        .from('events')
        .select('start_date, end_date, start_time, end_time')
        .eq('id', req.params.id)
        .eq('user_id', req.user!.id)
        .single();
      if (curErr) throw curErr;
      const merged = { ...current, ...updates };
      // Only reject a past start when the update actually moves the start — i.e.
      // the merged start_date/start_time differs from what's already stored.
      // Editing only the end (e.g. stopping a live event, whose start is
      // legitimately in the past) must not trip the future-start guard.
      // DB time columns come back as HH:MM:SS while the payload is HH:MM —
      // compare on HH:MM so an unchanged start isn't seen as moved.
      const hm = (t?: string | null) => (t == null ? t : t.slice(0, 5));
      const startMoved =
        merged.start_date !== current.start_date ||
        hm(merged.start_time) !== hm(current.start_time);
      if (startMoved && isStartInPast(merged.start_date, merged.start_time)) {
        return res.status(400).json({ error: 'Event start date cannot be in the past.' });
      }
      if (await hasOverlap(supabase, req.user!.id, merged, req.params.id)) {
        return res.status(409).json({ error: 'This event overlaps another event. Choose a non-overlapping time.' });
      }
    }

    const { data, error } = await supabase
      .from('events')
      .update(updates)
      .eq('id', req.params.id)
      .eq('user_id', req.user!.id)
      .select()
      .single();

    if (error) throw error;

    res.json({ data: { ...data, status: getEventStatus(data) }, message: 'Event updated successfully' });
  } catch (error) {
    next(error);
  }
});

router.put('/:id', async (req, res, next) => {
  try {
    const supabase = req.supabase!;
    const parsedBody = eventWriteSchema.safeParse(req.body);
    if (!parsedBody.success) return res.status(400).json({ error: parsedBody.error.flatten() });

    const { data, error } = await supabase
      .from('events')
      .update(parsedBody.data)
      .eq('id', req.params.id)
      .eq('user_id', req.user!.id)
      .select()
      .single();

    if (error) throw error;

    res.json({ data: { ...data, status: getEventStatus(data) } });
  } catch (error) {
    next(error);
  }
});

// GET /api/events/:id/stats
router.get('/:id/stats', async (req, res, next) => {
  try {
    const supabase = req.supabase!;
    const eventId = req.params.id;

    // Get total captures
    const { count: capturesCount } = await supabase
      .from('captures')
      .select('*', { count: 'exact', head: true })
      .eq('event_id', eventId)
      .is('deleted_at', null);

    // Get total contacts via contact_events
    const { count: contactEventsCount } = await supabase
      .from('contact_events')
      .select('*', { count: 'exact', head: true })
      .eq('event_id', eventId)
      .is('deleted_at', null);

    // Get total targets
    const { count: targetsCount } = await supabase
      .from('target_companies')
      .select('*', { count: 'exact', head: true })
      .eq('event_id', eventId)
      .is('deleted_at', null);

    // Collect all unique contact IDs from both contact_events AND captures
    const [{ data: contactEventRows }, { data: captureRows }] = await Promise.all([
      supabase.from('contact_events').select('contact_id').eq('event_id', eventId).is('deleted_at', null),
      supabase.from('captures').select('contact_id').eq('event_id', eventId).eq('status', 'completed').not('contact_id', 'is', null).is('deleted_at', null),
    ]);

    const contactIds = Array.from(new Set([
      ...(contactEventRows?.map((c: any) => c.contact_id) || []),
      ...(captureRows?.map((c: any) => c.contact_id) || []),
    ]));

    // Per-event follow-up counts from the unified table. needed = new + pending.
    let followUpsCount = 0;
    let skippedCount = 0;
    let doneCount = 0;
    {
      const { data: fuRows } = await supabase
        .from('follow_ups')
        .select('contact_id, status')
        .eq('user_id', req.user!.id)
        .eq('event_id', eventId)
        .is('deleted_at', null);
      for (const r of fuRows || []) {
        if (r.status === 'done') doneCount++;
        else if (r.status === 'skipped') skippedCount++;
        else followUpsCount++; // new + pending
        // A follow-up is a valid event association too: logging an event-tagged
        // interaction creates one without a contact_events row. Count those
        // people so total_contacts matches the follow-up queue's roster.
        if (r.contact_id) contactIds.push(r.contact_id);
      }
    }

    // total_contacts = all unique people reached (contact_events ∪ captures ∪ follow_ups)
    const totalContacts = new Set(contactIds).size;

    // Calculate target reach: (unique contacts reached / total targets) * 100
    const targetReach = targetsCount && targetsCount > 0 ? Math.round(totalContacts / targetsCount * 100) : 0;

    res.json({
      data: {
        total_captures: capturesCount || 0,
        total_contacts: totalContacts,
        total_targets: targetsCount || 0,
        target_reach: targetReach,
        follow_ups_needed: followUpsCount,
        follow_ups_skipped: skippedCount,
        follow_ups_done: doneCount,
      }
    });
  } catch (error) {
    next(error);
  }
});

// GET /api/events/:id/targets
router.get('/:id/targets', async (req, res, next) => {
  try {
    const supabase = req.supabase!;
    const { data, error } = await supabase
      .from('target_companies')
      .select('*, company:companies(*)')
      .eq('event_id', req.params.id)
      .is('deleted_at', null)
      .order('priority', { ascending: true });

    if (error) throw error;

    res.json({ data: data || [] });
  } catch (error) {
    next(error);
  }
});

// GET /api/events/:id/targets/:targetId
router.get('/:id/targets/:targetId', async (req, res, next) => {
  try {
    const supabase = req.supabase!;
    const { data, error } = await supabase
      .from('target_companies')
      .select('*, company:companies(*)')
      .eq('id', req.params.targetId)
      .eq('event_id', req.params.id)
      .is('deleted_at', null)
      .single();

    if (error) throw error;

    res.json({ data });
  } catch (error) {
    next(error);
  }
});

// GET /api/events/:id/live
router.get('/:id/live', async (req, res, next) => {
  try {
    const supabase = req.supabase!;
    const eventId = req.params.id;
    console.log(`[GET /events/:id/live] eventId: ${eventId}`);

    const [
      { data: event, error: eventError },
      { count: capturesCount },
      { count: targetsCount },
      { data: goalsData },
      { data: targetsRaw, error: targetsError },
      { data: contactEventRows, error: contactEventsError },
      { data: companyMetRows },
    ] = await Promise.all([
      supabase.from('events').select('*').eq('id', eventId).is('deleted_at', null).single(),
      supabase.from('captures').select('*', { count: 'exact', head: true }).eq('event_id', eventId).is('deleted_at', null),
      supabase.from('target_companies').select('*', { count: 'exact', head: true }).eq('event_id', eventId).is('deleted_at', null),
      supabase.from('event_goals').select('*').eq('event_id', eventId).is('deleted_at', null).order('created_at', { ascending: true }),
      supabase
        .from('target_companies')
        .select(`
          id, priority, booth_location, status, company_id, talking_points, notes, use_notes_for_briefing,
          company:companies(id, name)
        `)
        .eq('event_id', eventId)
        .is('deleted_at', null)
        .limit(50),
      supabase
        .from('contact_events')
        .select(`
          id, contact_id, status, notes, talking_points, created_at,
          contact:contacts(id, first_name, last_name, job_title, company_id, deleted_at, company_name:companies(name))
        `)
        .eq('event_id', eventId)
        .is('deleted_at', null)
        .order('created_at', { ascending: true }),
      // Per-user "met" state for company targets (see /live-session).
      supabase
        .from('target_company_met')
        .select('target_id, met')
        .eq('event_id', eventId),
    ]);

    if (eventError || !event) {
      console.log(`[GET /events/:id/live] Event not found: ${eventId}`);
      res.status(404).json({ error: 'Event not found' });
      return;
    }
    if (targetsError) throw targetsError;
    if (contactEventsError) throw contactEventsError;

    // contact:contacts(...) is a left join and can't filter the embedded row's
    // deleted_at inline; drop rows whose linked contact was soft-deleted instead.
    const liveContactEventRows = (contactEventRows || []).filter((row: any) => row.contact?.deleted_at == null);
    const contactEventsCount = liveContactEventRows.length;
    console.log(`[GET /events/:id/live] Event: ${event.name}, Stats - Scanned: ${capturesCount}, Targets: ${targetsCount}, Contacts: ${contactEventsCount}`);

    // Sort targets: high > medium > low
    const priorityOrder: Record<string, number> = { high: 0, medium: 1, low: 2 };
    const sortedTargets = (targetsRaw || []).sort((a: any, b: any) =>
      (priorityOrder[a.priority] ?? 3) - (priorityOrder[b.priority] ?? 3)
    );

    const companyMetSet = new Set(
      (companyMetRows || []).filter((r: any) => r.met).map((r: any) => r.target_id)
    );

    // Target companies — independent of contacts
    const priorityTargets = sortedTargets.map((target: any, index: number) => ({
      id: target.id,
      rank: index + 1,
      company_id: target.company_id ?? null,
      company_name: target.company?.name ?? '',
      booth: target.booth_location || '',
      status: target.status || 'not_contacted',
      priority: target.priority || 'medium',
      talking_points: target.talking_points || '',
      notes: target.notes || '',
      use_notes_for_briefing: target.use_notes_for_briefing ?? false,
      // Per-user met state (not the shared `status` field above).
      met: companyMetSet.has(target.id),
    }));

    // Target contacts — independent list from contact_events
    const targetContacts = liveContactEventRows.map((row: any) => {
      const c = (row as any).contact;
      const companyName = c?.company_name?.name ?? '';
      return {
        id: row.id,
        contact_id: row.contact_id,
        name: c ? `${c.first_name} ${c.last_name ?? ''}`.trim() : '',
        job_title: c?.job_title ?? '',
        company_name: companyName,
        status: row.status || 'not_contacted',
        notes: row.notes || '',
        talking_points: row.talking_points || '',
      };
    });

    // Pending follow-ups: target contacts not yet met
    const followUpsCount = targetContacts.filter((tc: any) => tc.status !== 'met').length;

    const tc = targetsCount || 0;
    const cc = contactEventsCount;
    const targetReach = tc > 0 ? Math.round((cc / tc) * 100) : 0;

    console.log(`[GET /events/:id/live] Returning ${priorityTargets.length} company targets, ${targetContacts.length} contact targets`);

    res.json({
      data: {
        event: {
          id: event.id,
          title: event.name,
          venue: event.location || '',
        },
        stats: {
          target_reach: targetReach,
          scanned: capturesCount || 0,
          targets_left: Math.max(0, tc - cc),
          pending_follow_ups: followUpsCount,
          total_targets: tc,
        },
        goals: (goalsData || []).map((g: any) => ({
          id: g.id,
          label: g.label,
          current: g.current,
          total: g.total,
        })),
        targets: priorityTargets,
        target_contacts: targetContacts,
      },
    });
  } catch (error) {
    console.error(`[GET /events/:id/live] Error:`, error);
    next(error);
  }
});

// GET /api/events/:id/goals
router.get('/:id/goals', async (req, res, next) => {
  try {
    const supabase = req.supabase!;
    const { data, error } = await supabase
      .from('event_goals').select('*')
      .eq('event_id', req.params.id).is('deleted_at', null).order('created_at', { ascending: true });
    if (error) throw error;
    res.json({ data: data || [] });
  } catch (error) { next(error); }
});

// POST /api/events/:id/ask
router.post('/:id/ask', async (req, res, next) => {
  try {
    const supabase = req.supabase!;
    const parsed = z.object({ question: z.string().trim().min(1).max(1000) }).safeParse(req.body);
    if (!parsed.success) { res.status(400).json({ error: parsed.error.flatten() }); return; }
    const { question } = parsed.data;
    const [{ data: event }, { data: targets }] = await Promise.all([
      supabase.from('events').select('name, location, start_date, end_date').eq('id', req.params.id).is('deleted_at', null).single(),
      supabase.from('target_companies').select('company:companies(name, industry), booth_location, status, priority').eq('event_id', req.params.id).is('deleted_at', null).limit(20),
    ]);
    if (!event) { res.status(404).json({ error: 'Event not found' }); return; }

    const eventName = event.name as string;
    const eventLocation = event.location || '';
    const eventDates = event.start_date
      ? `${event.start_date.slice(0, 10)}${event.end_date ? ` to ${event.end_date.slice(0, 10)}` : ''}`
      : '';
    const targetSummary = (targets || []).map((t: any) =>
      `${t.company?.name} (${t.company?.industry || 'unknown'}, booth: ${t.booth_location || 'TBD'}, status: ${t.status})`
    ).join('\n');

    // Tavily search — include event name, location, schedule and the question
    let webContext = '';
    try {
      const searchQuery = [eventName, eventLocation, eventDates, question].filter(Boolean).join(' ');
      const results = await TavilyService.search(searchQuery, { maxResults: 4, searchDepth: 'basic' });
      webContext = TavilyService.formatForPrompt(results);
    } catch (_) { /* Tavily failure is non-fatal */ }

    const eventContext = [
      `Event: "${eventName}"`,
      eventLocation ? `Location: ${eventLocation}` : '',
      eventDates ? `Dates: ${eventDates}` : '',
    ].filter(Boolean).join('\n');

    const llm = new LiteLLMService();
    const answer = await llm.generateCompletion([{
      role: 'user',
      content: `You are a smart assistant helping someone attending a live event.\n\n${eventContext}\n\nTarget companies:\n${targetSummary || 'None listed'}${webContext ? `\n\nReal-time web context:\n${webContext}` : ''}\n\nQuestion: ${question}\n\nAnswer in 2-3 sentences. Be specific and actionable.`
    }]);
    res.json({ answer });
  } catch (error) { next(error); }
});

// POST /api/events/:id/goals
router.post('/:id/goals', async (req, res, next) => {
  try {
    const supabase = req.supabase!;
    const parsed = goalWriteSchema.safeParse(req.body);
    if (!parsed.success) { res.status(400).json({ error: parsed.error.flatten() }); return; }
    const { label, total } = parsed.data;
    const { data, error } = await supabase
      .from('event_goals')
      .insert({ event_id: req.params.id, label, total: total ?? 1, current: 0, user_id: req.user!.id })
      .select().single();
    if (error) throw error;
    res.json({ data });
  } catch (error) { next(error); }
});

// PATCH /api/events/:id/goals/:goalId
router.patch('/:id/goals/:goalId', async (req, res, next) => {
  try {
    const supabase = req.supabase!;
    const parsedBody = goalPatchSchema.safeParse(req.body);
    if (!parsedBody.success) { res.status(400).json({ error: parsedBody.error.flatten() }); return; }
    const parsedGoalId = uuidSchema.safeParse(req.params.goalId);
    if (!parsedGoalId.success) { res.status(400).json({ error: 'Invalid goalId' }); return; }

    const updates: any = {};
    if (parsedBody.data.current !== undefined) updates.current = parsedBody.data.current;
    if (parsedBody.data.label !== undefined) updates.label = parsedBody.data.label;
    if (parsedBody.data.total !== undefined) updates.total = parsedBody.data.total;
    updates.updated_at = new Date().toISOString();
    const { data, error } = await supabase
      .from('event_goals')
      .update(updates)
      .eq('id', req.params.goalId)
      .eq('event_id', req.params.id)
      .select().single();
    if (error) throw error;
    res.json({ data });
  } catch (error) { next(error); }
});

// DELETE /api/events/:id/goals/:goalId
router.delete('/:id/goals/:goalId', async (req, res, next) => {
  try {
    const supabase = req.supabase!;
    const { error } = await supabase
      .from('event_goals')
      .update({ deleted_at: new Date().toISOString() })
      .eq('id', req.params.goalId)
      .eq('event_id', req.params.id);
    if (error) throw error;
    res.json({ message: 'Goal deleted' });
  } catch (error) { next(error); }
});

// POST /api/events/:id/targets/import
router.post('/:id/targets/import', upload.single('file'), async (req: any, res, next) => {
  try {
    const supabase = req.supabase!;
    const eventId = req.params.id;
    if (!req.file) {
      res.status(400).json({ error: 'No file uploaded' });
      return;
    }

    // Parse file (works for .xlsx, .xls, .csv)
    const workbook = XLSX.read(req.file.buffer, { type: 'buffer' });
    const sheetName = workbook.SheetNames[0];
    const sheet = workbook.Sheets[sheetName];
    const rows: Record<string, string>[] = XLSX.utils.sheet_to_json(sheet, { defval: '' });

    const results: { added: number; skipped: number; errors: string[] } = {
      added: 0,
      skipped: 0,
      errors: [],
    };

    for (const row of rows) {
      // Accept columns: name, company, company_name (case-insensitive)
      const rawName = (row['name'] || row['company'] || row['company_name'] || row['Company'] || row['Name'] || '').toString().trim();
      const industry = (row['industry'] || row['Industry'] || row['sector'] || row['Sector'] || '').toString().trim();
      const website = (row['website'] || row['Website'] || row['url'] || '').toString().trim();
      const description = (row['description'] || row['Description'] || '').toString().trim();
      const boothNumber = (row['booth_number'] || row['booth'] || row['Booth'] || row['Booth Number'] || row['stand'] || '').toString().trim();

      if (!rawName) {
        results.skipped++;
        continue;
      }

      try {
        // Find or create company. Companies are an admin-managed shared resource
        // (no INSERT policy for the user-scoped client), so this runs through
        // supabaseAdmin; the target insert below stays on the user client.
        const { data: existing } = await supabaseAdmin
          .from('companies')
          .select('id')
          .ilike('name', rawName)
          .limit(1)
          .single();

        let companyId: string;
        if (existing) {
          companyId = existing.id;
        } else {
          const { data: created, error: createError } = await supabaseAdmin
            .from('companies')
            .insert({ name: rawName, industry: industry || null, website: website || null, description: description || null })
            .select('id')
            .single();
          if (createError || !created) {
            results.errors.push(`Failed to create company: ${rawName}`);
            continue;
          }
          companyId = created.id;
        }

        // Add as target (ignore duplicate)
        const { error: targetError } = await supabase
          .from('target_companies')
          .insert({ event_id: eventId, company_id: companyId, priority: 'medium', status: 'not_contacted', user_id: req.user!.id, booth_location: boothNumber || null });

        if (targetError && targetError.code !== '23505') {
          results.errors.push(`Failed to add ${rawName} as target`);
        } else {
          results.added++;
        }
      } catch (e: any) {
        results.errors.push(e.message || `Error processing ${rawName}`);
      }
    }

    res.json({ data: results, message: `Import complete: ${results.added} added, ${results.skipped} skipped` });
  } catch (error) {
    next(error);
  }
});

// POST /api/events/:id/targets
router.post('/:id/targets', async (req, res, next) => {
  try {
    const supabase = req.supabase!;
    const parsedBody = targetWriteSchema.safeParse(req.body);
    if (!parsedBody.success) return res.status(400).json({ error: parsedBody.error.flatten() });
    const { company_id, priority, notes, booth_location } = parsedBody.data;
    const eventId = req.params.id;

    // Check for a soft-deleted row first and restore it
    const { data: softDeleted } = await supabase
      .from('target_companies')
      .select('id')
      .eq('event_id', eventId)
      .eq('company_id', company_id)
      .not('deleted_at', 'is', null)
      .single();

    if (softDeleted) {
      const { data: restored } = await supabase
        .from('target_companies')
        .update({ deleted_at: null, priority: priority || 'medium', booth_location: booth_location || null, status: 'not_contacted' })
        .eq('id', softDeleted.id)
        .select('*, company:companies(*)')
        .single();
      res.json({ data: restored });
      return;
    }

    const { data, error } = await supabase
      .from('target_companies')
      .insert({
        event_id: eventId,
        company_id,
        priority: priority || 'medium',
        status: 'not_contacted',
        notes,
        booth_location: booth_location || null,
        user_id: req.user!.id,
      })
      .select('*, company:companies(*)')
      .single();

    if (error) {
      if (error.code === '23505') {
        // Active row already exists — return it
        const { data: existing } = await supabase
          .from('target_companies')
          .select('*, company:companies(*)')
          .eq('event_id', eventId)
          .eq('company_id', company_id)
          .single();
        res.json({ data: existing });
        return;
      }
      throw error;
    }

    res.json({ data });
  } catch (error) {
    next(error);
  }
});

// PUT /api/events/:id/targets/:targetId
router.put('/:id/targets/:targetId', async (req, res, next) => {
  try {
    const supabase = req.supabase!;
    const parsedBody = targetPatchSchema.safeParse(req.body);
    if (!parsedBody.success) return res.status(400).json({ error: parsedBody.error.flatten() });
    const parsedTargetId = uuidSchema.safeParse(req.params.targetId);
    if (!parsedTargetId.success) return res.status(400).json({ error: 'Invalid targetId' });

    const { data, error } = await supabase
      .from('target_companies')
      .update(parsedBody.data)
      .eq('id', req.params.targetId)
      .eq('event_id', req.params.id)
      .select('*, company:companies(*)')
      .single();

    if (error) throw error;

    res.json({ data });
  } catch (error) {
    next(error);
  }
});

// PUT /api/events/:id/targets/:targetId/met
// Per-user "met" toggle for a company target. Distinct from the shared
// target_companies.status field and the contact follow-up system: toggling
// this never creates or consumes a follow-up.
router.put('/:id/targets/:targetId/met', async (req, res, next) => {
  try {
    const supabase = req.supabase!;
    const userId = req.user!.id;
    const parsedTargetId = uuidSchema.safeParse(req.params.targetId);
    if (!parsedTargetId.success) return res.status(400).json({ error: 'Invalid targetId' });
    const met = req.body?.met === true;

    const { error } = await supabase
      .from('target_company_met')
      .upsert(
        {
          user_id: userId,
          event_id: req.params.id,
          target_id: req.params.targetId,
          met,
          updated_at: new Date().toISOString(),
        },
        { onConflict: 'user_id,target_id' }
      );

    if (error) throw error;

    res.json({ data: { target_id: req.params.targetId, met } });
  } catch (error) {
    next(error);
  }
});

// POST /api/events/:id/targets/:targetId/briefing
router.post('/:id/targets/:targetId/briefing', async (req, res, next) => {
  try {
    const supabase = req.supabase!;
    const { targetId } = req.params;
    const { data: target, error } = await supabase
      .from('target_companies')
      .select('*, company:companies(*)')
      .eq('id', targetId)
      .is('deleted_at', null)
      .single();
    if (error) throw error;

    const company = target.company as any;
    const companyName = company?.name || 'Unknown Company';
    const industry = company?.industry || '';
    const description = company?.description || '';

    // Tavily web search for real-time company grounding
    console.log(`[briefing] → running Tavily search for company: "${companyName}"`);
    const [newsResults, overviewResults] = await Promise.all([
      TavilyService.search(`${companyName} latest news`, { maxResults: 3, searchDepth: 'basic' }),
      TavilyService.search(`${companyName}${industry ? ` ${industry}` : ''} company products services overview`, { maxResults: 3, searchDepth: 'basic' }),
    ]);
    const webContext = TavilyService.formatForPrompt([...overviewResults, ...newsResults]);
    console.log(`[briefing] → Tavily returned ${overviewResults.length + newsResults.length} results`);

    const companyContext = `${companyName}${industry ? ` (${industry})` : ''}${description ? `. ${description}` : ''}`;
    const userNotes = (target.use_notes_for_briefing && target.notes?.trim()) ? target.notes.trim() : null;

    let prompt = `You are preparing a pre-meeting briefing for someone about to have a business networking conversation with ${companyContext}.

Write it in whatever structure best fits what you actually know about this company — there is no required format. Use short paragraphs, and where a section heading genuinely helps the reader skim, write it on its own line wrapped in **double asterisks**. Don't force headings or a fixed number of sections; let the content decide the shape. Keep it concise and skimmable.`;

    if (userNotes) {
      prompt += `\n\nThe user has provided the following personal notes about this company — treat these as high-priority context and let them shape the briefing:\n\n${userNotes}`;
    }

    if (webContext) {
      prompt += `\n\nUse the following real-time web research to make the briefing current and specific:\n\n${webContext}`;
    }
    prompt += `\n\nPlain text only — no bullet points, no numbered lists. Separate paragraphs with a blank line.`;

    const llm = new LiteLLMService();
    const talkingPoints = await llm.generateCompletion([{ role: 'user', content: prompt }]);

    const { data: updated, error: updateError } = await supabase
      .from('target_companies')
      .update({ talking_points: talkingPoints, status: 'researched' })
      .eq('id', targetId)
      .select('*, company:companies(*)')
      .single();
    if (updateError) throw updateError;

    res.json({ data: updated });
  } catch (error) {
    next(error);
  }
});

// DELETE /api/events/:id/targets/:targetId
router.delete('/:id/targets/:targetId', async (req, res, next) => {
  try {
    const supabase = req.supabase!;
    const { error } = await supabase
      .from('target_companies')
      .update({ deleted_at: new Date().toISOString() })
      .eq('id', req.params.targetId)
      .eq('event_id', req.params.id);

    if (error) throw error;

    res.json({ message: 'Target removed successfully' });
  } catch (error) {
    next(error);
  }
});

// GET /api/events/:id/follow-ups
// Returns a merged list of:
//   1. Scanned contacts (contact_events) with their company + email draft
//   2. Targeted companies that were never scanned — surfaced as unmet targets
// PATCH /api/events/:id/follow-ups/:contactId
// Marks a contact as contacted and upserts the email draft as sent.
// Body: { subject?, body?, action: 'send' | 'skip' }
router.patch('/:id/follow-ups/:contactId', async (req, res, next) => {
  try {
    const supabase = req.supabase!;
    const { id: eventId, contactId } = req.params;
    const parsedContactId = uuidSchema.safeParse(contactId);
    if (!parsedContactId.success) { res.status(400).json({ error: 'Invalid contactId' }); return; }

    const parsedBody = followUpActionSchema.safeParse(req.body);
    if (!parsedBody.success) { res.status(400).json({ error: parsedBody.error.flatten() }); return; }
    const { subject, body, action } = parsedBody.data;

    if (action === 'send') {
      // Mark this event's follow-up record as done. last_contacted_at on the
      // contact is still useful as a denormalized "most recent touch".
      await setEventFollowUpStatus(supabase, req.user!.id, contactId, eventId, 'done');
      await supabase
        .from('contacts')
        .update({ last_contacted_at: new Date().toISOString(), updated_at: new Date().toISOString() })
        .eq('id', contactId);

      // Upsert the draft as sent — update if exists, insert if not
      const { data: existing } = await supabase
        .from('email_drafts')
        .select('id')
        .eq('event_id', eventId)
        .eq('contact_id', contactId)
        .is('deleted_at', null)
        .order('created_at', { ascending: false })
        .limit(1)
        .single();

      if (existing) {
        await supabase
          .from('email_drafts')
          .update({
            subject: subject ?? undefined,
            body: body ?? undefined,
            status: 'sent',
            sent_at: new Date().toISOString(),
            updated_at: new Date().toISOString(),
          })
          .eq('id', existing.id);
      } else {
        await supabase
          .from('email_drafts')
          .insert({
            event_id: eventId,
            contact_id: contactId,
            email_type: 'follow_up',
            subject: subject || 'Following up from our meeting',
            body: body || '',
            status: 'sent',
            sent_at: new Date().toISOString(),
            user_id: req.user!.id,
          });
      }
    } else if (action === 'skip') {
      // skip — keep visible in the Skipped section, reversible.
      await setEventFollowUpStatus(supabase, req.user!.id, contactId, eventId, 'skipped');
    } else {
      // unskip — back to pending so it reappears in the queue.
      await setEventFollowUpStatus(supabase, req.user!.id, contactId, eventId, 'pending');
    }

    const messages: Record<string, string> = { send: 'Follow-up sent.', skip: 'Contact skipped.', unskip: 'Contact moved back to pending.' };
    res.json({ message: messages[action] });
  } catch (error) {
    next(error);
  }
});

// POST /api/events/:id/follow-ups/:contactId/draft
// Returns existing draft if one exists, otherwise generates via AI, saves, and returns it.
router.post('/:id/follow-ups/:contactId/draft', async (req, res, next) => {
  try {
    const supabase = req.supabase!;
    const { id: eventId, contactId } = req.params;

    // Return existing draft immediately if one exists
    const { data: existing } = await supabase
      .from('email_drafts')
      .select('subject, body')
      .eq('event_id', eventId)
      .eq('contact_id', contactId)
      .is('deleted_at', null)
      .order('created_at', { ascending: false })
      .limit(1)
      .single();

    if (existing?.subject && existing?.body) {
      res.json({ subject: existing.subject, body: existing.body });
      return;
    }

    // No saved draft — generate via AI
    const [{ data: eventData }, { data: contactData }] = await Promise.all([
      supabase.from('events').select('name, location, start_date').eq('id', eventId).is('deleted_at', null).single(),
      supabase.from('contacts')
        .select('first_name, last_name, job_title, ai_insights, companies(name, industry, description)')
        .eq('id', contactId)
        .is('deleted_at', null)
        .single(),
    ]);

    if (!contactData) { res.status(404).json({ error: 'Contact not found' }); return; }

    const firstName = contactData.first_name || '';
    const lastName = contactData.last_name || '';
    const jobTitle = contactData.job_title || '';
    const company = (contactData as any).companies as any;
    const companyName = company?.name || '';
    const companyIndustry = company?.industry || '';
    const insights = contactData.ai_insights as any;
    const eventName = eventData?.name || 'the event';

    const insightLines: string[] = [];
    if (insights?.strategic_context) insightLines.push(`Strategic context: ${insights.strategic_context}`);
    if (insights?.primary_pain_point) insightLines.push(`Pain point: ${insights.primary_pain_point}`);
    if (insights?.current_sentiment) insightLines.push(`Sentiment: ${insights.current_sentiment}`);
    if (insights?.buying_authority) insightLines.push(`Buying authority: ${insights.buying_authority}`);
    if (insights?.briefing_items?.length) insightLines.push(`Key notes: ${(insights.briefing_items as string[]).join('; ')}`);

    const prompt = `You are a professional relationship manager writing a follow-up email after a business event.

Contact details:
- Name: ${firstName}${lastName ? ' ' + lastName : ''}
- Title: ${jobTitle || 'Unknown'}
- Company: ${companyName || 'Unknown'}${companyIndustry ? ` (${companyIndustry})` : ''}
- Event met at: ${eventName}

${insightLines.length > 0 ? `AI-captured context:\n${insightLines.join('\n')}` : ''}

Write a short, warm, professional follow-up email. Rules:
- Do NOT include the sender's name or signature — the recipient will add it
- Address the contact by first name
- Reference the event and one specific insight if available
- Keep the body to 3-4 short paragraphs
- End with a clear but soft call to action (e.g. a quick call)
- Do NOT use generic filler phrases like "I hope this email finds you well"
- Do NOT include any placeholder text like [Your Name] or [Signature]

Respond in JSON with exactly two fields: "subject" (string) and "body" (string). Nothing else.`;

    const llm = new LiteLLMService();
    const raw = await llm.generateCompletion([{ role: 'user', content: prompt }]);

    let subject = `Following up — ${companyName || firstName}`;
    let body = raw;

    try {
      const jsonMatch = raw.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        const parsed = JSON.parse(jsonMatch[0]);
        if (parsed.subject) subject = parsed.subject;
        if (parsed.body) body = parsed.body;
      }
    } catch (_) { /* use raw body */ }

    // Save the generated draft so future calls skip AI entirely
    await supabase.from('email_drafts').insert({
      event_id: eventId,
      contact_id: contactId,
      email_type: 'follow_up',
      subject,
      body,
      status: 'draft',
      user_id: req.user!.id,
    });

    res.json({ subject, body });
  } catch (error) {
    next(error);
  }
});

// GET /api/events/:id/targets/:targetId/contacts
router.get('/:id/targets/:targetId/contacts', async (req, res, next) => {
  try {
    const supabase = req.supabase!;
    const { id: eventId, targetId } = req.params;

    // Get the target to find company_id
    const { data: target, error: targetError } = await supabase
      .from('target_companies')
      .select('company_id')
      .eq('id', targetId)
      .is('deleted_at', null)
      .single();
    if (targetError || !target) { res.status(404).json({ error: 'Target not found' }); return; }

    // Get all contacts for this company
    const { data: contacts, error: contactsError } = await supabase
      .from('contacts')
      .select('id, first_name, last_name, email, job_title')
      .eq('company_id', target.company_id)
      .is('deleted_at', null)
      .order('first_name');
    if (contactsError) throw contactsError;

    // Get contacts already linked to this event
    const { data: linked } = await supabase
      .from('contact_events')
      .select('contact_id')
      .eq('event_id', eventId)
      .is('deleted_at', null);
    const linkedIds = new Set((linked || []).map((l: any) => l.contact_id));

    const result = (contacts || []).map((c: any) => ({
      ...c,
      linked_to_event: linkedIds.has(c.id),
    }));

    res.json({ data: result });
  } catch (error) { next(error); }
});

// POST /api/events/:id/targets/:targetId/contacts
router.post('/:id/targets/:targetId/contacts', async (req, res, next) => {
  try {
    const supabase = req.supabase!;
    const { id: eventId } = req.params;
    const parsed = z.object({ contact_id: uuidSchema }).safeParse(req.body);
    if (!parsed.success) { res.status(400).json({ error: parsed.error.flatten() }); return; }
    const { contact_id } = parsed.data;

    // RLS on contact_events only checks the new row's user_id, not the foreign
    // contact_id — verify the caller owns the contact before linking it.
    const { data: ownedContact } = await supabase
      .from('contacts').select('id').eq('id', contact_id).eq('user_id', req.user!.id).is('deleted_at', null).maybeSingle();
    if (!ownedContact) { res.status(403).json({ error: 'Forbidden' }); return; }

    const { error } = await supabase
      .from('contact_events')
      .insert({ contact_id, event_id: eventId, user_id: req.user!.id });

    if (error && error.code !== '23505') throw error; // ignore duplicate

    res.json({ message: 'Contact linked to event' });
  } catch (error) { next(error); }
});

// DELETE /api/events/:id/targets/:targetId/contacts/:contactId
router.delete('/:id/targets/:targetId/contacts/:contactId', async (req, res, next) => {
  try {
    const supabase = req.supabase!;
    const { id: eventId, contactId } = req.params;

    const { error } = await supabase
      .from('contact_events')
      .update({ deleted_at: new Date().toISOString() })
      .eq('contact_id', contactId)
      .eq('event_id', eventId);

    if (error) throw error;
    res.json({ message: 'Contact unlinked from event' });
  } catch (error) { next(error); }
});

// DELETE /api/events/:id/contacts/:contactId — unlink a contact from an event
router.delete('/:id/contacts/:contactId', async (req, res, next) => {
  try {
    const supabase = req.supabase!;
    const { error } = await supabase
      .from('contact_events')
      .update({ deleted_at: new Date().toISOString() })
      .eq('contact_id', req.params.contactId)
      .eq('event_id', req.params.id);
    if (error) throw error;
    res.json({ message: 'Contact removed from event' });
  } catch (error) { next(error); }
});

// GET /api/events/:id/contacts — list target contacts for an event
router.get('/:id/contacts', async (req, res, next) => {
  try {
    const supabase = req.supabase!;
    const { data, error } = await supabase
      .from('contact_events')
      .select(`
        id, contact_id, status, notes, talking_points, created_at,
        contact:contacts(id, first_name, last_name, job_title, deleted_at, company_name:companies(name))
      `)
      .eq('event_id', req.params.id)
      .is('deleted_at', null)
      .order('created_at', { ascending: true });

    if (error) throw error;

    // contact:contacts(...) is a left join and can't filter the embedded row's
    // deleted_at inline; drop rows whose linked contact was soft-deleted instead.
    const contacts = (data || []).filter((row: any) => row.contact?.deleted_at == null).map((row: any) => {
      const c = row.contact;
      return {
        id: row.id,
        contact_id: row.contact_id,
        name: c ? `${c.first_name} ${c.last_name ?? ''}`.trim() : '',
        job_title: c?.job_title ?? '',
        company_name: c?.company_name?.name ?? '',
        status: row.status || 'not_contacted',
        notes: row.notes || '',
        talking_points: row.talking_points || '',
      };
    });

    res.json({ data: contacts });
  } catch (error) { next(error); }
});

// POST /api/events/:id/contacts — link a contact directly to an event
router.post('/:id/contacts', async (req, res, next) => {
  try {
    const supabase = req.supabase!;
    const parsed = z.object({ contact_id: uuidSchema }).safeParse(req.body);
    if (!parsed.success) { res.status(400).json({ error: parsed.error.flatten() }); return; }
    const { contact_id } = parsed.data;

    // RLS on contact_events only checks the new row's user_id, not the foreign
    // contact_id — verify the caller owns the contact before linking it.
    const { data: ownedContact } = await supabase
      .from('contacts').select('id').eq('id', contact_id).eq('user_id', req.user!.id).is('deleted_at', null).maybeSingle();
    if (!ownedContact) { res.status(403).json({ error: 'Forbidden' }); return; }

    const { error } = await supabase
      .from('contact_events')
      .insert({ contact_id, event_id: req.params.id, user_id: req.user!.id });

    if (error && error.code !== '23505') throw error; // ignore duplicate

    res.json({ message: 'Contact linked to event' });
  } catch (error) { next(error); }
});

// PATCH /api/events/:id/contacts/:contactId — update target contact status/notes
router.patch('/:id/contacts/:contactId', async (req, res, next) => {
  try {
    const supabase = req.supabase!;
    const { id: eventId, contactId } = req.params;
    const parsedContactId = uuidSchema.safeParse(contactId);
    if (!parsedContactId.success) { res.status(400).json({ error: 'Invalid contactId' }); return; }

    const parsedBody = contactEventStatusSchema.safeParse(req.body);
    if (!parsedBody.success) { res.status(400).json({ error: parsedBody.error.flatten() }); return; }
    const { status, notes, talking_points } = parsedBody.data;

    const updates: Record<string, any> = {};
    if (status !== undefined) updates.status = status;
    if (notes !== undefined) updates.notes = notes;
    if (talking_points !== undefined) updates.talking_points = talking_points;

    if (Object.keys(updates).length === 0) {
      res.status(400).json({ error: 'No fields to update' });
      return;
    }

    const { error } = await supabase
      .from('contact_events')
      .update(updates)
      .eq('contact_id', contactId)
      .eq('event_id', eventId);

    if (error) throw error;

    // Follow-up trigger #3: checking a known target off the list (status 'met')
    // promotes their follow-up to 'pending' immediately, keyed to this event —
    // without waiting for an interaction to be logged. Dedup with any
    // interaction-driven record happens automatically on the (contact, event) key.
    if (status === 'met') {
      try {
        await upsertFollowUp(supabase, req.user!.id, {
          contactId,
          eventId,
          seedStatus: 'pending',
          touchInteraction: true,
        });
      } catch (e) {
        console.error('follow_up upsert (target check-off) failed:', e);
      }

      // Also drop a "Met" entry onto the contact's engagement timeline.
      // Idempotent on (contact, event, details.met_target) so toggling met
      // off/on — or checking off from multiple places — never duplicates it.
      try {
        const { data: existingMet } = await supabase
          .from('interactions')
          .select('id')
          .eq('contact_id', contactId)
          .eq('event_id', eventId)
          .eq('interaction_type', 'meeting')
          .contains('details', { met_target: true })
          .is('deleted_at', null)
          .maybeSingle();

        if (!existingMet) {
          const { data: ev } = await supabase
            .from('events')
            .select('name')
            .eq('id', eventId)
            .maybeSingle();
          const summary = ev?.name ? `Met at ${ev.name}` : 'Met';

          await supabase.from('interactions').insert({
            contact_id: contactId,
            event_id: eventId,
            interaction_type: 'meeting',
            summary,
            interaction_date: new Date().toISOString(),
            details: { met_target: true },
            user_id: req.user!.id,
          });
        }
      } catch (e) {
        console.error('met interaction insert failed:', e);
      }
    } else if (status !== undefined) {
      // Un-checking met (status back to not_contacted/contacted) removes the
      // auto "Met" entry from the timeline — soft-delete to match how
      // interactions are deleted elsewhere.
      try {
        await supabase
          .from('interactions')
          .update({ deleted_at: new Date().toISOString() })
          .eq('contact_id', contactId)
          .eq('event_id', eventId)
          .eq('interaction_type', 'meeting')
          .contains('details', { met_target: true })
          .is('deleted_at', null);
      } catch (e) {
        console.error('met interaction soft-delete failed:', e);
      }
    }

    res.json({ message: 'Target contact updated' });
  } catch (error) { next(error); }
});

router.delete('/:id', async (req, res, next) => {
  try {
    const supabase = req.supabase!;
    const { error } = await supabase
      .from('events')
      .update({ deleted_at: new Date().toISOString() })
      .eq('id', req.params.id)
      .eq('user_id', req.user!.id);

    if (error) throw error;

    res.json({ message: 'Event deleted successfully' });
  } catch (error) {
    next(error);
  }
});

export default router;
