# Local-First Realtime Sync — Implementation Plan

> **Status:** Not started. This document is the single source of truth for the
> "instant screens, always-fresh data" rebuild. Implement phases in order. Do not
> skip the schema phase — every later phase depends on it.

## 0. Context an implementer must not re-derive

**Repos / paths (all absolute from repo root `/home/nikant/Desktop/crm`):**
- Backend (Express + TypeScript): `backend/src/`
  - Routes: `backend/src/routes/*.ts` (one file per resource: `events.ts`, `contacts.ts`, `captures.ts`, `companies.ts`, `emails.ts`, `followUps.ts`, `conversations.ts`, `index.ts` mounts them).
  - Supabase clients: `backend/src/config/supabaseClients.ts` exports `supabaseAdmin` (service role, bypasses RLS) and `createSupabaseUserClient(token)` (RLS-bound). `backend/src/config/supabase.ts` re-exports `supabaseAdmin as supabase` — **existing routes use this admin client**, so they already bypass RLS and filter by `user_id` manually.
  - Auth middleware: `backend/src/middleware/requireAuth.ts` sets `req.user.id`.
- Flutter app: `exono/lib/`
  - Screens: `exono/lib/screens/*.dart` (~35 screens, `setState`-based, no FutureBuilder/StreamBuilder anywhere today).
  - Providers (ChangeNotifier + `provider` package): `exono/lib/providers/*.dart`, wired in `exono/lib/main.dart` via `MultiProvider` (around line 77).
  - Services: `exono/lib/services/api_service.dart` (all HTTP today), `exono/lib/services/offline/` (existing offline queue: `offline_queue.dart`, `sync_service.dart`, `connectivity_service.dart`, `background_sync.dart`).
  - Config: `exono/lib/config/supabase_config.dart`, `api_config.dart`. Supabase already initialized in `main.dart` (~line 53 `await Supabase.initialize(...)`).
- Scripts: `scripts/` (existing `.mjs` scripts use `@supabase/supabase-js` + `dotenv`). The purge script `scripts/purge-soft-deleted.mjs` already exists (see §7).

**Supabase project:** `Exono`, project ref `ezammzqvbjgpuzleqmla`, Postgres 17, region `ap-northeast-2`. RLS enabled on all `public` tables. Use the Supabase MCP tools (`mcp__supabase__apply_migration`, `mcp__supabase__execute_sql`, `mcp__supabase__list_tables`) for DB changes; **prefer `apply_migration` for DDL** (it versions the migration).

**Flutter deps already present (`exono/pubspec.yaml`):** `provider: ^6.1.1`, `supabase_flutter: ^2.6.1`, `sqflite: ^2.3.0`, `path_provider: ^2.1.1`, `connectivity_plus: ^6.1.4`. **`drift` is NOT yet added** — Phase 4 adds it.

**Backend deps already present (`backend/package.json`):** `@supabase/supabase-js: ^2.39.0`, `express`, `dotenv`. No websocket libs (good — we use Supabase Realtime, not hand-rolled sockets).

## 1. Goal & non-goals

**Goal:** After first launch, every list/detail screen paints instantly from a local
drift database. Data stays fresh in near-real-time (Supabase Realtime push) with no
spinners and no mandatory pull-to-refresh. Survives offline/background via delta sync.

**Non-goals (do NOT build):**
- Hand-rolled websockets/SSE on Express — use Supabase Realtime.
- A `records_updated_at` "signal column" on the user row — rejected (write hotspot,
  lost signals, still forces full refetch). We subscribe to row-level changes directly.
- Delta sync that ignores deletes — deletes MUST be handled via tombstones (§3).

## 2. The data model: which tables sync, and how ownership works

**Ownership is the crux.** Supabase Realtime server-side filters and RLS policies can
only filter on a column that **physically exists on the row**. You cannot subscribe to
"target_companies where the owning event belongs to me" because `target_companies` has
no `user_id`. Therefore we denormalize `user_id` onto every synced child table.

### 2a. Synced tables and their current ownership

| Table | Has `user_id` today? | Owner derivation | Action |
|---|---|---|---|
| `events` | ✅ yes | direct | none (already has it) |
| `contacts` | ✅ yes | direct | none |
| `captures` | ✅ yes | direct | none |
| `target_companies` | ❌ no | via `event_id → events.user_id` | **add `user_id`** |
| `contact_events` | ❌ no | via `event_id → events.user_id` | **add `user_id`** |
| `event_goals` | ❌ no | via `event_id → events.user_id` | **add `user_id`** |
| `email_drafts` | ❌ no | via `event_id`/`contact_id` | **add `user_id`** |
| `interactions` | ❌ no | via `contact_id → contacts.user_id` | **add `user_id`** |
| `notes` | ❌ no | via `contact_id`/`event_id` | **add `user_id`** |
| `documents` | ❌ no | via `contact_id`/`company_id`/`event_id` | **add `user_id`** |

### 2b. Special case: `companies` (shared lookup, do NOT add user_id)

`companies` has **no `user_id` and is shared** — multiple users can reference the same
company row. Do **not** denormalize `user_id` onto it (that would be semantically wrong
and break sharing). Instead, sync companies as a **referenced lookup**: the `/sync`
endpoint (§5) returns the set of `companies` rows that the user references through their
`contacts.company_id` and `target_companies.company_id`. Realtime for companies is
**out of scope** (company rows rarely change and are not user-private) — clients refresh
referenced companies only via delta sync, not live push.

### 2c. Out of scope for v1 sync

Chat/assistant tables (`conversations`, `messages`, `assistant_runs`, `tool_calls`,
`message_links`, `conversation_members`, `message_attachments`) — chat already has its
own realtime path in `chat_provider.dart`. `enrichment_queue`, `company_research`,
`marketing_assets`, `attachments`, `contact_documents`, `user_settings`,
`user_profiles`, `assistant_rate_limits` — not list-screen data; leave on direct REST.
Revisit only if a screen needs them local-first.

## 3. Phase 1 — Schema migrations (BLOCKING; do first)

Apply each as a separate named migration via `mcp__supabase__apply_migration`. All DDL is
idempotent-friendly (`IF NOT EXISTS`). The synced tables are exactly:
`events, contacts, captures, target_companies, contact_events, event_goals, email_drafts, interactions, notes, documents`.

### 3.1 Add `deleted_at` tombstone to every synced table

```sql
-- migration: add_deleted_at_tombstones
ALTER TABLE public.events            ADD COLUMN IF NOT EXISTS deleted_at timestamptz;
ALTER TABLE public.contacts          ADD COLUMN IF NOT EXISTS deleted_at timestamptz;
ALTER TABLE public.captures          ADD COLUMN IF NOT EXISTS deleted_at timestamptz;
ALTER TABLE public.target_companies  ADD COLUMN IF NOT EXISTS deleted_at timestamptz;
ALTER TABLE public.contact_events    ADD COLUMN IF NOT EXISTS deleted_at timestamptz;
ALTER TABLE public.event_goals       ADD COLUMN IF NOT EXISTS deleted_at timestamptz;
ALTER TABLE public.email_drafts      ADD COLUMN IF NOT EXISTS deleted_at timestamptz;
ALTER TABLE public.interactions      ADD COLUMN IF NOT EXISTS deleted_at timestamptz;
ALTER TABLE public.notes             ADD COLUMN IF NOT EXISTS deleted_at timestamptz;
ALTER TABLE public.documents         ADD COLUMN IF NOT EXISTS deleted_at timestamptz;
```

### 3.2 Add `user_id` to child tables + backfill + index

For EACH child table in the list `target_companies, contact_events, event_goals, email_drafts, interactions, notes, documents`:

```sql
-- migration: add_user_id_to_child_tables
-- 1. add column (nullable first so backfill can run)
ALTER TABLE public.target_companies ADD COLUMN IF NOT EXISTS user_id uuid REFERENCES auth.users(id);
-- ... repeat ALTER for each child table ...

-- 2. backfill from the owning parent. Use the FIRST available parent link.
-- target_companies, contact_events, event_goals  -> via event
UPDATE public.target_companies tc SET user_id = e.user_id
  FROM public.events e WHERE tc.event_id = e.id AND tc.user_id IS NULL;
UPDATE public.contact_events ce SET user_id = e.user_id
  FROM public.events e WHERE ce.event_id = e.id AND ce.user_id IS NULL;
UPDATE public.event_goals g SET user_id = e.user_id
  FROM public.events e WHERE g.event_id = e.id AND g.user_id IS NULL;
-- interactions, notes, email_drafts, documents -> prefer contact, fall back to event
UPDATE public.interactions i SET user_id = c.user_id
  FROM public.contacts c WHERE i.contact_id = c.id AND i.user_id IS NULL;
UPDATE public.interactions i SET user_id = e.user_id
  FROM public.events e WHERE i.event_id = e.id AND i.user_id IS NULL;
UPDATE public.notes n SET user_id = c.user_id
  FROM public.contacts c WHERE n.contact_id = c.id AND n.user_id IS NULL;
UPDATE public.notes n SET user_id = e.user_id
  FROM public.events e WHERE n.event_id = e.id AND n.user_id IS NULL;
UPDATE public.email_drafts d SET user_id = c.user_id
  FROM public.contacts c WHERE d.contact_id = c.id AND d.user_id IS NULL;
UPDATE public.email_drafts d SET user_id = e.user_id
  FROM public.events e WHERE d.event_id = e.id AND d.user_id IS NULL;
UPDATE public.documents dc SET user_id = c.user_id
  FROM public.contacts c WHERE dc.contact_id = c.id AND dc.user_id IS NULL;
UPDATE public.documents dc SET user_id = e.user_id
  FROM public.events e WHERE dc.event_id = e.id AND dc.user_id IS NULL;

-- 3. index for fast user-scoped delta queries + realtime RLS
CREATE INDEX IF NOT EXISTS idx_target_companies_user_id ON public.target_companies(user_id);
-- ... repeat CREATE INDEX for each child table ...
-- also index the sync hot path on every synced table:
CREATE INDEX IF NOT EXISTS idx_target_companies_user_updated ON public.target_companies(user_id, updated_at);
-- ... repeat (user_id, updated_at) composite for each synced table including events/contacts/captures ...
```

> After backfill, verify zero orphans: `SELECT count(*) FROM public.<table> WHERE user_id IS NULL AND deleted_at IS NULL;` should be 0 for each. If not, investigate before continuing — an orphan row will never sync to any client.

### 3.3 Ensure `updated_at` auto-bumps on UPDATE (DB-level trigger)

Today some routes set `updated_at` in app code, inconsistently. Delta sync correctness
requires the DB to bump it on **every** update. Use Supabase's `moddatetime` extension.

```sql
-- migration: updated_at_triggers
CREATE EXTENSION IF NOT EXISTS moddatetime SCHEMA extensions;

DROP TRIGGER IF EXISTS set_updated_at ON public.events;
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.events
  FOR EACH ROW EXECUTE FUNCTION extensions.moddatetime(updated_at);
-- ... repeat for: contacts, captures, target_companies, contact_events,
--     event_goals, email_drafts, interactions, notes, documents ...
```

> `contact_events` and `event_goals` already have `updated_at`? Check §0 table dump:
> `event_goals` HAS `updated_at`; `contact_events` does **NOT** have `updated_at`.
> **Add it first** for `contact_events`:
> `ALTER TABLE public.contact_events ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();`
> then create its trigger. Verify each synced table actually has an `updated_at` column
> before creating its trigger.

### 3.4 Enable Realtime replication on synced tables

```sql
-- migration: enable_realtime
ALTER PUBLICATION supabase_realtime ADD TABLE public.events;
-- ... repeat for: contacts, captures, target_companies, contact_events,
--     event_goals, email_drafts, interactions, notes, documents ...
-- (NOT companies — see §2b)
```

> Postgres errors if a table is already in the publication. Guard each with a check or
> wrap in a DO block that ignores `duplicate_object`. Verify with:
> `SELECT tablename FROM pg_publication_tables WHERE pubname='supabase_realtime';`

### 3.5 RLS policy for Realtime (per synced table)

Realtime delivers a change to a client only if that client's RLS `SELECT` policy allows
the row. Every synced table now has `user_id`, so add a uniform policy. The Flutter app
connects to Realtime as the **authenticated user** (via `supabase_flutter` session), so
`auth.uid()` is available.

```sql
-- migration: rls_select_own_rows
ALTER TABLE public.events ENABLE ROW LEVEL SECURITY; -- already enabled; harmless
DROP POLICY IF EXISTS sync_select_own ON public.events;
CREATE POLICY sync_select_own ON public.events
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());
-- ... repeat for every synced table ...
```

> The backend uses the **service-role** admin client, which bypasses RLS — so existing
> REST routes are unaffected by these policies. Only the Flutter Realtime/anon path is
> gated by them. Do not remove or weaken existing policies; just add `sync_select_own`.

### 3.6 Convert hard deletes to soft deletes (backend)

Every `.delete()` on a synced table in `backend/src/routes/` must become an UPDATE that
sets `deleted_at = now()`. Files containing `.delete()`:
`events.ts, contacts.ts, captures.ts, emails.ts, followUps.ts, conversations.ts`.

For each DELETE handler on a **synced** table, replace:

```ts
// BEFORE
const { error } = await supabase.from('events').delete()
  .eq('id', req.params.id).eq('user_id', req.user!.id);
```
```ts
// AFTER
const { error } = await supabase.from('events')
  .update({ deleted_at: new Date().toISOString() })
  .eq('id', req.params.id).eq('user_id', req.user!.id);
```

Rules:
- Only convert deletes on the 10 synced tables. Leave deletes on non-synced tables
  (`conversations`, etc.) as hard deletes.
- **Every read/list query on a synced table must now exclude tombstones**: add
  `.is('deleted_at', null)` to existing SELECTs (list endpoints, the batch stats
  endpoint in `events.ts`, joins, counts). Audit each route file for `.from('<synced
  table>')...select(` and append the filter. Missing one means deleted rows reappear.
- For join-embedded selects (e.g. `captures(*, contact:contacts(*))`), the embedded
  resource cannot be filtered inline easily — filter in app code after fetch, OR switch
  the embed to an explicit filtered sub-select. Note each spot you do this.

## 4. Phase 2 — Backend `/sync` delta endpoint

Add `backend/src/routes/sync.ts`, mount in `backend/src/routes/index.ts` under
`/api/sync`. Uses `requireAuth` and the `supabase` admin client (manual `user_id`
filter, consistent with all other routes).

**Contract:**
```
GET /api/sync?since=<ISO8601>&tables=events,contacts,...
  - since   : optional. If omitted/empty => full snapshot (since epoch).
  - tables  : optional CSV. If omitted => all synced tables.
Response 200:
{
  "server_time": "2026-06-18T00:00:00.000Z",   // client stores as next `since`
  "data": {
    "events":   { "upserts": [ {...row...} ], "deleted_ids": ["uuid", ...] },
    "contacts": { "upserts": [...], "deleted_ids": [...] },
    ...,
    "companies":{ "upserts": [...], "deleted_ids": [] }   // referenced lookup, see §2b
  }
}
```

**Per-table query (for each requested synced table):**
```ts
// rows changed since `since` for THIS user, including tombstones
const { data: rows } = await supabase
  .from(table)
  .select('*')
  .eq('user_id', userId)
  .gt('updated_at', since)          // strictly greater; server_time is exclusive lower bound next call
  .order('updated_at', { ascending: true });

const upserts    = rows.filter(r => r.deleted_at == null);
const deletedIds = rows.filter(r => r.deleted_at != null).map(r => r.id);
```

**Why `updated_at > since` catches deletes:** soft-delete sets `deleted_at` via an
UPDATE, which the §3.3 trigger reflects in `updated_at`. So a delete is just a row whose
`updated_at` advanced and whose `deleted_at` is now non-null — it appears in the same
query and lands in `deleted_ids`. This is the entire reason tombstones are mandatory.

**`companies` special handling:** after computing the user's contact/target company_ids
from the upserted contacts + target_companies, fetch referenced companies changed since
`since`:
```ts
const referencedCompanyIds = [...new Set([
  ...contactUpserts.map(c => c.company_id).filter(Boolean),
  ...targetUpserts.map(t => t.company_id).filter(Boolean),
])];
const { data: companies } = await supabase.from('companies')
  .select('*').in('id', referencedCompanyIds).gt('updated_at', since);
// companies.deleted_ids is always [] (no tombstones on shared lookup)
```

**`server_time`:** capture `new Date().toISOString()` at the START of the handler (before
queries) and return it. The client stores it as the next `since`. Using start-time avoids
missing rows written during the request.

**Set `user_id` on INSERT going forward:** in every POST/insert handler for the child
tables (§2a), populate `user_id: req.user!.id` so new rows are owned without relying on a
trigger. (Optionally also add a DB trigger as a backstop, but app-level set is required.)

## 5. Phase 3 — Flutter: drift local DB

Add to `exono/pubspec.yaml`:
```yaml
dependencies:
  drift: ^2.18.0
  sqlite3_flutter_libs: ^0.5.0
dev_dependencies:
  drift_dev: ^2.18.0
  build_runner: ^2.4.0
```
> Keep `sqflite` for now (existing offline queue uses it); drift can coexist. Do not rip
> out `sqflite` in this plan.

Create `exono/lib/db/`:
- `app_database.dart` — drift `@DriftDatabase` with one table class per synced entity,
  mirroring the columns the screens actually read (you do NOT need every column; mirror
  what UI + filtering needs, always include `id`, `updated_at`, `deleted_at`, `user_id`).
- `tables/*.dart` — table definitions. Primary key `id` (text). Add a
  `sync_state` table: `(table_name TEXT PRIMARY KEY, last_synced_at TEXT)`.
- Run `dart run build_runner build` to generate `app_database.g.dart`.

**Reads exclude tombstones:** every UI query filters `deleted_at IS NULL`. Drift
`.watch()` returns a `Stream<List<T>>` that re-emits on any local write — this is what
makes the UI auto-update with zero manual `setState`.

## 6. Phase 4 — Flutter: the repository ("middleman")

Create `exono/lib/repositories/`. One base + one repo per entity. **Screens talk ONLY to
repositories (which expose drift streams). Screens never call `ApiService` for synced
data and never touch Supabase Realtime directly.**

### 6a. `SyncedRepository` responsibilities
1. `Stream<List<T>> watchAll()` / `watchById(id)` — proxy drift `.watch()` for the UI.
2. `Future<void> catchUp()` — call `GET /api/sync?since=<sync_state.last_synced_at>` for
   this table, upsert `upserts` into drift, delete `deleted_ids` from drift (hard local
   delete — local cache has no need for tombstones), then store `server_time` into
   `sync_state.last_synced_at`. Idempotent; safe to call repeatedly.
3. `void subscribeRealtime()` — Supabase Realtime channel on this table filtered to the
   user; on INSERT/UPDATE upsert into drift (if `deleted_at != null`, delete locally
   instead); on DELETE (shouldn't happen post-soft-delete, but handle) delete locally.
4. `void dispose()` — remove channel.

### 6b. Realtime subscription pattern (per repo)
```dart
final channel = Supabase.instance.client
  .channel('public:events:user=$userId')
  .onPostgresChanges(
    event: PostgresChangeEvent.all,
    schema: 'public',
    table: 'events',
    filter: PostgresChangeFilter(
      type: PostgresChangeFilterType.eq, column: 'user_id', value: userId),
    callback: (payload) {
      final row = payload.newRecord; // map
      if (row['deleted_at'] != null) { _localDelete(row['id']); }
      else { _localUpsert(row); }
    },
  )
  .subscribe();
```

### 6c. Optimistic writes (user's own edits feel instant)
On a user mutation: (1) write optimistic row to drift immediately (UI updates via
stream), (2) fire the REST call, (3) on success let the subsequent Realtime/`catchUp`
reconcile (server row overwrites optimistic), (4) on REST error roll back the drift write
and surface the error to the UI (e.g. `showAppToast`). The POST-error case the user
described (backend rejects a new contact, error shown instantly) is exactly this step 4 —
independent of the sync layer.

> **Conflict policy:** last-write-wins by `updated_at`. When upserting, if an incoming
> row's `updated_at` is older than the local row's, ignore it. This prevents a late
> Realtime echo from clobbering a newer optimistic/local state.

## 7. Phase 5 — App lifecycle wiring

In `exono/lib/main.dart` `MultiProvider` (~line 77), register the new repositories
(e.g. `Provider(create: (_) => EventsRepository(db)..start())`). A small
`SyncCoordinator` ties lifecycle:
- On login / app start (post-auth): for each repo → `catchUp()` then `subscribeRealtime()`.
- On `AppLifecycleState.resumed` and on connectivity-restored
  (`connectivity_plus`, already a dep; `OfflineProvider` already observes this): call
  `catchUp()` on all repos (Realtime may have missed events while backgrounded).
- On `AppLifecycleState.paused`: optionally unsubscribe channels to save battery;
  re-subscribe on resume. Always `catchUp()` after re-subscribe.
- On logout: dispose all channels, and **wipe the local drift DB** (clear all synced
  tables + `sync_state`) so another user on the device can't read cached rows.

## 8. Phase 6 — Migrate screens (one entity at a time)

Reference implementation order: **Events first** (smallest, already has the batch-stats
work done), then **Contacts**, then **Captures**, then the rest.

Per screen:
1. Replace `initState`'s `ApiService.getX()` + `setState` with
   `context.read<XRepository>().watchAll()` consumed by a `StreamBuilder` (or a thin
   `ChangeNotifier` adapter if you want to avoid `StreamBuilder` in the widget — but
   `StreamBuilder` over a drift stream is the idiomatic path).
2. First-ever load (empty drift) is the ONLY time a skeleton shows. After that the stream
   always has cached rows → instant paint. Keep the existing skeleton widget for that
   first-load case only.
3. Pull-to-refresh becomes "force `catchUp()`" — optional manual trigger, no longer
   required for freshness.
4. Delete the now-dead `_loadX()`/`_isLoading`/`_error` fetch scaffolding for synced data.
5. Verify with `flutter analyze <file>` (per CLAUDE.md — analyze is the source of truth,
   no second line-by-line pass).

## 9. Phase 7 — Purge job for soft-deleted rows (already scripted)

Soft deletes accumulate forever otherwise. `scripts/purge-soft-deleted.mjs` (already
created) hard-deletes rows whose `deleted_at` is older than `RETENTION_DAYS` (default 30).

**Run manually:**
```bash
node scripts/purge-soft-deleted.mjs                 # purge rows deleted > 30 days ago
DRY_RUN=1 node scripts/purge-soft-deleted.mjs       # report only
RETENTION_DAYS=7 node scripts/purge-soft-deleted.mjs
RETENTION_DAYS=0 node scripts/purge-soft-deleted.mjs # purge ALL soft-deleted rows
```
It reads `backend/.env` for `SUPABASE_URL` + `SUPABASE_SERVICE_ROLE_KEY`, iterates the 10
synced tables, and reports counts. **Manual only** — not wired to any cron. Retention
must exceed the longest plausible offline window of any client so a device that was off
for weeks still learns about the deletion via `catchUp()` before the tombstone is purged.
If you later schedule it, use the `schedule`/cron tooling deliberately — do not auto-run.

## 10. Acceptance criteria (definition of done)

- [ ] Cold launch after first run: Events/Contacts/Captures screens paint from drift with
      **no skeleton** and no network wait.
- [ ] Editing data on a second device/browser reflects on the first device within ~1–2s
      with no user action (Realtime).
- [ ] Deleting a row on device B removes it from device A's list (tombstone → Realtime/
      `catchUp`), and it does NOT reappear after app restart.
- [ ] Airplane mode → make changes elsewhere → reconnect → `catchUp()` reconciles
      (upserts + deletions) with no full reload flash.
- [ ] `SELECT count(*) WHERE user_id IS NULL AND deleted_at IS NULL` is 0 on every synced
      table.
- [ ] Logout wipes local drift DB; a different login shows only its own data.
- [ ] `node scripts/purge-soft-deleted.mjs` (DRY_RUN) reports expected counts; live run
      removes them and `pg_publication_tables` / list screens stay correct.
- [ ] `flutter analyze` clean on every migrated screen; backend `npx tsc --noEmit` clean.

## 11. Production-readiness verdict

Production-ready and scalable **only if** the two hard blockers ship: (1) `deleted_at`
tombstones + soft-delete conversion + tombstone-excluding reads (§3.1, §3.6), and (2)
`user_id` denormalized onto child tables for Realtime/RLS filtering (§3.2, §3.5). Per-user
row counts are tiny, so Realtime fan-out and delta payloads stay small; the design scales
linearly with users and is bounded per-user. Skipping either blocker breaks correctness
(resurrecting deleted rows, or Realtime delivering nothing for child tables).

## 12. Risks / gotchas the implementer must respect

- **Forgetting `.is('deleted_at', null)` on any existing read** → deleted rows reappear.
  Audit every `.from('<synced table>')` SELECT in `backend/src/routes/`.
- **Embedded joins can't filter the child inline** → filter in app code or use explicit
  filtered sub-selects; note each spot.
- **`contact_events` lacks `updated_at`** → add it before its trigger (§3.3 note).
- **Realtime needs RLS SELECT policy** keyed on `auth.uid()` = `user_id`; the Flutter
  client must be connected with the user's JWT (it is — `supabase_flutter` session).
- **Service-role backend bypasses RLS** → existing routes unaffected; do not "fix" them
  to use the user client.
- **Last-write-wins by `updated_at`** → guard upserts against older incoming rows.
- **Logout must wipe drift** → otherwise cross-user data leak on shared device.
- **Migration order matters:** add columns → backfill → indexes → triggers → realtime →
  RLS. Backfill before adding NOT NULL/realtime, or rows orphan.
```
