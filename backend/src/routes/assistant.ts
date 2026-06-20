import { Router } from 'express';
import { randomUUID } from 'crypto';
import { z } from 'zod';
import { requireAuth } from '../middleware/requireAuth';
import { createSupabaseUserClient } from '../config/supabaseClients';
import { supabase as supabaseAdmin } from '../config/supabase';
import { litellm, ConversationTurn, ToolCall } from '../services/litellm-service';
import { slayerQuery, slayerHealthy } from '../services/slayer-client';
import { autoTitleConversation } from '../services/ai/titling';

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
attachments.`,
  parameters: {
    type: 'object',
    properties: {
      source_model: {
        type: 'string',
        description: 'The CRM table/model to query (e.g. contacts, events, notes)',
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
        description: 'Filter conditions e.g. ["follow_up_status = \'needs_followup\'", "created_at > \'2025-01-01\'"]',
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
    description: 'Update fields on an existing contact',
    parameters: {
      type: 'object',
      properties: {
        contact_id: { type: 'string' },
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
      required: ['contact_id'],
    },
  },
  {
    name: 'create_event',
    description: 'Create a new event/exhibition',
    parameters: {
      type: 'object',
      properties: {
        name: { type: 'string' },
        location: { type: 'string' },
        start_date: { type: 'string', description: 'ISO 8601 datetime' },
        end_date: { type: 'string', description: 'ISO 8601 datetime' },
        event_type: { type: 'string' },
      },
      required: ['name', 'start_date'],
    },
  },
  {
    name: 'update_event',
    description: 'Update fields on an existing event. Always query_crm first to get the event_id.',
    parameters: {
      type: 'object',
      properties: {
        event_id: { type: 'string', description: 'UUID of the event to update' },
        name: { type: 'string' },
        location: { type: 'string' },
        start_date: { type: 'string', description: 'ISO 8601 datetime' },
        end_date: { type: 'string', description: 'ISO 8601 datetime' },
        event_type: { type: 'string' },
      },
      required: ['event_id'],
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

const ALL_TOOLS = [SLAYER_QUERY_TOOL, ...WRITE_TOOLS];

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

async function execUpdateContact(args: Record<string, unknown>, userId: string) {
  const a = z.object({
    contact_id: z.string().uuid(),
    first_name: z.string().trim().optional(),
    last_name: z.string().trim().optional(),
    email: z.string().trim().email().optional(),
    phone: z.string().trim().optional(),
    job_title: z.string().trim().optional(),
    notes: z.string().trim().optional(),
    follow_up_status: z.string().trim().optional(),
    follow_up_urgency: z.string().trim().optional(),
    last_contacted_at: z.any().optional(),
  }).parse(args);

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
  const { data, error } = await supabaseAdmin.from('contacts').update(update).eq('id', a.contact_id).eq('user_id', userId).is('deleted_at', null).select('*').maybeSingle();
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

async function execUpdateEvent(args: Record<string, unknown>, userId: string) {
  const a = z.object({
    event_id: z.string().uuid(),
    name: z.string().trim().optional(),
    location: z.string().trim().optional(),
    start_date: z.any().optional(),
    end_date: z.any().optional(),
    event_type: z.string().trim().optional(),
  }).parse(args);

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

  const { data, error } = await supabaseAdmin.from('events').update(update).eq('id', a.event_id).eq('user_id', userId).is('deleted_at', null).select('*').maybeSingle();
  if (error) throw new Error(error.message);
  if (!data) throw new Error('Event not found or access denied');
  return data;
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
      const slayerResult = await slayerQuery(q, userId);
      result = {
        row_count: slayerResult.row_count,
        columns: slayerResult.columns,
        data: slayerResult.data.slice(0, 100), // cap rows sent back to LLM
      };
    } else {
      // ── WRITE: execute directly against Supabase ────────────────────────────
      switch (call.name) {
        case 'create_contact': result = await execCreateContact(call.args, userId); break;
        case 'update_contact': result = await execUpdateContact(call.args, userId); break;
        case 'create_event': result = await execCreateEvent(call.args, userId); break;
        case 'update_event': result = await execUpdateEvent(call.args, userId); break;
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

function buildSystemPrompt(userProfile?: UserProfile): string {
  const tone = userProfile?.ai_tone ?? 'professional';

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

  return `You are an AI CRM assistant for exhibitions and trade shows. ${toneInstruction}

You have access to tools to READ and WRITE CRM data.

READ: Use query_crm for any data retrieval — listing contacts, events,
email drafts, captures, companies, or searching messages.
The semantic layer handles SQL — just describe what you want with source_model,
dimensions, filters, and optional measures.

WRITE: Use create_contact, update_contact, create_event, update_event,
draft_email for mutations.

Rules:
- ALWAYS call query_crm FIRST before any write operation to look up the record's ID. Never assume you know an ID.
- If the user says "update", "change", "reschedule", "rename", "edit", or anything that implies modifying an existing record: query_crm first by name, get the ID, then call the update tool. NEVER call create_* for an update request.
- Only call create_* when the user explicitly wants a brand-new record that does not yet exist.
- Be concise and action-oriented in your final reply.
- If required info is missing, ask 1-2 focused questions.
- Dates must be ISO 8601 (e.g. 2026-06-01T10:00:00Z).
- You may call multiple tools in sequence — each result is fed back to you.
- NEVER include UUIDs or any database IDs in your text reply. Entity cards are shown separately — just refer to things by name.
- When drafting emails, follow-up messages, or any outbound communication, incorporate the user's products, value proposition, and tone naturally.${profileSection}`;
}

// ─── POST /api/assistant/respond ─────────────────────────────────────────────

const respondSchema = z.object({
  conversation_id: z.string().uuid(),
  text: z.string().trim().min(1).max(8000),
});

router.post('/respond', async (req, res) => {
  const parsed = respondSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });

  const supabaseUser = createSupabaseUserClient(req.accessToken!);
  const userId = req.user!.id;
  const { conversation_id, text: rawText } = parsed.data;

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
    .insert({ conversation_id, user_id: userId, sender_type: 'user', sender_user_id: userId, content: text })
    .select('*').single();
  if (userMsgErr) return res.status(400).json({ error: userMsgErr.message });

  // (auto-titling is done after the assistant response, see below)

  try {
    // 2. Load user profile context
    const { data: userProfile } = await supabaseAdmin.from('user_profiles').select('name, designation, profile_type, products_services, value_proposition, additional_context, ai_tone, website, linkedin_url').eq('user_id', userId).maybeSingle();
    const systemPrompt = buildSystemPrompt(userProfile ?? undefined);

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

        // If query_crm failed (slayer down or query error), abort immediately.
        // Don't let the LLM proceed to write tools with incomplete or missing data.
        if (call.name === 'query_crm' && !toolResult.ok) {
          throw new Error('CRM query service is unavailable. Please try again in a moment.');
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

    // 6. Build linked entities directly from tool results — last write wins per entity ID.
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
    const linkedEntities = Array.from(linkedEntitiesMap.values());

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
