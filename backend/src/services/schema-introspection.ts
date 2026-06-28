/**
 * Live-schema introspection for the AI assistant.
 *
 * The assistant hardcodes some schema knowledge in TypeScript (see
 * backend/CLAUDE.md). This module lets two pieces of that knowledge be
 * auto-derived from the live database instead of hand-maintained:
 *
 *   - USER_ID_TABLES   — tables that carry a `user_id` column (ownership filter)
 *   - SOFT_DELETE_TABLES — tables that carry a `deleted_at` column
 *
 * Both are PURELY structural ("does this column exist on this table"), so the DB
 * is the correct source of truth and there is no judgement call to lose. The
 * IMMUTABLE_FIELDS denylist and per-field Zod refinements are deliberately NOT
 * derived here — those are semantic decisions that must stay human-owned.
 *
 * Data comes from the `introspect_public_columns()` SQL function (read-only,
 * returns only column names). Callers degrade gracefully: if introspection
 * fails (DB down at boot, missing function), they fall back to the hardcoded
 * sets so the assistant keeps working with the last-known-good schema.
 */

import { supabaseAdmin } from '../config/supabaseClients';

export interface SchemaSnapshot {
  /** table name -> sorted column names */
  columnsByTable: Record<string, string[]>;
  /** tables that have a `user_id` column */
  userIdTables: Set<string>;
  /** tables that have a `deleted_at` column */
  softDeleteTables: Set<string>;
}

/**
 * Read the live public-schema columns via the introspection RPC and shape them
 * into a SchemaSnapshot. Throws on any DB/RPC error — callers decide whether to
 * fall back. Returns an empty snapshot only if the DB genuinely has no columns
 * (never in practice), so an empty result is treated as a failure upstream.
 */
export async function introspectSchema(): Promise<SchemaSnapshot> {
  const { data, error } = await supabaseAdmin.rpc('introspect_public_columns');
  if (error) throw new Error(`introspect_public_columns failed: ${error.message}`);
  const rows = (data ?? []) as Array<{ table_name: string; column_name: string }>;
  if (rows.length === 0) throw new Error('introspect_public_columns returned no rows');

  const columnsByTable: Record<string, string[]> = {};
  const userIdTables = new Set<string>();
  const softDeleteTables = new Set<string>();

  for (const { table_name, column_name } of rows) {
    (columnsByTable[table_name] ??= []).push(column_name);
    if (column_name === 'user_id') userIdTables.add(table_name);
    if (column_name === 'deleted_at') softDeleteTables.add(table_name);
  }
  for (const cols of Object.values(columnsByTable)) cols.sort();

  return { columnsByTable, userIdTables, softDeleteTables };
}
