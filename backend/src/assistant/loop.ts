import { litellm, ConversationTurn, ToolCall } from '../services/litellm-service';
import { supabase as supabaseAdmin } from '../config/supabase';
import { createSupabaseUserClient } from '../config/supabaseClients';
import { ALL_TOOLS, WRITE_TOOL_NAMES } from './tools/schemas';
import { executeTool, describeWrite, ToolResult } from './tools/dispatcher';
import { LINKABLE_CARD_COLUMNS, normaliseRow, readRowToEntity } from './entities';

export type ReadCandidate = { id: string; type: string; payload: Record<string, unknown> };

// Fully JSON-serializable snapshot of an in-flight agentic turn, persisted on a
// pending action so the loop can be suspended for a permission prompt and resumed.
export interface LoopState {
  history: ConversationTurn[];
  allToolResults: ToolResult[];
  readCandidates: ReadCandidate[];
  iteration: number;
  // Carried across a permission pause so the resumed turn keeps research mode on
  // (web_search stays "advanced"). The pause is a continuation of the same turn.
  researchMode: boolean;
}

const MAX_ITERATIONS = 6;

// Older tool results pile up across loop iterations and get re-sent verbatim on
// every subsequent LLM call. Once the model has seen a tool result and acted on
// it, it does not need the full payload re-sent on the next iterations — it has
// already reasoned about it. So before each LLM call we collapse every
// tool_results turn EXCEPT the most recent one, replacing each large result with
// a compact placeholder (keeping row_count/columns so the model still knows what
// the earlier read found). This ONLY rewrites tool_results turns — user,
// assistant, and tool_calls turns are passed through untouched — and it operates
// on a COPY, never mutating state.history (the persisted snapshot + card/finalize
// logic keep the real data).
function collapseOldToolResults(history: ConversationTurn[]): ConversationTurn[] {
  // Index of the last tool_results turn — that one stays full.
  let lastToolResultsIdx = -1;
  for (let i = history.length - 1; i >= 0; i--) {
    if (history[i].role === 'tool_results') { lastToolResultsIdx = i; break; }
  }
  if (lastToolResultsIdx === -1) return history;

  return history.map((turn, idx) => {
    if (turn.role !== 'tool_results' || idx === lastToolResultsIdx) return turn;
    return {
      role: 'tool_results',
      results: turn.results.map((r) => ({
        id: r.id,
        name: r.name,
        result: summariseToolResult(r.result),
      })),
    };
  });
}

// Replace a tool result's payload with a small placeholder. For a query_crm
// result we preserve the shape the model cares about (how many rows, which
// columns) but drop the row data; small/non-row results are left as-is.
function summariseToolResult(result: unknown): unknown {
  if (!result || typeof result !== 'object') return result;
  const r = result as Record<string, unknown>;
  // Preserve errors verbatim — the model may need the exact message to recover.
  if ('error' in r) return r;
  if ('row_count' in r && 'data' in r) {
    const rowCount = r.row_count;
    return {
      row_count: rowCount,
      columns: r.columns,
      data: `[${rowCount} row(s) omitted from history to save tokens — you already reviewed these results above. Re-run the query if you need the rows again.]`,
    };
  }
  return result;
}

export type LoopOutcome =
  | { kind: 'done'; assistantText: string }
  | { kind: 'paused'; call: ToolCall };

/**
 * Drive the tool-calling loop from the given state. Reads/searches execute
 * inline; the FIRST write tool the model requests pauses the loop (kind:'paused')
 * so the caller can ask the user for permission. Resuming = calling this again
 * after appending the write's tool_result to state.history.
 */
export async function runLoop(
  state: LoopState,
  systemPrompt: string,
  userId: string,
): Promise<LoopOutcome> {
  const readCandidates = new Map<string, ReadCandidate>(
    state.readCandidates.map((c) => [c.id, c]),
  );

  for (; state.iteration < MAX_ITERATIONS; state.iteration++) {
    // Send a copy with older tool-result payloads collapsed (keeps the latest
    // full); state.history itself keeps the real data for resume/finalize.
    const llmResult = await litellm.generateWithTools(systemPrompt, collapseOldToolResults(state.history), ALL_TOOLS);

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

      let llmResultPayload: unknown = toolResult.ok ? toolResult.result : { error: toolResult.error };

      if (call.name === 'query_crm' && toolResult.ok) {
        const model = call.args.source_model as string;
        // Card-building reads the FULL rows (_cardRows), which still carry the
        // auto-added id/display columns the dispatcher stripped from the LLM copy.
        const full = toolResult.result as { _cardRows?: Record<string, unknown>[] } | undefined;
        const cardRows = full?._cardRows;
        if (LINKABLE_CARD_COLUMNS[model] && Array.isArray(cardRows) && cardRows.length === 1) {
          const entity = readRowToEntity(model, normaliseRow(cardRows[0]));
          if (entity) readCandidates.set(entity.id, { id: entity.id, type: entity.type, payload: entity.payload });
        }
        // Never forward the internal _cardRows to the model — strip it from the
        // payload that goes into history (and thus into the next LLM request).
        if (full && typeof full === 'object' && '_cardRows' in full) {
          const { _cardRows, ...rest } = full as Record<string, unknown>;
          llmResultPayload = rest;
        }
      }

      iterResults.push({
        id: call.id,
        name: call.name,
        result: llmResultPayload,
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

  // Loop exhausted without a text reply — ask for a one-line summary. The
  // appended user turn is now the last turn, so every tool_results turn collapses
  // (the summary only needs the gist, not every row).
  state.readCandidates = Array.from(readCandidates.values());
  const summaryResult = await litellm.generateWithTools(systemPrompt, collapseOldToolResults([
    ...state.history,
    { role: 'user', content: 'Summarise what was done in one or two sentences.' },
  ]), []);
  return {
    kind: 'done',
    assistantText: summaryResult.type === 'text' ? summaryResult.content : 'Done.',
  };
}

/**
 * Persist the assistant's final reply + linked-entity cards, run titling, and
 * shape the success JSON. Shared by /respond and /resume.
 */
export async function finalizeTurn(
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
export async function suspendForPermission(
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
