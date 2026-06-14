# Offline Mode — Implementation Plan

> Audience: an LLM/engineer implementing offline support for the Exono Flutter app.
> Scope: **mobile only (Android/iOS)**. Web is always-online; all offline code must be
> guarded so it is a no-op (or disabled) on `kIsWeb`.

## 0. TL;DR / Architecture decision

- **No RabbitMQ / Redis required.** This is a *client-side outbox* problem. The pending-work
  queue lives on the phone in **SQLite** (`sqflite` is already a dependency). When connectivity
  returns, the phone replays queued operations against the **existing REST endpoints**.
- Offline scans **save the image on the phone and defer AI**; when the user reconnects, the queued
  image is run through the existing `analyze-card` → `createCapture` pipeline **on the client at
  sync time**. No raw-image-to-storage step, no new image endpoint.
- Backend changes are minimal: **idempotency keys** so a retried op can't duplicate data, plus a
  `/health` probe. No server-side image processing required.
- Background sync (sync while app is not foregrounded) uses **`workmanager`** on Android/iOS.
- A message bus (Redis/RabbitMQ) is only worth adding in a *later* phase if you want the
  **backend** to run AI enrichment on synced images asynchronously. Not needed for v1.

---

## 1. Current architecture (verified facts — do not re-investigate)

### Flutter app (`exono/`)
- Networking: all calls are static methods in `lib/services/api_service.dart` using `package:http`.
  Each method builds a `Uri`, calls `http.get/post/...`, checks status, throws on failure.
- Auth headers: `ApiService._headers({withAuth})` (line ~10).
- Relevant write methods that must become offline-capable:
  - `createContact(Map)` → `POST /contacts`
  - `createCapture({captureType, imageData, rawText, extractedData, eventId})` → `POST /captures`
    (`api_service.dart:887`)
  - `logInteraction({...})` → `POST /interactions`
  - `createEvent(Map)` → `POST /events`
  - `linkContactToEvent`, `updateContact`, `markFollowUpSent`, `skipFollowUp` (lower priority)
- AI-dependent (must be **skipped/deferred** offline):
  - `analyzeCard(b64)` → `POST /ai/analyze-card` (LiteLLM). Used by `capture_screen.dart`
    `_capturePhoto`, `_analyzeBytes`, `_pickFile`.
  - `transcribeAudio`, `assistantRespond`, enrichment, briefings, email drafts.
- Capture screen (`lib/screens/capture_screen.dart`): camera → `base64Encode(bytes)` → `analyzeCard`
  → `_applyExtracted` → user edits → `createCapture(captureType:'manual'|'card_scan', ...)`.
- Manual entry: `manual_entry_screen.dart` → `createCapture(captureType:'manual', extractedData:{...})`.
- Voice: `voice_contact_capture_screen.dart` → records audio → `transcribeAudio` (AI) → capture.
- DB libs already present in `pubspec.yaml`: `sqflite ^2.3.0`, `path_provider ^2.1.1`,
  `shared_preferences ^2.2.2`, `http ^1.2.0`, `dio ^5.4.0`. **No connectivity/workmanager yet.**
- Providers use `ChangeNotifier` (`lib/providers/`). App shell: `lib/screens/app_shell.dart`.
  Header: `lib/widgets/app_header.dart` (this is where the Offline/Syncing badge goes).
- UI rule (CLAUDE.md): use `App*` wrappers; the header badge should use `AppChip`.

### Backend (`backend/`)
- Express, routes in `backend/src/routes/`. Supabase as DB/storage.
- `POST /captures` (`captures.ts:48`): accepts `{ image, capture_type, event_id, extracted_data,
  raw_text }`. For `card_scan`/`file_scan` requires `image`; for `manual` requires
  `extracted_data.name`; for `voice` requires `raw_text`. It inserts a `captures` row
  (`image_url: image`), then tries to create a contact + company from `extracted_data`.
  **Note:** `image` is stored directly as `image_url` — confirm whether this is a URL or base64;
  offline images will be base64/binary and may need the upload route instead.
- `POST /upload` (`upload.ts:7`): `upload.single('file')` (multipart) → Supabase storage. Use this
  for raw offline image bytes.
- `POST /contacts` (`contacts.ts:99`), `POST /contacts/check-duplicate` (`contacts.ts:39`),
  `POST /interactions`, `POST /events`.
- `requireAuth` middleware is applied per-route (e.g. captures POST).

---

## 2. Data model — local SQLite (the outbox)

Create `exono/lib/services/offline/local_db.dart`. One sqflite database, e.g. `exono_offline.db`.

### Table `outbox` (the sync queue)
| column | type | notes |
|---|---|---|
| `id` | TEXT PK | client-generated UUID (use `uuid` pkg) — also the **idempotency key** |
| `op_type` | TEXT | `create_contact` \| `create_capture` \| `log_interaction` \| `create_event` \| ... |
| `payload` | TEXT (JSON) | the request body, minus any large blob (see `image_ref`) |
| `image_ref` | TEXT NULL | filename of the saved image in app docs dir (for scans) |
| `event_id` | TEXT NULL | denormalized for display |
| `status` | TEXT | `pending` \| `syncing` \| `done` \| `failed` |
| `attempts` | INTEGER | retry count |
| `last_error` | TEXT NULL | |
| `created_at` | INTEGER | epoch ms — preserves order; sync replays oldest-first |
| `server_id` | TEXT NULL | id returned by backend once synced (for de-dupe / linking) |

### Table `local_contacts` (optional but recommended)
A read-model so offline-created contacts appear in lists immediately. Mirror the fields the
`Contact` model needs. Flag `is_synced` and `pending_op_id`. When the outbox op syncs, update
`server_id` here. **Simplest v1:** skip this and have `getContacts()` merge outbox `create_contact`
payloads into the returned list (see §5).

### Images — AI extraction is DEFERRED to sync time (client-driven)
- Offline scans **save the image locally and skip AI**. Save the raw image bytes to
  `getApplicationDocumentsDirectory()/offline_images/<uuid>.jpg` and store the filename in
  `outbox.image_ref`. The `payload` for a `create_capture` op holds `captureType:'card_scan'`,
  the `eventId`, and any fields the user typed/QR provided (often empty — the AI hasn't run yet).
- **The image is the deferred unit of work.** When the user comes back online, the queued op is
  what runs `analyze-card` — i.e. the AI step that was skipped offline executes **on the client at
  sync time**, exactly as it would have run live. There is no separate "raw image upload to
  storage" step; the image goes through the normal scan pipeline, just later.
- On sync, a `create_capture` op with an `image_ref`:
  1. Read the image file from disk → base64.
  2. Call `ApiService.analyzeCard(b64)` (the same AI endpoint the live flow uses).
  3. Merge AI-extracted fields with any fields the user already entered offline (user-entered
     fields win on conflict).
  4. Call `createCapture(captureType, imageData: b64, extractedData: merged, eventId)` exactly as
     the online flow does (`api_service.dart:887`).
  5. On success, delete the local image file.
- This means **`analyze-card` must be reachable at sync time** — so don't run image ops while the
  reachability probe (§3.1) still says offline. If `analyze-card` fails (5xx/timeout) but the
  network is up, leave the op `pending` and retry with backoff; do not fall back to saving a
  capture with no extraction unless the user explicitly chooses to.
- **No `POST /upload` / no new backend image route is needed for this flow.** The existing
  `analyze-card` + `captures` endpoints already accept the image inline (base64), same as live
  scanning. (The earlier idea of uploading raw bytes to storage is dropped per the requirement:
  images are *processed* on reconnect, not just stored server-side.)

---

## 3. New services (Flutter)

### 3.1 `ConnectivityService` (`lib/services/offline/connectivity_service.dart`)
- Add dep `connectivity_plus`. Wrap it. Expose:
  - `bool get isOnline`
  - `Stream<bool> onStatusChange`
- **Important:** `connectivity_plus` reports *interface* (wifi/cellular) not *reachability*.
  Add a lightweight reachability check: on "connected", do a `HEAD`/cheap `GET` to the API base
  (e.g. a `/health` endpoint — add one to backend if missing) with a short timeout before
  declaring truly online. Debounce flapping.

### 3.2 `OfflineQueue` (`lib/services/offline/offline_queue.dart`)
- CRUD over the `outbox` table. Methods:
  - `Future<String> enqueue({required opType, required payload, Uint8List? imageBytes, eventId})`
    — generates UUID, saves image to disk if provided, inserts row `status:pending`.
  - `Future<List<OutboxOp>> pending()` (oldest-first).
  - `Future<void> markDone(id, serverId)`, `markFailed(id, error)`, `markSyncing(id)`.
  - `Future<int> pendingCount()` — drives the header badge count.
  - `Stream<int> pendingCountStream()` — or just notify via the provider.

### 3.3 `SyncService` (`lib/services/offline/sync_service.dart`)
- The replay engine. `Future<void> sync()`:
  1. If offline → return.
  2. Set global state `syncing`.
  3. For each pending op oldest-first:
     - `markSyncing`.
     - Build the real HTTP call based on `op_type` (reuse `ApiService` low-level helpers, but
       send the **idempotency key** = `outbox.id`, see §4).
     - For `create_capture` with `image_ref`: upload image first, then capture.
     - On 2xx → `markDone(serverId)`, delete image file.
     - On 4xx (validation/permanent) → `markFailed`, do **not** retry endlessly (cap attempts,
       surface to UI). On 409/idempotent-replay → treat as success.
     - On 5xx / network drop → leave `pending`, increment attempts, break and retry later
       (exponential backoff).
  4. Clear `syncing` state; refresh affected providers (contacts/events).
- Concurrency guard: a single `_isSyncing` flag so connectivity events + manual + background don't
  run `sync()` twice simultaneously.

### 3.4 `OfflineProvider` (`lib/providers/offline_provider.dart`) — `ChangeNotifier`
- Holds and exposes app-wide state for the UI:
  - `SyncState state` = enum `{ online, offline, syncing }`
  - `int pendingCount`
- Subscribes to `ConnectivityService.onStatusChange` and to queue changes.
- On transition offline→online: trigger `SyncService.sync()`.
- Register at app root (likely where other providers are wired, near `main.dart`/`app_shell.dart`).

---

## 4. Backend changes (small)

1. **Idempotency.** Accept a header `Idempotency-Key` (= the client outbox UUID) on
   `POST /captures`, `POST /contacts`, `POST /interactions`, `POST /events`.
   - Simplest correct approach: add a nullable unique column `client_op_id` (or
     `idempotency_key`) to the relevant tables. On insert, `ON CONFLICT (client_op_id) DO NOTHING`
     / upsert and return the existing row. This makes retries safe without an external store.
   - Apply via a Supabase migration (use the supabase MCP tools / a migration file).
2. **Health endpoint.** Add `GET /health` (no auth) returning `200 {ok:true}` for the
   reachability probe.
3. **No new image endpoint needed.** Offline scans are processed via the **existing**
   `analyze-card` + `captures` endpoints at sync time (the client runs the AI on reconnect — see
   §2). Do **not** add a raw-image-to-storage route; the requirement is that images are *processed*
   on reconnect, not just stored. Just verify the live flow's base64 path works unchanged when
   replayed from the queue.
4. **(Optional, future) Server-side deferred AI.** Only if you later want the *server* to run the
   extraction instead of the client (e.g. to offload battery/latency from the phone during a big
   batch sync): the client would POST the image and the backend would enqueue an `analyze-card`
   job. **That** is the only scenario where Redis/RabbitMQ (or a Postgres job table + pg_cron /
   Supabase Edge Function) would be justified. It is NOT part of this plan — v1 does AI extraction
   client-side at sync time.

---

## 5. Read path while offline

Lists must show offline-created records or the UX feels broken.
- `getContacts()` and event capture lists: catch network failure → return last-cached data
  **merged** with pending `create_contact` / `create_capture` payloads from the outbox, tagged so
  the UI can show a small "pending sync" marker.
- Cache last successful GET responses (contacts, events) in SQLite (`local_contacts`, `local_events`)
  so the app opens with data offline. Refresh-on-online.
- Reads that *require* AI or live data (assistant chat, enrichment, dashboard AI summaries) should
  show a clear "unavailable offline" state, not spin forever.

---

## 6. Capture/scan flow changes (the core UX)

In `capture_screen.dart`, `manual_entry_screen.dart`, `voice_contact_capture_screen.dart`:
- Branch on `OfflineProvider.state`:
  - **Online (unchanged):** camera → `analyzeCard` → edit → `createCapture`.
  - **Offline scan:** camera/upload → **skip `analyzeCard` for now** → save image bytes locally →
    show the manual edit form (empty/whatever QR gave; user can optionally type fields) → on save,
    `OfflineQueue.enqueue(op_type:'create_capture', payload:{captureType:'card_scan',
    extractedData:{...typed...}, eventId}, imageBytes: bytes)`. Toast: "Saved offline — the card
    will be analyzed when you're back online." The AI extraction runs later, at **sync time**, on
    the client (see §2 "Images — AI extraction is DEFERRED").
  - **Offline manual entry:** works fully — just enqueue `create_capture`/`create_contact`.
  - **Offline voice:** transcription is AI → either disable voice offline, or record + store the
    audio file and enqueue a `voice` capture to transcribe on sync (defer; v1 can disable voice
    offline with a clear message).
- All existing online write call sites should be routed through a single helper that decides
  "call API now" vs "enqueue" based on connectivity — so screens don't each duplicate the logic.
  Consider adding `ApiService.createContactSmart(...)` etc., or better: a thin
  `WriteGateway`/repository layer that wraps each write op. **Recommended:** introduce
  `lib/services/offline/write_gateway.dart` with one method per write op; screens call the gateway,
  the gateway calls `ApiService` (online) or `OfflineQueue.enqueue` (offline). Keep `ApiService`
  as the pure HTTP layer.

---

## 7. Frontend / UI work (STRICTLY follow CLAUDE.md + forUI rules)

> **Governing rule (CLAUDE.md "grow the wrappers, don't work around them"):** every new piece of
> UI here must use the `App*` wrappers in `lib/widgets/`. The first time a wrapper can't do
> something, **extend the wrapper** (add the param / make a new `App*` wrapper, update the wrapper
> table in CLAUDE.md), then use it from the screen. Never drop to raw forui/Material in a screen.
> Use `context.theme.colors.*` / `context.theme.typography.*` tokens — **never** hardcode colors or
> `fontSize`. **No emojis** anywhere. After touching any wrapper or screen, verify with
> `flutter analyze <file>` (analyze is the source of truth — do NOT re-read files to "confirm").

### 7.0 Verified current state (don't re-investigate)
- `AppHeader` (`lib/widgets/app_header.dart`) builds a `suffixChildren` list, then a
  `suffixRow` (`Row`, 8px gaps), and passes it to `FHeader.nested(suffixes: [suffixRow])`. It
  already reads a provider (`context.read<AuthProvider>()`). Insert the status badge as the FIRST
  entry in `suffixChildren` (left of the action button / profile).
- `AppChip` (`lib/widgets/app_chip.dart`) has `.tag` / `.label` / `.status(label, color:)`
  variants, all backed by `FBadge`. **It takes only a `String` label — no icon slot, no child,
  no spinner.** So it CANNOT render the offline cloud icon or the syncing spinner as-is.
- Providers are registered in `lib/main.dart:38` inside a `MultiProvider` (`ChangeNotifierProvider`
  entries for Auth/Conversation/Chat/LiveEvent). Add `OfflineProvider` here.

### 7.1 Wrapper change — add an icon/spinner-capable status badge
`AppChip` can't show an icon or spinner, so per the "grow the wrappers" rule, **extend the wrapper
set** (do NOT hand-roll a `Container`/`Row` badge in the header). Two acceptable options — pick one:

- **Option A (preferred): new `AppStatusBadge` wrapper** in `lib/widgets/app_status_badge.dart`,
  backed by `FBadge` (same as `AppChip`) so it inherits the existing badge styling. API:
  ```dart
  AppStatusBadge(
    label: 'OFFLINE',
    color: context.theme.colors.muted,          // bg
    textColor: context.theme.colors.mutedForeground,
    leading: Icon(Icons.cloud_off_rounded, size: 12, ...),   // optional icon
    spinner: false,                              // when true, leading = FCircularProgress()
  )
  ```
  Internally reuse the `FBadge` + `FBadgeStyleDelta` pattern from `AppChip` (filled rect,
  borderRadius 4, bold small-caps text), but build the `child` as a small `Row(mainAxisSize: min,
  [leading-or-spinner, SizedBox(width:4), Text(label)])`. The spinner is `FCircularProgress()`
  sized down (wrap in `SizedBox(width:12,height:12)`).
- **Option B: add `leading`/`spinner` params to `AppChip` itself** and build the same Row in its
  `child`. Acceptable, but `AppChip`'s three constructors make this messier — A is cleaner.

After adding/changing the wrapper: **update the wrapper table in CLAUDE.md** (add a "Status badge
(icon/spinner)" row) and run `flutter analyze lib/widgets/app_status_badge.dart`.

> Note on the spinner: CLAUDE.md says `FProgress` is indeterminate; for a tiny inline spinner use
> `FCircularProgress()` (allowed — it's the listed spinner replacement). Keep it small via
> `SizedBox`.

### 7.2 Header integration (`lib/widgets/app_header.dart`)
- Add `import 'package:provider/provider.dart';` is already present; add the offline provider import.
- `final offline = context.watch<OfflineProvider>();` (watch, so the badge rebuilds on state change).
- Prepend to `suffixChildren`:
  ```dart
  if (offline.state != SyncState.online || offline.pendingCount > 0)
    _buildStatusBadge(context, offline),
  ```
  where `_buildStatusBadge` returns:
  - `SyncState.offline` → `AppStatusBadge(label: 'OFFLINE', leading: Icon(Icons.cloud_off_rounded),
    color: context.theme.colors.muted, textColor: context.theme.colors.mutedForeground)`.
  - `SyncState.syncing` → `AppStatusBadge(label: 'SYNCING ${offline.pendingCount}', spinner: true,
    color: _c.accentGlow, textColor: _c.accent)` (brand accent has no forui token → `_c.*` is
    correct here per CLAUDE.md).
  - `SyncState.online && pendingCount > 0` (queued but not yet syncing) → optional
    `AppStatusBadge(label: 'PENDING ${pendingCount}', ...)`; or just show nothing and let sync kick
    in. Keep simple: show "PENDING N" only if you want it.
- The badge already sits inside the existing 8px-gap `suffixRow` logic — no layout changes needed.
- This makes the indicator appear on **every** screen that uses `AppHeader` (the requirement:
  "Offline Mode should be shown on the header").

### 7.3 Capture / scan screens (forUI-compliant)
Screens: `capture_screen.dart`, `manual_entry_screen.dart`, `voice_contact_capture_screen.dart`.
- Read connectivity via `context.read<OfflineProvider>()` (or `WriteGateway`, §6) — do not call
  `ConnectivityService` directly from widgets.
- Offline feedback strings go through `showAppToast(context, '...')` (CLAUDE.md: never
  `ScaffoldMessenger`). Example: `showAppToast(context, 'Saved offline - will sync when online')`.
  **No emojis, no special unicode** — plain ASCII.
- Any new buttons (e.g. "Save offline", "Retry") use `AppButton` with `onPressed:` and the right
  `variant:` (primary/secondary/ghost). Never raw `FButton`/`ElevatedButton`.
- Any new card surface (e.g. a "Saved offline" confirmation card) uses `AppCard`. Avatars stay
  `AppAvatar`. Inputs stay `AppInput`. Section labels `AppSectionLabel`.
- If a scan/capture screen needs to disable the AI-dependent affordance offline (e.g. voice in v1),
  show an `AppCard`/inline note using `context.theme.typography.sm.copyWith(color:
  context.theme.colors.mutedForeground)` — no hardcoded `TextStyle(fontSize:...)`.

### 7.4 "Sync issues" / pending list screen (optional but recommended)
A small screen listing `outbox` rows with `status: failed` (or all pending), each as an `AppCard`
with a `Retry` (`AppButton variant: secondary`) and `Discard` (`AppButton variant: destructive`,
guarded by `showAppConfirmDialog`). Use `AppHeader(onBack: ...)`, `FScaffold` or the
`ColoredBox + Column` shell per CLAUDE.md scaffold rules. Empty state via the existing
`empty_state.dart` widget. Reachable from settings or by tapping the header badge.

### 7.5 List screens — pending markers (`contacts_screen.dart`, event captures)
- When a contact/capture came from an unsynced outbox op, show a small `AppChip.status('PENDING',
  color: _c.accent)` (or `AppStatusBadge`) on its row/card. Source this from the merged read path
  (§5). Keep it a wrapper, not a hand-rolled badge.

### 7.6 Provider wiring (`lib/main.dart`)
Add to the `MultiProvider` list (line ~44):
```dart
ChangeNotifierProvider(create: (_) => OfflineProvider()..initialize()),
```
`initialize()` starts the connectivity subscription and computes the initial `pendingCount`.
On mobile only it also wires the connectivity-regain → `SyncService.sync()` trigger. Guard the
whole offline subsystem behind `if (!kIsWeb)` so web behaves exactly as today.

### 7.7 forUI compliance checklist (run mentally before `flutter analyze`)
- [ ] No `Container`+`BoxDecoration` used as a badge/card → `AppStatusBadge`/`AppChip`/`AppCard`.
- [ ] No `ScaffoldMessenger`/`showSnackBar` → `showAppToast`.
- [ ] No raw `FButton`/Material buttons in screens → `AppButton`.
- [ ] No hardcoded `Color(...)` / `fontSize:` → `context.theme.colors.*` / `.typography.*`
      (brand-only colors with no token: `_c.accent`, `_c.accentGlow`, `_c.success`, `_c.destructive`).
- [ ] No emojis in any string.
- [ ] Wrapper table in CLAUDE.md updated for `AppStatusBadge`.
- [ ] `flutter analyze` clean on every touched wrapper + screen.

---

## 8. Background sync (app not foregrounded)

- Add dep `workmanager`.
- Register a periodic task (Android min interval 15 min) and a one-off task triggered on
  connectivity regain.
- The background isolate must: open SQLite, instantiate `SyncService`, run `sync()`. Because it's a
  separate isolate, it needs its own DB + http instances and the **auth token** (read from
  `shared_preferences`/secure storage — confirm where the token lives in `auth_service.dart`).
- iOS background execution is best-effort (BGTaskScheduler); document that iOS may delay sync until
  the OS schedules it. Foreground sync on app-resume + on connectivity regain is the reliable path;
  background is a bonus.
- **Guard:** background sync only registered on mobile, never web.

---

## 9. Dependencies to add (`exono/pubspec.yaml`)
```
connectivity_plus: ^6.x
workmanager: ^0.5.x      # verify latest compatible
uuid: ^4.x
# already present: sqflite, path_provider, shared_preferences, http, dio
```
Run `flutter pub get`. Add Android permissions (`ACCESS_NETWORK_STATE`) and iOS background modes
(`fetch`, `processing`) as the packages' READMEs require.

---

## 10. Edge cases & rules
- **Idempotency is mandatory** — a sync can be interrupted after the server committed but before
  the client recorded success. The `client_op_id` unique constraint (§4.1) prevents duplicates.
- **Ordering:** replay oldest-first. If op B (link contact to event) depends on op A (create
  contact) whose `server_id` isn't known yet, resolve A first and substitute the returned id into
  B's payload before sending. v1 can avoid this by only queueing self-contained ops (create
  contact/capture). Defer dependent-op chains.
- **Backoff:** exponential with cap; mark `failed` after N attempts and surface in a "Sync issues"
  list the user can retry/delete.
- **Storage cleanup:** delete the local image file after the capture syncs.
- **Auth expiry offline:** token may expire while offline. On sync, a 401 should trigger
  refresh/re-login, not mark ops failed. Keep ops `pending` through a re-auth.
- **Conflict on contact duplicates:** backend already has `/contacts/check-duplicate`; on sync,
  decide merge vs create (v1: just create; dedupe later).

---

## 11. Suggested build order (phased)
1. **Foundation + indicator (frontend):** add deps; `local_db.dart` + `outbox` table;
   `ConnectivityService`; `OfflineProvider` wired in `main.dart` (§7.6). **Wrapper work:** add
   `AppStatusBadge` (§7.1) and update the CLAUDE.md wrapper table. Integrate into `AppHeader`
   (§7.2) for online/offline only (no sync yet). Verify the badge flips on airplane mode and
   `flutter analyze` is clean on the wrapper + header.
2. **Outbox + manual writes:** `OfflineQueue`, `WriteGateway` (§6); route `create_contact` /
   manual `create_capture` through it; capture/manual screens use `showAppToast` + `AppButton`
   (§7.3); `SyncService` replay; backend idempotency + `/health`; add `syncing` state to the badge.
   Test: airplane mode → manual add → online → syncs once, no dupes.
3. **Offline scans:** local image save; skip AI offline; on sync run `analyzeCard(image)` →
   merge with user-entered fields → `createCapture(image, extractedData)`. AI extraction is
   deferred to sync time, client-side. Offline "saved" UI via `AppCard`/`showAppToast` (§7.3).
4. **Read path + pending markers (frontend):** cache contacts/events; merge pending into lists
   (§5); show `AppChip.status('PENDING', ...)`/`AppStatusBadge` on unsynced rows (§7.5); optional
   "Sync issues" screen (§7.4). `flutter analyze` each touched screen.
5. **Background sync:** `workmanager` foreground-resume + connectivity-triggered, then periodic.
6. **(Optional, future):** move AI extraction server-side (only if offloading from the phone
   becomes desirable) — a job queue (Postgres job table + pg_cron / Edge Function, or
   Redis/RabbitMQ if volume justifies it). Not part of v1; v1 extracts client-side at sync time.

---

## 12. Verification
- Flutter: `flutter analyze <changed files>` after each file (per CLAUDE.md — analyze is the source
  of truth; do not re-read whole files to verify).
- Manual: Android device + airplane mode for the full offline→online→sync round trip.
- Idempotency: kill the app mid-sync, relaunch, confirm no duplicate rows server-side.
