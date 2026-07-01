# Exono CRM — Complete Infrastructure Cost Breakdown

**Method:** Every service below was identified by reading the code, not assumed. Sources:
`backend/package.json`, `exono/pubspec.yaml`, `backend/vercel.json`, `codemagic.yaml`,
`Dockerfile.slayer`, `exono/firebase.json`, `.env.example`, and the route/service files.
All pricing is from official vendor pages (June 2026).

**On assumptions:** vendor pricing and the code-derived facts (which services exist, how many channels per
user, which call paths hit which API) are **exact**. The *usage magnitudes* (card size, tokens per call, MB
egress, peak users, etc.) are **not** — they can't be read from code. Every such number is flagged inline with
a **⚠️ ASSUMED … NOT measured** callout that says exactly how to instrument or query for the real value. **Treat
no assumed number as final** — they're placeholders to be replaced by experiment. Section 0 collects them.

---

## 0. Measurement plan — pre-launch (no public traffic yet)

> **Context: the app is NOT rolled out.** There is no production traffic, no user base, and no seed/load
> harness in the repo (`scripts/` has only maintenance scripts; no faker/seed). So the "read it off the
> dashboard ÷ active users" advice does **not** apply yet — there's nothing to read and no users to divide by.
> Split the unknowns into two kinds and handle each differently:

**Kind A — PER-UNIT costs (the bytes/tokens/RAM of ONE action).** These do **not** need real users or scale.
You can measure them **today** with a single device + a handful of records you create by hand. **Measure these now —
they turn the formula constants from guesses into facts.**

| # | Per-unit unknown | How to get it **pre-launch** | §ref |
|---|---|---|---|
| 1 | **Avg card image size** | Run the backend locally (`npm run dev`), scan **10–20 real business cards** from the app, log `buffer.length` at upload, average | §2.1a |
| 2 | **Bytes per DB row** | After creating ~20 contacts+captures+enrichments by hand, run `pg_total_relation_size('contacts')` ÷ row count per heavy table | §2.1c |
| 3 | **Gemini tokens per call path** | Log `response.usageMetadata` and do **one** of each: scan a card, transcribe a clip, enrich a contact/company, send 1 assistant message. Records exact tokens per action | §2.2 |
| 4 | **Exa searches per enrichment** | Already exact from code (contact=2, company=2, event=1–2); per-search cost verified live against the production account — highlights/text add $0, only `summary` (unused here) is billed extra | §2.3 |
| 5 | **Slayer + backend RAM/CPU** | `docker compose up` both locally, fire a burst of scans + assistant queries, watch `docker stats` peak | §7.0 |
| 6 | **Current Railway bill** | Read the invoice/Usage tab (Slayer is already deployed there) | §7.1 |

**Kind B — VOLUME / behaviour (how many actions, how many concurrent users).** These are **unknowable before
launch** — no amount of local testing produces them. Do **NOT** invent a single number. Instead:

1. **Model by business scenario, not by guess.** Pick the inputs from your *go-to-market plan*, not from thin air:
   *"We onboard N exhibition teams of T reps; a rep scans ~C cards per show day over D show days."* That makes
   `cards/mo = N×T×C×D` a **decision you own**, not an assumption I fabricated. State the scenario explicitly.
2. **Compute a range, not a point.** Plug a **conservative / expected / aggressive** scenario into the §2 formulas
   (using the Kind-A measured per-unit costs) to get a low–mid–high monthly cost band. That band is the honest answer.
3. **Re-measure after a pilot.** The first real exhibition (even one team, one show) gives true volume + the
   realtime peak. *Then* the dashboard reads (Supabase → Reports → Bandwidth / Realtime) become valid — they are
   **post-pilot** steps, not pre-launch ones.

> **Bottom line:** measure Kind A locally now; for Kind B, **don't guess — model named scenarios** and carry a
> range until a pilot produces real numbers. Every assumed value in this doc is a Kind-B placeholder unless its
> callout says it's been measured.

### Two measurement methods per parameter — **PLAN-A** and **PLAN-B**

Every variable in this doc can be pinned down by one of two methods. Each parameter section below names which
applies. Pick **PLAN-A wherever it exists** (it gives a real number today, no users needed); fall back to
**PLAN-B** only for the genuinely volume-driven ones that can't be known until traffic exists.

| | **PLAN-A — measure pre-launch (now)** | **PLAN-B — measure post-pilot (from live data)** |
|---|---|---|
| **What it is** | Instrument the code / run a DB query / read a resource gauge on **one device with hand-made records**. | Read the real figure off the vendor **dashboard** (or invoice) after the first pilot/show, ÷ active users. |
| **When usable** | **Today** — no traffic, no users required. | **Only after** real usage exists (one pilot team is enough). |
| **Applies to** | All **per-unit** (Kind-A) costs: bytes/row, MB/card, tokens/call, RAM/CPU held, bundle size, route CPU-time. | All **volume/behaviour** (Kind-B) costs: MAU, cards/user/mo, peak concurrent users, sessions/mo, egress/user. |
| **Output** | A **fact** — replaces a formula constant for good. | A **fact** — but only valid once measured; until then, **model a named scenario** as a range (do NOT guess a point). |
| **Cost of being wrong** | None — re-run the measurement. | Carry conservative/expected/aggressive range until PLAN-B data lands. |

Read each parameter's **PLAN-A** / **PLAN-B** line as: "this is *exactly* how you measure this specific number."
If a parameter lists only PLAN-A, it is fully measurable now. If it lists only PLAN-B, it is unknowable
pre-launch and must be modeled until a pilot. Most list both: PLAN-A gives the per-unit constant now, PLAN-B
gives the volume later, and the formula multiplies the two.

---

## 1. Architecture map (what the code actually runs)

| Layer | Component | Evidence in code |
|---|---|---|
| Mobile/web client | Flutter app | `exono/pubspec.yaml` |
| Backend API | Express on **Vercel** | `backend/vercel.json` (`@vercel/node`); client points at `https://exhibitioncrm.vercel.app/api` (`exono/lib/config/api_config.dart:5`) |
| Database + Auth + Storage + Realtime | **Supabase** | `@supabase/supabase-js`, `supabase_flutter`; realtime is a **single per-user Broadcast channel** (`sync_provider.dart:158-177`) + a per-conversation chat channel (`chat_provider.dart:306-308`) — see §2.1d |
| Read-only NL→SQL service | **Slayer** (Python) on **Railway** | `Dockerfile.slayer` (`SLAYER_READONLY_PASSWORD must be set as a Railway env var`); backend calls `SLAYER_URL/query` (`slayer-client.ts:154`) |
| LLM (text + multimodal) | **Google Gemini** `gemini-3.1-flash-lite` via **`@google/genai`** SDK | `litellm-service.ts:128`, `config/ai.ts` |
| LLM (embeddings) | **Google Gemini** `gemini-embedding-001` @ 768 dims | `litellm-service.ts:499-523` — used for the oversized-document RAG fallback |
| Web search | **Exa** `https://api.exa.ai/search` | `exa-service.ts:51,146`. `searchDepth` maps to Exa `type` (`basic`→`fast`, `advanced`→`auto`); every call requests `contents:{highlights:true}` |
| OCR | **Tesseract.js** (in-process, no API) | `analyzeCard.ts` / route OCR path |
| Web hosting | **Firebase Hosting** | `exono/firebase.json` |
| Analytics | **Firebase Analytics** | `analytics_service.dart:18` |
| Crash reporting + replay | **Sentry** | `main.dart:85-99`, tracesSampleRate `0.0` (no perf) but **replay sampleRate `1.0`** (every session billable) |
| Session replay | **UXCam** | `analytics_service.dart:16,22-32` — key read from `--dart-define=UXCAM_APP_KEY`; active whenever a key is supplied at build (schematic gesture/screen recordings enabled) |
| iOS CI builds | **Codemagic** (mac_mini_m2) | `codemagic.yaml` |

**Not present (confirmed absent):** no Redis, no queue (SQS/RabbitMQ), no dedicated email
provider (auth emails ride on Supabase Auth's built-in SMTP), no push notifications (no
`firebase_messaging`/FCM), no payment gateway (no Stripe), no separate CDN/object store
beyond Supabase Storage + Firebase Hosting, no Vercel KV/Blob, no monitoring/logging SaaS,
no dedicated vector DB (RAG uses **pgvector inside Supabase Postgres** — `document_chunks`
table queried via the `match_document_chunks` RPC, `assistant/tools/executors/documents.ts:40`).
`openai` SDK is present but **dormant** — Gemini is the active provider whenever
`GEMINI_API_KEY` is set (`config/ai.ts`); OpenAI only runs if it is unset.
Web search runs through `exa-service.ts` (Exa).

---

## 2. Per-service cost breakdown

### 2.1 Supabase (Database + Auth + Storage + Realtime) — fixed + usage
**Why:** Primary datastore (~30+ tables, `SUPABASE_SCHEMA.md`), user auth (MAU), private Storage
buckets (`contact-cards`, `chat-attachments` — `captures.ts:18`, `conversations.ts:285`), and
Realtime for chat/sync/live-events.

- **Plan:** Pro **$25/mo fixed** (needed for >500 realtime connections + production).
- **Included:** 8 GB DB, 100 GB storage, 250 GB bandwidth, 100K MAU, **500 concurrent realtime peak connections**, 5M realtime messages.
- **Overage units:** Bandwidth **$0.09/GB** · DB storage **$0.125/GB** · File storage **$0.021/GB** · Auth **$0.00325/MAU** beyond 100K · **Realtime peak connections $10 per additional 1,000** · Realtime messages $2.50/M.
- **Cost variables:** MAU, egress, stored card images + chat attachments (the two live storage drivers — `contact_documents` is a dead route, see §2.1a), DB size (incl. `document_chunks` vectors), **concurrent (peak) realtime connections**.
- **Headline formula (monthly):**
  `25 + max(MAU-100000,0)*0.00325 + max(GB_egress-250,0)*0.09 + max(GB_db-8,0)*0.125 + max(GB_files-100,0)*0.021 + realtime_overage`
- Pricing: https://supabase.com/pricing

The three storage/egress/db terms and realtime are **not free variables** — the code fixes their
relationship to MAU. Estimates below.

#### 2.1a `GB_files` — Storage
**Two** buckets are written by a live client path; a third path exists in the backend but has **no caller
in the Flutter app**, so it does not currently add storage:

| Bucket / table | Content | Max upload size (code-enforced) | Live? |
|---|---|---|---|
| `contact-cards` (private) | The scanned business-card photo, uploaded once per capture as `{userId}/{captureId}.{ext}` (`captures.ts`, `uploadCardImage`) — the primary storage driver. **Re-encoded server-side before storage** (see compression note below). | **5 MB hard cap (pre-compression)** — `MAX_IMAGE_BYTES` in `backend/src/utils/imageValidation.ts:12`; JPEG/PNG/WebP only (magic-byte sniffed, not by client mime) | **Yes** |
| `chat-attachments` (private) | AI-chat file attachments (images + documents) uploaded from the composer. The Flutter app uses `file_picker: ^8.0.0` (`pubspec.yaml:66`) and `chat_provider.dart` carries optimistic attachments through the send path (`chat_provider.dart:16,356-424`, `ChatAttachment` model); the backend receives uploads at `POST /conversations/:id/attachments/upload` (`conversations.ts:191-266`). **Image attachments are re-encoded server-side before storage; non-image documents (PDF/xlsx/docx/etc.) pass through untouched** — see compression note below. | **15 MB hard cap — PER FILE, not cumulative (pre-compression for images).** `limits.fileSize` in `backend/src/routes/conversations.ts:31`, enforced via `upload.single('file')` (`:256`) — the route accepts exactly one file per request, so 15 MB is the ceiling on each individual attachment. A message with multiple attachments sends multiple requests, each independently capped at 15 MB; there is no per-message or per-conversation total cap in code. | **Yes** |
| `contact_documents` (DB table, no dedicated storage bucket) | `POST /documents` (`backend/src/routes/documents.ts:18`) only inserts a row referencing a **client-supplied `file_url` string** — it does not accept a file body, run multer, or write to any storage bucket itself. **No Flutter screen/service calls this endpoint** (confirmed: no reference to `/documents` or `contact_documents` anywhere under `exono/lib`). | n/a — no upload path exists to cap | **No — dead route.** Adds $0 storage today. If a client uploader is ever built, it would presumably reuse `document-extraction.ts`'s **15 MB cap** (`MAX_DOC_BYTES`, `backend/src/services/document-extraction.ts:29`), since that's the size limit already enforced on the adjacent chat-attachment parsing path — but that is a guess about a future implementation, not a measured fact. |

> **Storage compression (implemented) — `backend/src/utils/imageCompression.ts`.** Both image upload paths
> (`captures.ts:uploadCardImage` and the image branch of `conversations.ts`'s attachment upload route) now
> re-encode the validated buffer with `sharp` before it reaches Storage: resize to a max **2000px** long edge
> (`fit: 'inside', withoutEnlargement`, so already-small images are never upscaled), strip EXIF, and re-encode as
> **WebP @ quality 80** (`webp()`). The stored `type`/`mime_type`/`path` extension all reflect the re-encoded
> WebP output, not the original upload format. Type detection for both Storage and the document-extraction
> pipeline is by **sniffed magic bytes** (`sniffImage`), so this is safe to apply before `extractDocument` runs —
> vision/OCR still sees a valid, slightly smaller image. Documents (PDF/xlsx/docx/pptx) are **not** touched —
> `sniffImage` returns null for them and they fall through to the original buffer unchanged, since those formats
> are already compressed and re-encoding them would do nothing (or be lossy for no benefit). Both call sites are
> **best-effort**: a `sharp` failure logs and falls back to storing the original validated buffer rather than
> failing the upload. Net effect: phone-camera card photos (commonly 3000–4000px @ q90+) and chat image
> attachments now typically land at **~150–400 KB** post-compression instead of multi-MB pre-compression sizes —
> roughly a **60–80% reduction** for images. This directly lowers `avg_card_MB` and the image share of
> `avg_attachment_MB` below; **re-run the PLAN-A measurement now** (logging is unaffected, the measured value
> will simply come out smaller) rather than relying on the pre-compression assumption still in the callouts below.

> **Oversized-document RAG (pgvector) — applies to `chat-attachments`, not `contact_documents`.** When a chat
> attachment is too large to inline, it is **chunked and embedded** at upload (`conversations.ts:322-346`,
> `chunkText` + `litellm.embed`) and the vectors stored in `document_chunks (embedding vector(768))`. Read-time
> queries embed the question and call `match_document_chunks`. This adds **(a)** Gemini *embedding* token spend
> (§2.2), **(b)** a little DB storage for the vectors, and **(c)** image/office documents that go to the
> **vision/parse path** (`document-extraction.ts`) — small docs inline (no embedding), big docs chunk+embed.

There is **no separate avatar upload** — the contact `avatar_url` (`contact.dart:16`) points at the
**same stored card image** (or an external URL from enrichment), so avatars do **not** add storage.

Card images are captured via the camera and sent as base64; gallery picks use `imageQuality: 80–85`
(`contact_detail_screen.dart:266`, `contact_links_files_sheet.dart:269`).

> **`avg_card_MB` (per-unit) — ⚠️ ASSUMED ~0.1–0.15 MB/card POST-COMPRESSION (was ~0.3 MB pre-compression), NOT
> measured; hard ceiling 5 MB pre-compression (the cap is checked before re-encoding, in `decodeAndValidateImage`).**
> - **PLAN-A (now):** add a log right after the `compressImage()` call in `captures.ts` (`uploadCardImage`) —
>   `console.log(`[card-size] ${type.mime} ${(buffer.length/1024).toFixed(1)} KB`)` — then scan **10–20 real
>   business cards** through the app against a local backend and average the logged KB. True `avg_card_MB`, no
>   users needed. **Must be re-measured now that compression is live** — the old assumption was for the
>   uncompressed upload and is stale.
> - **PLAN-B (post-pilot):** Supabase → Storage → `contact-cards` bucket total bytes ÷ object count.
> - The **5 MB `MAX_IMAGE_BYTES` cap is exact from code**, not assumed — it's the absolute pre-compression
>   per-card ceiling; the stored size after `compressImage()` (2000px max dimension, WebP q80) is materially
>   smaller and capped independently by the resize/re-encode, not by `MAX_IMAGE_BYTES`.

> **`avg_attachment_MB` (per-unit) — ⚠️ ASSUMED, NOT measured at all (no log point exists yet); hard ceiling 15 MB
> pre-compression. Image attachments now go through the same `compressImage()` re-encode as card images; document
> attachments (PDF/xlsx/docx/pptx) are unaffected and keep their original size.**
> - **PLAN-A (now):** add a `buffer.length` log right after the `compressImage()` branch in
>   `conversations.ts` (logging `uploadBuffer.length` for both the image and pass-through document cases), then
>   attach **5–10 real files** (a mix of images and documents) through the chat composer locally and average the
>   logged size **per kind** (image vs. document) — they now have very different size profiles post-compression.
> - **PLAN-B (post-pilot):** Supabase → Storage → `chat-attachments` bucket total bytes ÷ object count (mixed;
>   for a kind-split figure, join `message_attachments.mime_type` against stored size).
> - The **15 MB multer `fileSize` cap is exact from code** and still applies pre-compression to both kinds.
>   Documents remain the larger driver of `avg_attachment_MB` — PDF/xlsx/docx routinely run several MB and are
>   NOT compressed by this change; only the image-attachment share shrinks ~60–80%.

> **`cards_per_user_per_mo` / `attachments_per_user_per_mo` (volume):**
> - **PLAN-A:** *not available* — cannot be measured pre-launch.
> - **PLAN-B (post-pilot):** `total cards created last 30d ÷ active users` from `captures`; `total attachments
>   last 30d ÷ active users` from `message_attachments`. Until then, **model both** from go-to-market (cards per
>   rep per show day × show days; attachments are rarer — model as a small fraction of assistant messages/mo).

- **Driver:** total cards scanned + total attachments sent (cumulative, storage never shrinks), not MAU directly.
  `contact_documents` contributes **$0** — it is unused by the client.
- **Relation to MAU (cumulative over `M` months of operation):**
  `GB_files ≈ MAU × M_months × (cards_per_user_per_mo × avg_card_MB + attachments_per_user_per_mo × avg_attachment_MB) / 1024`
- **Worked with assumed inputs (POST-COMPRESSION) — 1,000 MAU, 12 months, cards 0.12 MB×40/mo, attachments
  2 MB×2/mo (attachments figure still a pre-compression document-heavy guess pending PLAN-A; image attachments
  would be far smaller post-compression but documents dominate this term):**
  `1000 × 12 × (40×0.12 + 2×2) / 1024 = 1000 × 12 × 8.8 / 1024 ≈ 103 GB` → just over the 100 GB included →
  `(103-100)×0.021 ≈ $0.06/mo`. For comparison, the pre-compression figure was `≈188 GB ≈ $1.85/mo` — compression
  drops the worked-example bill by roughly **30x** at this volume, almost entirely from the card-image term
  (cards alone: `~56 GB`, under the included 100 GB, i.e. **$0** vs. the pre-compression `~141 GB ≈ $0.86/mo`).
  Storage was already cheap before this change and is now closer to negligible until attachment volume grows.
  **Recompute once `avg_card_MB`, `avg_attachment_MB`, and both per-user-per-mo volumes are re-measured
  post-compression** — both per-unit assumptions above are still illustrative, not logged.

#### 2.1b `GB_egress` — Bandwidth
Egress is dominated by **(1)** clients downloading card images (signed URLs, 1-hr TTL —
`captures.ts`/`contacts.ts:543`), **(2)** clients downloading chat attachments they previously sent or
received (same signed-URL pattern, `chat-attachments` bucket — see §2.1a), **(3)** the initial drift
`catchUpAll()` sync that pulls every row on login/resume (`sync_provider.dart:71`), and **(4)** realtime row
payloads. `contact_documents` downloads contribute **$0** — per §2.1a, no client path uploads to that table, so
there is nothing stored there to download. The local-first drift DB means steady-state browsing is *not*
re-downloading data, so egress is front-loaded at sync + image/attachment views.

- **Estimate per active user/mo:** initial + delta sync of ~10 tables (a few MB of rows) + viewing card
  images and chat attachments (each viewed file ≈ its stored size, possibly re-fetched after the 1-hr signed
  URL expires) + realtime deltas.

> ⚠️ **ASSUMED: ~100 MB/active user/mo (range 50–150 MB) — Kind-B volume.**
> - **PLAN-A (now, bottom-up from per-unit parts):** measure the components locally on one device with the
>   browser/dio network inspector — `initial_sync_payload` (one fresh login's `catchUpAll`), `avg_card_MB` and
>   `avg_attachment_MB` (both from §2.1a), and a realtime delta — then compose
>   `egress/user ≈ initial_sync_payload + (cards_viewed × avg_card_MB) + (attachments_viewed × avg_attachment_MB) + realtime_deltas`.
>   The *per-unit* components are PLAN-A measurable; only the `_viewed/mo` volumes are Kind-B.
> - **PLAN-B (post-pilot):** read the true figure from **Supabase → Reports → Bandwidth ÷ active users**.
>
> Until a pilot, carry this as a PLAN-A-composed modeled range, not a fact.

- **Relation to MAU (assumed input):** `GB_egress ≈ MAU × 0.1 GB/mo` (× a re-view multiplier if users browse card images heavily).
- **Worked with assumed 100 MB — 1,000 MAU →** `~100 GB/mo` → under the 250 GB included → **$0**. At **3,000 MAU** → ~300 GB → `(300-250)×0.09 ≈ $4.50/mo`. **Replace the 0.1 GB/mo with the dashboard figure.**

#### 2.1c `GB_db` — Database size
~30 tables; the row-heavy ones are `contacts`, `captures`, `interactions`, `follow_ups`, `contact_events`,
`email_drafts`, `messages` (chat). A contact + its capture + a few interactions/follow-ups is on the order
of **a few KB of row data + indexes**; enrichment text and chat messages add more.

> ⚠️ **Two different unknowns here — each has its own measurement plan:**
> - **`bytes_per_contact` (~5 KB), per-unit:**
>   - **PLAN-A (now):** create ~20 contacts + their captures/enrichments by hand in a local/staging DB, then
>     `SELECT pg_total_relation_size('contacts') / count(*) FROM contacts;` (repeat per heavy table). True bytes/row
>     incl. indexes & TOAST — no real users required.
>   - **PLAN-B (post-pilot):** same query against the live DB once it holds real rows.
> - **`contacts_per_user_per_mo` (~40), volume:**
>   - **PLAN-A:** *not available* pre-launch.
>   - **PLAN-B (post-pilot):** `SELECT count(*)::float / count(DISTINCT user_id) FROM contacts WHERE created_at > now()-interval '30 days';`. Until then, **model** it from the launch scenario as a range.

- **Relation to MAU (cumulative, assumed inputs):** `GB_db ≈ MAU × contacts_per_user_per_mo × bytes_per_contact × M_months / 1e9`
- **Worked with assumed 5 KB & 40/mo — 1,000 MAU, 12 months:** `1000 × 40 × 5 KB × 12 / 1e6 ≈ 2.4 GB` → **under 8 GB included → $0**. The DB likely stays free until ~**3,000+ MAU sustained for a year** — **confirm with the two queries above.**

#### 2.1d Realtime — peak **concurrent** connections (cap 500)
The sync layer uses a **single private Broadcast channel per user** as a wake-up signal, not one
`postgres_changes` channel per table. A DB trigger (`broadcast_sync_change()`) emits a per-user "table changed"
poke; on any poke the client runs the existing debounced `catchUpAll()` delta-sync over HTTP — **Realtime is
only a wake-up signal, not the data path** (`sync_provider.dart:154-186`). The code opens, per logged-in user:

| When | Channels opened | Source |
|---|---|---|
| **Always, while the app is foregrounded** | **1** — a single private Broadcast channel `sync:user={userId}` | `sync_provider.dart:158-177` (`_subscribeSyncBroadcast`) |
| Chat screen open | **+1** (`messages:{conversationId}`) | `chat_provider.dart:306-308` |
| During a **live event** | **+0** — live mode reuses the same broadcast via `onSyncPoke`; no per-table channels | `live_event_provider.dart:46-47` (comment: *"no per-table postgres_changes channels needed here"*) |

So a single active user holds **1 concurrent connection** baseline, **2** with a chat screen open, and **still
1–2** during a live event.

The **per-user channel counts (1 / +1 / +0) are MEASURED from code, not assumed.** What's assumed is the
**human behaviour**: how many users are foregrounded at once, and what fraction have a chat screen open.

> ⚠️ **ASSUMED: peak concurrent users and the chat fraction — Kind-B volume.** The connections-per-user
> multiplier (1–2) is **code-derived and exact** (no measurement needed); only the *simultaneous user count* and
> *chat fraction* are unknown.
> - **`peak_concurrent_users` & `fraction_in_chat`:**
>   - **PLAN-A:** *not available* — simultaneity cannot exist pre-launch. (You *can* PLAN-A confirm the 1–2 conns/user multiplier by opening the app + a chat screen on one device and watching **Supabase → Reports → Realtime** tick to 1 then 2.)
>   - **PLAN-B (post-pilot):** read the true peak off **Supabase → Reports → Realtime** during a real show day; derive `fraction_in_chat` from concurrent `messages:{id}` channels ÷ total connections. Until then, **model** from the launch plan (*"one team of T reps all live on the floor"* → peak ≈ T, +1 per chat-open user).

- **Concurrent connections ≈ (peak simultaneously-active users) × (1 + fraction_in_chat)** — i.e. roughly **1 per user**, up to ~2 for the fraction with a chat open. Live mode adds nothing.
- **The 500 included connections are exhausted at ~250–500 simultaneously-active users** (500 ÷ ~1–2), a **code-derived** figure, comfortably in line with the MAU at which other Supabase resources start to cost money.
- **Overage:** Supabase Pro bills **$10 per additional 1,000 peak connections**.
- **Realtime formula:**
  `peak_connections ≈ peak_concurrent_users × (1 + 1·fraction_in_chat)`
  `realtime_overage = max(peak_connections − 500, 0) / 1000 × 10`
- **Worked: 400 concurrent users, 25% with chat open →** `400 × (1 + 0.25) = 500` peak connections → **$0** (right at the included cap). At **2,000 concurrent users, 25% in chat** → `2,500` → `(2500-500)/1000 × 10 = $20/mo`.

> **Bottom line on Supabase relations:** with the single-broadcast-channel architecture, **realtime is not the
> first cost ceiling.** Storage, DB, and egress stay inside the free Pro allotments into the low-thousands of MAU,
> and realtime scales to roughly that same range on the included 500 connections.

### 2.2 Google Gemini API (`gemini-3.1-flash-lite` + `gemini-embedding-001`) — usage (tokens)
**Why:** Gemini is invoked on **six** distinct paths in code (via the `@google/genai` SDK):

1. **Business-card extraction** — 1 call per scanned card (`analyzeCard.ts:10`).
2. **Voice transcription** — 1 multimodal call (audio→text) per non-silent recording
   (`litellm-service.ts:transcribeAudio`, model hard-coded `gemini-3.1-flash-lite`). Called from
   `ai.ts:156` and `captures.ts:59`, **gated by a server-side silence check** (`ai.ts:113-152`)
   so silent clips cost nothing.
3. **Contact enrichment** — Exa search **then** `AIService.generateCompletion(...)` to structure
   the result (`contacts.ts:798`). **1 Gemini call per enrichment.**
4. **Company / event enrichment + talking points + prep** — Exa **then** `llm.generateCompletion(...)`
   (`companies.ts`, `events.ts`). **1+ Gemini call per enrichment/generation.**
5. **AI assistant agentic loop** — tools dispatched in `assistant/tools/dispatcher.ts` (`query_crm`,
   `web_search`, `describe_model`, `parse_document`, write tools). **N Gemini calls per user message**
   (one per tool step; typically 2–5).
6. **Document embeddings** — `gemini-embedding-001` @ 768 dims, called on the oversized-document
   RAG path: every chunk embedded at upload, plus 1 embed per retrieval query (`litellm-service.ts:507-523`,
   `conversations.ts:340`). Multimodal **card/audio/vision** inputs (paths 1, 2 + document vision) bill as
   multimodal tokens on the same Flash-Lite model.

- **Pricing (Flash-Lite tier):** Input **$0.10 / 1M tokens**, Output **$0.40 / 1M tokens**.
- **Pricing (embedding tier, `gemini-embedding-001`):** confirm current rate at the pricing URL below; embeddings are output-only token billing and far cheaper than generation. The cost is dominated by total chars chunked × embeds, not by retrieval.
- **Free tier:** Flash-Lite retains free access with reduced daily limits. Code rotates a pool of
  multiple API keys (`litellm-service.ts:110`), consistent with free-tier key pooling.
- **Cost variables:** cards scanned, voice clips transcribed, enrichments, assistant messages,
  tool steps per message, prompt+schema+history token size, audio length (multimodal tokens).
- **Formula (monthly):** `(input_tokens/1e6 * 0.10) + (output_tokens/1e6 * 0.40)`
  where `input_tokens ≈ (cards * card_prompt) + (voice_clips * audio_tokens) + (enrichments * enrich_prompt) + (assistant_msgs * steps * avg_prompt)`.

> ⚠️ **NO per-call token counts asserted — they are deliberately left as variables.** The Gemini SDK returns
> exact usage on every response. Add one log per call path (in `litellm-service.ts`, after each `generateContent`):
> ```ts
> const u = result.response.usageMetadata; // { promptTokenCount, candidatesTokenCount, totalTokenCount }
> console.log(`[gemini-tokens] ${this.config.model} prompt=${u?.promptTokenCount} out=${u?.candidatesTokenCount}`);
> ```
> **`card_prompt` / `audio_tokens` / `enrich_prompt` / `avg_prompt × steps` (per-unit tokens):**
> - **PLAN-A (now, no traffic needed):** trigger **one** of each path once — scan a card, transcribe a clip, enrich
>   a contact and a company, send one assistant message — and read the logged `usageMetadata`. That gives every
>   per-call token count directly. Card images and audio bill as multimodal tokens; the SDK already counts them.
> - **PLAN-B (post-pilot):** Google AI Studio / Cloud billing → token usage per model, ÷ the count of each action
>   over the same window — useful as a cross-check, but PLAN-A already yields exact per-call figures.
>
> **`how many of each per month` (volume):** PLAN-A *not available*; **PLAN-B** = count actions from the DB
> (`captures`, enrichment `enriched_at`, `messages`) post-pilot, or model by scenario until then.
> **Until the per-call tokens are logged via PLAN-A, no dollar estimate for Gemini is given** — the formula is
> correct but its per-unit inputs are unmeasured.

- Pricing: https://ai.google.dev/gemini-api/docs/pricing

### 2.3 Exa Search API — usage (per request + per content)
**Why:** Web enrichment for contacts/companies/events and the assistant's `web_search` tool, via
**Exa** (`exa-service.ts`). **Every call here passes `contents:{highlights:true}`** (`exa-service.ts:152`).

**Per-action SEARCH counts are EXACT from code.** `searchDepth` only changes Exa's `type` (`basic`→`fast`,
`advanced`→`auto`); it does **not** change price (verified below). Every call site enumerated:

| Action | Route | Exa searches fired | depth |
|---|---|---|---|
| Enrich a **contact** (with company) | `contacts.ts:798` → `searchContact` (`exa-service.ts:198-227`) | **2** (person + company) | basic/`fast` |
| Enrich a **contact** (independent / no company) | same | **1** (person only) | basic/`fast` |
| Enrich a **company** | `companies.ts:126-127` | **2** (1 `advanced`/`auto` + 1 `basic`/`fast`) | mixed |
| **Event** company prep / talking points | `events.ts:1113`, `events.ts:1506-1507` | **1–2** | basic/`fast` |
| Assistant **`web_search`** tool | `assistant/tools/dispatcher.ts:185-191` | **1 per tool call**; depth chosen by the model (defaults basic, `advanced` in research mode), `maxResults` capped at 10 (`Math.min(a.max_results ?? 5, 10)`) | model-chosen |

Every production call site uses `numResults: 5` (or ≤10 via the assistant's cap) — none exceed the
10-result flat-fee threshold seen in this account.

#### Verified live pricing (tested against the production Exa account/key, June 2026)

Earlier drafts of this doc **assumed** highlights/text content was billed as a per-page surcharge on top of
search, based on Exa's general marketing pricing copy. That assumption was **not verified against this
account** and turned out to be wrong for it. The table below replaces it with numbers read directly from
`costDollars` in the live API response, **each combination run 2–3× to confirm repeatability** (script:
`/tmp/.../exa_test.mjs`, `exa_test2.mjs`, `exa_test3.mjs` during this audit — not checked into the repo).

| Request (`numResults`, `type`, `contents`) | Repeats | `costDollars.total` | Notes |
|---|---|---|---|
| n=5, `fast`, no `contents` | 2× | **$0.007** | bare search, no content fields returned |
| n=5, `fast`, `{highlights:true}` | 2× | **$0.007** | identical to bare search — **highlights add $0 in this account** |
| n=5, `auto`, no `contents` | 2× | **$0.007** | `type` does not change price |
| n=5, `auto`, `{highlights:true}` | 2× | **$0.007** | confirms depth-independence |
| n=3, `fast`, `{text:true}` | 1× | **$0.007** | `text` (full page) also adds **$0** |
| n=3, `fast`, `{text:true, highlights:true}` | 1× | **$0.007** | both content fields together, still **$0** |
| n=5, `keyword`, `{highlights:true}` | 1× | **$0.007** | bills under `costDollars.search.keyword` instead of `.neural`, same $0.007 |
| n=5, `neural`, `{highlights:true}` | 1× | **$0.007** | only returned 4 results this run (relevance-dependent), cost still $0.007 |
| n=10, `fast`, `{highlights:true}` | 1× | **$0.007** | still flat — confirms the "≤10 results" base tier boundary |
| n=11, `fast`, `{highlights:true}` | 2× | **$0.008** | **+$0.001 for the 1 result over 10** — matches $1/1,000-per-extra-result |
| n=15, `fast`, `{highlights:true}` | 2× | **$0.012** | +$0.005 for 5 results over 10 |
| n=20, `fast`, `{highlights:true}` | 2× | **$0.017** | +$0.010 for 10 results over 10 |
| n=3, `fast`, `{summary:true}` | 2× | **$0.010** (`search:$0.007 + summary:$0.003`) | **`summary` IS billed separately** — $0.001/result, confirmed linear |
| n=5, `fast`, `{summary:true}` | 1× | **$0.012** (`search:$0.007 + summary:$0.005`) | 5 × $0.001 = $0.005 |
| n=10, `fast`, `{summary:true}` | 1× | **$0.017** (`search:$0.007 + summary:$0.01`) | 10 × $0.001 = $0.010, confirms linearity |
| n=3, `auto`/`keyword`, `{summary:true}` | 1× each | **$0.010** | summary surcharge is depth-independent too |
| n=3, `fast`, `{text:true,highlights:true,summary:true}` | 1× | **$0.010** | summary is the only field billed even combined with the other two |

**Verified conclusions for this codebase:**
- **`highlights` (what every call here uses) and `text` are free** — they ride on the base search cost
  with no measurable surcharge, at every `numResults` and `type` tested. The "$1/1,000 pages for content"
  line on Exa's public pricing page evidently refers to `summary` (AI-generated page summaries), not
  `highlights`/`text` — **this codebase never requests `summary`**, so it is unaffected.
- **Base search is a flat $0.007 for ≤10 results**, then **+$0.001 per result above 10**, regardless of
  `type` (`fast`/`auto`/`neural`/`keyword`) or `category`.
- Since every production call site here uses `numResults` ≤ 10, **every Exa call in this codebase costs
  exactly $0.007 flat** — there is no content surcharge to add, and the previous `~$0.012`/search
  ("search + 5×highlights") and `~$0.024`/enrichment figures below this point in earlier drafts were too high.
- This was verified against **one specific account/key on one day**; if Exa changes its plan tiers or this
  account's plan changes, re-run the same test script before trusting these numbers again.

- **Pricing (Exa, June 2026 — pay-as-you-go, no required monthly plan):**
  - **Search** (≤10 results): **$7 / 1,000 requests** (= **$0.007/search**) — verified above.
  - **Extra results** beyond 10: **+$1 / 1,000 per result** — verified above (n=11→$0.008, n=15→$0.012, n=20→$0.017); **not triggered here** (all calls use ≤10 results).
  - **`highlights` / `text` content**: **$0 surcharge in this account** — verified above, contradicts the public pricing page's general "page content" line, which appears to apply to `summary` only.
  - **`summary` content** (NOT used by this codebase): **$1 / 1,000 results** (= **$0.001/result**) — verified linear above. Documented here only because it's the field the $0.001/page general pricing copy actually refers to.
  - **Free tier:** **up to 20,000 requests/month free** — far more generous than Tavily's 1,000 credits.
  - Enterprise/volume = custom quote.
- **Cost variables (all Kind-B volume):** `contact_enrich/mo`, `company_enrich/mo`, `event_preps/mo`, `assistant_web_searches/mo`. Per-action **search counts** above are fixed from code (no measurement needed).
  - **PLAN-A:** *not available* for the volumes (Kind-B). The per-action search counts are already exact from code; you can PLAN-A *confirm* them by counting outbound requests in one local enrich run (§0 #4).
  - **PLAN-B (post-pilot):** read **Exa dashboard → requests/mo**, or count enrichment actions from the DB (`enriched_at` timestamps) ÷ window. Until then, model the per-month action counts by scenario.
- **Effective per-action cost (CORRECTED — verified $0.007 flat per search, no highlights surcharge):**
  contact enrich (2 searches) ≈ **$0.014**, company enrich (2 searches) ≈ **$0.014**, event prep (1–2 searches) ≈ **$0.007–0.014**, assistant search (1 call) ≈ **$0.007** each.
- **Formula (monthly):**
  `searches = 2·contact_enrich + 2·company_enrich + ~1.5·event_preps + ~1.5·assistant_searches`
  `cost = max(searches − 20000, 0) × $0.007`   (no content-surcharge term — highlights is free; would only need a `summary`-surcharge term if that field is ever requested)
- **Concrete free-tier headroom:** 20,000 free requests/mo ÷ 2 per company enrich = **~10,000 company enrichments/mo** before any spend — roughly **30× more headroom than Tavily's old 1,000 credits**. This service is very likely **$0** well into real production volume, and the corrected (lower) per-search cost makes any eventual overage cheaper than previously documented too.
- Pricing: https://exa.ai/pricing (general page); per-field billing behavior verified empirically against the live account as documented above, since the public page does not itemize `text`/`highlights`/`summary` separately.

### 2.4 Vercel (backend hosting) — fixed + usage
**Why:** Hosts the entire Express API. **Code fact:** `backend/src/server.ts` does `export default app`
and `backend/vercel.json` routes **all** paths (`/(.*)`) to `src/server.ts` via `@vercel/node` — so the
**whole Express app is one Fluid Compute function**, invoked once per API request.

- **Plan:** Pro **$20/mo per seat**, includes **$20/mo usage credit**, **1 TB** Fast Data Transfer, **10M** edge requests. **Hobby is not allowed** — Vercel ToS restricts it to non-commercial use (a CRM is commercial), so Pro is the floor.
- **Usage rates (Fluid Compute, 2026):**
  - **Active CPU $0.128 / CPU-hour** — billed **only while your code actively runs**, *not* during I/O waits (DB queries, Gemini/Exa HTTP calls). This matters a lot here: most request time is **waiting on Gemini/Exa/Supabase**, which is **not** billed as Active CPU. The OCR (`tesseract.js`) and JSON work **is** billed.
  - **Provisioned Memory $0.0106 / GB-hour.**
  - **Fast Data Transfer (egress) $0.15/GB** over the 1 TB included.
  - Invocations counted per request.
- **Cost variables (Kind-B volume):** requests/mo, **active-CPU seconds per request** (high for OCR routes, near-zero for proxy routes that just await Gemini/Exa), response payload size, seats.
- **Formula (monthly):**
  `20 + max( (active_CPU_hours×0.128) + (mem_GB_hours×0.0106) + max(egress_GB−1000,0)×0.15 − 20, 0 ) + 20×(extra_seats)`
- **`active_CPU_seconds_per_route` (per-unit):**
  - **PLAN-A (now):** log `process.hrtime()` around each handler body locally, especially `/ai/analyze-card` (OCR, CPU-heavy) vs `/ai/assistant` (mostly I/O wait). Gives per-route active-CPU directly — this is what burns the $0.128/CPU-hr.
  - **PLAN-B (post-pilot):** Vercel → Observability → Active CPU per function, ÷ invocations.
- **`requests/mo` & `egress_GB` (volume):** PLAN-A *not available*; **PLAN-B** = Vercel dashboard (invocations + Fast Data Transfer). Model by scenario until then.
- **Likely reality:** with the $20 credit and I/O-dominated handlers, a low-traffic commercial CRM often stays at the **$20 floor**; the first overage driver is OCR active-CPU if card scanning is heavy.
- Pricing: https://vercel.com/pricing · https://vercel.com/docs/functions/usage-and-pricing

### 2.5 Railway (Slayer NL→SQL container) — fixed + usage
**Why:** Runs the **always-on** Python Slayer service the assistant queries for read-only NL→SQL
(`Dockerfile.slayer` → FastAPI/uvicorn on `PORT`, default 5143). Unlike Vercel's per-request functions,
this is a **24/7 container** — you pay for every hour it's up, whether or not a query arrives.

- **Plan:** Hobby **$5/mo**, includes **$5 usage credit**. Usage billed by the **minute** on what the container actually consumes:
  - **CPU $20 / vCPU-month** (≈ **$0.000463/vCPU-minute**, ≈ $0.028/vCPU-hr).
  - **RAM $10 / GB-month** (≈ **$0.000231/GB-minute**, ≈ $0.014/GB-hr).
  - **Egress** billed per GB (Slayer→Supabase queries + Slayer→backend responses).
- **The key cost driver is allocation × 730 hrs, NOT request count** — an idle always-on box still bills for its reserved vCPU/RAM. Railway scales CPU/RAM to actual use, so right-sizing (and sleeping it when idle) is the lever.
- **Cost variables:** vCPU/RAM the container holds, uptime hours, egress GB.
  - **`vCPU_used` / `RAM_GB_used` (per-unit, the dominant lever):**
    - **PLAN-A (now):** `docker compose up` Slayer locally, fire a burst of assistant queries, watch `docker stats` peak `MEM USAGE`/`CPU %` (§0 #5).
    - **PLAN-B (live):** read the real held allocation off **Railway → Metrics/Usage** (Slayer is already deployed there — this is available *today*, §0 #6, so PLAN-B is unusually usable pre-launch here).
  - **`uptime_hours`:** known (730/mo for an always-on box) — no measurement needed.
- **Formula (monthly):** `5 + max( vCPU_used×730×0.028 + RAM_GB_used×730×0.014 + egress_GB×rate − 5, 0 )`
- **Worked, both ways (replace with measured allocation):**
  - At **0.5 vCPU + 1 GB held 24/7:** `0.5×20 + 1×10 = $20` usage → ~$20/mo (over the $5 credit).
  - At **0.25 vCPU + 0.5 GB:** `0.25×20 + 0.5×10 = $10` → ~$10/mo.
  - **Read the real figure off the Railway → Metrics/Usage tab** (§0 #5/#6) — the multiplier is exact, only the allocation is unknown, and it's directly visible, not an assumption.
- Pricing: https://railway.com/pricing

### 2.6 Firebase Hosting (web build) — free / usage
**Why:** Hosts the compiled Flutter **web** build (`exono/firebase.json` → `"public":"build/web"`). The
mobile apps (iOS/Android) do **not** use Hosting at all — they hit the Vercel API directly — so Hosting
only serves the web client's static bundle (HTML/JS/wasm/fonts) + whatever assets the browser loads.

- **Spark (free, no card):** **10 GB stored**, **360 MB/day** download (~10 GB/mo). **Blaze (pay-as-you-go):** **10 GB storage + 10 GB/mo egress still free**, then **storage $0.026/GB-mo**, **egress $0.15/GB**.
- **What's actually stored:** one Flutter web build — a few MB to ~20–30 MB of static files (`main.dart.js`, wasm, assets). Storage is **structurally tiny**; it does not grow with users (it's the app bundle, not user data — user data lives in Supabase).
- **What drives egress:** `bundle_size × web_page_loads/mo` (minus browser caching). A returning PWA user re-downloads almost nothing; egress ≈ `unique_first_loads × bundle_size`.
- **Cost variables:**
  - **`bundle_GB` (per-unit):** **PLAN-A (now):** `du -sh build/web` after `flutter build web`. **PLAN-B:** Firebase → Hosting → storage used. (PLAN-A is exact and trivial — use it.)
  - **`cold_web_loads/mo` (volume):** **PLAN-A** *not available*; **PLAN-B (post-pilot):** Firebase → Hosting → bandwidth, or egress_GB ÷ bundle_GB. Model by scenario until then.
- **Formula (monthly):** `max(storage_GB − 10, 0)×0.026 + max(egress_GB − 10, 0)×0.15` — where `egress_GB ≈ cold_web_loads × bundle_GB`.
- **Concrete free-tier headroom:** at a ~10 MB bundle, 10 GB/mo free egress = **~1,000 cold web loads/mo before $0.15/GB starts**. For a mobile-first CRM whose users mostly use the app, this is **almost certainly $0** indefinitely.
- Pricing: https://firebase.google.com/pricing · https://firebase.google.com/docs/hosting/usage-quotas-pricing

### 2.7 Firebase Analytics — free
**Why:** Event analytics (`analytics_service.dart`). **Always free, unlimited** (500 distinct event names). **$0.**
Pricing: https://firebase.google.com/pricing

### 2.8 Sentry (crash reporting + **mobile session replay**) — tier-based, MULTIPLE billable categories
**Why:** Crash/error reporting via `sentry_flutter` (`main.dart:85-99`). **Read the actual init — it bills on
two categories, not one:**

| Sentry config (`main.dart`) | Value | Billing impact |
|---|---|---|
| `tracesSampleRate` | **0.0** | **Performance/tracing OFF** — no span/transaction spend. Good. |
| `replay.sessionSampleRate` | **1.0** | **Mobile Session Replay ON for EVERY session** — a **separate billable category**. ⚠️ |
| `replay.onErrorSampleRate` | **1.0** | Replay also captured on every error. |
| `attachScreenshot` | true | Screenshots attached to errors (counts toward attachment storage). |

> ⚠️ **Session Replay is NOT free here.** The code comment even says *"record every session… Lower
> sessionSampleRate in production once testing is complete."* (`main.dart:93`) — **this has not been lowered.**
> At `1.0`, every app open is a billable replay. Sentry's session replay is normally described as web-only, but
> `sentry_flutter` ships **mobile replay**, which the SDK is actively recording.

- **Errors:** Free (Developer) **5K errors/mo, 1 user**. **Team $26–29/mo: 50K errors, unlimited users**, then PAYG.
- **Replays:** Free **50 replays/mo**; Team **500 replays/mo**; then **~$0.00375/replay** (drops at very high volume).
- **Cost variables:** error events/mo, **replays/mo ≈ app sessions/mo while sampleRate=1.0**, seats. All Kind-B volume:
  - **PLAN-A:** *not available* — error/session counts require real usage. (The replay-per-session multiplier is **code-derived**: `sessionSampleRate=1.0` ⇒ 1 replay per session, no measurement needed.)
  - **PLAN-B (post-pilot):** **Sentry → Stats/Usage** for errors and replays directly. `sessions/mo` also readable from UXCam/Firebase. Model by scenario until then.
- **Formula (monthly):**
  `plan_fee + max(errors − errors_incl, 0)×err_rate + max(replays − replays_incl, 0)×0.00375`
  with `replays ≈ total_app_sessions` while `sessionSampleRate = 1.0`.
- **Concrete risk:** at 100% replay sampling, replays = **every session**. 500 included (Team) is gone at ~17 sessions/day. At, say, 30,000 sessions/mo → `(30000−500)×0.00375 ≈ $111/mo` in **replay alone**, on top of error spend. **The fix is config, not money** — see §6.
- Pricing: https://sentry.io/pricing/ · https://docs.sentry.io/pricing/quotas/manage-replay-quota/

### 2.9 UXCam (mobile session analytics / replay) — key supplied at build
**Why:** mobile session recording + screen analytics. The key is read from a build-time define
(`static const String _uxcamKey = String.fromEnvironment('UXCAM_APP_KEY');`, `analytics_service.dart:16`),
init is gated on `_uxcamKey.isNotEmpty` (`:22`), and schematic gesture/screen recording is explicitly
enabled (`FlutterUxcam.optIntoSchematicRecordings()`, `:25`). A real key is supplied via
`--dart-define=UXCAM_APP_KEY=...`, so on those builds UXCam authenticates and records every session.

- **Code fact:** with a real key, UXCam records sessions → it is **billable on its own session quota**, in
  addition to Sentry mobile replay (§2.8). That means **two** recording tools running at once (UXCam +
  Sentry replay) plus Firebase Analytics for events — overlapping coverage, see §6 item 3.
- **Pricing (what's public, 2026):** **Free plan = 3,000 sessions/mo + 3,000 videos/mo**, resets monthly, never expires; **when 3,000 sessions is exceeded, recording simply STOPS** (it does not auto-bill). **Starter / Growth / Enterprise are sales-quote only** — UXCam does **not** publish a per-1,000-session overage rate; overages are toggled in-dashboard at a rate you negotiate.
- **Cost variables:** sessions/mo (Kind-B volume). Below 3,000/mo it stays free (recording auto-caps); above that, recording stops on Free, or you pay a **negotiated** rate on Growth+.
  - **PLAN-A:** *not available* — session count needs real usage.
  - **PLAN-B (post-pilot):** **UXCam dashboard → sessions/mo** (the authoritative source; also cross-checks Sentry replay counts). Model by scenario until then.
- **Formula:** **$0 up to 3,000 recorded sessions/mo** on Free (then recording stops, no auto-bill); on a paid tier, a **negotiated** per-session rate above the plan allotment — **not derivable from code or public pricing; requires a sales quote.** ($0 on builds where `UXCAM_APP_KEY` is empty — e.g. web, where init is also skipped via `!kIsWeb`.)
- **Decision:** keep evaluating whether you want **both** UXCam and Sentry mobile replay recording every session — that is double recording cost/quota for overlapping data. If UXCam's UX heatmaps aren't needed, drop one. See §6 item 3.
- Pricing: https://uxcam.com/plans/ (Free tier public; paid tiers sales-led)

### 2.10 Codemagic (iOS CI) — usage / fixed
**Why:** Builds the unsigned iOS IPA on `mac_mini_m2`, 60-min cap (`codemagic.yaml`).

- **Free:** 500 M2 minutes/mo (personal accounts only). **PAYG:** $0.095/min. **Team fixed:** $399/mo unlimited.
- **Cost variables:** builds/mo × minutes/build (~15–30 min).
  - **`minutes/build` (per-unit):** **PLAN-A (now):** run one build and read the actual wall-clock minutes from the Codemagic build log. **PLAN-B:** Codemagic → Billing → minutes used ÷ builds.
  - **`builds/mo` (volume):** **PLAN-A** *not available* — depends on release cadence; set it from your planned release schedule (a decision you own, not a guess). **PLAN-B:** Codemagic build history count.
- **Formula:** `max(total_build_minutes - 500, 0) * 0.095` (personal) — likely **$0** at low cadence.
- Pricing: https://codemagic.io/pricing/

### 2.11 In-process libraries — $0 (no external billing)
Tesseract.js (OCR), `exceljs`/`xlsx`/`papaparse` (import/export), `pdf-parse`/`mammoth`/`officeparser`
(doc parsing, lazily loaded — `document-extraction.ts`), `cheerio`, `multer` (upload parsing), `helmet`
(headers), `image_picker`/`camera`/`file_picker`/`record` (Flutter capture/upload), `drift`/`sqflite`
(local DB), `flutter_uxcam` SDK (billed on UXCam's own session quota, see §2.9, not an
in-process cost), `google_fonts` (Google's free font CDN). No API cost — they
consume Vercel/Railway compute already counted.

---

## 3. Backend scaling estimate (per typical user action)

The *per-action shape* is determinable from code; absolute volumes (users, cards, messages, clips)
**cannot be determined from code — user input required.**

| User action | Vercel API calls | Gemini calls | Exa searches | Supabase ops | Storage growth |
|---|---|---|---|---|---|
| Scan business card | 1 (`/captures`) + 1 (`/ai analyze-card`) | **1** (extract) | 0 | 1 storage upload + few DB writes | ~0.1–0.5 MB/image |
| Record a voice note | 1 (`/ai/transcribe` or `/captures/voice-transcribe`) | **1** (audio→text, skipped if silence-gate trips) | 0 | 1 write | 0 (audio not persisted) |
| Enrich a contact | 1 | **1** (structure result) | **~2** (search+highlights) | reads + 1 write | 0 |
| Enrich a company | 1 | **1** | **~2** (1 auto + 1 fast) | reads + write | 0 |
| Enrich an event / talking points / prep | 1 | **1–2** | **~1–2** | reads + write | 0 |
| Ask AI assistant 1 question | 1 (then SSE) | **N** (1 per tool step; typ. 2–5) | 0–N (only if it calls `web_search`) | Slayer `/query` per step + writes if action approved | 0 |
| Send a chat message (text) | 1 (then SSE) | **N** (assistant agentic loop) | 0–N | 1 write + realtime broadcast | 0 |
| Send a chat message **with attachment** | 1 upload + 1 send (SSE) | **N** + **embeds if doc is oversized** (chunk embed at upload + 1 query embed) | 0–N | storage upload + `document_chunks` writes (oversized only) + realtime | **attachment size** (image/doc) |
| ~~Add a contact document (PDF)~~ | **Not reachable from the app today.** `POST /documents` exists (`backend/src/routes/documents.ts`) but only accepts a pre-existing `file_url` string — no file body, no multer, no storage write of its own — and no Flutter screen calls it. Listed for completeness; contributes $0 to every column until a client uploader is built. | — | — | — | — |
| Normal browsing | served from local **drift** DB; realtime keeps it synced | 0 | 0 | realtime connection (counts vs 500 cap) | 0 |
| Import file (CSV/XLSX) | 1 (parsed in-process) | 0 | 0 | bulk writes | 0 |

**Realtime (see §2.1d):** every foregrounded user holds **1 concurrent Broadcast channel**
(`sync:user={userId}`, `sync_provider.dart:158`), +1 with a chat screen open, +0 during a live event (live
mode reuses the same broadcast). The Pro plan's **500 concurrent connections last to ~250–500 simultaneously
active users**, roughly in line with where storage/DB/egress costs begin. Overage is **$10 / extra 1,000 peak
connections**.

**Cron/background jobs:** `workmanager` runs **on-device** offline-sync (free). No server-side cron found.

---

## 4. Cost rollup

### One-time costs
- **$0 platform.** Apple Developer Program ($99/yr) is implied for real iOS distribution, but CI builds
  **unsigned/sideload** IPAs (`codemagic.yaml`). **Cannot determine from code whether a paid Apple account
  is used; user input required.**

### Fixed monthly subscriptions (floor)
| Service | Fixed/mo |
|---|---|
| Supabase Pro | $25 |
| Vercel Pro | $20 |
| Railway Hobby | $5 base (+ ~$15 usage for always-on Slayer ≈ ~$20 effective) |
| Sentry | $0 (free tier) |
| Firebase Hosting/Analytics | $0 |
| UXCam | $0 up to 3,000 sessions/mo (Free tier auto-caps) |
| Codemagic | $0 (within 500 free min) |
| **Floor total** | **~$50–65/mo** before any AI/search/MAU usage |

### Annual
`~$600–780/yr` baseline (+ usage). Codemagic Team ($3,990/yr) only if you outgrow free build minutes — not currently needed.

### Usage-based (the variable layer)
Gemini tokens (extraction + transcription + enrichment + assistant + doc embeddings), Exa search requests,
Supabase MAU/egress/storage, Vercel compute/egress, Railway resources.

---

## 5. Spreadsheet-ready table

| Service | Feature Used | Pricing Model | Current Price | Unit | Free Tier | Monthly Cost Formula | Official Pricing URL |
|---|---|---|---|---|---|---|---|
| Supabase | DB + Auth + Storage + Realtime | Fixed + usage | $25 base; $0.00325 MAU; $0.09 BW; $0.125 DB; $0.021 file; $10/1k realtime conns | per MAU / per GB / per 1k conns | 100K MAU, 8GB DB, 100GB file, 250GB BW, 500 conns | `25 + max(MAU-1e5,0)*0.00325 + max(BWgb-250,0)*0.09 + max(DBgb-8,0)*0.125 + max(filegb-100,0)*0.021 + max(peak_conns-500,0)/1000*10` | https://supabase.com/pricing |
| Google Gemini | `gemini-3.1-flash-lite` (card/voice/enrich/assistant) + `gemini-embedding-001` (doc RAG, 768d) | Usage | $0.10 in / $0.40 out (Flash-Lite); embedding tier separate | per 1M tokens | Flash-Lite free w/ rate limits | `(in/1e6*0.10)+(out/1e6*0.40)+embed_tokens*embed_rate` | https://ai.google.dev/gemini-api/docs/pricing |
| Exa | enrichment (contact 2 / company 2 / event 1–2 searches) + assistant `web_search`; each = search + highlights | PAYG | $7/1k search (≤10 res) + $1/1k extra result; **highlights/text content verified $0 surcharge in this account (§2.3)** | per request | **20,000 requests/mo** | `max(searches-20000,0)*0.007` (no content-surcharge term — `summary` would add `+results*0.001` but is never requested here) | https://exa.ai/pricing |
| Vercel | whole Express app = 1 Fluid function | Fixed + usage | $20 base; CPU $0.128/CPU-hr; mem $0.0106/GB-hr; egress $0.15/GB | per seat / CPU-hr / GB-hr / GB | 1TB BW, 10M edge req, $20 credit | `20 + max(cpu_hr*0.128 + mem_GBhr*0.0106 + max(egressGB-1000,0)*0.15 - 20, 0)` | https://vercel.com/docs/functions/usage-and-pricing |
| Railway | Slayer NL→SQL container (always-on 24/7) | Fixed + usage | $5 base; $20/vCPU-mo; $10/GB-mo | per vCPU-mo / GB-mo | $5 usage credit | `5 + max(vCPU*20 + RAMgb*10 + egress$ - 5, 0)` | https://railway.com/pricing |
| Firebase Hosting | Flutter web bundle (static) | Free / usage | storage $0.026/GB; egress $0.15/GB | per GB | 10GB store + 10GB/mo egress free | `max(storeGB-10,0)*0.026 + max(egressGB-10,0)*0.15` | https://firebase.google.com/docs/hosting/usage-quotas-pricing |
| Firebase Analytics | Event analytics | Free | $0 | — | Unlimited (500 events) | `0` | https://firebase.google.com/pricing |
| Sentry | error/crash events (tracing off) | Tier | $0 free / $26 Team | per error event | 5K errors (Free) / 50K (Team) | `plan_fee + max(errors-incl,0)*err_rate` | https://sentry.io/pricing/ |
| Sentry replay | mobile session replay @ 100% | Usage | ~$0.00375/replay | per replay | 50 (Free) / 500 (Team) | `max(replays-incl,0)*0.00375` where replays≈sessions | https://docs.sentry.io/pricing/quotas/manage-replay-quota/ |
| UXCam | mobile session analytics (**active** — key via `--dart-define`) | Free tier / sales quote | $0 ≤3k sessions | per session | 3,000 sessions/mo (then recording stops) | `$0 ≤3k recorded sessions/mo (Free auto-caps); negotiated rate above on paid tier` | https://uxcam.com/plans/ |
| Codemagic | iOS CI builds | Usage / fixed | $0.095/min or $399 Team | per build-min | 500 M2 min/mo (personal) | `max(buildmin-500,0)*0.095` | https://codemagic.io/pricing/ |
| OpenAI | dormant LLM fallback | Usage | only if Gemini key unset | per 1M tokens | n/a | `0 while GEMINI_API_KEY set` | https://openai.com/api/pricing/ |

---

## 6. Cost-reduction opportunities & dead weight

1. **Realtime fan-out is already efficient — no action needed.** The app opens a **single private Broadcast
   channel per user** as a wake-up poke and runs the drift `catchUpAll()` delta-sync over HTTP on each poke
   (`sync_provider.dart:154-186`); live mode reuses it via `onSyncPoke` (`live_event_provider.dart:46`). The
   500-connection cap lasts to ~250–500 concurrent users. Only remaining realtime channel beyond the broadcast
   is the per-conversation `messages:{id}` channel while a chat screen is open (`chat_provider.dart:306`),
   which is fine.

2. **Lower Sentry replay `sessionSampleRate` from 1.0 — a one-line change that can save $100+/mo.** At
   `replay.sessionSampleRate = 1.0` (`main.dart:93`) Sentry records **every app session** as a billable mobile
   replay; the 500 included (Team) are gone at ~17 sessions/day, and 30k sessions/mo ≈ **$111/mo in replay alone**.
   The code comment literally flags this as a testing-only setting. **Set it to ~0.1 (sample 10% of sessions) and
   keep `onErrorSampleRate` high** so you still capture replays around crashes. Pure config — no functionality lost.

3. **Decide UXCam vs Sentry replay — you are recording on BOTH.** A real key is supplied via
   `--dart-define=UXCAM_APP_KEY` and schematic recording is enabled (`analytics_service.dart:16,25`), so
   UXCam records **every session** — at the same time Sentry mobile replay
   (§2.8, `sessionSampleRate=1.0`) also records every session. That is **two full session-recording pipelines
   capturing overlapping data**, each against its own quota. You still have **three** behaviour tools
   (UXCam + Sentry replay + Firebase Analytics). **Pick one recorder:** keep UXCam *or* Sentry replay, not both,
   unless you specifically need UXCam's UX heatmaps. Firebase Analytics (free) covers events regardless.

4. **Railway/Slayer is the most questionable fixed line item (~$10–20/mo for an always-on box).** Slayer is a
   read-only NL→SQL layer the assistant calls. If assistant traffic is low, an always-on container is
   wasteful. Options: (a) fold Slayer into a Vercel serverless function or the existing Express backend;
   (b) scale it to zero on Railway; (c) drop Slayer and have the assistant query Supabase via
   parameterized server-side SQL. Also see §7 (a single VPS hosts backend + Slayer for ~$5/mo).

5. **OpenAI SDK is dead weight in deps.** Only a fallback that never runs while `GEMINI_API_KEY` is set.
   Remove it or document it as intentional fallback.

6. **Enrichment burns Exa AND Gemini per entity** (Exa is cheap). Company/contact enrichment
   each fire **2 Exa searches + 1 Gemini call** (exact, §2.3). Exa's **20,000 free requests/mo** cover
   ~10,000 enrichments/mo, so Exa is unlikely to cost anything for a long time.
   **Cache enrichment results** — the code short-circuits when `enriched_at` is set (`companies.ts:109`);
   ensure the client doesn't force-refresh. The Gemini call is the more meaningful per-enrichment cost.

7. **Voice transcription** — the silence gate (`ai.ts:113-152`) already avoids paying for silent clips;
   keep it. Longer recordings cost more (audio multimodal tokens) — cap recording length client-side.

8. **Gemini assistant loop cost scales with tool steps.** Each message triggers N calls. Lazy schema via
   `describe_model` (`assistant.ts:444`) already trims input tokens; keep a hard cap on max tool steps.

9. **Three hosting providers (Vercel + Firebase Hosting + Railway).** You pay base fees on multiple
   platforms. Firebase Hosting is free anyway, but consolidating Express + Slayer onto one box (§7)
   removes a base subscription and the Vercel→Railway egress hop.

10. **Vercel Pro is per-seat.** Pro bills $20 **per developer seat**, not per app — add seats only as needed.
    Hobby is not an option (commercial-use restriction), so Pro is the floor while you stay on Vercel; §7 shows
    the VPS alternative that removes it.

---

## 7. Hosting decision — VPS vs PaaS for backend + Slayer (researched)

### 7.0 What the two services actually need (from code)
- **Express backend** — light: routing, Zod, Exa/Gemini HTTP calls, and **OCR via `tesseract.js`** (runs
  in-process per request; CPU-spiky but short). No persistent heavy memory.
- **Slayer** (`Dockerfile.slayer`, `slayer/pyproject.toml`) — FastAPI + `uvicorn` + `pandas` + `duckdb` +
  `sqlglot` + `tantivy`/BM25 search. **No GPU, no torch, no embedding model loaded** (the `litellm`/`numpy`
  embedding extra is optional and search degrades to BM25 without it). Moderate RAM (~300–800 MB resident).
- **Verdict:** both fit comfortably in **2 vCPU / 4 GB RAM** on one box, with headroom. **1 vCPU / 2 GB** works
  for low traffic but leaves little margin for an OCR spike + a Slayer query at once. **Target: 2 vCPU / 4 GB.**

> ⚠️ **ASSUMED: Slayer ~300–800 MB resident, "2 vCPU / 4 GB fits both" — NOT measured.** This is a per-unit
> resource figure, so **PLAN-A applies and you should use it before committing to a box size:**
> - **PLAN-A (now):** run both with `docker stats` (live `MEM USAGE` / `CPU %` per container) under realistic load —
>   fire a burst of card scans (OCR) while running assistant queries (Slayer); read peak RSS + CPU.
> - **PLAN-B (live):** the **Railway → Metrics tab** already graphs Slayer's real memory/CPU today — read the peak
>   off it (available now since Slayer is deployed).
>
> If peak RSS stays well under 2 GB and CPU rarely saturates, a 1 vCPU / 2 GB box (cheaper) is enough; size up only
> if the measurements say so.

### 7.1 The PaaS baseline you're on today
| | Monthly | Notes |
|---|---|---|
| Vercel **Pro** (backend) | **$20** | Hobby is **not an option** — Vercel ToS restricts Hobby to *non-commercial* use; a commercial CRM **must** be on Pro. |
| Railway Hobby + Slayer usage | **~$20** ⚠️ | $5 base + **ASSUMED ~$15** for an always-on ~0.5 vCPU/1 GB container. **Read the actual figure off your Railway invoice / Usage tab — don't trust this guess.** |
| **PaaS total** | **~$40/mo** ⚠️ | Vercel Pro is exact ($20); Railway half is assumed — confirm from the invoice. Two platforms, two bills, two egress hops. |

### 7.2 VPS options — researched June 2026 (one box runs both via Docker Compose / nginx)
A single VPS hosts the Node backend **and** the Slayer container side by side, with nginx/Caddy as a
reverse proxy. The Express app runs as a long-lived process (`npm start`), not serverless — so `vercel.json`
is dropped and you set `SLAYER_URL=http://localhost:5143` (the two services talk over localhost — **zero
inter-service egress**, which is a real saving vs the current Vercel→Railway hop).

| Provider / plan | vCPU / RAM / SSD | Incl. egress | Price/mo | Egress overage |
|---|---|---|---|---|
| **Hetzner CX22** (Intel, shared) | 2 / 4 GB / 40 GB | **20 TB** | **€4.49 (~$5)** | €1.19/TB (~$0.0013/GB) |
| **Hetzner CPX11** (AMD) | 2 / 2 GB / 40 GB | 20 TB | €5.49 (~$6) | same |
| **DigitalOcean Basic** | 2 / 4 GB / 80 GB | 4 TB | **$24** | $0.01/GB |
| **AWS Lightsail** (fixed-price VPS) | 2 / 4 GB / 80 GB | ~4 TB | **~$24** | $0.09/GB |
| **AWS EC2 t4g.small** (on-demand) | 2 / 2 GB | none bundled | ~$12.26 + egress | **$0.09/GB** (the killer) |
| **GCP e2-small** (shared 2 vCPU / 2 GB) | 2 / 2 GB | none bundled | ~$12–13 + egress | **$0.085–0.12/GB** |
| GCP e2-micro (always-free, US) | shared / 1 GB | 1 GB free | $0 (too small) | — |

### 7.3 Recommendation

**Use Hetzner Cloud CX22 (2 vCPU / 4 GB / 40 GB SSD, 20 TB traffic) at ~€4.49 (~$5)/mo.** It is the clear
winner for this workload:

1. **~8× cheaper than the current PaaS** (~$5 vs ~$40/mo → **~$420/yr saved**) and ~5× cheaper than DO/Lightsail at the same specs.
2. **20 TB included egress** — effectively uncapped for this app. AWS/GCP's metered egress ($0.09/GB) is the
   hidden trap: their cheap-looking compute is undercut by egress bills, exactly the cost you're trying to avoid.
3. **Right-sized** — comfortably runs backend + Slayer; you stop paying Railway for an idle always-on container.
4. **Collapses two bills into one** and removes the Vercel→Railway network hop (localhost instead).

**When to pick something else:**
- **Want zero ops / managed deploys, don't care about ~$35/mo?** Stay on Railway and **move the Node backend
  onto Railway too** (drop Vercel). One platform, ~$25–30/mo, still cheaper than Vercel+Railway and far less
  setup than a VPS. This is the **best "minimal-effort" option**.
- **Already committed to AWS/GCP** for the rest of your stack and want one cloud? Use **Lightsail 2vCPU/4GB
  ($24, 4 TB egress)** — predictable and bundled — **not** raw EC2/GCE, whose metered egress makes the bill unpredictable.
- **Need multi-region / autoscaling / 99.99% SLA?** None of the above — that's managed Kubernetes / Fargate
  territory and a different cost class. This app (single backend + one Slayer) does **not** need it.

**Trade-off to accept on a VPS:** you own patching, the Docker Compose setup, TLS (Caddy/Let's Encrypt auto-renews),
backups, and uptime monitoring. For a single always-on box this is ~an hour of setup + occasional maintenance —
worth it for ~$420/yr. If that ops burden isn't wanted, the Railway-only consolidation (above) is the pragmatic pick.

**Net:** Hetzner CX22 for **lowest cost** (~$5/mo, ~$420/yr saved); Railway-only for **lowest effort** (~$25–30/mo);
avoid raw EC2/GCE due to egress pricing; Supabase + Gemini + Exa stay exactly as they are regardless.

---

## 8. Items requiring your input (not determinable from code)

> Each item below carries a **PLAN-A** (measure pre-launch, locally) or **PLAN-B** (measure post-pilot, from the
> dashboard) method in its §section — see the table in §0. Per-unit items have a usable PLAN-A *now*; the
> volume items (MAU and the per-month action counts) are PLAN-B only and must be modeled by named scenario until a pilot.

- **MAU, cards scanned/mo, voice clips/mo, enrichments/mo, assistant messages/mo, web traffic** → drive every usage formula. *(All volume — PLAN-B only; model by scenario pre-launch.)*
- **Apple Developer account** ($99/yr) — CI builds unsigned, so unclear if a paid account is held.
- **UXCam plan** — which paid tier / overage rate is a sales-quote decision once you exceed 3,000 sessions/mo.
- **Slayer container size on Railway** (vCPU/RAM allocation) — set in Railway UI, not in repo.
- **Ops tolerance** — decides VPS (Hetzner, cheapest) vs managed PaaS (Railway-only, easiest); see §7.3.

---

**Sources (official only):**
[Supabase](https://supabase.com/pricing) ·
[Vercel](https://vercel.com/pricing) ·
[Vercel Hobby ToS](https://vercel.com/legal/terms) ·
[Gemini API](https://ai.google.dev/gemini-api/docs/pricing) ·
[Exa](https://exa.ai/pricing) ·
[Railway](https://railway.com/pricing) ·
[Hetzner Cloud](https://www.hetzner.com/cloud) ·
[DigitalOcean Droplets](https://www.digitalocean.com/pricing/droplets) ·
[AWS Lightsail](https://aws.amazon.com/lightsail/pricing/) ·
[AWS EC2 on-demand](https://aws.amazon.com/ec2/pricing/on-demand/) ·
[GCP Compute Engine](https://cloud.google.com/products/compute/pricing) ·
[Firebase](https://firebase.google.com/pricing) ·
[Sentry](https://sentry.io/pricing/) ·
[Codemagic](https://codemagic.io/pricing/)
