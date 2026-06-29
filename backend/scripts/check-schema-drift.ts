/**
 * CI schema-drift check for the AI assistant.
 *
 * The assistant hardcodes schema knowledge in TypeScript (see backend/CLAUDE.md).
 * Most of it cannot be auto-derived because it encodes human judgement (is a
 * column writable or system-managed? what is its per-field validation?). This
 * script does NOT try to make those decisions — it makes them IMPOSSIBLE TO
 * FORGET by failing the build whenever the live DB schema drifts away from what
 * the assistant has been told.
 *
 * It fails when:
 *   1. The hardcoded USER_ID_TABLES / SOFT_DELETE_TABLES fallback seeds disagree
 *      with the live DB (these gate ownership + soft-delete injection; a wrong
 *      fallback is a security/correctness risk when boot introspection fails).
 *   2. A column on a writable table (contacts/events/email_drafts) is
 *      UNCLASSIFIED — neither exposed to the LLM via the write tool's params nor
 *      listed in IMMUTABLE_FIELDS. Every column must be a deliberate
 *      "writable" or "system-managed" choice. This is the bug that once silently
 *      hid `linkedin_url` from the assistant.
 *
 * Run: `npm run check:schema-drift` (needs SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY).
 * Exits 0 on no drift, 1 on drift, 2 on an operational error (DB unreachable).
 */

import { introspectSchema } from '../src/services/schema-introspection';
import { USER_ID_TABLES, SOFT_DELETE_TABLES } from '../src/services/slayer-client';
import { IMMUTABLE_FIELDS } from '../src/assistant/tools/validation';
import { WRITE_TOOLS } from '../src/assistant/tools/schemas';

// Allowlisted models the assistant may query (mirror of slayer-client ALLOWED_MODELS).
// Only these are checked for user_id/deleted_at drift — extra tables in the DB
// the assistant can't touch are irrelevant.
const ALLOWED_MODELS = new Set([
  'contacts', 'events', 'email_drafts', 'captures', 'companies', 'interactions',
  'messages', 'conversations', 'attachments', 'contact_documents', 'user_profiles',
  'target_companies', 'event_goals', 'message_attachments', 'contact_events',
  'follow_ups', 'target_company_met',
]);

// Tables the assistant WRITES to, and the write tools that cover each. Every
// column on these tables must be classified (LLM-writable OR immutable).
const WRITABLE_TABLES: Record<string, string[]> = {
  contacts: ['create_contact', 'update_contact', 'bulk_import_contacts'],
  events: ['create_event', 'update_event'],
  email_drafts: ['draft_email'],
};

// Tool param keys that select/link a target record rather than name a DB column
// (so they correctly have no matching column and must not count as "unknown").
const NON_COLUMN_TOOL_KEYS = new Set([
  'contact_name', 'event_name', 'company_name',
]);

// Columns that ARE deliberately handled, but by executor logic rather than by a
// plain LLM-writable tool param or the IMMUTABLE_FIELDS denylist. These are a
// third, explicit bucket: foreign keys resolved from a *_name/*_id input, or
// values the executor sets itself (e.g. email_drafts.status = 'draft'). Listed
// here so the classification stays a visible, human-owned decision — adding a
// new such column still requires a deliberate edit here.
const EXECUTOR_MANAGED: Record<string, Set<string>> = {
  contacts: new Set(['company_id']),               // set via company_id/company_name in execCreateContact
  email_drafts: new Set(['contact_id', 'event_id', 'status']), // FK inputs + status:'draft'
};

function toolParamKeys(toolName: string): Set<string> {
  const tool = WRITE_TOOLS.find((t) => t.name === toolName);
  const props = (tool?.parameters?.properties ?? {}) as Record<string, unknown>;
  return new Set(Object.keys(props).filter((k) => !NON_COLUMN_TOOL_KEYS.has(k)));
}

function diffSet(label: string, hardcoded: Set<string>, live: Set<string>): string[] {
  const errors: string[] = [];
  const missing = [...live].filter((t) => !hardcoded.has(t)).sort();
  const extra = [...hardcoded].filter((t) => !live.has(t)).sort();
  if (missing.length) errors.push(`${label}: live DB has these but the hardcoded set is MISSING them: ${missing.join(', ')}`);
  if (extra.length) errors.push(`${label}: hardcoded set has these but the live DB does NOT: ${extra.join(', ')}`);
  return errors;
}

async function main() {
  let snapshot;
  try {
    snapshot = await introspectSchema();
  } catch (e: any) {
    console.error(`[schema-drift] could not introspect the live schema: ${e?.message ?? e}`);
    console.error('[schema-drift] ensure SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are set.');
    process.exit(2);
  }

  const errors: string[] = [];

  // ── 1. ownership / soft-delete flag drift (scoped to allowlisted models) ──────
  const liveUserId = new Set([...snapshot.userIdTables].filter((t) => ALLOWED_MODELS.has(t)));
  const liveSoftDelete = new Set([...snapshot.softDeleteTables].filter((t) => ALLOWED_MODELS.has(t)));
  errors.push(...diffSet('USER_ID_TABLES (fallback seed)', USER_ID_TABLES, liveUserId));
  errors.push(...diffSet('SOFT_DELETE_TABLES (fallback seed)', SOFT_DELETE_TABLES, liveSoftDelete));

  // ── 2. unclassified columns on writable tables ────────────────────────────────
  for (const [table, tools] of Object.entries(WRITABLE_TABLES)) {
    const liveCols = snapshot.columnsByTable[table];
    if (!liveCols) {
      errors.push(`writable table "${table}" not found in the live schema — was it renamed/dropped?`);
      continue;
    }
    const known = new Set<string>();
    for (const t of tools) for (const k of toolParamKeys(t)) known.add(k);
    const executorManaged = EXECUTOR_MANAGED[table] ?? new Set<string>();

    const unclassified = liveCols.filter(
      (c) => !known.has(c) && !IMMUTABLE_FIELDS.has(c) && !executorManaged.has(c),
    );
    if (unclassified.length) {
      errors.push(
        `table "${table}" has UNCLASSIFIED columns: ${unclassified.join(', ')}.\n` +
        `    -> Either expose each to the LLM (add to the ${tools.join('/')} tool params + the exec* Zod schema)\n` +
        `       or mark it system-managed (add to IMMUTABLE_FIELDS in src/routes/assistant.ts).`,
      );
    }
  }

  if (errors.length) {
    console.error('\nSchema drift detected — the AI assistant is out of sync with the database:\n');
    for (const e of errors) console.error(`  - ${e}`);
    console.error('\nSee backend/CLAUDE.md "Keeping the AI assistant in sync with the DB schema".\n');
    process.exit(1);
  }

  console.log('Schema-drift check passed: assistant schema knowledge matches the live DB.');
}

main().catch((e) => {
  console.error('[schema-drift] unexpected error:', e);
  process.exit(2);
});
