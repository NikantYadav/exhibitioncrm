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
const ALLOWED_MODELS = [
  'contacts', 'events', 'email_drafts',
  'captures', 'companies', 'interactions',
  'messages', 'conversations', 'attachments',
  'contact_documents', 'user_profiles',
  'target_companies',
  'message_attachments',
] as const;

type AllowedModel = typeof ALLOWED_MODELS[number];

// Tables that carry user_id — the authenticated user's ownership filter is injected for these
const USER_ID_TABLES = new Set<string>([
  'contacts', 'events', 'user_profiles', 'captures', 'conversations', 'messages',
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
 * Strip any user_id filters the LLM may have hallucinated,
 * then inject the real authenticated user's ownership filter.
 */
function applyOwnership(query: SlayerQuery, userId: string): SlayerQuery {
  // Strip LLM-hallucinated ownership filters
  const cleanFilters = (query.filters ?? []).filter(
    (f) => !/\buser_id\s*=/i.test(f)
  );

  if (USER_ID_TABLES.has(query.source_model as AllowedModel)) {
    return { ...query, filters: [`user_id = '${userId}'`, ...cleanFilters] };
  }

  return { ...query, filters: cleanFilters };
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
