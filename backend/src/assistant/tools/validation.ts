import { z } from 'zod';

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
export const IMMUTABLE_FIELDS = new Set([
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

export function stripImmutable(data: Record<string, unknown>): Record<string, unknown> {
  return Object.fromEntries(
    Object.entries(data).filter(([k]) => !IMMUTABLE_FIELDS.has(k))
  );
}

export function toIso(value: unknown, field: string): string {
  if (typeof value !== 'string' || !value.trim()) throw new Error(`${field} is required`);
  const d = new Date(value);
  if (isNaN(d.getTime())) throw new Error(`${field} must be a valid date/time`);
  return d.toISOString();
}

// 24h HH:MM time-of-day (events.start_time / end_time). Mirrors the validation in
// routes/events.ts: end_time must be after start_time and cannot stand alone.
export const timeOfDay = z.string().trim().regex(/^([01]\d|2[0-3]):[0-5]\d$/, 'Time must be 24h HH:MM');

export function assertTimeRange(start?: string, end?: string): void {
  if (end != null && start == null) throw new Error('end_time requires a start_time');
  if (start != null && end != null && end <= start) throw new Error('end_time must be after start_time');
}

// scanned_details is stored as a flat { key: string } dictionary of extra
// business-card fields (address, website, fax, telephone, …). The card-scan UI
// and mergeScannedDetails() both read it as that flat object.
//
// The WRITE TOOLS, however, expose it to the LLM as an ARRAY of {key, value}
// pairs — not a free-form object. JSON Schema can only describe an open-ended
// object via `additionalProperties`, which Gemini's function-declaration schema
// rejects; an array of fixed-shape items is fully expressible, so the model gets
// a complete formal contract instead of a prose hint. This schema validates that
// array and TRANSFORMS it back into the flat object the rest of the code expects,
// so executors, the merge helper, the DB column, and the UI are all unchanged.
// A pair with an empty `value` is preserved as "" so mergeScannedDetails() can
// use it to delete a key. Duplicate keys: last one wins.
export const scannedDetailsSchema = z
  .array(
    z.object({
      key: z.string().trim().min(1),
      value: z.union([z.string(), z.number(), z.boolean()]).transform((v) => String(v)),
    }),
  )
  .transform((pairs) => {
    const out: Record<string, string> = {};
    for (const { key, value } of pairs) out[key] = value;
    return out;
  });

/**
 * Merge a partial scanned_details patch into the existing object so editing one
 * field ("add address") never wipes the other scanned fields. A key set to an
 * empty string is removed. Returns the merged object to persist.
 */
export function mergeScannedDetails(
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
