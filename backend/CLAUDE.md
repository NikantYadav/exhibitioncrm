# Exono CRM backend — Claude instructions

Express + TypeScript API under `backend/`. Talks to Supabase (Postgres) and the
Slayer semantic layer.

## AI assistant module layout

The assistant was split out of the old monolithic `src/routes/assistant.ts` into
`src/assistant/`. The route file is now thin (just the Express handlers). When a
doc below says "in assistant.ts", use this map to find the real home:

- [src/routes/assistant.ts](src/routes/assistant.ts) — Express router + the
  `/respond`, `/resume`, `/pending`, health handlers only. Re-exports
  `IMMUTABLE_FIELDS` + `WRITE_TOOLS` so the drift script's import path is stable.
- [src/assistant/tools/schemas.ts](src/assistant/tools/schemas.ts) — every tool's
  JSON schema, `ALL_TOOLS`, `WRITE_TOOL_NAMES`, `MODEL_DIRECTORY`, `WRITE_TOOLS`.
- [src/assistant/tools/validation.ts](src/assistant/tools/validation.ts) —
  `IMMUTABLE_FIELDS`, `stripImmutable`, `scannedDetailsSchema`, `timeOfDay`,
  `toIso`, `assertTimeRange`, `mergeScannedDetails`.
- [src/assistant/tools/resolvers.ts](src/assistant/tools/resolvers.ts) —
  `resolveContactId/EventId/CompanyId` + the `assertOwns*` ownership guards.
- `src/assistant/tools/executors/*.ts` — the `exec*` functions, grouped by domain
  (contacts, events, followups, targets, email, documents).
- [src/assistant/tools/dispatcher.ts](src/assistant/tools/dispatcher.ts) —
  `executeTool` (the read/write switch) + `describeWrite`.
- [src/assistant/prompt.ts](src/assistant/prompt.ts) — `buildSystemPrompt` +
  `MODEL_DIRECTORY` consumption.
- [src/assistant/loop.ts](src/assistant/loop.ts) — the agentic loop (`runLoop`,
  `LoopState`, `finalizeTurn`, `suspendForPermission`).
- [src/assistant/security.ts](src/assistant/security.ts) — `checkRateLimit`,
  `sanitiseUserInput`. [src/assistant/dateWindows.ts](src/assistant/dateWindows.ts)
  — `expandDateWindow`. [src/assistant/entities.ts](src/assistant/entities.ts) —
  linked-entity (card) helpers.

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

## Adding a new WRITE tool to the assistant (MANDATORY checklist)

Write tools mutate the DB through `supabaseAdmin`, which **bypasses RLS** — every
ownership/safety boundary is enforced in code, not by the database. A new tool
that misses one of these is a security bug, not a style nit. When you add a write
tool, do ALL of the following (use the existing `exec*` functions as the
template; see the module map at the top for where each piece lives):

1. **Define the JSON tool schema** in the `WRITE_TOOLS` array in
   `src/assistant/tools/schemas.ts` (name, description, `parameters`). Describe
   every arg; prefer `*_name` + `*_id` pairs so the model can pass either. Keep
   `required` minimal — validate in Zod, not the schema.
2. **Write the `exec*` function** in the right `src/assistant/tools/executors/*.ts`
   file with a per-field **Zod schema** (`z.object({...}).parse(args)`).
   Validate formats the DB can't (uuid, email, enums, max lengths, date parses,
   cross-field rules). Use `.refine(...)` for "either id or name is required".
3. **Enforce ownership — the load-bearing safeguard.** `supabaseAdmin` ignores
   RLS, so:
   - **Resolve by name is already user-scoped** (`resolveContactId` /
     `resolveEventId` filter `user_id`). But they **trust a directly-supplied
     UUID without checking ownership** — so on any path that uses a raw `*_id` as
     a foreign key in an INSERT, call `assertOwnsEvent` / `assertOwnsContact`
     (mirroring `execCreateContact`). Add a similar guard for any new owned
     entity type.
   - **UPDATE / DELETE paths** must end with `.eq('user_id', userId).is('deleted_at', null)`
     so an unowned/foreign id matches zero rows; then check the result is
     non-empty and `throw` a clear "not found / not a target" error. Never assume
     the write hit a row.
   - **Companies are an intentional exception** — a global, shared,
     admin-managed resource with no `user_id`; a raw `company_id` needs no
     ownership check (the boundary is the owning `target_companies` row's
     `user_id`). Don't add a bogus check.
4. **Return a real success/failure result.** `throw new Error(msg)` on every
   failure (validation, not-found, Supabase error). `executeTool` turns a throw
   into `{ ok:false, error }`, which the agentic loop feeds back so the model
   cannot falsely claim success. Never `return` a silent no-op on failure.
5. **Register the name in `WRITE_TOOL_NAMES`** (in `src/assistant/tools/schemas.ts`).
   This is what pauses the loop for the user-permission card and routes the tool
   through `/resume`. A write tool missing from this set would execute **without
   user consent** — a critical bug. (A read tool that happens to live in
   `WRITE_TOOLS`, like `get_event_followups`, is deliberately EXCLUDED here.)
6. **Add a `describeWrite` case** (in `src/assistant/tools/dispatcher.ts`) so the
   permission card shows a plain-English summary (no UUIDs/IDs in the text).
7. **Add the dispatcher `case`** in `executeTool`'s write `switch`
   (`src/assistant/tools/dispatcher.ts`), importing the `exec*` you wrote.
8. **Idempotency / soft-delete:** if the target table soft-deletes and has a
   unique constraint, restore a soft-deleted row instead of inserting a dup, and
   handle the `23505` unique-violation as "already exists" (see
   `execAddTargetCompanyToEvent`).
9. **If the tool writes contacts / events / email_drafts**, you ALSO trip the
   schema-sync rules above (Zod + tool params + `IMMUTABLE_FIELDS` + the
   `EXECUTOR_MANAGED` map in the drift script). Tools writing OTHER tables
   (`contact_events`, `target_companies`, `event_goals`, …) are NOT covered by
   the drift check, so they must use **explicit column writes** (never a generic
   copy + `stripImmutable` of arbitrary args) — that is what keeps an unintended
   column from flowing through.
10. **Verify:** `npx tsc --noEmit` and `npm run check:schema-drift` from
    `backend/`. The dispatcher, `/resume`, rate limiting, and prompt-injection
    sanitising are all generic — they need NO per-tool change once steps 5 and 7
    are done.

The Flutter permission card (`chat_screen._permissionFields`) renders args
generically, so it needs no change per new tool.

## Document parsing (parse_document) + attachments

The assistant can read user-attached documents (exhibitor lists, floor plans,
PDFs, spreadsheets, Word/PowerPoint, photos) via the `parse_document` READ tool.
Pipeline:

- **Upload** — `POST /conversations/:id/attachments/upload`
  ([src/routes/conversations.ts](src/routes/conversations.ts)) stores the file in
  the **private** `chat-attachments` bucket (path `userId/conversationId/uuid.ext`,
  server-generated — no client path control), then extracts text via
  [src/services/document-extraction.ts](src/services/document-extraction.ts).
  Small docs (≤ `INLINE_TOKEN_BUDGET`) store `extracted_text` on
  `message_attachments`; oversized docs are chunked + embedded into
  `document_chunks` (pgvector) for retrieval. Rate-limited via `DOC_UPLOAD_SCOPE`.
- **Extraction** sniffs the real type by **magic bytes** (never the client mime),
  caps size/pages/chars (DoS guards). Images/scans → vision (`litellm.analyzeImage`);
  pdf-text → `pdf-parse`; xlsx/csv → `xlsx`; docx → `mammoth`; pptx → `officeparser`.
- **parse_document** ([src/routes/assistant.ts](src/routes/assistant.ts)) is a
  READ tool (NOT in `WRITE_TOOL_NAMES`, no permission gate). Security boundary:
  `assertOwnsAttachment` walks attachment → message → user_id; oversized retrieval
  uses the `match_document_chunks` RPC scoped to BOTH `p_user_id` AND
  `p_attachment_id`, so a query can never reach another user's or another
  document's chunks. The model learns an attachment_id from the
  "[The user attached ...]" note injected into the user turn by `/respond` (which
  re-verifies ownership of `attachment_ids` / `user_message_id`). The DOCUMENTS
  section of the system prompt is only included when a document is attached this
  turn — `buildSystemPrompt(profile, researchMode, hasDocuments)` gates it
  (`/respond` passes `attachmentNote !== ''`; `/resume` detects the note in the
  saved history). Keeps the prompt lean when no file is involved.
- **Embeddings** — `litellm.embed()` uses Gemini `text-embedding-004` (768 dims,
  matching `document_chunks.embedding vector(768)`). RAG is the FALLBACK for big
  docs only; most exhibitor lists fit inline and skip embeddings entirely.

Schema-sync note: `document_chunks` and the new `message_attachments` columns
(`extracted_text`, `extraction_status`, `token_estimate`) are NOT written by the
assistant's write tools, so they are NOT in the drift-check's writable-table set —
they're set by route/executor code with explicit columns. If you add
`document_chunks` to `ALLOWED_MODELS` for querying, give it a `MODEL_DIRECTORY`
entry too.

## Slayer model files (`slayer/slayer_data/models/exono/*.yaml`)

These are auto-generated by Slayer's ingestion (they carry `sampled_values`
caches). Do NOT hand-edit them to fix schema drift — regenerate via Slayer's
ingest / `validate-models` tooling so the caches stay consistent. The only drift
found in the last audit was a stale `contacts.follow_up_urgency` column.

## Verify
- Typecheck with `npx tsc --noEmit` from `backend/` after edits.
- Use the Supabase MCP (`list_tables` verbose, or `information_schema` via
  `execute_sql`) as the source of truth for column names — never guess.
