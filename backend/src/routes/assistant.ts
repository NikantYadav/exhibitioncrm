import { Router } from 'express';
import { randomUUID } from 'crypto';
import { z } from 'zod';
import { requireAuth } from '../middleware/requireAuth';
import { createSupabaseUserClient } from '../config/supabaseClients';
import { supabase as supabaseAdmin } from '../config/supabase';
import { litellm, ConversationTurn, ToolCall } from '../services/litellm-service';
import { slayerQuery, slayerHealthy } from '../services/slayer-client';

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
  'id', 'owner_user_id', 'user_id', 'created_at', 'updated_at',
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
listing contacts, events, notes, reminders, email drafts, captures, companies,
meetings, interactions, dashboard stats, or searching messages.
The semantic layer handles SQL generation — you just describe what you want.
Available source_models: contacts, events, notes, reminders, email_drafts,
captures, companies, meeting_briefs, interactions, messages, conversations,
documents, attachments.`,
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
        description: { type: 'string' },
        event_type: { type: 'string' },
        status: { type: 'string' },
      },
      required: ['name', 'start_date'],
    },
  },
  {
    name: 'create_note',
    description: 'Add a note to a contact or event',
    parameters: {
      type: 'object',
      properties: {
        content: { type: 'string' },
        contact_id: { type: 'string' },
        event_id: { type: 'string' },
        note_type: { type: 'string', enum: ['text', 'voice', 'ai'] },
      },
      required: ['content'],
    },
  },
  {
    name: 'create_reminder',
    description: 'Create a reminder for a contact or event',
    parameters: {
      type: 'object',
      properties: {
        title: { type: 'string' },
        reminder_date: { type: 'string', description: 'ISO 8601 datetime' },
        reminder_type: { type: 'string' },
        message: { type: 'string' },
        priority: { type: 'string', enum: ['low', 'medium', 'high'] },
        contact_id: { type: 'string' },
        event_id: { type: 'string' },
      },
      required: ['title', 'reminder_date', 'reminder_type'],
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
    .insert({ first_name: a.first_name, last_name: a.last_name, email: a.email, phone: a.phone, job_title: a.job_title, notes: a.notes, company_id })
    .select('*').single();
  if (error) throw new Error(error.message);

  if (a.event_id) {
    await supabaseAdmin.from('interactions').insert({ contact_id: contact.id, event_id: a.event_id, interaction_type: 'capture', summary: 'Added by assistant' });
    await supabaseAdmin.from('captures').insert({ contact_id: contact.id, event_id: a.event_id, capture_type: 'manual', status: 'completed', raw_data: { source: 'assistant' } });
  }

  return contact;
}

async function execUpdateContact(args: Record<string, unknown>) {
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

  const { data, error } = await supabaseAdmin.from('contacts').update(update).eq('id', a.contact_id).select('*').single();
  if (error) throw new Error(error.message);
  return data;
}

async function execCreateEvent(args: Record<string, unknown>) {
  const a = z.object({
    name: z.string().trim().min(1),
    location: z.string().trim().optional(),
    start_date: z.any(),
    end_date: z.any().optional(),
    description: z.string().trim().optional(),
    event_type: z.string().trim().optional(),
    status: z.string().trim().optional(),
  }).parse(args);

  const { data, error } = await supabaseAdmin.from('events').insert({
    name: a.name, location: a.location,
    start_date: toIso(a.start_date, 'start_date'),
    end_date: a.end_date ? toIso(a.end_date, 'end_date') : null,
    description: a.description, event_type: a.event_type, status: a.status,
  }).select('*').single();
  if (error) throw new Error(error.message);
  return data;
}

async function execCreateNote(args: Record<string, unknown>) {
  const a = z.object({
    content: z.string().trim().min(1),
    contact_id: z.string().uuid().optional(),
    event_id: z.string().uuid().optional(),
    note_type: z.string().trim().optional(),
  }).parse(args);

  const { data, error } = await supabaseAdmin.from('notes').insert({
    content: a.content, contact_id: a.contact_id ?? null,
    event_id: a.event_id ?? null, note_type: a.note_type ?? 'text',
  }).select('*').single();
  if (error) throw new Error(error.message);
  return data;
}

async function execCreateReminder(args: Record<string, unknown>) {
  const a = z.object({
    title: z.string().trim().min(1),
    reminder_date: z.any(),
    reminder_type: z.string().trim().min(1),
    message: z.string().trim().optional(),
    priority: z.enum(['low', 'medium', 'high']).optional(),
    contact_id: z.string().uuid().optional(),
    event_id: z.string().uuid().optional(),
  }).parse(args);

  const { data, error } = await supabaseAdmin.from('reminders').insert({
    title: a.title, reminder_date: toIso(a.reminder_date, 'reminder_date'),
    reminder_type: a.reminder_type, message: a.message ?? null,
    priority: a.priority ?? 'medium', contact_id: a.contact_id ?? null, event_id: a.event_id ?? null,
  }).select('*').single();
  if (error) throw new Error(error.message);
  return data;
}

async function execDraftEmail(args: Record<string, unknown>) {
  const a = z.object({
    contact_id: z.string().uuid(),
    subject: z.string().trim().min(1).max(300),
    body: z.string().trim().min(1),
    email_type: z.string().trim().optional(),
    event_id: z.string().uuid().optional(),
  }).parse(args);

  const { data, error } = await supabaseAdmin.from('email_drafts').insert({
    contact_id: a.contact_id, subject: a.subject, body: a.body,
    email_type: a.email_type ?? null, event_id: a.event_id ?? null, status: 'draft',
  }).select('*').single();
  if (error) throw new Error(error.message);
  return data;
}

// ─── Tool dispatcher ──────────────────────────────────────────────────────────

type ToolResult = { name: string; ok: boolean; result?: unknown; error?: string };

async function executeTool(
  call: ToolCall,
  userId: string,
  supabaseUser: ReturnType<typeof createSupabaseUserClient>,
  runId: string
): Promise<ToolResult> {
  // Persist the tool call record
  const { data: tcRow } = await supabaseUser
    .from('tool_calls')
    .insert({ assistant_run_id: runId, name: call.name, args_json: call.args })
    .select('id').single();
  const tcId = tcRow?.id as string | undefined;

  const persist = async (result: unknown, error?: string) => {
    if (!tcId) return;
    await supabaseUser.from('tool_calls').update(
      error ? { error } : { result_json: result }
    ).eq('id', tcId);
  };

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
        case 'create_contact':  result = await execCreateContact(call.args, userId); break;
        case 'update_contact':  result = await execUpdateContact(call.args); break;
        case 'create_event':    result = await execCreateEvent(call.args); break;
        case 'create_note':     result = await execCreateNote(call.args); break;
        case 'create_reminder': result = await execCreateReminder(call.args); break;
        case 'draft_email':     result = await execDraftEmail(call.args); break;
        default:
          throw new Error(`Unknown tool: ${call.name}`);
      }
    }

    await persist(result);
    return { name: call.name, ok: true, result };
  } catch (e: any) {
    const msg = e?.message || 'Tool error';
    await persist(undefined, msg);
    return { name: call.name, ok: false, error: msg };
  }
}

// ─── System prompt builder ────────────────────────────────────────────────────

function buildSystemPrompt(entityContext: string): string {
  return `You are an AI CRM assistant for exhibitions and trade shows.

You have access to tools to READ and WRITE CRM data.

READ: Use query_crm for any data retrieval — listing contacts, events, notes,
reminders, email drafts, captures, companies, meetings, or searching messages.
The semantic layer handles SQL — just describe what you want with source_model,
dimensions, filters, and optional measures.

WRITE: Use create_contact, update_contact, create_event, create_note,
create_reminder, draft_email for mutations.

Rules:
- Always use query_crm before writing if you need to look up an ID.
- Be concise and action-oriented in your final reply.
- If required info is missing, ask 1-2 focused questions.
- Dates must be ISO 8601 (e.g. 2026-06-01T10:00:00Z).
- You may call multiple tools in sequence — each result is fed back to you.${entityContext}`;
}

// ─── Entity context loader ────────────────────────────────────────────────────

async function loadEntityContext(convo: { kind: string; contact_id?: string; event_id?: string }): Promise<string> {
  if (convo.kind === 'contact' && convo.contact_id) {
    const { data: contact } = await supabaseAdmin
      .from('contacts')
      .select('id, first_name, last_name, email, phone, job_title, notes, follow_up_status, follow_up_urgency, last_contacted_at, company:companies(id, name, domain, industry)')
      .eq('id', convo.contact_id).maybeSingle();
    const { data: interactions } = await supabaseAdmin
      .from('interactions')
      .select('interaction_type, interaction_date, summary')
      .eq('contact_id', convo.contact_id)
      .order('interaction_date', { ascending: false }).limit(5);
    return `\n\nContext — this conversation is about contact:\n${JSON.stringify({ contact, recent_interactions: interactions ?? [] })}`;
  }
  if (convo.kind === 'event' && convo.event_id) {
    const { data: event } = await supabaseAdmin
      .from('events')
      .select('id, name, description, location, start_date, end_date, event_type, status')
      .eq('id', convo.event_id).maybeSingle();
    return `\n\nContext — this conversation is about event:\n${JSON.stringify({ event })}`;
  }
  return '';
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
    .insert({ conversation_id, owner_user_id: userId, sender_type: 'user', sender_user_id: userId, content: text })
    .select('*').single();
  if (userMsgErr) return res.status(400).json({ error: userMsgErr.message });

  // 2. Create assistant run record
  const { data: run, error: runErr } = await supabaseUser
    .from('assistant_runs')
    .insert({ conversation_id, owner_user_id: userId, user_message_id: userMessage.id, correlation_id: correlationId, status: 'running' })
    .select('*').single();
  if (runErr) return res.status(400).json({ error: runErr.message });

  try {
    // 3. Load conversation + entity context
    const { data: convo } = await supabaseUser
      .from('conversations')
      .select('id, kind, contact_id, event_id')
      .eq('id', conversation_id).single();

    const entityContext = convo ? await loadEntityContext(convo) : '';
    const systemPrompt = buildSystemPrompt(entityContext);

    // 4. Build conversation history (last 20 messages)
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

    // 5. Agentic loop — max 6 iterations
    const MAX_ITERATIONS = 6;
    let assistantText = '';
    const allToolResults: ToolResult[] = [];
    const linksToInsert: Array<{ contact_id?: string; event_id?: string; reminder_id?: string; email_draft_id?: string }> = [];

    for (let i = 0; i < MAX_ITERATIONS; i++) {
      const llmResult = await litellm.generateWithTools(systemPrompt, history, ALL_TOOLS);

      if (llmResult.type === 'text') {
        assistantText = llmResult.content;
        break;
      }

      // Execute all requested tool calls (sequentially — results may depend on each other)
      const iterResults: Array<{ id: string; name: string; result: unknown }> = [];

      for (const call of llmResult.calls) {
        const toolResult = await executeTool(call, userId, supabaseUser, run.id);
        allToolResults.push(toolResult);

        iterResults.push({
          id: call.id,
          name: call.name,
          result: toolResult.ok ? toolResult.result : { error: toolResult.error },
        });

        // Track created records for message_links
        if (toolResult.ok && toolResult.result && typeof toolResult.result === 'object') {
          const r = toolResult.result as Record<string, unknown>;
          if (call.name === 'create_contact' && r.id) linksToInsert.push({ contact_id: r.id as string });
          if (call.name === 'create_event' && r.id) linksToInsert.push({ event_id: r.id as string });
          if (call.name === 'create_reminder' && r.id) linksToInsert.push({ reminder_id: r.id as string });
          if (call.name === 'draft_email' && r.id) linksToInsert.push({ email_draft_id: r.id as string });
        }
      }

      // Append tool calls + results to history for next iteration
      history.push({ role: 'tool_calls', calls: llmResult.calls });
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

    // Append action summary to assistant message
    if (allToolResults.length > 0) {
      const lines = ['\n\nActions:'];
      for (const r of allToolResults) {
        if (r.name === 'query_crm') continue; // don't clutter with read ops
        const id = r.ok && r.result && typeof r.result === 'object' ? (r.result as any).id : undefined;
        lines.push(r.ok ? `- ${r.name} ✅${id ? ` (id: ${id})` : ''}` : `- ${r.name} ❌ (${r.error})`);
      }
      if (lines.length > 1) assistantText = `${assistantText}${lines.join('\n')}`.trim();
    }

    // 6. Persist assistant message
    const { data: assistantMessage, error: assistantErr } = await supabaseUser
      .from('messages')
      .insert({ conversation_id, owner_user_id: userId, sender_type: 'assistant', sender_user_id: null, content: assistantText || 'Done.' })
      .select('*').single();
    if (assistantErr) throw new Error(assistantErr.message);

    // 7. Insert message links for created records
    if (linksToInsert.length > 0) {
      await supabaseUser.from('message_links').insert(
        linksToInsert.map((l) => ({
          message_id: assistantMessage.id,
          contact_id: l.contact_id ?? null,
          event_id: l.event_id ?? null,
          reminder_id: l.reminder_id ?? null,
          email_draft_id: l.email_draft_id ?? null,
        }))
      );
    }

    // 8. Update run status
    const errCount = allToolResults.filter((r) => !r.ok).length;
    const { data: updatedRun } = await supabaseUser
      .from('assistant_runs')
      .update({ status: errCount > 0 ? 'failed' : 'succeeded', finished_at: new Date().toISOString() })
      .eq('id', run.id).select('*').single();

    res.json({ user_message: userMessage, assistant_message: assistantMessage, run: updatedRun ?? run });

  } catch (err: any) {
    await supabaseUser.from('assistant_runs').update({
      status: 'failed', finished_at: new Date().toISOString(), error: err?.message || 'Assistant error',
    }).eq('id', run.id);
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
