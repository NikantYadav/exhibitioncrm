import { Router } from 'express';
import { randomUUID } from 'crypto';
import { z } from 'zod';
import { requireAuth } from '../middleware/requireAuth';
import { createSupabaseUserClient } from '../config/supabaseClients';
import { supabase as supabaseAdmin } from '../config/supabase';
import { ToolCall, ConversationTurn } from '../services/litellm-service';
import { slayerHealthy } from '../services/slayer-client';
import { autoTitleConversation } from '../services/ai/titling';
import { checkRateLimit, sanitiseUserInput } from '../assistant/security';
import { buildSystemPrompt } from '../assistant/prompt';
import { LoopState, runLoop, finalizeTurn, suspendForPermission } from '../assistant/loop';
import { executeTool } from '../assistant/tools/dispatcher';
import { buildMentionNote } from '../assistant/entities';

// The assistant's schema knowledge (tool defs + the immutable-field denylist) is
// kept in src/assistant/tools/* and re-exported here so the CI schema-drift
// script (scripts/check-schema-drift.ts) keeps its stable import path.
export { IMMUTABLE_FIELDS } from '../assistant/tools/validation';
export { WRITE_TOOLS } from '../assistant/tools/schemas';

const router = Router();
router.use(requireAuth);

const respondSchema = z.object({
  conversation_id: z.string().uuid(),
  text: z.string().trim().min(1).max(8000),
  research_mode: z.boolean().optional(),
  // An already-persisted user message to use for this turn instead of inserting a
  // new one. Used when the client created the message first to attach files to it.
  // Ownership + conversation membership are re-verified server-side.
  user_message_id: z.string().uuid().optional(),
  // Attachments (already uploaded against user_message_id via
  // /conversations/:id/attachments/upload) to surface to the model so it can call
  // parse_document. Ownership is re-verified server-side.
  attachment_ids: z.array(z.string().uuid()).max(5).optional(),
  // CRM records the user @-mentioned in the composer. The backend pre-resolves
  // each to its full record (ownership re-verified via the user-scoped client)
  // and injects a context note into this turn, so the model answers about the
  // exact entity the user pointed at — Notion-AI-style mentions.
  mentions: z
    .array(
      z.object({
        type: z.enum(['contact', 'event', 'company']),
        id: z.string().uuid(),
      }),
    )
    .max(10)
    .optional(),
});

router.post('/respond', async (req, res) => {
  const parsed = respondSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });

  const supabaseUser = createSupabaseUserClient(req.accessToken!);
  const userId = req.user!.id;
  const { conversation_id, text: rawText, research_mode, attachment_ids, user_message_id, mentions } = parsed.data;

  // Sanitise user input — truncate + log suspicious injection attempts
  const text = sanitiseUserInput(rawText, userId);

  // Require actual prose — a turn whose text is only @-mention directives (no
  // typed message) is not a valid query. Mentions are context, not a question.
  const MENTION_DIRECTIVE = /@\[(?:contact|event|company):[0-9a-fA-F-]{36}:[^\]]+\]/g;
  if (text.replace(MENTION_DIRECTIVE, '').trim().length === 0) {
    return res.status(400).json({ error: 'Message text is required.' });
  }

  // Rate limit
  const rate = await checkRateLimit(userId);
  if (!rate.ok) {
    res.setHeader('Retry-After', String(rate.retryAfterSeconds));
    return res.status(429).json({ error: 'Rate limit exceeded. Please retry shortly.' });
  }

  const correlationId = (typeof req.headers['x-correlation-id'] === 'string' && req.headers['x-correlation-id']) || randomUUID();
  res.setHeader('x-correlation-id', correlationId);

  // 1. Persist (or adopt) the user message. When the client created the message
  // first to attach files to it, reuse that row (verified to be the caller's and
  // in this conversation) instead of inserting a duplicate.
  let userMessage: any;
  if (user_message_id) {
    const { data: existing, error: exErr } = await supabaseUser
      .from('messages')
      .select('*')
      .eq('id', user_message_id)
      .eq('conversation_id', conversation_id)
      .eq('sender_type', 'user')
      .maybeSingle();
    if (exErr) return res.status(400).json({ error: exErr.message });
    if (!existing) return res.status(400).json({ error: 'user_message_id not found in this conversation' });
    userMessage = existing;
  } else {
    const { data: inserted, error: userMsgErr } = await supabaseUser
      .from('messages')
      .insert({ conversation_id, user_id: userId, sender_type: 'user', sender_user_id: userId, content: text, research_mode: research_mode === true })
      .select('*').single();
    if (userMsgErr) return res.status(400).json({ error: userMsgErr.message });
    userMessage = inserted;
  }

  // Re-link any pre-uploaded attachments to this user message and build a
  // context note so the model knows their attachment_id and can call
  // parse_document. Ownership is re-verified (attachment -> message -> user_id)
  // before re-linking — a user can only attach their own uploads.
  let attachmentNote = '';
  if (attachment_ids && attachment_ids.length > 0 && userMessage?.id) {
    const { data: owned } = await supabaseAdmin
      .from('message_attachments')
      .select('id, path, mime_type, extraction_status, messages!inner(user_id)')
      .in('id', attachment_ids)
      .eq('messages.user_id', userId);
    const ownedRows = (owned ?? []) as unknown as Array<{ id: string; path: string; mime_type: string | null; extraction_status: string }>;
    if (ownedRows.length > 0) {
      await supabaseAdmin
        .from('message_attachments')
        .update({ message_id: userMessage.id })
        .in('id', ownedRows.map((r) => r.id));
      const lines = ownedRows.map((r) => {
        const fname = r.path.split('/').pop() ?? 'file';
        const status = r.extraction_status === 'failed' ? ' (could not be read)' : '';
        return `- ${fname} [attachment_id: ${r.id}]${status}`;
      });
      attachmentNote =
        `\n\n[The user attached ${ownedRows.length} document(s) to this message. ` +
        `To read one, call parse_document with its attachment_id:\n${lines.join('\n')}]`;
    }
  }

  // Resolve any @-mentioned CRM records to a context note. Loaded with the
  // user-scoped client so RLS enforces ownership — a mention the caller does not
  // own simply returns no row and is skipped (no leak, no error). The note is
  // injected into this turn's history (not persisted to the message) so the model
  // treats the named records as the subject of the turn.
  const mentionNote = await buildMentionNote(supabaseUser, mentions);

  // (auto-titling is done after the assistant response, see below)

  const respondStart = Date.now();
  const tag = `[respond conv=${conversation_id.slice(0, 8)} user=${userId.slice(0, 8)}]`;
  console.log(`${tag} start research=${research_mode === true} attachments=${attachment_ids?.length ?? 0} mentions=${mentions?.length ?? 0}`);

  try {
    // 2. Load user profile context
    const profileStart = Date.now();
    const { data: userProfile } = await supabaseAdmin.from('user_profiles').select('name, designation, profile_type, products_services, value_proposition, additional_context, ai_tone, website, linkedin_url').eq('user_id', userId).maybeSingle();
    const systemPrompt = buildSystemPrompt(userProfile ?? undefined, research_mode === true, attachmentNote !== '');
    console.log(`${tag} profile+prompt built in ${Date.now() - profileStart}ms`);

    // 3. Build conversation history (last 12 messages — enough context for the
    //    short, task-focused turns this CRM assistant handles, and re-sent on
    //    every loop iteration, so a tighter window meaningfully cuts tokens).
    const { data: recentMessages } = await supabaseUser
      .from('messages')
      .select('sender_type, content')
      .eq('conversation_id', conversation_id)
      .order('created_at', { ascending: false })
      .limit(12);

    const history: ConversationTurn[] = (recentMessages ?? [])
      .slice().reverse()
      .map((m) => ({
        role: m.sender_type === 'user' ? 'user' : 'assistant',
        content: m.content,
      } as ConversationTurn));

    // Surface this turn's attachments + mentions to the model by appending the
    // notes to the latest user turn (the message just sent). Kept out of the
    // persisted message content so the chat transcript stays clean.
    const turnNote = `${attachmentNote}${mentionNote}`;
    if (turnNote) {
      for (let i = history.length - 1; i >= 0; i--) {
        if (history[i].role === 'user') {
          (history[i] as { content: string }).content += turnNote;
          break;
        }
      }
    }

    // 4. Run the agentic loop. It either completes with a text reply or pauses
    //    on the first write tool, awaiting the user's permission.
    const state: LoopState = { history, allToolResults: [], readCandidates: [], iteration: 0, researchMode: research_mode === true };
    const loopStart = Date.now();
    const outcome = await runLoop(state, systemPrompt, userId, conversation_id);
    console.log(`${tag} loop done kind=${outcome.kind} iterations=${state.iteration} in ${Date.now() - loopStart}ms`);

    if (outcome.kind === 'paused') {
      // Suspend: persist state + the proposed write, return a permission request.
      // The user message stays persisted (titling runs on resume).
      const pending = await suspendForPermission(
        conversation_id, userId, userMessage?.id ?? null, outcome.call, state,
      );
      console.log(`${tag} suspended for permission tool=${outcome.call.name} total=${Date.now() - respondStart}ms`);
      return res.json({ user_message: userMessage, ...pending });
    }

    // 5. Completed — persist reply, attach cards, title, respond.
    const finalizeStart = Date.now();
    const { assistantMessage, linkedEntities } = await finalizeTurn(
      supabaseUser, conversation_id, userId, outcome.assistantText, state,
    );
    const { data: conversation } = await supabaseUser.from('conversations').select('*').eq('id', conversation_id).single();
    console.log(`${tag} finalized cards=${linkedEntities.length} in ${Date.now() - finalizeStart}ms total=${Date.now() - respondStart}ms`);

    res.json({
      user_message: userMessage,
      assistant_message: assistantMessage,
      conversation: conversation,
      linked_entities: linkedEntities,
    });

    // Auto-titling runs AFTER the response is sent (fire-and-forget) so the user
    // never waits on the extra titling LLM call. It persists the title itself, so
    // the client picks it up via realtime / the next conversation fetch. It
    // swallows its own errors; we add timing + a guard so a rejection here can
    // never crash the process (the response is already flushed).
    const titleStart = Date.now();
    void autoTitleConversation(supabaseUser, conversation_id, text)
      .then(() => console.log(`${tag} titling done in ${Date.now() - titleStart}ms`))
      .catch((e) => console.warn(`${tag} titling failed: ${e?.message}`));

  } catch (err: any) {
    // Roll back the user message so a failed turn leaves nothing persisted —
    // the client keeps the message as an optimistic bubble with inline retry,
    // and a retry re-sends cleanly without creating a duplicate.
    // Only roll back a message THIS request inserted; never delete a
    // client-created message (it owns its own lifecycle + attachments).
    if (userMessage?.id && !user_message_id) {
      await supabaseAdmin.from('messages').delete().eq('id', userMessage.id);
    }
    console.error(`${tag} error after ${Date.now() - respondStart}ms: ${err?.message}`);
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

  const resumeStart = Date.now();
  const tag = `[resume conv=${conversation_id.slice(0, 8)} user=${userId.slice(0, 8)}]`;
  console.log(`${tag} decision=${decision} tool=${call.name} pending_id=${pending_action_id.slice(0, 8)}`);

  try {
    // Resolve the write -> a tool_result the model sees next.
    let resultPayload: unknown;
    if (decision === 'approve') {
      const toolStart = Date.now();
      const toolResult = await executeTool(call, userId);
      const toolMs = Date.now() - toolStart;
      state.allToolResults.push(toolResult);
      resultPayload = toolResult.ok ? toolResult.result : { error: toolResult.error };
      if (toolResult.ok) {
        console.log(`${tag} write tool=${call.name} executed in ${toolMs}ms`);
      } else {
        console.log(`${tag} write tool=${call.name} FAILED in ${toolMs}ms error="${toolResult.error}"`);
      }
    } else {
      resultPayload = { error: 'The user declined this action. Do not retry it. Acknowledge briefly and ask how else you can help, or continue with anything that does not require it.' };
      console.log(`${tag} write tool=${call.name} denied by user`);
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
    // Keep the DOCUMENTS guidance if the original (paused) turn involved an
    // attachment — the model may still need parse_document after the write.
    const hadDocuments = state.history.some(
      (t) => (t as { content?: string }).content?.includes('[The user attached ') ?? false,
    );
    const systemPrompt = buildSystemPrompt(userProfile ?? undefined, state.researchMode, hadDocuments);

    const loopStart = Date.now();
    const outcome = await runLoop(state, systemPrompt, userId, conversation_id);
    console.log(`${tag} loop done kind=${outcome.kind} iterations=${state.iteration} in ${Date.now() - loopStart}ms`);

    if (outcome.kind === 'paused') {
      const pending = await suspendForPermission(
        conversation_id, userId, pa.user_message_id as string | null, outcome.call, state,
      );
      console.log(`${tag} suspended again for tool=${outcome.call.name} total=${Date.now() - resumeStart}ms`);
      return res.json(pending);
    }

    const { assistantMessage, linkedEntities } = await finalizeTurn(
      supabaseUser, conversation_id, userId, outcome.assistantText, state,
    );
    const { data: conversation } = await supabaseUser.from('conversations').select('*').eq('id', conversation_id).single();
    console.log(`${tag} finalized cards=${linkedEntities.length} total=${Date.now() - resumeStart}ms`);

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
    console.error(`${tag} error after ${Date.now() - resumeStart}ms: ${err?.message}`);
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
