# Plan: Migrate Realtime sync from `postgres_changes` to Broadcast-from-Database

**Audience:** an implementing agent (Sonnet 4.6). Follow this exactly. Every SQL signature,
function name, and column fact below was verified against the **live Exono Supabase project
(`ezammzqvbjgpuzleqmla`, Postgres 17.6)** on 2026-06-29 via the Supabase MCP — not from memory.
Do not invent signatures. If something here disagrees with what you observe in the DB, STOP and
report; do not guess.

---

## 0. Why this change (context — do not skip)

The Flutter app keeps a local-first drift cache and uses **one shared Supabase WebSocket** (single
`Supabase.initialize()` in [main.dart:68](exono/lib/main.dart#L68)). Over that socket it opens **10
`postgres_changes` channels per user** (one per synced table) in
[sync_provider.dart:46-57](exono/lib/providers/sync_provider.dart#L46-L57) +
[synced_repository.dart:134-158](exono/lib/repositories/synced_repository.dart#L134-L158), plus up to
5 more during a live event ([live_event_provider.dart:199-220](exono/lib/providers/live_event_provider.dart#L199-L220)),
plus 1 for chat ([chat_provider.dart:277-325](exono/lib/providers/chat_provider.dart#L277-L325)).

**Confirmed facts (do not re-litigate):**
- **Concurrent connections are NOT the bottleneck.** The Supabase dashboard shows *Max concurrent
  peak connections = 3* across multiple devices. Billing counts WebSocket connections (clients),
  and one client multiplexes ≤100 channels. This is fine for a long time.
- **The metric that scales badly is Realtime *messages*** and the DB-side cost of `postgres_changes`.
  Supabase bills "1 DB change × N listening clients = N messages", and each `postgres_changes`
  subscription is evaluated against RLS *per change, per subscriber* on the database. That is the
  thing Supabase's own docs tell you not to lean on at scale.

**The fix:** replace `postgres_changes` row streaming with **Broadcast-from-Database**. A DB trigger
calls `realtime.broadcast_changes(...)` to a **single per-user topic**. The client subscribes to that
one private broadcast topic and, on any message, fires the **existing** `catchUp` delta-sync over HTTP
to pull the actual rows. Realtime carries a tiny "something changed" poke, not full row payloads.

**This keeps the local-first architecture intact** — `catchUpAll()` / `catchUp()` already exist and
are idempotent. We are only changing the *wake-up signal*, not the data path.

> **No live app exists yet.** There are no released clients in the wild, so there is nothing to keep
> backward-compatible. Do the whole thing — triggers, policy, AND removing the old `postgres_changes`
> tables from the publication — in **one** migration. The old "ship in parallel, clean up later"
> staging is unnecessary; a single cutover is correct here.

---

## 1. Verified DB facts (from live project, 2026-06-29)

**`realtime.broadcast_changes` signature (verified — note the 8th `level` param the public docs omit):**
```
realtime.broadcast_changes(
  topic_name   text,
  event_name   text,
  operation    text,
  table_name   text,
  table_schema text,
  new_record   record,
  old_record   record,
  level        text     -- 8th arg; pass 'ROW'
)
```
**`realtime.send` signature (verified):** `realtime.send(payload jsonb, event text, topic text, private boolean)`
**`realtime.topic()` exists, takes no args** (returns the topic the client is joining; for use in RLS).

**Synced tables + columns (verified).** All 10 synced tables have `user_id`, `updated_at`, `deleted_at`
EXCEPT as noted:

| table | user_id | updated_at | deleted_at | RLS | in `supabase_realtime` publication |
|---|---|---|---|---|---|
| events | yes | yes | yes | on | yes |
| contacts | yes | yes | yes | on | yes |
| captures | yes | yes | yes | on | yes |
| target_companies | yes | yes | yes | on | yes |
| contact_events | yes | yes | yes | on | yes |
| event_goals | yes | yes | yes | on | yes |
| email_drafts | yes | yes | yes | on | yes |
| interactions | yes | yes | yes | on | yes |
| follow_ups | yes | yes | yes | on | yes |
| target_company_met | yes | yes | yes | on | yes |
| **companies** | **NO user_id** | yes | **NO deleted_at** | on | **NOT in publication** |
| messages (chat) | yes | no | no | on | yes |

**Critical implications:**
- `companies` is a **shared/global** table with no `user_id`. It is **not** currently realtime-synced
  (not in the publication) and the client never subscribes to it
  ([sync_provider.dart:46-57](exono/lib/providers/sync_provider.dart#L46-L57) excludes it — it is only
  in `catchUpAll`'s table list, refreshed on resume). **Do NOT add a per-user broadcast trigger to
  `companies`.** Leave companies exactly as-is (pulled by `catchUpAll`). This plan covers only the 10
  per-user tables.
- **`realtime.messages` currently has ZERO policies** (verified). Private broadcast channels cannot be
  joined until we add a SELECT policy. We must add it (Step 2.3).

---

## 2. Backend / database changes (one migration)

Apply as a single migration via `mcp__supabase__apply_migration` (project `ezammzqvbjgpuzleqmla`),
name it `realtime_broadcast_sync`. Author it as plain SQL. Steps 2.1–2.4 go in that one migration.

### 2.1 — Trigger function: broadcast a per-user "table changed" poke

We do **not** broadcast row contents. We broadcast a minimal poke keyed to the owning user so the
client knows which table to delta-sync. Topic is **per user**: `sync:user=<user_id>`.

`user_id` is read from `NEW` on INSERT/UPDATE and from `OLD` on DELETE. Because every covered table
has a `user_id` column, a single generic function works for all 10 tables.

```sql
create or replace function public.broadcast_sync_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid;
begin
  -- Owning user: present on NEW (insert/update) or OLD (delete).
  uid := coalesce(
    (case when tg_op = 'DELETE' then null else (new).user_id end),
    (old).user_id
  );
  if uid is null then
    return null;  -- nothing to route; never block the write
  end if;

  -- Tiny poke: which table changed + the row id + op. NO full row payload.
  -- The client reacts by running its existing catchUp() for that table.
  perform realtime.send(
    jsonb_build_object(
      'table', tg_table_name,
      'op',    tg_op,
      'id',    coalesce((case when tg_op='DELETE' then null else (new).id end), (old).id)
    ),
    'sync',                          -- event name the client listens for
    'sync:user=' || uid::text,       -- per-user private topic
    true                             -- private := true (requires RLS authz, see 2.3)
  );
  return null;
exception
  when others then
    -- A realtime failure must NEVER fail the underlying write.
    return null;
end;
$$;
```

**Why `realtime.send` and not `realtime.broadcast_changes`:** `broadcast_changes` serializes the full
NEW/OLD record into the message — exactly the payload bloat we are trying to avoid, and it would also
leak full rows onto the channel. We want a *poke*, so `realtime.send` with a 3-field jsonb is correct
and cheaper. (Both functions are verified present; we deliberately choose `send`.)

**Why `id` is included** even though the client re-pulls via HTTP: it is cheap, aids debugging/logging,
and lets a future optimization apply single-row deletes without a full delta. The client in this plan
ignores it beyond triggering catchUp.

**Why `security definer` + `set search_path = ''`:** required so the trigger can call into the
`realtime` schema regardless of the writing role, and `search_path=''` is the Supabase-recommended
hardening (all object refs are schema-qualified). This matches the pattern in Supabase's own docs.

### 2.2 — Attach the trigger to all 10 per-user tables

Do **NOT** attach to `companies` (no user_id, not synced) or `messages` (chat has its own path; see
Step 4 note). One `CREATE TRIGGER` per table:

```sql
create trigger broadcast_sync_change_trigger
after insert or update or delete on public.events
for each row execute function public.broadcast_sync_change();

create trigger broadcast_sync_change_trigger
after insert or update or delete on public.contacts
for each row execute function public.broadcast_sync_change();

create trigger broadcast_sync_change_trigger
after insert or update or delete on public.captures
for each row execute function public.broadcast_sync_change();

create trigger broadcast_sync_change_trigger
after insert or update or delete on public.target_companies
for each row execute function public.broadcast_sync_change();

create trigger broadcast_sync_change_trigger
after insert or update or delete on public.contact_events
for each row execute function public.broadcast_sync_change();

create trigger broadcast_sync_change_trigger
after insert or update or delete on public.event_goals
for each row execute function public.broadcast_sync_change();

create trigger broadcast_sync_change_trigger
after insert or update or delete on public.email_drafts
for each row execute function public.broadcast_sync_change();

create trigger broadcast_sync_change_trigger
after insert or update or delete on public.interactions
for each row execute function public.broadcast_sync_change();

create trigger broadcast_sync_change_trigger
after insert or update or delete on public.follow_ups
for each row execute function public.broadcast_sync_change();

create trigger broadcast_sync_change_trigger
after insert or update or delete on public.target_company_met
for each row execute function public.broadcast_sync_change();
```

### 2.3 — RLS policy on `realtime.messages` so a user may join ONLY their own topic

`realtime.messages` has no policies yet, so private channels reject all joins. Add a SELECT policy that
authorizes a user for the topic `sync:user=<their own uid>` and nothing else. Use the verified
`realtime.topic()` helper.

```sql
-- Receiving broadcasts requires a SELECT policy on realtime.messages.
create policy "users read own sync broadcast topic"
on realtime.messages
for select
to authenticated
using (
  realtime.messages.extension = 'broadcast'
  and realtime.topic() = 'sync:user=' || (select auth.uid())::text
);
```

**This is the security boundary.** Without the `realtime.topic()` equality check a user could subscribe
to another user's poke stream. The poke contains only `{table, op, id}` (no row data), but still gate it
per-user. We do **not** add an INSERT policy on `realtime.messages` — the trigger inserts as
`security definer`, and clients must not be able to forge pokes.

### 2.4 — Drop the 10 sync tables from the `postgres_changes` publication (same migration)

No live clients exist, so cut over immediately — remove the per-user sync tables from
`supabase_realtime` in this same migration. This stops the old `postgres_changes` fan-out from
double-billing messages alongside the new broadcast.

```sql
alter publication supabase_realtime drop table public.events;
alter publication supabase_realtime drop table public.contacts;
alter publication supabase_realtime drop table public.captures;
alter publication supabase_realtime drop table public.target_companies;
alter publication supabase_realtime drop table public.contact_events;
alter publication supabase_realtime drop table public.event_goals;
alter publication supabase_realtime drop table public.email_drafts;
alter publication supabase_realtime drop table public.interactions;
alter publication supabase_realtime drop table public.follow_ups;
alter publication supabase_realtime drop table public.target_company_met;
```

**The full 10-table drop above is correct** because Step 3.3 (live-event migration) is being done in
this same pass — after 3.3 the live provider opens no `postgres_changes` channels, so its five tables
(`captures, event_goals, target_companies, contact_events, contacts`) have no remaining
`postgres_changes` consumer and are safe to drop.

**One caveat — do NOT drop these:** `messages` and `conversations` stay in the publication — chat still
uses `postgres_changes` (it needs the actual row pushed live; the poke-then-pull pattern does not fit
it). They are not in the drop list above; keep it that way. Do not touch `chat_provider.dart`.

> Sequencing safety: run the Step 2 migration (triggers + policy + publication drop) and ship the
> client changes (3.1–3.4, including 3.3) together. Since no live app exists, there is no window where a
> client expects `postgres_changes` on a dropped table.

---

## 3. Client changes (Flutter)

The goal: replace the per-table `postgres_changes` subscriptions with **one** private broadcast channel
that triggers the existing `catchUp`. Keep everything else (drift cache, `catchUpAll`, repositories,
screens) untouched.

### 3.1 — Add a single broadcast subscription owned by `SyncProvider`

Edit [exono/lib/providers/sync_provider.dart](exono/lib/providers/sync_provider.dart).

**Remove** the per-repo realtime loop. In `start()`
([sync_provider.dart:72-81](exono/lib/providers/sync_provider.dart#L72-L81)) the block:
```dart
if (!_started) {
  for (final repo in _realtimeRepos) {
    repo.subscribeRealtime(userId);
  }
  _started = true;
}
```
becomes a single channel subscription:
```dart
if (!_started) {
  _subscribeSyncBroadcast(userId);
  _started = true;
}
```

**Add** these members + methods to `SyncProvider` (import `package:supabase_flutter/supabase_flutter.dart`
and `dart:async` at the top of the file):

```dart
RealtimeChannel? _syncChannel;
Timer? _broadcastDebounce;

/// Single private Broadcast channel carrying per-user "table changed" pokes
/// emitted by the public.broadcast_sync_change() DB trigger. On any poke we
/// run the existing catchUpAll() delta-sync (debounced) — Realtime is only a
/// wake-up signal, not the data path. Replaces the 10 postgres_changes channels.
void _subscribeSyncBroadcast(String userId) {
  final client = Supabase.instance.client;
  // Required for private channels: hand the current JWT to the realtime socket
  // so the realtime.messages RLS policy can evaluate auth.uid().
  client.realtime.setAuth();
  _syncChannel?.unsubscribe();
  _syncChannel = client
      .channel(
        'sync:user=$userId',
        opts: const RealtimeChannelConfig(private: true),
      )
      .onBroadcast(
        event: 'sync',
        callback: (_) => _scheduleBroadcastCatchUp(),
      )
      .subscribe();
}

/// Coalesce a burst of pokes (e.g. a multi-row write) into one catchUpAll.
void _scheduleBroadcastCatchUp() {
  _broadcastDebounce?.cancel();
  _broadcastDebounce = Timer(const Duration(milliseconds: 400), () {
    catchUpAll();
  });
}
```

**Update `stop()`** ([sync_provider.dart:123-130](exono/lib/providers/sync_provider.dart#L123-L130)) and
**`dispose()`** ([sync_provider.dart:139-147](exono/lib/providers/sync_provider.dart#L139-L147)) to tear
down the new channel + timer:
```dart
// in stop():
_broadcastDebounce?.cancel();
await _syncChannel?.unsubscribe();
_syncChannel = null;
// (keep the existing repo.dispose() loop and db.wipeAll())

// in dispose():
_broadcastDebounce?.cancel();
_syncChannel?.unsubscribe();
// (keep the rest)
```

> The `for (final repo in _realtimeRepos) repo.dispose()` loops in `stop()`/`dispose()` can stay — after
> Step 3.2 `dispose()` on the repo just nulls an already-null channel (harmless). Keep them; do not
> churn unrelated code.

### 3.2 — Neutralize `SyncedRepository.subscribeRealtime` (do not delete the method yet)

Edit [exono/lib/repositories/synced_repository.dart](exono/lib/repositories/synced_repository.dart).

We keep `applyDelta`, `_upsertOne`, `catchUp`, `applyTableDelta` (still used by catchUp). We stop the
per-table `postgres_changes` subscription. Replace the body of `subscribeRealtime`
([synced_repository.dart:134-158](exono/lib/repositories/synced_repository.dart#L134-L158)) with a no-op,
or remove the call site (Step 3.1 already removed the only caller). Safest minimal change: delete the
`subscribeRealtime` method **and** the now-unused `_channel` field + its uses in `dispose`
([synced_repository.dart:30](exono/lib/repositories/synced_repository.dart#L30),
[synced_repository.dart:160-163](exono/lib/repositories/synced_repository.dart#L160-L163)).

After removal, `dispose()` becomes:
```dart
Future<void> dispose() async {}
```
Keep the method (it is called by `SyncProvider`), just empty it. Run `flutter analyze` to confirm no
dangling `_channel` references remain.

### 3.3 — Live-event provider: drop its 5 `postgres_changes` channels, react to the same poke (REQUIRED — do in this same pass)

[live_event_provider.dart:199-220](exono/lib/providers/live_event_provider.dart#L199-L220) opens 5 extra
`postgres_changes` channels during a live event (`_liveTables` =
[`captures, event_goals, target_companies, contact_events, contacts`](exono/lib/providers/live_event_provider.dart#L49-L55))
purely to call `_scheduleRefresh()` — it already **ignores the payload**
(`callback: (_) => _scheduleRefresh()`). That is exactly the poke pattern, so it can ride the **same
single broadcast channel** `SyncProvider` already opens. The single sync poke covers all five live
tables (they're all in the synced-10), so the live provider needs no realtime channels of its own.

**Step 3.3a — `SyncProvider` exposes a poke hook.** In
[sync_provider.dart](exono/lib/providers/sync_provider.dart), add a public callback that fires on every
debounced poke, alongside the existing `catchUpAll()`:
```dart
/// Optional listener notified on each (debounced) sync poke, after catchUpAll
/// runs. LiveEventProvider sets this to refresh the live aggregate, so the
/// live floor reacts to the SAME broadcast as the rest of sync — no separate
/// realtime channels needed during a live event.
VoidCallback? onSyncPoke;
```
Update `_scheduleBroadcastCatchUp` (added in 3.1) so it calls the hook **after** the catchUp completes
(the live `/live-session` refresh should read rows already written to drift):
```dart
void _scheduleBroadcastCatchUp() {
  _broadcastDebounce?.cancel();
  _broadcastDebounce = Timer(const Duration(milliseconds: 400), () async {
    await catchUpAll();
    onSyncPoke?.call();
  });
}
```

**Step 3.3b — `LiveEventProvider` reacts to the hook instead of its own channels.** In
[live_event_provider.dart](exono/lib/providers/live_event_provider.dart):
- **Delete** `_subscribeLiveRealtime()`, `_teardownLiveRealtime()`, the `_liveChannels` list
  ([:56](exono/lib/providers/live_event_provider.dart#L56)), the `_liveTables` const
  ([:49-55](exono/lib/providers/live_event_provider.dart#L49-L55)), and the
  `import 'package:supabase_flutter/supabase_flutter.dart';` **only if** nothing else in the file uses it
  (grep first — `RealtimeChannel` was the only user; confirm with `flutter analyze`).
- In `_enterLiveMode()` ([:182-187](exono/lib/providers/live_event_provider.dart#L182-L187)): remove the
  `_subscribeLiveRealtime();` call. Keep `_refresh();` and the 60s `_safetyTimer` (it stays as the
  dropped-socket / missed-poke backstop).
- In `_leaveLiveMode()` ([:189-197](exono/lib/providers/live_event_provider.dart#L189-L197)): remove the
  `_teardownLiveRealtime();` call.
- In `dispose()` ([:565-573](exono/lib/providers/live_event_provider.dart#L565-L573)): remove the
  `_teardownLiveRealtime();` call.
- The poke is delivered by `SyncProvider.onSyncPoke`. `LiveEventProvider` must only act on it **while
  live** — guard inside the callback so an idle account does no `/live-session` work:
  ```dart
  // called from main.dart wiring (3.3c); _hasOngoing is the existing live gate
  void onSyncPoke() {
    if (_hasOngoing) _scheduleRefresh();
  }
  ```
  Keep the existing `_scheduleRefresh()` 800ms debounce ([:231-234](exono/lib/providers/live_event_provider.dart#L231-L234))
  and `_refresh()` as-is.

**Step 3.3c — wire the two providers in `main.dart`.** Both are siblings in `MultiProvider`
([main.dart:118,121](exono/lib/main.dart#L118)) and `LiveEventProvider.init(sync.db, userId)` is already
called immediately before `sync.start(userId)` in the auth listener
([main.dart:159-161](exono/lib/main.dart#L159-L161) and again at [:171-172](exono/lib/main.dart#L171-L172)).
Right after each `LiveEventProvider.init(...)` / `sync.start(...)` pair, connect the hook:
```dart
final live = context.read<LiveEventProvider>();
live.init(sync.db, userId);
sync.onSyncPoke = live.onSyncPoke;   // live floor reacts to the same broadcast
WriteGateway().init(sync.db, userId); // (existing line, only in the listener branch)
sync.start(userId);
```
On logout, clear it so a stale closure can't fire: in the `else if (wasAuthenticated)` branch
([main.dart:163-166](exono/lib/main.dart#L163-L166)) add `sync.onSyncPoke = null;` next to `sync.stop();`.

> Net effect: during a live event the app now opens **zero** extra realtime channels — the one sync
> broadcast drives both the drift catchUp and the live-session refresh. All five live tables
> (`captures, event_goals, target_companies, contact_events, contacts`) are therefore safe to drop from
> the publication in Step 2.4 (use the **full 10-table drop list** as written there).

### 3.4 — `setAuth` on token refresh

Private channels need a valid JWT on the socket. The app already initializes Supabase auth; `setAuth()`
is called in `_subscribeSyncBroadcast`. If the session token rotates while subscribed, the socket keeps
the old token. **Add**: in the existing auth-state listener (main.dart wires `AuthProvider` to
`SyncProvider.start/stop`), on `tokenRefreshed` call `Supabase.instance.client.realtime.setAuth()`.
Locate the auth listener that already calls `start()`/`stop()` and add the `setAuth()` on refresh there.
Verify the event name against the installed SDK (`supabase_flutter 2.14.1`): it is
`AuthChangeEvent.tokenRefreshed`.

---

## 4. Verification (do every item — this is how we avoid silent breakage)

1. **DB function/trigger present:**
   ```sql
   select tgname, tgrelid::regclass from pg_trigger where tgname='broadcast_sync_change_trigger' order by 2;
   -- expect exactly the 10 tables from 2.2, none extra
   select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
     where n.nspname='public' and p.proname='broadcast_sync_change';
   ```
2. **Policy present:**
   ```sql
   select policyname, cmd from pg_policies where schemaname='realtime' and tablename='messages';
   -- expect: "users read own sync broadcast topic" / SELECT
   ```
3. **Trigger does not block writes / does not error:** with the MCP, run a harmless update on one row
   of `events` for a real user and confirm it succeeds (the `exception when others` guard means a
   realtime failure can't fail the write — but confirm the happy path too).
4. **Client compiles:** from `exono/`, `flutter analyze lib/providers/sync_provider.dart
   lib/repositories/synced_repository.dart lib/providers/live_event_provider.dart lib/main.dart` — zero
   errors. Fix anything flagged (likely an unused import — the deleted `RealtimeChannel` use in the live
   provider — or a leftover `_channel` / `_liveChannels` reference).
5. **End-to-end poke→sync on two devices:** log in as the same user on device A and device B. On A,
   create a contact. Confirm B's contacts list updates within ~1–2s (poke → debounced `catchUpAll` →
   drift write → UI stream repaint). Confirm a soft-delete on A removes it on B.
6. **Cross-user isolation:** log in as user X on one device, user Y on another. A write by X must NOT
   trigger a catchUp on Y's device (the per-user topic + RLS policy enforces this). Verify by watching
   logs / network: Y's device should see no `sync` broadcast for X's write.
7. **Live event still updates (Phase-2 / Step 3.3 check):** with an event ongoing (so `_hasOngoing` is
   true and the app is in live mode) on device A and device B, scan/add a capture or change a goal on A.
   Confirm B's live floor refreshes within ~1–2s. This proves the live provider now reacts to the single
   sync poke (via `SyncProvider.onSyncPoke`) instead of its deleted `postgres_changes` channels. Also
   confirm an **idle** account (no ongoing event) does NOT fire `/live-session` on a poke (the
   `if (_hasOngoing)` guard).
8. **Dashboard delta:** after a day of dual-device testing, check Supabase → Reports → Realtime. The
   *Messages* count per write should drop from "N subscribers × per-table fan-out" to ~1 poke per write
   per subscribed device. *Concurrent connections* stays ~1/user (it already was).

---

## 5. Cleanup — folded into Step 2.4 (no separate migration needed)

Because no live app exists, the publication drop is part of the single Step 2.4 migration above. There
is no follow-up cleanup migration and no rollout gate. (This section previously described a staged
cutover for in-the-wild clients — not applicable here.)

---

## 6. Rollback

- **Client:** revert the `sync_provider.dart` / `synced_repository.dart` changes.
- **DB (single rollback migration):**
  ```sql
  drop trigger broadcast_sync_change_trigger on public.events;          -- ×10, one per table from 2.2
  -- ... (repeat for contacts, captures, target_companies, contact_events,
  --      event_goals, email_drafts, interactions, follow_ups, target_company_met)
  drop function public.broadcast_sync_change();
  drop policy "users read own sync broadcast topic" on realtime.messages;
  -- Restore postgres_changes for the dropped tables:
  alter publication supabase_realtime add table public.events;          -- ×10, the same set dropped in 2.4
  ```
  Then revert the client. The triggers are guarded (`exception when others → return null`) and never
  affected writes, so rollback is low-risk. Re-add only the tables you actually dropped in 2.4 (see the
  Phase-2 caveat there).

---

## 7. Hard constraints (do not violate)

- **No emojis** anywhere (repo rule, [CLAUDE.md]).
- **Do not touch** `companies` (no user_id), `messages`/chat, or any screen file.
- **Do not** drop `messages` / `conversations` from the publication (chat still uses `postgres_changes`).
- **Do not** broadcast full row payloads — use `realtime.send` with the 3-field poke, not
  `realtime.broadcast_changes`.
- The poke MUST NOT be able to fail a write — keep the `exception when others` guard.
- Step 3.3 (live event) is part of this pass — after it, the live provider opens no realtime channels,
  so the full 10-table drop in 2.4 is correct. Do not leave the live provider on `postgres_changes`.
- Verify `AuthChangeEvent` / `RealtimeChannelConfig` / `onBroadcast` / `setAuth` names against the
  installed `supabase_flutter 2.14.1` / `realtime_client 2.7.3` before finalizing; if an API name
  differs, STOP and report rather than guessing.
- The poke MUST NOT be able to fail a write — keep the `exception when others` guard.
- Verify the `AuthChangeEvent` and `RealtimeChannelConfig` / `onBroadcast` / `setAuth` names against the
  installed `supabase_flutter 2.14.1` / `realtime_client 2.7.3` before finalizing; if an API name
  differs in that version, STOP and report rather than guessing.
