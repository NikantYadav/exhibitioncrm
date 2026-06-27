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

// ─── System-managed columns — never writable by the assistant ────────────────
// The single safety denylist. Anything NOT here is allowed to flow to the DB
// (Supabase rejects columns that don't actually exist), so adding a normal
// column to a table auto-exposes it without code changes. These are the columns
// that are identity/ownership, audit timestamps, soft-delete, sync bookkeeping,
// or AI/enrichment-generated — letting the model write them corrupts data or
// breaks ownership/security. Verified against the live schema (information_schema).
// NOTE: relational FKs (event_id, company_id, contact_id, …) are intentionally
// NOT denied here — some are legitimate write-tool inputs (create_contact links an
// event_id/company_id). They are gated per-tool by Zod + ownership checks instead.
const IMMUTABLE_FIELDS = new Set([
  // identity / ownership keys set by the system
  'id', 'user_id', 'sender_user_id',
  // audit + soft-delete bookkeeping
  'created_at', 'updated_at', 'deleted_at',
  // offline-sync bookkeeping
  'client_op_id',
  // AI / enrichment generated — owned by background jobs, not the assistant.
  // (scanned_details is intentionally NOT here — the assistant may edit it via
  // the update_contact `scanned_details` param, validated + merged below.)
  'ai_insights', 'ai_insights_generated_at', 'contact_assets',
  'ai_context_summary', 'ai_context_summarized_through',
  'enriched_at', 'enrichment_failed', 'enrichment_confidence',
  // media handled by dedicated upload flows
  'avatar_url', 'image_url',
  // status / activity timestamps maintained by app flows, not free-form writes.
  // (last_contacted_at is intentionally NOT here — update_contact sets it on
  // purpose, e.g. "mark Sasha as contacted today".)
  'sent_at', 'done_at', 'last_interaction_at', 'met',
  // chat/message internals
  'conversation_id', 'content', 'sender_type', 'linked_entities', 'research_mode',
  // assistant pending-action internals
  'loop_state', 'tool_name', 'tool_args', 'user_message_id', 'summary',
  // rate-limit bookkeeping
  'request_count', 'window_start', 'scope',
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
attachments, contact_events, follow_ups, target_companies,
target_company_met, event_goals.

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
        linkedin_url: { type: 'string', description: 'LinkedIn profile URL' },
        notes: { type: 'string' },
        scanned_details: {
          type: 'object',
          description: 'Extra business-card details as a FLAT object of string values (e.g. {"address": "Doha, Qatar", "fax": "+974..."}). For fields with no dedicated parameter (address, fax, alternate phone, website, etc.) — NOT notes. Values must be strings; no nested objects or arrays.',
          additionalProperties: { type: 'string' },
        },
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
        linkedin_url: { type: 'string', description: 'LinkedIn profile URL' },
        notes: { type: 'string' },
        follow_up_status: { type: 'string', enum: ['not_contacted', 'contacted', 'needs_followup', 'ignore'] },
        last_contacted_at: { type: 'string', description: 'ISO 8601 datetime' },
        scanned_details: {
          type: 'object',
          description: 'Extra business-card details as a FLAT object of string values (e.g. {"address": "Doha, Qatar", "fax": "+974...", "website": "x.com"}). Merged into existing scanned details — only include the keys you are adding or changing; set a key to "" to remove it. Use this (NOT notes) when the user wants to add an address, fax, alternate phone, website, or other card field. Values must be strings; no nested objects or arrays.',
          additionalProperties: { type: 'string' },
        },
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
        start_time: { type: 'string', description: 'Time of day the event starts, 24h HH:MM (e.g. "09:30")' },
        end_time: { type: 'string', description: 'Time of day the event ends, 24h HH:MM. Must be after start_time.' },
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
        start_time: { type: 'string', description: 'Time of day the event starts, 24h HH:MM (e.g. "09:30")' },
        end_time: { type: 'string', description: 'Time of day the event ends, 24h HH:MM. Must be after start_time.' },
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

// Tools that MUTATE data — these require explicit user permission before they run.
// get_event_followups is a read despite living in WRITE_TOOLS, so it is excluded.
const WRITE_TOOL_NAMES = new Set([
  'create_contact', 'update_contact', 'create_event', 'update_event', 'draft_email',
]);

// Build a short, human-readable description of a proposed write for the
// confirmation card. Kept deliberately plain — no IDs, just what will happen.
function describeWrite(call: ToolCall): string {
  const a = call.args as Record<string, any>;
  const name = (v: any) => (typeof v === 'string' && v.trim() ? v.trim() : null);
  switch (call.name) {
    case 'create_contact': {
      const full = [name(a.first_name), name(a.last_name)].filter(Boolean).join(' ');
      const co = name(a.company_name) ? ` at ${name(a.company_name)}` : '';
      return `Create a new contact${full ? `: ${full}` : ''}${co}`;
    }
    case 'update_contact':
      return `Update contact ${name(a.contact_name) ?? '(selected)'}`;
    case 'create_event':
      return `Create a new event${name(a.name) ? `: ${name(a.name)}` : ''}`;
    case 'update_event':
      return `Update event ${name(a.event_name) ?? '(selected)'}`;
    case 'draft_email':
      return `Draft an email${name(a.subject) ? `: "${name(a.subject)}"` : ''}`;
    default:
      return `Perform ${call.name.replace(/_/g, ' ')}`;
  }
}

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

// 24h HH:MM time-of-day (events.start_time / end_time). Mirrors the validation in
// routes/events.ts: end_time must be after start_time and cannot stand alone.
const timeOfDay = z.string().trim().regex(/^([01]\d|2[0-3]):[0-5]\d$/, 'Time must be 24h HH:MM');

function assertTimeRange(start?: string, end?: string): void {
  if (end != null && start == null) throw new Error('end_time requires a start_time');
  if (start != null && end != null && end <= start) throw new Error('end_time must be after start_time');
}

// scanned_details is a flat { key: string } dictionary of extra business-card
// fields (address, website, fax, telephone, …). The assistant may edit it, but
// only as a flat object of string (or number→string) values — nested objects /
// arrays would break the card-scan UI that reads it. Numbers/bools are coerced
// to strings; anything else is rejected.
const scannedDetailsSchema = z.record(
  z.string().min(1),
  z.union([z.string(), z.number(), z.boolean()]).transform((v) => String(v)),
);

/**
 * Merge a partial scanned_details patch into the existing object so editing one
 * field ("add address") never wipes the other scanned fields. A key set to an
 * empty string is removed. Returns the merged object to persist.
 */
function mergeScannedDetails(
  existing: Record<string, unknown> | null | undefined,
  patch: Record<string, string>,
): Record<string, string> {
  const out: Record<string, string> = {};
  if (existing && typeof existing === 'object' && !Array.isArray(existing)) {
    for (const [k, v] of Object.entries(existing)) {
      if (typeof v === 'string') out[k] = v;
      else if (v != null && (typeof v === 'number' || typeof v === 'boolean')) out[k] = String(v);
    }
  }
  for (const [k, v] of Object.entries(patch)) {
    if (v === '') delete out[k];
    else out[k] = v;
  }
  return out;
}

async function execCreateContact(args: Record<string, unknown>, userId: string) {
  const a = z.object({
    first_name: z.string().trim().min(1),
    last_name: z.string().trim().optional(),
    email: z.string().trim().email().optional(),
    phone: z.string().trim().optional(),
    job_title: z.string().trim().optional(),
    linkedin_url: z.string().trim().optional(),
    notes: z.string().trim().optional(),
    scanned_details: scannedDetailsSchema.optional(),
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

  // Generic copy of the plain column values (Plan B): every provided field flows
  // through except the linking/resolver keys handled explicitly below. Adding a
  // new contact column then means only adding it to the Zod schema above.
  const LINKING_KEYS = new Set(['company_id', 'company_name', 'event_id']);
  const insert: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(a)) {
    if (v === undefined || LINKING_KEYS.has(k)) continue;
    insert[k] = v;
  }
  // Normalise scanned_details (drop empty-string keys) — no existing on create.
  if (a.scanned_details !== undefined) {
    insert.scanned_details = mergeScannedDetails(null, a.scanned_details);
  }
  const { data: contact, error } = await supabaseAdmin
    .from('contacts')
    .insert({ ...stripImmutable(insert), company_id, user_id: userId })
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
    linkedin_url: z.string().trim().optional(),
    notes: z.string().trim().optional(),
    follow_up_status: z.string().trim().optional(),
    last_contacted_at: z.any().optional(),
    scanned_details: scannedDetailsSchema.optional(),
  }).refine((v) => !!(v.contact_id || v.contact_name), {
    message: 'Either contact_id or contact_name is required.',
  }).parse(args);

  const contactId = await resolveContactId(a, userId);

  // Build the update from every provided value except the resolver keys (which
  // pick the target, not a column) and any specially-handled field. Adding a new
  // editable field then means only adding it to the Zod schema above.
  const RESOLVER_KEYS = new Set(['contact_id', 'contact_name', 'last_contacted_at', 'scanned_details']);
  const raw: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(a)) {
    if (v === undefined || RESOLVER_KEYS.has(k)) continue;
    raw[k] = v;
  }
  if (a.last_contacted_at !== undefined) raw.last_contacted_at = toIso(a.last_contacted_at, 'last_contacted_at');

  // scanned_details is merged into the existing object so editing one field
  // never wipes the rest of the scanned card data.
  if (a.scanned_details !== undefined) {
    const { data: existing } = await supabaseAdmin
      .from('contacts').select('scanned_details')
      .eq('id', contactId).eq('user_id', userId).is('deleted_at', null).maybeSingle();
    raw.scanned_details = mergeScannedDetails(existing?.scanned_details as Record<string, unknown> | null, a.scanned_details);
  }

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
- WRITABLE FIELDS ONLY: you can only write the fields exposed by the write tools' parameters. For extra business-card details that have no dedicated parameter — address, fax, alternate/secondary phone, website, PO box, etc. — use the "scanned_details" object parameter on create_contact/update_contact (a flat {key: "value"} map, merged into the existing details). Do NOT dump such details into "notes". Some data IS system-managed and NOT editable at all: AI-generated insights/summaries, avatar image, enrichment data, and all timestamps/IDs. If the user asks to edit one of those, say plainly it can't be edited here rather than silently writing a different field.
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

// ─── Agentic loop (shared by /respond and /resume) ────────────────────────────

type ReadCandidate = { id: string; type: string; payload: Record<string, unknown> };

// Fully JSON-serializable snapshot of an in-flight agentic turn, persisted on a
// pending action so the loop can be suspended for a permission prompt and resumed.
interface LoopState {
  history: ConversationTurn[];
  allToolResults: ToolResult[];
  readCandidates: ReadCandidate[];
  iteration: number;
  // Carried across a permission pause so the resumed turn keeps research mode on
  // (web_search stays "advanced"). The pause is a continuation of the same turn.
  researchMode: boolean;
}

const MAX_ITERATIONS = 6;

type LoopOutcome =
  | { kind: 'done'; assistantText: string }
  | { kind: 'paused'; call: ToolCall };

/**
 * Drive the tool-calling loop from the given state. Reads/searches execute
 * inline; the FIRST write tool the model requests pauses the loop (kind:'paused')
 * so the caller can ask the user for permission. Resuming = calling this again
 * after appending the write's tool_result to state.history.
 */
async function runLoop(
  state: LoopState,
  systemPrompt: string,
  userId: string,
): Promise<LoopOutcome> {
  const readCandidates = new Map<string, ReadCandidate>(
    state.readCandidates.map((c) => [c.id, c]),
  );

  for (; state.iteration < MAX_ITERATIONS; state.iteration++) {
    const llmResult = await litellm.generateWithTools(systemPrompt, state.history, ALL_TOOLS);

    if (llmResult.type === 'text') {
      state.readCandidates = Array.from(readCandidates.values());
      return { kind: 'done', assistantText: llmResult.content };
    }

    // A write request pauses the whole turn. The model may batch a write with
    // reads in one step; we honour the first write and defer the rest by only
    // executing calls up to (not including) that write this iteration. On resume
    // the model re-plans with the write's result in hand.
    const writeIdx = llmResult.calls.findIndex((c) => WRITE_TOOL_NAMES.has(c.name));

    const callsToRun = writeIdx === -1 ? llmResult.calls : llmResult.calls.slice(0, writeIdx);
    const iterResults: Array<{ id: string; name: string; result: unknown }> = [];

    for (const call of callsToRun) {
      const toolResult = await executeTool(call, userId);
      state.allToolResults.push(toolResult);

      if (call.name === 'query_crm' && !toolResult.ok) {
        const msg = toolResult.error ?? '';
        const recoverable = /failed \(4\d\d\)|Invalid filter|invalid|syntax|unmatched|not found|unknown column/i.test(msg);
        if (!recoverable) {
          throw new Error('CRM query service is unavailable. Please try again in a moment.');
        }
        iterResults.push({
          id: call.id,
          name: call.name,
          result: { error: `Query rejected: ${msg}. Fix the query and call query_crm again. Each filter must be a plain condition string like "start_date >= '2026-06-21T00:00:00Z'" with no surrounding brackets, commas, or quotes around the whole condition.` },
        });
        continue;
      }

      if (call.name === 'query_crm' && toolResult.ok) {
        const model = call.args.source_model as string;
        const rows = (toolResult.result as { data?: Record<string, unknown>[] })?.data;
        if (LINKABLE_CARD_COLUMNS[model] && Array.isArray(rows) && rows.length === 1) {
          const entity = readRowToEntity(model, normaliseRow(rows[0]));
          if (entity) readCandidates.set(entity.id, { id: entity.id, type: entity.type, payload: entity.payload });
        }
      }

      iterResults.push({
        id: call.id,
        name: call.name,
        result: toolResult.ok ? toolResult.result : { error: toolResult.error },
      });
    }

    // Persist read candidates before we possibly suspend.
    state.readCandidates = Array.from(readCandidates.values());

    if (writeIdx !== -1) {
      const writeCall = llmResult.calls[writeIdx];
      // Record the model's planned tool_calls turn truncated to what we ran (the
      // pre-write reads + the write itself), plus the read results, so that on
      // resume the conversation is consistent and the write's tool_result slots in.
      const ranCalls = llmResult.calls.slice(0, writeIdx + 1);
      state.history.push({ role: 'tool_calls', calls: ranCalls, _geminiParts: (llmResult as any)._geminiParts });
      if (iterResults.length > 0) {
        state.history.push({ role: 'tool_results', results: iterResults });
      }
      return { kind: 'paused', call: writeCall };
    }

    state.history.push({ role: 'tool_calls', calls: llmResult.calls, _geminiParts: (llmResult as any)._geminiParts });
    state.history.push({ role: 'tool_results', results: iterResults });
  }

  // Loop exhausted without a text reply — ask for a one-line summary.
  state.readCandidates = Array.from(readCandidates.values());
  const summaryResult = await litellm.generateWithTools(systemPrompt, [
    ...state.history,
    { role: 'user', content: 'Summarise what was done in one or two sentences.' },
  ], []);
  return {
    kind: 'done',
    assistantText: summaryResult.type === 'text' ? summaryResult.content : 'Done.',
  };
}

/**
 * Persist the assistant's final reply + linked-entity cards, run titling, and
 * shape the success JSON. Shared by /respond and /resume.
 */
async function finalizeTurn(
  supabaseUser: ReturnType<typeof createSupabaseUserClient>,
  conversationId: string,
  userId: string,
  text: string,
  state: LoopState,
) {
  const { data: assistantMessage, error: assistantErr } = await supabaseUser
    .from('messages')
    .insert({ conversation_id: conversationId, user_id: userId, sender_type: 'assistant', sender_user_id: null, content: text || 'Done.' })
    .select('*').single();
  if (assistantErr) throw new Error(assistantErr.message);

  const linkedEntitiesMap = new Map<string, any>();
  for (const tr of state.allToolResults) {
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
  for (const cand of state.readCandidates) {
    if (!linkedEntitiesMap.has(cand.id)) linkedEntitiesMap.set(cand.id, cand.payload);
  }

  const linkedEntities = Array.from(linkedEntitiesMap.values());
  if (linkedEntities.length > 0 && assistantMessage?.id) {
    const { error: updateErr } = await supabaseAdmin
      .from('messages')
      .update({ linked_entities: linkedEntities })
      .eq('id', assistantMessage.id);
    if (updateErr) console.error('[assistant] failed to save linked_entities:', updateErr.message);
    if (assistantMessage) (assistantMessage as any).linked_entities = linkedEntities;
  }

  return { assistantMessage, linkedEntities };
}

/**
 * Suspend the loop on a pending write: persist the state + the proposed write and
 * return the pending-action descriptor the client renders as a confirmation card.
 */
async function suspendForPermission(
  conversationId: string,
  userId: string,
  userMessageId: string | null,
  call: ToolCall,
  state: LoopState,
) {
  const summary = describeWrite(call);
  const { data, error } = await supabaseAdmin
    .from('assistant_pending_actions')
    .insert({
      conversation_id: conversationId,
      user_id: userId,
      user_message_id: userMessageId,
      tool_name: call.name,
      tool_args: call.args,
      summary,
      status: 'pending',
      loop_state: { ...state, pending_call: call },
    })
    .select('id, tool_name, tool_args, summary')
    .single();
  if (error) throw new Error(error.message);

  return {
    status: 'awaiting_permission',
    pending_action: {
      id: data.id,
      tool_name: data.tool_name,
      tool_args: data.tool_args,
      summary: data.summary,
    },
  };
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

    // 4. Run the agentic loop. It either completes with a text reply or pauses
    //    on the first write tool, awaiting the user's permission.
    const state: LoopState = { history, allToolResults: [], readCandidates: [], iteration: 0, researchMode: research_mode === true };
    const outcome = await runLoop(state, systemPrompt, userId);

    if (outcome.kind === 'paused') {
      // Suspend: persist state + the proposed write, return a permission request.
      // The user message stays persisted (titling runs on resume).
      const pending = await suspendForPermission(
        conversation_id, userId, userMessage?.id ?? null, outcome.call, state,
      );
      return res.json({ user_message: userMessage, ...pending });
    }

    // 5. Completed — persist reply, attach cards, title, respond.
    const { assistantMessage, linkedEntities } = await finalizeTurn(
      supabaseUser, conversation_id, userId, outcome.assistantText, state,
    );
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

// ─── POST /api/assistant/resume ──────────────────────────────────────────────
// Approve or deny a pending write. On approve the write executes and the loop
// continues; on deny the model is told the user declined and continues.

const resumeSchema = z.object({
  pending_action_id: z.string().uuid(),
  decision: z.enum(['approve', 'deny']),
});

router.post('/resume', async (req, res) => {
  const parsed = resumeSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });

  const supabaseUser = createSupabaseUserClient(req.accessToken!);
  const userId = req.user!.id;
  const { pending_action_id, decision } = parsed.data;

  // Load + lock the pending action (admin client; RLS-safe via explicit user_id filter).
  const { data: pa, error: paErr } = await supabaseAdmin
    .from('assistant_pending_actions')
    .select('*')
    .eq('id', pending_action_id)
    .eq('user_id', userId)
    .maybeSingle();
  if (paErr) return res.status(500).json({ error: paErr.message });
  if (!pa) return res.status(404).json({ error: 'Pending action not found' });
  if (pa.status !== 'pending') {
    return res.status(409).json({ error: 'This action has already been resolved.' });
  }

  const conversation_id = pa.conversation_id as string;
  const loop = pa.loop_state as LoopState & { pending_call: ToolCall };
  const call = loop.pending_call;
  const state: LoopState = {
    history: loop.history,
    allToolResults: loop.allToolResults,
    readCandidates: loop.readCandidates,
    iteration: loop.iteration,
    researchMode: loop.researchMode === true,
  };

  try {
    // Resolve the write -> a tool_result the model sees next.
    let resultPayload: unknown;
    if (decision === 'approve') {
      const toolResult = await executeTool(call, userId);
      state.allToolResults.push(toolResult);
      resultPayload = toolResult.ok ? toolResult.result : { error: toolResult.error };
    } else {
      resultPayload = { error: 'The user declined this action. Do not retry it. Acknowledge briefly and ask how else you can help, or continue with anything that does not require it.' };
    }

    // Slot the write's result into the suspended conversation, then advance the
    // iteration counter past the paused step before continuing.
    state.history.push({ role: 'tool_results', results: [{ id: call.id, name: call.name, result: resultPayload }] });
    state.iteration += 1;

    // Mark the action resolved before continuing (idempotent against double-tap).
    await supabaseAdmin
      .from('assistant_pending_actions')
      .update({ status: decision === 'approve' ? 'executed' : 'denied', updated_at: new Date().toISOString() })
      .eq('id', pending_action_id);

    // Rebuild the system prompt, preserving research mode from the original turn
    // so web_search stays "advanced" after the user approves a write mid-turn.
    const { data: userProfile } = await supabaseAdmin.from('user_profiles').select('name, designation, profile_type, products_services, value_proposition, additional_context, ai_tone, website, linkedin_url').eq('user_id', userId).maybeSingle();
    const schema = await getSchemaMap();
    const systemPrompt = buildSystemPrompt(userProfile ?? undefined, state.researchMode, schema);

    const outcome = await runLoop(state, systemPrompt, userId);

    if (outcome.kind === 'paused') {
      const pending = await suspendForPermission(
        conversation_id, userId, pa.user_message_id as string | null, outcome.call, state,
      );
      return res.json(pending);
    }

    const { assistantMessage, linkedEntities } = await finalizeTurn(
      supabaseUser, conversation_id, userId, outcome.assistantText, state,
    );
    const { data: conversation } = await supabaseUser.from('conversations').select('*').eq('id', conversation_id).single();

    res.json({
      assistant_message: assistantMessage,
      conversation,
      linked_entities: linkedEntities,
    });
  } catch (err: any) {
    // Re-open the action so the user can retry the decision.
    await supabaseAdmin
      .from('assistant_pending_actions')
      .update({ status: 'pending' })
      .eq('id', pending_action_id);
    res.status(500).json({ error: err?.message || 'Assistant error' });
  }
});

// ─── GET /api/assistant/pending ──────────────────────────────────────────────
// The latest unresolved write awaiting permission for a conversation, if any.
// Lets the client restore the confirmation card after it was backgrounded /
// navigated away mid-turn (the turn is suspended server-side with no message row).

const pendingQuerySchema = z.object({
  conversation_id: z.string().uuid(),
});

router.get('/pending', async (req, res) => {
  const parsed = pendingQuerySchema.safeParse(req.query);
  if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });
  const userId = req.user!.id;

  const { data, error } = await supabaseAdmin
    .from('assistant_pending_actions')
    .select('id, tool_name, tool_args, summary')
    .eq('conversation_id', parsed.data.conversation_id)
    .eq('user_id', userId)
    .eq('status', 'pending')
    .order('created_at', { ascending: false })
    .limit(1)
    .maybeSingle();
  if (error) return res.status(500).json({ error: error.message });

  res.json({ pending_action: data ?? null });
});

// ─── GET /api/assistant/health ────────────────────────────────────────────────
// Lets the frontend check whether Slayer is up.
router.get('/health', async (_req, res) => {
  const slayer = await slayerHealthy();
  res.json({ status: 'ok', slayer_available: slayer });
});

export default router;
