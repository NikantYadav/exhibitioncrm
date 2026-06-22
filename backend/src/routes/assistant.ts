import { Router } from 'express';
import { randomUUID } from 'crypto';
import { z } from 'zod';
import { requireAuth } from '../middleware/requireAuth';
import { createSupabaseUserClient } from '../config/supabaseClients';
import { supabase as supabaseAdmin } from '../config/supabase';
import { litellm, ConversationTurn, ToolCall } from '../services/litellm-service';
import { slayerQuery, slayerHealthy, USER_ID_TABLES, slayerSchemaMap } from '../services/slayer-client';
import { autoTitleConversation } from '../services/ai/titling';
import { TavilyService } from '../services/tavily-service';

const router = Router();
router.use(requireAuth);

// ─── Persistent rate limiter (Supabase-backed) ────────────────────────────────
// Uses assistant_rate_limits table — survives restarts, works across processes.
const RATE_WINDOW_MS = 60_000;
const RATE_MAX = 30;

async function checkRateLimit(userId: string): Promise<{ ok: true } | { ok: false; retryAfterSeconds: number }> {
  const now = new Date();
  const windowStart = new Date(now.getTime() - RATE_WINDOW_MS);

  // Upsert: if no row exists, create with count=1.
  // If row exists and window has expired, reset it.
  // If row exists and within window, increment.
  const { data, error } = await supabaseAdmin.rpc('upsert_rate_limit', {
    p_user_id: userId,
    p_window_start: windowStart.toISOString(),
    p_max_requests: RATE_MAX,
  });

  if (error) {
    // On DB error, fail open (don't block the user)
    console.warn('Rate limit check failed, failing open:', error.message);
    return { ok: true };
  }

  if (data === false) {
    // Function returns false when limit exceeded
    const { data: row } = await supabaseAdmin
      .from('assistant_rate_limits')
      .select('window_start')
      .eq('user_id', userId)
      .maybeSingle();
    const resetAt = row ? new Date(row.window_start).getTime() + RATE_WINDOW_MS : now.getTime() + RATE_WINDOW_MS;
    return { ok: false, retryAfterSeconds: Math.ceil((resetAt - now.getTime()) / 1000) };
  }

  return { ok: true };
}

// ─── Prompt injection guard ───────────────────────────────────────────────────
const INJECTION_PATTERNS = [
  /ignore (previous|all|above|prior) instructions/i,
  /disregard (previous|all|above|prior)/i,
  /you are now/i,
  /new (persona|role|identity)/i,
  /system prompt/i,
  /\[INST\]/i,
  /<\|im_start\|>/i,
];

function sanitiseUserInput(text: string, userId: string): string {
  const suspicious = INJECTION_PATTERNS.some((p) => p.test(text));
  if (suspicious) {
    console.warn(`[security] Possible prompt injection from user ${userId}: ${text.slice(0, 120)}`);
  }
  // Hard truncate — prevents context stuffing regardless
  return text.slice(0, 8000);
}

// ─── Immutable fields — never allowed in write tool args ─────────────────────
const IMMUTABLE_FIELDS = new Set([
  'id', 'user_id', 'created_at', 'updated_at',
  'sender_user_id', 'conversation_id',
]);

function stripImmutable(data: Record<string, unknown>): Record<string, unknown> {
  return Object.fromEntries(
    Object.entries(data).filter(([k]) => !IMMUTABLE_FIELDS.has(k))
  );
}

// ─── Tool schemas (given to the LLM) ─────────────────────────────────────────

const SLAYER_QUERY_TOOL = {
  name: 'query_crm',
  description: `Query CRM data using the semantic layer. Use this for ANY read operation:
listing contacts, events, email drafts, captures, companies,
interactions, dashboard stats, or searching messages.
The semantic layer handles SQL generation — you just describe what you want.
Available source_models: contacts, events, email_drafts,
captures, companies, interactions, messages, conversations,
attachments.

DATE FILTERING — IMPORTANT:
- For any relative time window on events (today, live now, upcoming, next N days, this week/month, past), DO NOT write your own date filters. Instead set the "date_window" parameter to the matching value. The backend computes the exact, correct timestamp bounds for you. This is the ONLY correct way to do relative-date queries — hand-written date filters are error-prone and will be rejected.
- "date_window" applies to the events model (filters on start_date). For other models or absolute dates, use "filters" with explicit timestamptz ranges (never bare date equality like start_date = '2026-06-21').
- You may still combine date_window with other non-date filters in "filters" (e.g. location).`,
  parameters: {
    type: 'object',
    properties: {
      source_model: {
        type: 'string',
        description: 'The CRM table/model to query (e.g. contacts, events, notes)',
      },
      date_window: {
        type: 'string',
        enum: ['today', 'live_now', 'upcoming', 'next_7_days', 'next_10_days', 'next_30_days', 'this_week', 'this_month', 'past'],
        description: 'Relative time window for events. The backend expands this into correct start_date bounds — ALWAYS use this instead of hand-writing date filters for relative windows. "today"/"live_now" = events today; "upcoming" = today onward; "next_N_days"/"this_week"/"this_month" = today through N days; "past" = before today.',
      },
      measures: {
        type: 'array',
        items: { type: 'string' },
        description: 'Aggregations e.g. ["*:count", "revenue:sum"]. Omit for raw rows.',
      },
      dimensions: {
        type: 'array',
        items: { type: 'string' },
        description: 'Columns to group by or return e.g. ["status", "first_name", "email"]',
      },
      filters: {
        type: 'array',
        items: { type: 'string' },
        description: 'Filter conditions e.g. ["follow_up_status = \'needs_followup\'", "start_date >= \'2026-06-21T00:00:00Z\'", "start_date < \'2026-06-22T00:00:00Z\'"]. For date columns always use timestamptz range filters, never bare date equality.',
      },
      time_dimensions: {
        type: 'array',
        items: {
          type: 'object',
          properties: {
            dimension: { type: 'string' },
            granularity: { type: 'string', enum: ['day', 'week', 'month', 'quarter', 'year'] },
            date_range: { type: 'array', items: { type: 'string' }, minItems: 2, maxItems: 2 },
          },
          required: ['dimension'],
        },
        description: 'Time-based grouping e.g. [{"dimension": "created_at", "granularity": "month"}]',
      },
      order: {
        type: 'array',
        items: {
          type: 'object',
          properties: {
            column: { type: 'string' },
            direction: { type: 'string', enum: ['asc', 'desc'] },
          },
          required: ['column'],
        },
      },
      limit: { type: 'number', description: 'Max rows to return (default 50, max 200)' },
    },
    required: ['source_model'],
  },
};

const WRITE_TOOLS = [
  {
    name: 'create_contact',
    description: 'Create a new contact in the CRM',
    parameters: {
      type: 'object',
      properties: {
        first_name: { type: 'string' },
        last_name: { type: 'string' },
        email: { type: 'string' },
        phone: { type: 'string' },
        job_title: { type: 'string' },
        notes: { type: 'string' },
        company_name: { type: 'string', description: 'Company name — will be created if not found' },
        company_id: { type: 'string', description: 'Existing company UUID (use instead of company_name if known)' },
        event_id: { type: 'string', description: 'Link contact to this event UUID' },
      },
      required: ['first_name'],
    },
  },
  {
    name: 'update_contact',
    description: 'Update fields on an existing contact. Provide contact_id if known, otherwise contact_name. The system resolves the contact via the primary database.',
    parameters: {
      type: 'object',
      properties: {
        contact_id: { type: 'string' },
        contact_name: { type: 'string', description: 'Full or partial name of the contact to update — use this if you do not have the contact_id.' },
        first_name: { type: 'string' },
        last_name: { type: 'string' },
        email: { type: 'string' },
        phone: { type: 'string' },
        job_title: { type: 'string' },
        notes: { type: 'string' },
        follow_up_status: { type: 'string', enum: ['not_contacted', 'contacted', 'needs_followup', 'ignore'] },
        follow_up_urgency: { type: 'string', enum: ['low', 'medium', 'high'] },
        last_contacted_at: { type: 'string', description: 'ISO 8601 datetime' },
      },
      required: [],
    },
  },
  {
    name: 'create_event',
    description: 'Create a new event/exhibition. A real start_date from the user is mandatory — never fabricate or default it. If the user did not specify a date, ask them first; do not call this tool yet.',
    parameters: {
      type: 'object',
      properties: {
        name: { type: 'string' },
        location: { type: 'string' },
        start_date: { type: 'string', description: 'ISO 8601 datetime. Must come from the user — do not guess or default.' },
        end_date: { type: 'string', description: 'ISO 8601 datetime' },
        event_type: { type: 'string' },
      },
      required: ['name', 'start_date'],
    },
  },
  {
    name: 'update_event',
    description: 'Update fields on an existing event. Provide event_id if known, otherwise event_name. The system resolves the event via the primary database.',
    parameters: {
      type: 'object',
      properties: {
        event_id: { type: 'string', description: 'UUID of the event to update' },
        event_name: { type: 'string', description: 'Name of the event to update — use this if you do not have the event_id.' },
        name: { type: 'string' },
        location: { type: 'string' },
        start_date: { type: 'string', description: 'ISO 8601 datetime' },
        end_date: { type: 'string', description: 'ISO 8601 datetime' },
        event_type: { type: 'string' },
      },
      required: [],
    },
  },
  {
    name: 'get_event_followups',
    description: 'List contacts linked to a specific event, optionally filtered by follow-up status. Use this when the user asks for pending/done/all follow-ups for a named event.',
    parameters: {
      type: 'object',
      properties: {
        event_id: { type: 'string', description: 'UUID of the event' },
        event_name: { type: 'string', description: 'Name of the event — use this if you do not have the event_id.' },
        follow_up_status: {
          type: 'string',
          enum: ['not_contacted', 'contacted', 'needs_followup', 'ignore'],
          description: 'Filter contacts by this follow-up status. Omit to return all contacts for the event.',
        },
      },
      required: [],
    },
  },
  {
    name: 'draft_email',
    description: 'Draft an email for a contact',
    parameters: {
      type: 'object',
      properties: {
        contact_id: { type: 'string' },
        subject: { type: 'string' },
        body: { type: 'string' },
        email_type: { type: 'string' },
        event_id: { type: 'string' },
      },
      required: ['contact_id', 'subject', 'body'],
    },
  },
];

const WEB_SEARCH_TOOL = {
  name: 'web_search',
  description: `Search the live web for current, real-time information — news, recent events,
company/person background, pricing, or anything that may not be in your training data.
Use this when the user asks about something current or external to the CRM
(e.g. "what's the latest on <company>", "who is <person>", industry news).
Do NOT use this for CRM data — use query_crm for that.`,
  parameters: {
    type: 'object',
    properties: {
      query: { type: 'string', description: 'The search query' },
      search_depth: {
        type: 'string',
        enum: ['basic', 'advanced'],
        description: 'Use "advanced" for deeper, more thorough research; "basic" (default) for quick lookups',
      },
      max_results: { type: 'number', description: 'Max results to return (default 5, max 10)' },
    },
    required: ['query'],
  },
};

const ALL_TOOLS = [SLAYER_QUERY_TOOL, ...WRITE_TOOLS, WEB_SEARCH_TOOL];

// ─── date_window expansion ────────────────────────────────────────────────────
// The model picks a window name; we compute the exact timestamptz bounds here so
// it never has to do date math or hand-write fragile filter strings. All bounds
// are half-open [lo, hi) on start_date, in UTC.

const DATE_WINDOWS = new Set([
  'today', 'live_now', 'upcoming', 'next_7_days', 'next_10_days',
  'next_30_days', 'this_week', 'this_month', 'past',
]);

/** YYYY-MM-DDT00:00:00Z for `now + n` days (UTC midnight). */
function midnightPlusDays(now: Date, n: number): string {
  return `${new Date(now.getTime() + n * 86400000).toISOString().slice(0, 10)}T00:00:00Z`;
}

/**
 * Expand a date_window value into start_date filter strings. Returns the filters
 * to append, or null for an unknown window. "live_now" maps to today's bounds:
 * most events have a null end_date, so "live" = "happening today".
 */
function expandDateWindow(window: string, now = new Date()): string[] | null {
  const today = midnightPlusDays(now, 0);
  switch (window) {
    case 'today':
    case 'live_now':
      return [`start_date >= '${today}'`, `start_date < '${midnightPlusDays(now, 1)}'`];
    case 'upcoming':
      return [`start_date >= '${today}'`];
    case 'next_7_days':
    case 'this_week':
      return [`start_date >= '${today}'`, `start_date < '${midnightPlusDays(now, 7)}'`];
    case 'next_10_days':
      return [`start_date >= '${today}'`, `start_date < '${midnightPlusDays(now, 10)}'`];
    case 'next_30_days':
    case 'this_month':
      return [`start_date >= '${today}'`, `start_date < '${midnightPlusDays(now, 30)}'`];
    case 'past':
      return [`start_date < '${today}'`];
    default:
      return null;
  }
}

// ─── Linked entities from read (query_crm) results ────────────────────────────
// Columns we inject into query_crm results so any entity the assistant names in
// its reply can be rendered as a card. Keyed by source_model.
const LINKABLE_CARD_COLUMNS: Record<string, string[]> = {
  events: ['id', 'name', 'start_date', 'location'],
  contacts: ['id', 'first_name', 'last_name'],
  email_drafts: ['id', 'subject'],
};

/** Strip a Slayer dotted column prefix ("events.name" -> "name"). */
function unprefix(key: string): string {
  const dot = key.indexOf('.');
  return dot === -1 ? key : key.slice(dot + 1);
}

/** Flatten a Slayer row's dotted keys to plain field names. */
function normaliseRow(row: Record<string, unknown>): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(row)) out[unprefix(k)] = v;
  return out;
}

/** Build a linked-entity payload from a normalised read row, or null if no id. */
function readRowToEntity(model: string, r: Record<string, unknown>): { type: string; id: string; payload: Record<string, unknown> } | null {
  if (!r.id || typeof r.id !== 'string') return null;
  const id = r.id;
  if (model === 'events') {
    return { type: 'event', id, payload: { type: 'event', id, name: r.name, start_date: r.start_date, location: r.location } };
  }
  if (model === 'contacts') {
    return { type: 'contact', id, payload: { type: 'contact', id, first_name: r.first_name, last_name: r.last_name } };
  }
  if (model === 'email_drafts') {
    return { type: 'email_draft', id, payload: { type: 'email_draft', id, subject: r.subject } };
  }
  return null;
}

// ─── Write tool executors ─────────────────────────────────────────────────────

function toIso(value: unknown, field: string): string {
  if (typeof value !== 'string' || !value.trim()) throw new Error(`${field} is required`);
  const d = new Date(value);
  if (isNaN(d.getTime())) throw new Error(`${field} must be a valid date/time`);
  return d.toISOString();
}

async function execCreateContact(args: Record<string, unknown>, userId: string) {
  const a = z.object({
    first_name: z.string().trim().min(1),
    last_name: z.string().trim().optional(),
    email: z.string().trim().email().optional(),
    phone: z.string().trim().optional(),
    job_title: z.string().trim().optional(),
    notes: z.string().trim().optional(),
    company_id: z.string().uuid().optional(),
    company_name: z.string().trim().optional(),
    event_id: z.string().uuid().optional(),
  }).parse(args);

  // Verify the linked event belongs to this user
  if (a.event_id) {
    const { data: ev } = await supabaseAdmin.from('events').select('id').eq('id', a.event_id).eq('user_id', userId).is('deleted_at', null).maybeSingle();
    if (!ev) throw new Error('Event not found or access denied');
  }

  let company_id = a.company_id;
  if (a.company_name && !company_id) {
    const { data: existing } = await supabaseAdmin.from('companies').select('id').ilike('name', a.company_name).maybeSingle();
    if (existing?.id) {
      company_id = existing.id;
    } else {
      const { data: newCo, error } = await supabaseAdmin.from('companies').insert({ name: a.company_name }).select('id').single();
      if (error) throw new Error(error.message);
      company_id = newCo.id;
    }
  }

  const { data: contact, error } = await supabaseAdmin
    .from('contacts')
    .insert({ first_name: a.first_name, last_name: a.last_name, email: a.email, phone: a.phone, job_title: a.job_title, notes: a.notes, company_id, user_id: userId })
    .select('*').single();
  if (error) throw new Error(error.message);

  if (a.event_id) {
    await supabaseAdmin.from('interactions').insert({ contact_id: contact.id, event_id: a.event_id, interaction_type: 'capture', summary: 'Added by assistant', user_id: userId });
    await supabaseAdmin.from('captures').insert({ contact_id: contact.id, event_id: a.event_id, capture_type: 'manual', status: 'completed', raw_data: { source: 'assistant' }, user_id: userId });
  }

  return contact;
}

/**
 * Resolve a contact_id from either a direct UUID or a name, querying supabaseAdmin
 * (the primary) so a contact written moments earlier in the same flow is always visible —
 * Slayer's read-replica path cannot guarantee that. Never auto-picks among ambiguous matches.
 */
async function resolveContactId(
  args: { contact_id?: string; contact_name?: string },
  userId: string,
): Promise<string> {
  if (args.contact_id) return args.contact_id;

  if (!args.contact_name) {
    throw new Error('Either contact_id or contact_name is required.');
  }

  const { data: matches, error } = await supabaseAdmin
    .from('contacts')
    .select('id, first_name, last_name')
    .eq('user_id', userId)
    .is('deleted_at', null)
    .or(`first_name.ilike.%${args.contact_name}%,last_name.ilike.%${args.contact_name}%`);
  if (error) throw new Error(error.message);

  if (!matches || matches.length === 0) {
    throw new Error(`No contact named "${args.contact_name}" found. Use query_crm to list the user's contacts and confirm the exact name.`);
  }
  if (matches.length > 1) {
    const names = matches.map((m) => `${m.first_name ?? ''} ${m.last_name ?? ''}`.trim()).join(', ');
    throw new Error(`Multiple contacts match "${args.contact_name}": ${names}. Ask the user which one.`);
  }
  return matches[0].id;
}

async function execUpdateContact(args: Record<string, unknown>, userId: string) {
  const a = z.object({
    contact_id: z.string().uuid().optional(),
    contact_name: z.string().trim().optional(),
    first_name: z.string().trim().optional(),
    last_name: z.string().trim().optional(),
    email: z.string().trim().email().optional(),
    phone: z.string().trim().optional(),
    job_title: z.string().trim().optional(),
    notes: z.string().trim().optional(),
    follow_up_status: z.string().trim().optional(),
    follow_up_urgency: z.string().trim().optional(),
    last_contacted_at: z.any().optional(),
  }).refine((v) => !!(v.contact_id || v.contact_name), {
    message: 'Either contact_id or contact_name is required.',
  }).parse(args);

  const contactId = await resolveContactId(a, userId);

  const raw: Record<string, unknown> = {};
  if (a.first_name !== undefined) raw.first_name = a.first_name;
  if (a.last_name !== undefined) raw.last_name = a.last_name;
  if (a.email !== undefined) raw.email = a.email;
  if (a.phone !== undefined) raw.phone = a.phone;
  if (a.job_title !== undefined) raw.job_title = a.job_title;
  if (a.notes !== undefined) raw.notes = a.notes;
  if (a.follow_up_status !== undefined) raw.follow_up_status = a.follow_up_status;
  if (a.follow_up_urgency !== undefined) raw.follow_up_urgency = a.follow_up_urgency;
  if (a.last_contacted_at !== undefined) raw.last_contacted_at = toIso(a.last_contacted_at, 'last_contacted_at');

  const update = stripImmutable(raw);
  if (Object.keys(update).length === 0) throw new Error('No valid fields to update');

  // user_id filter ensures the LLM cannot update a contact belonging to another user
  const { data, error } = await supabaseAdmin.from('contacts').update(update).eq('id', contactId).eq('user_id', userId).is('deleted_at', null).select('*').maybeSingle();
  if (error) throw new Error(error.message);
  if (!data) throw new Error('Contact not found or access denied');
  return data;
}

async function execCreateEvent(args: Record<string, unknown>, userId: string) {
  const a = z.object({
    name: z.string().trim().min(1),
    location: z.string().trim().optional(),
    start_date: z.any(),
    end_date: z.any().optional(),
    event_type: z.string().trim().optional(),
  }).parse(args);

  const startIso = toIso(a.start_date, 'start_date');

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

  const { data, error } = await supabaseAdmin.from('events').insert({
    name: a.name, location: a.location,
    start_date: startIso,
    end_date: a.end_date ? toIso(a.end_date, 'end_date') : null,
    event_type: a.event_type,
    user_id: userId,
  }).select('*').single();
  if (error) throw new Error(error.message);
  return data;
}

/**
 * Resolve an event_id from either a direct UUID or a name, querying supabaseAdmin
 * (the primary) so an event written moments earlier in the same flow is always visible —
 * Slayer's read-replica path cannot guarantee that. Never auto-picks among ambiguous matches.
 */
async function resolveEventId(
  args: { event_id?: string; event_name?: string },
  userId: string,
): Promise<string> {
  if (args.event_id) return args.event_id;

  if (!args.event_name) {
    throw new Error('Either event_id or event_name is required.');
  }

  const { data: matches, error } = await supabaseAdmin
    .from('events')
    .select('id, name, start_date')
    .eq('user_id', userId)
    .is('deleted_at', null)
    .ilike('name', `%${args.event_name}%`);
  if (error) throw new Error(error.message);

  if (!matches || matches.length === 0) {
    throw new Error(`No event named "${args.event_name}" found. Use query_crm to list the user's events and confirm the exact name.`);
  }
  if (matches.length > 1) {
    const names = matches.map((m) => `${m.name} (${m.start_date})`).join(', ');
    throw new Error(`Multiple events match "${args.event_name}": ${names}. Ask the user which one.`);
  }
  return matches[0].id;
}

async function execUpdateEvent(args: Record<string, unknown>, userId: string) {
  const a = z.object({
    event_id: z.string().uuid().optional(),
    event_name: z.string().trim().optional(),
    name: z.string().trim().optional(),
    location: z.string().trim().optional(),
    start_date: z.any().optional(),
    end_date: z.any().optional(),
    event_type: z.string().trim().optional(),
  }).refine((v) => !!(v.event_id || v.event_name), {
    message: 'Either event_id or event_name is required.',
  }).parse(args);

  const eventId = await resolveEventId(a, userId);

  const raw: Record<string, unknown> = {};
  if (a.name !== undefined) raw.name = a.name;
  if (a.location !== undefined) raw.location = a.location;
  if (a.start_date !== undefined) {
    const startIso = toIso(a.start_date, 'start_date');
    if (new Date(startIso) < new Date()) throw new Error('Event start date cannot be in the past.');
    raw.start_date = startIso;
  }
  if (a.end_date !== undefined) raw.end_date = toIso(a.end_date, 'end_date');
  if (a.event_type !== undefined) raw.event_type = a.event_type;

  const update = stripImmutable(raw);
  if (Object.keys(update).length === 0) throw new Error('No valid fields to update');

  const { data, error } = await supabaseAdmin.from('events').update(update).eq('id', eventId).eq('user_id', userId).is('deleted_at', null).select('*').maybeSingle();
  if (error) throw new Error(error.message);
  if (!data) throw new Error('Event not found or access denied');
  return data;
}

async function execGetEventFollowups(args: Record<string, unknown>, userId: string) {
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
        follow_up_status, follow_up_urgency, last_contacted_at, notes, scanned_details
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

async function execDraftEmail(args: Record<string, unknown>, userId: string) {
  const a = z.object({
    contact_id: z.string().uuid(),
    subject: z.string().trim().min(1).max(300),
    body: z.string().trim().min(1),
    email_type: z.string().trim().optional(),
    event_id: z.string().uuid().optional(),
  }).parse(args);

  const { data: c } = await supabaseAdmin.from('contacts').select('id').eq('id', a.contact_id).eq('user_id', userId).is('deleted_at', null).maybeSingle();
  if (!c) throw new Error('Contact not found or access denied');

  if (a.event_id) {
    const { data: ev } = await supabaseAdmin.from('events').select('id').eq('id', a.event_id).eq('user_id', userId).is('deleted_at', null).maybeSingle();
    if (!ev) throw new Error('Event not found or access denied');
  }

  const { data, error } = await supabaseAdmin.from('email_drafts').insert({
    contact_id: a.contact_id, subject: a.subject, body: a.body,
    email_type: a.email_type ?? null, event_id: a.event_id ?? null, status: 'draft',
    user_id: userId,
  }).select('*').single();
  if (error) throw new Error(error.message);
  return data;
}

// ─── Tool dispatcher ──────────────────────────────────────────────────────────

type ToolResult = { name: string; ok: boolean; result?: unknown; error?: string };

async function executeTool(
  call: ToolCall,
  userId: string,
): Promise<ToolResult> {
  try {
    let result: unknown;

    if (call.name === 'query_crm') {
      // ── READ: validate shape then forward to Slayer semantic layer ──────────
      // slayerQuery() runs Zod validation + ownership injection internally
      const q = call.args;
      if (typeof q.limit === 'number') q.limit = Math.min(q.limit, 200);

      // Expand date_window into start_date filters, then strip it (Slayer's schema
      // doesn't know the key). This is the model's only correct path for relative
      // date queries — the backend owns the math, so no fragile hand-written filters.
      if (typeof q.date_window === 'string') {
        const windowFilters = expandDateWindow(q.date_window);
        if (windowFilters) {
          q.filters = [...(Array.isArray(q.filters) ? q.filters : []), ...windowFilters];
        }
        delete q.date_window;
      }

      // Ensure card-building columns (id + display fields) are present in the
      // result even when the model didn't ask for them, so any entity the reply
      // mentions can be turned into a linked-entity card.
      const cardCols = LINKABLE_CARD_COLUMNS[q.source_model as string];
      if (cardCols) {
        const dims = new Set<string>(Array.isArray(q.dimensions) ? q.dimensions : []);
        for (const c of cardCols) dims.add(c);
        q.dimensions = Array.from(dims);
      }

      let slayerResult = await slayerQuery(q, userId);

      // Self-heal: a 0-row result on a user-scoped table may be Supabase pooler/replica
      // lag right after a write (Slayer's read connection hasn't caught up yet). One
      // short retry closes that narrow window without masking genuine "no data" results
      // (a second empty read is treated as real).
      if (
        slayerResult.row_count === 0 &&
        typeof q.source_model === 'string' &&
        USER_ID_TABLES.has(q.source_model)
      ) {
        await new Promise((r) => setTimeout(r, 350));
        slayerResult = await slayerQuery(q, userId);
      }

      result = {
        row_count: slayerResult.row_count,
        columns: slayerResult.columns,
        data: slayerResult.data.slice(0, 100), // cap rows sent back to LLM
      };
    } else if (call.name === 'web_search') {
      const a = call.args;
      const query = typeof a.query === 'string' ? a.query.trim() : '';
      if (!query) throw new Error('query is required');
      const results = await TavilyService.search(query, {
        maxResults: Math.min(typeof a.max_results === 'number' ? a.max_results : 5, 10),
        searchDepth: a.search_depth === 'advanced' ? 'advanced' : 'basic',
      });
      result = { query, results };
    } else {
      // ── WRITE: execute directly against Supabase ────────────────────────────
      switch (call.name) {
        case 'create_contact': result = await execCreateContact(call.args, userId); break;
        case 'update_contact': result = await execUpdateContact(call.args, userId); break;
        case 'create_event': result = await execCreateEvent(call.args, userId); break;
        case 'update_event': result = await execUpdateEvent(call.args, userId); break;
        case 'get_event_followups': result = await execGetEventFollowups(call.args, userId); break;
        case 'draft_email': result = await execDraftEmail(call.args, userId); break;
        default:
          throw new Error(`Unknown tool: ${call.name}`);
      }
    }

    return { name: call.name, ok: true, result };
  } catch (e: any) {
    const msg = e?.message || 'Tool error';
    return { name: call.name, ok: false, error: msg };
  }
}

// ─── System prompt builder ────────────────────────────────────────────────────

interface UserProfile {
  name?: string;
  designation?: string;
  profile_type?: string;
  products_services?: string;
  value_proposition?: string;
  additional_context?: string;
  ai_tone?: string;
  website?: string;
  linkedin_url?: string;
}

// Real CRM schema (model -> column names), fetched once from Slayer and cached.
// Grounds the LLM in actual column names so it never invents them (e.g. guessing
// "notes" when the interactions content column is "summary"). Refreshes on restart.
let schemaMapCache: Record<string, string[]> | null = null;
let schemaMapPromise: Promise<Record<string, string[]>> | null = null;

async function getSchemaMap(): Promise<Record<string, string[]>> {
  if (schemaMapCache) return schemaMapCache;
  if (!schemaMapPromise) {
    schemaMapPromise = slayerSchemaMap()
      .then((map) => {
        // Only cache a non-empty result so a transient Slayer outage at first
        // call doesn't permanently poison the cache with an empty schema.
        if (Object.keys(map).length > 0) schemaMapCache = map;
        return map;
      })
      .catch(() => ({}))
      .finally(() => { schemaMapPromise = null; });
  }
  return schemaMapPromise;
}

function buildSchemaSection(schema: Record<string, string[]>): string {
  const models = Object.keys(schema);
  if (models.length === 0) return '';
  const lines = models.map((m) => `- ${m}: ${schema[m].join(', ')}`);
  return `\n\nCRM SCHEMA — these are the ONLY valid column names per model. Use them exactly as written for dimensions, filters, and order. NEVER invent or guess a column name that is not listed here:\n${lines.join('\n')}`;
}

function buildSystemPrompt(userProfile?: UserProfile, researchMode = false, schema: Record<string, string[]> = {}): string {
  const tone = userProfile?.ai_tone ?? 'professional';
  const nowDate = new Date();
  const todayIso = nowDate.toISOString().slice(0, 10); // YYYY-MM-DD UTC
  const nowIso = nowDate.toISOString(); // full timestamp
  // Relative date windows are no longer computed here — the model passes a
  // query_crm "date_window" param and expandDateWindow() owns the bounds.

  const toneInstruction =
    tone === 'casual'     ? 'Use a relaxed, conversational tone — friendly and approachable.' :
    tone === 'formal'     ? 'Use a formal, precise tone — polished and business-appropriate.' :
    tone === 'friendly'   ? 'Use a warm, encouraging tone — supportive and personable.' :
                            'Use a professional tone — clear, confident, and concise.';

  const profileLines: string[] = [];
  if (userProfile?.name)               profileLines.push(`Name: ${userProfile.name}`);
  if (userProfile?.designation)        profileLines.push(`Role: ${userProfile.designation}`);
  if (userProfile?.profile_type)       profileLines.push(`Profile type: ${userProfile.profile_type}`);
  if (userProfile?.products_services)  profileLines.push(`Products & Services: ${userProfile.products_services}`);
  if (userProfile?.value_proposition)  profileLines.push(`Value proposition: ${userProfile.value_proposition}`);
  if (userProfile?.website)            profileLines.push(`Website: ${userProfile.website}`);
  if (userProfile?.linkedin_url)       profileLines.push(`LinkedIn: ${userProfile.linkedin_url}`);
  if (userProfile?.additional_context) profileLines.push(`Additional context: ${userProfile.additional_context}`);

  const profileSection = profileLines.length > 0
    ? `\n\nAbout the user you are assisting:\n${profileLines.join('\n')}`
    : '';

  const schemaSection = buildSchemaSection(schema);

  return `You are an AI CRM assistant for exhibitions and trade shows. ${toneInstruction}

Current time: ${nowIso} (UTC). Today is ${todayIso}.
RELATIVE DATES ON EVENTS — never compute or hand-write date filters. Set the query_crm "date_window" parameter and the backend fills in the exact bounds:
- "today" → date_window: "today"
- "live now" / "currently live" / "happening now" → date_window: "live_now"
- "upcoming" / "from now on" / "coming up" → date_window: "upcoming"
- "next 7 days" / "this week" → date_window: "next_7_days" (or "this_week")
- "next 10 days" → date_window: "next_10_days"
- "next 30 days" / "this month" → date_window: "next_30_days" (or "this_month")
- "past" / "previous" / "already happened" → date_window: "past"
Only use explicit "filters" date ranges for an absolute date the user names (e.g. "events on August 1") or for non-event models — and then always use a half-open timestamptz range, never bare date equality.

You have access to tools to READ and WRITE CRM data.

READ: Use query_crm for any data retrieval — listing contacts, events,
email drafts, captures, companies, searching messages, or reading event goals.
The semantic layer handles SQL — just describe what you want with source_model,
dimensions, filters, and optional measures.
Model hints: event goals (targets/objectives set for an event) live in the "event_goals" model — filter by event_id. Target companies for an event are in "target_companies" — filter by event_id.${schemaSection}

WRITE: Use create_contact, update_contact, create_event, update_event,
draft_email for mutations.

RESEARCH: Use web_search for current, real-time information not in the CRM —
news, company/person background, industry context, or anything that may have
changed since your training data. Use "advanced" search_depth for in-depth research.

Rules:
- ALWAYS call query_crm FIRST before any write operation to look up the record's ID. Never assume you know an ID.
- If the user says "update", "change", "reschedule", "rename", "edit", or anything that implies modifying an existing record: query_crm first by name, get the ID, then call the update tool. NEVER call create_* for an update request.
- Only call create_* when the user explicitly wants a brand-new record that does not yet exist.
- Be concise and action-oriented in your final reply.
- If required info is missing, ask 1-2 focused questions.
- Dates must be ISO 8601 (e.g. 2026-06-01T10:00:00Z).
- You may call multiple tools in sequence — each result is fed back to you.
- NEVER include UUIDs or any database IDs in your text reply. Entity cards are shown separately — just refer to things by name.
- When drafting emails, follow-up messages, or any outbound communication, incorporate the user's products, value proposition, and tone naturally.
- NEVER invent, guess, or default any field value. This includes dates, times, locations, names, emails, and any other data. If the user has not provided a required or relevant detail, you MUST ask a short clarifying question instead of filling it in.
- create_event REQUIRES a date. If the user asks to create an event without giving a date, DO NOT pick a date — ask: "What date is the event?" Optionally also ask for location and event type in the same question. Only call create_event once you have a real date from the user.
- When the user refers to an existing record by name (update/find/draft-for), prefer passing that name to the tool's *_name parameter (event_name / contact_name) so the system resolves it against the live database. Use query_crm to LIST or confirm names, but you do not need a UUID before calling an update tool — the update tool resolves names itself.
- If a tool returns an error saying a record was not found or that multiple matched, relay that to the user and ask them to clarify — NEVER retry with a guessed ID or guessed name.
- Treat tool results as the only source of truth about what exists. If query_crm returns 0 rows, that means you currently cannot see the record — say so and offer to list what you can see; do not assert the record does or does not exist beyond what the tool returned.
- DATE QUERIES: For relative windows (today/live/upcoming/next N days/past) use the "date_window" parameter — never hand-write the filter. For an absolute date the user names, start_date/end_date/created_at are timestamptz, so NEVER use equality (start_date = 'YYYY-MM-DD') — use a half-open range start_date >= 'YYYY-MM-DDT00:00:00Z' AND start_date < (next day). If a time-window query returns 0 rows, report that no records fell in that window — do not contradict a subsequent broader query that finds the same records.${profileSection}${
    researchMode
      ? `

RESEARCH MODE IS ON: The user has explicitly requested in-depth research for this message.
You MUST call web_search with search_depth "advanced" at least once before replying — run multiple
searches from different angles if needed (e.g. company + people + recent news) to gather thorough,
current information. Synthesize findings into a well-organized, detailed reply with sources.`
      : ''
  }`;
}

// ─── POST /api/assistant/respond ─────────────────────────────────────────────

const respondSchema = z.object({
  conversation_id: z.string().uuid(),
  text: z.string().trim().min(1).max(8000),
  research_mode: z.boolean().optional(),
});

router.post('/respond', async (req, res) => {
  const parsed = respondSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });

  const supabaseUser = createSupabaseUserClient(req.accessToken!);
  const userId = req.user!.id;
  const { conversation_id, text: rawText, research_mode } = parsed.data;

  // Sanitise user input — truncate + log suspicious injection attempts
  const text = sanitiseUserInput(rawText, userId);

  // Rate limit
  const rate = await checkRateLimit(userId);
  if (!rate.ok) {
    res.setHeader('Retry-After', String(rate.retryAfterSeconds));
    return res.status(429).json({ error: 'Rate limit exceeded. Please retry shortly.' });
  }

  const correlationId = (typeof req.headers['x-correlation-id'] === 'string' && req.headers['x-correlation-id']) || randomUUID();
  res.setHeader('x-correlation-id', correlationId);

  // 1. Persist user message
  const { data: userMessage, error: userMsgErr } = await supabaseUser
    .from('messages')
    .insert({ conversation_id, user_id: userId, sender_type: 'user', sender_user_id: userId, content: text, research_mode: research_mode === true })
    .select('*').single();
  if (userMsgErr) return res.status(400).json({ error: userMsgErr.message });

  // (auto-titling is done after the assistant response, see below)

  try {
    // 2. Load user profile context
    const { data: userProfile } = await supabaseAdmin.from('user_profiles').select('name, designation, profile_type, products_services, value_proposition, additional_context, ai_tone, website, linkedin_url').eq('user_id', userId).maybeSingle();
    const schema = await getSchemaMap();
    const systemPrompt = buildSystemPrompt(userProfile ?? undefined, research_mode === true, schema);

    // 3. Build conversation history (last 20 messages)
    const { data: recentMessages } = await supabaseUser
      .from('messages')
      .select('sender_type, content')
      .eq('conversation_id', conversation_id)
      .order('created_at', { ascending: false })
      .limit(20);

    const history: ConversationTurn[] = (recentMessages ?? [])
      .slice().reverse()
      .map((m) => ({
        role: m.sender_type === 'user' ? 'user' : 'assistant',
        content: m.content,
      } as ConversationTurn));

    // 4. Agentic loop — max 6 iterations
    const MAX_ITERATIONS = 6;
    let assistantText = '';
    const allToolResults: ToolResult[] = [];
    // Entities surfaced by query_crm reads, keyed by id. After the reply is
    // generated we attach the ones the assistant actually named (see step 6).
    const readCandidates = new Map<string, { type: string; payload: Record<string, unknown> }>();

    for (let i = 0; i < MAX_ITERATIONS; i++) {
      const llmResult = await litellm.generateWithTools(systemPrompt, history, ALL_TOOLS);

      if (llmResult.type === 'text') {
        assistantText = llmResult.content;
        break;
      }

      // Execute all requested tool calls (sequentially — results may depend on each other)
      const iterResults: Array<{ id: string; name: string; result: unknown }> = [];

      for (const call of llmResult.calls) {
        const toolResult = await executeTool(call, userId);
        allToolResults.push(toolResult);

        // query_crm failures split two ways:
        //  - A malformed query (Slayer 4xx — bad filter syntax, invalid column, the
        //    model leaked array punctuation into a value) is the model's fault and is
        //    recoverable: feed the error back so it fixes the query next iteration.
        //  - Slayer being unreachable/5xx is infra — abort the turn so the model never
        //    proceeds to write tools on missing data.
        if (call.name === 'query_crm' && !toolResult.ok) {
          const msg = toolResult.error ?? '';
          const recoverable = /failed \(4\d\d\)|Invalid filter|invalid|syntax|unmatched|not found|unknown column/i.test(msg);
          if (!recoverable) {
            throw new Error('CRM query service is unavailable. Please try again in a moment.');
          }
          // Recoverable: pass a corrective hint back to the model.
          iterResults.push({
            id: call.id,
            name: call.name,
            result: { error: `Query rejected: ${msg}. Fix the query and call query_crm again. Each filter must be a plain condition string like "start_date >= '2026-06-21T00:00:00Z'" with no surrounding brackets, commas, or quotes around the whole condition.` },
          });
          continue;
        }

        // When a read returns exactly ONE linkable entity, the assistant is
        // talking about that specific record — attach it as a card. (Multi-row
        // results are lists; we don't card every row.)
        if (call.name === 'query_crm' && toolResult.ok) {
          const model = call.args.source_model as string;
          const rows = (toolResult.result as { data?: Record<string, unknown>[] })?.data;
          if (LINKABLE_CARD_COLUMNS[model] && Array.isArray(rows) && rows.length === 1) {
            const entity = readRowToEntity(model, normaliseRow(rows[0]));
            if (entity) readCandidates.set(entity.id, { type: entity.type, payload: entity.payload });
          }
        }

        iterResults.push({
          id: call.id,
          name: call.name,
          result: toolResult.ok ? toolResult.result : { error: toolResult.error },
        });
      }

      // Append tool calls + results to history for next iteration.
      // _geminiParts carries thought_signature fields required by Gemini thinking models.
      history.push({ role: 'tool_calls', calls: llmResult.calls, _geminiParts: (llmResult as any)._geminiParts });
      history.push({ role: 'tool_results', results: iterResults });
    }

    // If the loop exhausted without a text response, generate a summary
    if (!assistantText) {
      const summaryResult = await litellm.generateWithTools(systemPrompt, [
        ...history,
        { role: 'user', content: 'Summarise what was done in one or two sentences.' },
      ], []);
      assistantText = summaryResult.type === 'text' ? summaryResult.content : 'Done.';
    }

    // 5. Persist assistant message
    const { data: assistantMessage, error: assistantErr } = await supabaseUser
      .from('messages')
      .insert({ conversation_id, user_id: userId, sender_type: 'assistant', sender_user_id: null, content: assistantText || 'Done.' })
      .select('*').single();
    if (assistantErr) throw new Error(assistantErr.message);

    // 6. Build linked entities. Write results (create/update/draft) are always
    // attached — the assistant just acted on them. Read results (query_crm) are
    // attached only when the assistant actually NAMES the entity in its reply, so
    // "list all events" doesn't dump a card per row but "one event today: testing"
    // links "testing".
    const linkedEntitiesMap = new Map<string, any>();
    for (const tr of allToolResults) {
      if (!tr.ok || !tr.result || typeof tr.result !== 'object') continue;
      const r = tr.result as Record<string, unknown>;
      if (!r.id) continue;
      const id = r.id as string;
      if (tr.name === 'create_contact' || tr.name === 'update_contact') {
        linkedEntitiesMap.set(id, { type: 'contact', id, first_name: r.first_name, last_name: r.last_name });
      } else if (tr.name === 'create_event' || tr.name === 'update_event') {
        linkedEntitiesMap.set(id, { type: 'event', id, name: r.name, start_date: r.start_date, location: r.location });
      } else if (tr.name === 'draft_email') {
        linkedEntitiesMap.set(id, { type: 'email_draft', id, subject: r.subject });
      }
    }

    // Attach single-entity read results. Skip ids already added by a write result.
    for (const [id, cand] of readCandidates) {
      if (!linkedEntitiesMap.has(id)) linkedEntitiesMap.set(id, cand.payload);
    }

    const linkedEntities = Array.from(linkedEntitiesMap.values());

    // Persist linked entities on the assistant message so history reloads include them
    if (linkedEntities.length > 0 && assistantMessage?.id) {
      const { error: updateErr } = await supabaseAdmin
        .from('messages')
        .update({ linked_entities: linkedEntities })
        .eq('id', assistantMessage.id);
      if (updateErr) console.error('[assistant] failed to save linked_entities:', updateErr.message);
      if (assistantMessage) (assistantMessage as any).linked_entities = linkedEntities;
    }

    // 7. Await titling (only happens on first message) and fetch updated conversation
    await autoTitleConversation(supabaseUser, conversation_id, text);
    const { data: conversation } = await supabaseUser.from('conversations').select('*').eq('id', conversation_id).single();

    res.json({
      user_message: userMessage,
      assistant_message: assistantMessage,
      conversation: conversation,
      linked_entities: linkedEntities,
    });

  } catch (err: any) {
    // Roll back the user message so a failed turn leaves nothing persisted —
    // the client keeps the message as an optimistic bubble with inline retry,
    // and a retry re-sends cleanly without creating a duplicate.
    if (userMessage?.id) {
      await supabaseAdmin.from('messages').delete().eq('id', userMessage.id);
    }
    res.status(500).json({ error: err?.message || 'Assistant error' });
  }
});

// ─── GET /api/assistant/health ────────────────────────────────────────────────
// Lets the frontend check whether Slayer is up.
router.get('/health', async (_req, res) => {
  const slayer = await slayerHealthy();
  res.json({ status: 'ok', slayer_available: slayer });
});

export default router;
