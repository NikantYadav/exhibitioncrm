/**
 * Slayer semantic-layer client.
 *
 * Slayer runs as a separate Python process (./slayer/start.sh) and exposes a
 * REST API on SLAYER_URL (default http://127.0.0.1:5143).
 *
 * Security responsibilities of this module:
 *   1. Validate the query shape (Zod) — blocks unknown tables, oversized payloads.
 *   2. Strip any user_id the LLM hallucinated in filters.
 *   3. Inject the authenticated user's ownership filter for user-scoped tables.
 *
 * Slayer connects as slayer_readonly (SELECT-only, RLS enforced) so even if
 * this module has a bug, Slayer cannot write data and RLS provides a second
 * ownership check.
 */

import { z } from 'zod';
import dotenv from 'dotenv';
dotenv.config();

const SLAYER_URL = (process.env.SLAYER_URL || 'http://127.0.0.1:5143').replace(/\/$/, '');

// ─── Allowlisted models ───────────────────────────────────────────────────────
// The LLM can only query these tables. Anything else (pg_catalog, auth.users,
// etc.) is blocked at validation time before the request reaches Slayer.
export const ALLOWED_MODELS = [
  'contacts', 'events', 'email_drafts',
  'captures', 'companies', 'interactions',
  'messages', 'conversations', 'attachments',
  'contact_documents', 'user_profiles',
  'target_companies', 'event_goals',
  'message_attachments',
  'contact_events', 'follow_ups', 'target_company_met',
] as const;

type AllowedModel = typeof ALLOWED_MODELS[number];

// Tables that carry a user_id column — the authenticated user's ownership filter
// is injected for these.
//
// These two sets are AUTO-DERIVED from the live DB at boot by initSchemaFlags()
// (see below) — they are purely structural ("does the table have a user_id /
// deleted_at column"), so the database is the source of truth and there is no
// judgement to hand-maintain. The literals here are the FALLBACK seed used if
// boot-time introspection fails (DB down at startup); keep them roughly in step
// with the live schema so the fallback is safe. The CI drift-check
// (scripts/check-schema-drift.ts) fails the build if they drift.
export const USER_ID_TABLES = new Set<string>([
  'contacts', 'events', 'user_profiles', 'captures', 'conversations', 'messages',
  'email_drafts', 'interactions', 'target_companies', 'event_goals',
  'contact_events', 'follow_ups', 'target_company_met',
]);

// Tables with a deleted_at column — `deleted_at IS NULL` is always injected so the
// LLM never sees soft-deleted rows. NOTE: companies has NO deleted_at.
export const SOFT_DELETE_TABLES = new Set<string>([
  'contacts', 'events', 'captures', 'interactions',
  'email_drafts', 'target_companies', 'event_goals',
  'contact_events', 'follow_ups', 'target_company_met',
]);

// ─── Zod schema for SlayerQuery ───────────────────────────────────────────────
const timeDimensionSchema = z.object({
  dimension: z.string().max(100),
  granularity: z.enum(['second', 'minute', 'hour', 'day', 'week', 'month', 'quarter', 'year']).optional(),
  date_range: z.tuple([z.string().max(30), z.string().max(30)]).optional(),
});

const orderItemSchema = z.object({
  column: z.string().max(200),
  direction: z.enum(['asc', 'desc']).optional(),
});

export const slayerQuerySchema = z.object({
  source_model: z.enum(ALLOWED_MODELS as unknown as [string, ...string[]]),
  measures: z.array(z.string().max(300)).max(20).optional(),
  dimensions: z.array(z.string().max(300)).max(30).optional(),
  filters: z.array(z.string().max(500)).max(20).optional(),
  time_dimensions: z.array(timeDimensionSchema).max(5).optional(),
  order: z.array(orderItemSchema).max(10).optional(),
  limit: z.number().int().min(1).max(200).optional(),
  offset: z.number().int().min(0).optional(),
  variables: z.record(z.unknown()).optional(),
});

export type SlayerQuery = z.infer<typeof slayerQuerySchema>;

export interface SlayerResponse {
  data: Record<string, unknown>[];
  columns: string[];
  row_count: number;
  sql?: string;
}

// ─── Ownership injection ──────────────────────────────────────────────────────

/**
 * Repair common malformations the LLM introduces into a filter string.
 * Small models (gemini flash-lite) frequently leak JSON-array punctuation into
 * the individual filter values — e.g. emitting `start_date < '2026-06-22T00:00:00Z']`
 * with a stray trailing `]`, or wrapping a value in extra brackets/quotes. Slayer
 * rejects these with a 400 "unmatched ']'" syntax error, which otherwise surfaces
 * to the user as a hard failure. We strip the obvious leaked punctuation here.
 */
function sanitiseFilter(raw: string): string {
  let f = raw.trim();
  // Strip array/object brackets that leaked onto the ends of a single filter value.
  f = f.replace(/[[\]]+$/g, '').replace(/^[[\]]+/g, '');
  // Re-trim and drop a dangling trailing comma the model sometimes appends.
  f = f.trim().replace(/,+$/g, '').trim();
  return f;
}

/**
 * Strip any user_id filters the LLM may have hallucinated,
 * then inject the real authenticated user's ownership filter.
 */
function applyOwnership(query: SlayerQuery, userId: string): SlayerQuery {
  // Strip LLM-hallucinated ownership filters; repair leaked JSON punctuation.
  const cleanFilters = (query.filters ?? [])
    .map(sanitiseFilter)
    .filter((f) => f.length > 0 && !/\buser_id\s*=/i.test(f));

  const withOwnership = USER_ID_TABLES.has(query.source_model as AllowedModel)
    ? [`user_id = '${userId}'`, ...cleanFilters]
    : cleanFilters;

  const withSoftDelete = SOFT_DELETE_TABLES.has(query.source_model as AllowedModel)
    ? [`deleted_at IS NULL`, ...withOwnership]
    : withOwnership;

  return { ...query, filters: withSoftDelete };
}

// ─── Public API ───────────────────────────────────────────────────────────────

/**
 * Validate, secure, and execute a SlayerQuery.
 * Throws if the query shape is invalid or the model is not allowlisted.
 */
export async function slayerQuery(
  rawQuery: unknown,
  userId: string
): Promise<SlayerResponse> {
  // 1. Validate shape — throws ZodError with a clear message on failure
  const query = slayerQuerySchema.parse(rawQuery);

  // 2. Inject ownership
  const safeQuery = applyOwnership(query, userId);

  // 3. Forward to Slayer
  console.log(`[slayer] query: ${JSON.stringify(safeQuery)}`);

  const res = await fetch(`${SLAYER_URL}/query`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(safeQuery),
    signal: AbortSignal.timeout(30_000),
  });

  if (!res.ok) {
    const body = await res.text();
    console.error(`[slayer] error (${res.status}): ${body}`);
    throw new Error(`Slayer query failed (${res.status}): ${body}`);
  }

  const result = await res.json() as SlayerResponse;
  console.log(`[slayer] result: ${result.row_count} rows, columns: ${result.columns.join(', ')}`);
  return result;
}

/**
 * Auto-derive USER_ID_TABLES and SOFT_DELETE_TABLES from the live database at
 * boot, replacing the hardcoded fallback seeds. Mutates the exported Set objects
 * in place so existing imports keep their reference. Only allowlisted models are
 * considered (a stray user_id/deleted_at on a non-queryable table is irrelevant).
 *
 * On any introspection failure this is a no-op: the hardcoded fallback sets stay
 * in effect and a warning is logged. Ownership/soft-delete injection therefore
 * always has a safe value — it never ends up empty because introspection blipped.
 */
export async function initSchemaFlags(): Promise<void> {
  let snapshot;
  try {
    // Imported lazily to avoid a config import cycle at module load.
    const { introspectSchema } = await import('./schema-introspection');
    snapshot = await introspectSchema();
  } catch (e: any) {
    console.warn(`[slayer] schema flag auto-derive failed, using fallback sets: ${e?.message ?? e}`);
    return;
  }

  const allowed = new Set<string>(ALLOWED_MODELS);
  const derivedUserId = new Set([...snapshot.userIdTables].filter((t) => allowed.has(t)));
  const derivedSoftDelete = new Set([...snapshot.softDeleteTables].filter((t) => allowed.has(t)));

  // Mutate in place (preserve the exported Set identity).
  USER_ID_TABLES.clear();
  for (const t of derivedUserId) USER_ID_TABLES.add(t);
  SOFT_DELETE_TABLES.clear();
  for (const t of derivedSoftDelete) SOFT_DELETE_TABLES.add(t);

  console.log(
    `[slayer] schema flags derived from DB: ` +
    `${USER_ID_TABLES.size} user_id tables, ${SOFT_DELETE_TABLES.size} soft-delete tables`,
  );
}

export async function slayerHealthy(): Promise<boolean> {
  try {
    const res = await fetch(`${SLAYER_URL}/health`, { signal: AbortSignal.timeout(3_000) });
    return res.ok;
  } catch {
    return false;
  }
}

export async function slayerListModels(): Promise<string[]> {
  try {
    const res = await fetch(`${SLAYER_URL}/models`, { signal: AbortSignal.timeout(5_000) });
    if (!res.ok) return [];
    const data = (await res.json()) as Array<{ name: string }>;
    return data.map((m) => m.name);
  } catch {
    return [];
  }
}

export interface SlayerColumn {
  name: string;
  type: string;
}

/**
 * Fetch the non-hidden columns (name + type) for one Slayer model. Powers the
 * `describe_model` tool's just-in-time schema loading — the model asks for one
 * table's shape right before building a query_crm call, instead of being handed
 * every table's columns up front. Hidden columns are filtered out. Returns []
 * on any failure so the caller can report a clean error.
 */
export async function slayerGetModelColumnsTyped(model: string): Promise<SlayerColumn[]> {
  try {
    const res = await fetch(`${SLAYER_URL}/models/${encodeURIComponent(model)}`, {
      signal: AbortSignal.timeout(5_000),
    });
    if (!res.ok) return [];
    const data = (await res.json()) as {
      columns?: Array<{ name: string; type?: string; hidden?: boolean }>;
    };
    return (data.columns ?? [])
      .filter((c) => c.hidden !== true)
      .map((c) => ({ name: c.name, type: (c.type ?? 'TEXT').toUpperCase() }));
  } catch {
    return [];
  }
}

