# Exono CRM backend — Claude instructions

Express + TypeScript API under `backend/`. Talks to Supabase (Postgres) and the
Slayer semantic layer. The AI assistant lives in [src/routes/assistant.ts](src/routes/assistant.ts).

## Keeping the AI assistant in sync with the DB schema (MANDATORY)

The assistant's write tools (`create_contact`, `update_contact`, `create_event`,
`update_event`, `draft_email`, `log_interaction`, `set_follow_up_status`,
`set_follow_up_priority`) and the Slayer read path hardcode some schema
knowledge in TypeScript. (The follow-up/interaction tools delegate to the shared
`services/followUps.ts` engine and `services/...` route logic, so they inherit the
app's status-promotion + priority-split rules rather than re-implementing them.)
**When the database schema changes (a column is added,
removed, or renamed on a table the assistant can read or write), update ALL of
the following in the same change** — they do NOT auto-derive from the DB:

1. **Zod validation schemas** in the relevant `exec*` function in
   [src/routes/assistant.ts](src/routes/assistant.ts). Keep these explicit and
   in step with the columns — they enforce per-field format rules (valid email,
   parseable date) that the DB cannot. Add the new field with the right validator;
   remove fields for dropped columns. This is intentional, hand-maintained, and
   expected to be updated alongside schema changes — not a smell.

2. **The write tool's JSON schema** (the `WRITE_TOOLS` / tool `parameters`
   block) so the LLM knows the field exists and can set it. A field missing here
   means the assistant literally cannot use it (this is what hid `linkedin_url`).

3. **`IMMUTABLE_FIELDS`** (the system-managed denylist) — if the new column is
   system-managed (ownership, audit/soft-delete, sync bookkeeping, AI/enrichment
   generated, media handled by upload flows, status timestamps maintained by app
   flows), ADD it here so the assistant can never write it. Anything NOT on this
   denylist is allowed to flow to the DB (Supabase rejects non-existent columns),
   so a normal new column auto-exposes via the generic copy in the `update_*`
   executors — but a system column MUST be denied explicitly. This list is the
   single safety boundary; keep it complete. Verify against the live schema via
   the Supabase MCP (`information_schema.columns`), not from memory.

4. **`slayer-client.ts` constants** — `ALLOWED_MODELS` (tables the assistant may
   query), `USER_ID_TABLES` (tables with a `user_id` column — ownership filter is
   injected), and `SOFT_DELETE_TABLES` (tables with `deleted_at` — `IS NULL`
   filter is injected). A table with `user_id` missing from `USER_ID_TABLES` is a
   security gap (no per-user scoping); a table in `SOFT_DELETE_TABLES` that lacks
   `deleted_at` injects an invalid filter and breaks the query. Verify both flags
   per-table against `information_schema` whenever tables are added/changed.

The **permission card** in the Flutter app (`chat_screen._permissionFields`)
renders every tool arg generically, so it does NOT need updating per new field.

5. **`MODEL_DIRECTORY`** in [src/routes/assistant.ts](src/routes/assistant.ts) —
   the one-line-per-table directory in the system prompt (lazy schema). The model
   no longer gets every table's columns in the prompt; it calls the
   `describe_model` tool to fetch one table's columns on demand (via
   `slayerGetModelColumnsTyped` → Slayer). So when you **add a new table** the
   assistant may query, add it to `ALLOWED_MODELS` (slayer-client) AND give it a
   `MODEL_DIRECTORY` entry, then make sure Slayer has ingested it. Adding/removing
   a **column** needs NO prompt change — `describe_model` reads live from Slayer;
   just ensure Slayer re-ingested so its model YAML reflects the new column.

### Automation (what is now auto-derived / enforced)

Two safety nets reduce the manual burden above — they do NOT remove the human
decisions (writable vs. system-managed, per-field Zod rules), they make them
impossible to forget:

- **`USER_ID_TABLES` / `SOFT_DELETE_TABLES` are auto-derived at boot.**
  `initSchemaFlags()` ([src/services/slayer-client.ts](src/services/slayer-client.ts))
  reads the live schema via the `introspect_public_columns()` RPC
  ([src/services/schema-introspection.ts](src/services/schema-introspection.ts))
  and overwrites those sets from the DB at server startup. The hardcoded literals
  are now only a FALLBACK seed used if introspection fails at boot. You no longer
  hand-maintain these — but keep the fallback roughly correct.
- **CI drift-check** ([scripts/check-schema-drift.ts](scripts/check-schema-drift.ts),
  `npm run check:schema-drift`, run by `.github/workflows/schema-drift.yml`)
  fails the build when (1) the fallback flag seeds disagree with the live DB, or
  (2) a column on a writable table (contacts/events/email_drafts) is
  UNCLASSIFIED — neither an LLM-writable tool param, nor in `IMMUTABLE_FIELDS`,
  nor in the script's `EXECUTOR_MANAGED` list. When you add a writable-table
  column you must still classify it (this is the forcing function), but you can
  no longer SILENTLY forget — that is the bug class that once hid `linkedin_url`.
  A new executor-handled column (FK/status set in code) goes in the script's
  `EXECUTOR_MANAGED` map.

## Slayer model files (`slayer/slayer_data/models/exono/*.yaml`)

These are auto-generated by Slayer's ingestion (they carry `sampled_values`
caches). Do NOT hand-edit them to fix schema drift — regenerate via Slayer's
ingest / `validate-models` tooling so the caches stay consistent. The only drift
found in the last audit was a stale `contacts.follow_up_urgency` column.

## Verify
- Typecheck with `npx tsc --noEmit` from `backend/` after edits.
- Use the Supabase MCP (`list_tables` verbose, or `information_schema` via
  `execute_sql`) as the source of truth for column names — never guess.
