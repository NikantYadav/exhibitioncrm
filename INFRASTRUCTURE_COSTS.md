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
| 4 | **Tavily credits per enrichment** | Already exact from code (contact=2, company=3, event=2); confirm by counting requests in one enrich run | §2.3 |
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

---

## 1. Architecture map (what the code actually runs)

| Layer | Component | Evidence in code |
|---|---|---|
| Mobile/web client | Flutter app | `exono/pubspec.yaml` |
| Backend API | Express on **Vercel** | `backend/vercel.json` (`@vercel/node`); client points at `https://exhibitioncrm.vercel.app/api` (`exono/lib/config/api_config.dart:5`) |
| Database + Auth + Storage + Realtime | **Supabase** | `@supabase/supabase-js`, `supabase_flutter`, realtime channels in `chat_provider.dart:280`, `synced_repository.dart:138`, `live_event_provider.dart:206` |
| Read-only NL→SQL service | **Slayer** (Python) on **Railway** | `Dockerfile.slayer` (`SLAYER_READONLY_PASSWORD must be set as a Railway env var`); backend calls `SLAYER_URL/query` (`slayer-client.ts:154`) |
| LLM | **Google Gemini** `gemini-3.1-flash-lite` | `litellm-service.ts:128`, `config/ai.ts` |
| Web search | **Tavily** `/search` | `tavily-service.ts:20-39`; depth varies per route (basic=1 credit, advanced=2) |
| OCR | **Tesseract.js** (in-process, no API) | `analyzeCard.ts:1-7` |
| Web hosting | **Firebase Hosting** | `exono/firebase.json` |
| Analytics | **Firebase Analytics** | `analytics_service.dart:18` |
| Crash reporting + replay | **Sentry** | `main.dart:85-99`, tracesSampleRate `0.0` (no perf) but **replay sampleRate `1.0`** (every session billable) |
| Session replay | **UXCam** | `analytics_service.dart:22` — **key is placeholder `YOUR_UXCAM_APP_KEY`** (inactive) |
| iOS CI builds | **Codemagic** (mac_mini_m2) | `codemagic.yaml` |

**Not present (confirmed absent):** no Redis, no queue (SQS/RabbitMQ), no dedicated email
provider (auth emails ride on Supabase Auth's built-in SMTP), no push notifications (no
`firebase_messaging`/FCM), no payment gateway (no Stripe), no separate CDN/object store
beyond Supabase Storage + Firebase Hosting, no Vercel KV/Blob, no monitoring/logging SaaS.
`openai` SDK is present but **dormant** — `AI_PROVIDER = hasGemini ? 'gemini' : 'openai'`
(`config/ai.ts`); OpenAI only runs if `GEMINI_API_KEY` is unset.

---

## 2. Per-service cost breakdown

### 2.1 Supabase (Database + Auth + Storage + Realtime) — fixed + usage
**Why:** Primary datastore (~30+ tables, `SUPABASE_SCHEMA.md`), user auth (MAU), private Storage
buckets (`contact-cards`, `chat-attachments` — `captures.ts:18`, `conversations.ts:213`), and
Realtime for chat/sync/live-events.

- **Plan:** Pro **$25/mo fixed** (needed for >500 realtime connections + production).
- **Included:** 8 GB DB, 100 GB storage, 250 GB bandwidth, 100K MAU, **500 concurrent realtime peak connections**, 5M realtime messages.
- **Overage units:** Bandwidth **$0.09/GB** · DB storage **$0.125/GB** · File storage **$0.021/GB** · Auth **$0.00325/MAU** beyond 100K · **Realtime peak connections $10 per additional 1,000** · Realtime messages $2.50/M.
- **Cost variables:** MAU, egress, stored card images (chat attachments exist server-side but are **not wired in the app**), DB size, **concurrent (peak) realtime connections**.
- **Headline formula (monthly):**
  `25 + max(MAU-100000,0)*0.00325 + max(GB_egress-250,0)*0.09 + max(GB_db-8,0)*0.125 + max(GB_files-100,0)*0.021 + realtime_overage`
- Pricing: https://supabase.com/pricing

The three storage/egress/db terms and realtime are **not free variables** — the code fixes their
relationship to MAU. Estimates below.

#### 2.1a `GB_files` — Storage (scanned card images only, in practice)
Only **one** thing actually lands in a bucket from the live app (confirmed in code):

| Bucket | Content | Status |
|---|---|---|
| `contact-cards` (private) | The **scanned business-card photo**, uploaded once per capture as `{userId}/{captureId}.{ext}` (`captures.ts:27-49`, `uploadCardImage`) | **Live** — the only real storage driver |
| `chat-attachments` (private) | AI-chat file attachments (`conversations.ts:191-224`) | **Backend-only, never used** — see note below |

> **Chat attachments are dead backend code.** The endpoints `/conversations/:id/attachments/upload`
> and the `chat-attachments` bucket exist server-side, but **nothing in the Flutter app ever calls them**
> — there is no file picker or upload call in `chat_provider.dart`, `chat_screen.dart`, or `api_service.dart`.
> So chat attachments contribute **0 GB** today. (Either wire them up or delete the unused route + bucket.)

There is **no separate avatar upload** — the contact `avatar_url` (`contact.dart:16`) points at the
**same stored card image** (or an external URL from enrichment), so avatars do **not** add storage.

Card images are captured via the camera and sent as base64; gallery picks use `imageQuality: 80–85`
(`contact_detail_screen.dart:266`, `contact_links_files_sheet.dart:269`).

> ⚠️ **ASSUMED: ~0.3 MB/card (range ~150–400 KB) — NOT measured.** To replace with a real number, add a
> log at the upload point in `captures.ts` (`uploadCardImage`, right after `decodeAndValidateImage`):
> ```ts
> const { buffer, type } = decodeAndValidateImage(image);
> console.log(`[card-size] ${type.mime} ${(buffer.length / 1024).toFixed(1)} KB`);
> ```
> **Pre-launch:** scan **10–20 real business cards** through the app against a local backend and average the logged
> sizes — that's a true `avg_card_MB`, no users needed. The **"40 cards/user/mo"** figure is **Kind-B (volume)** and
> cannot be measured pre-launch — set it from your go-to-market scenario (cards per rep per show day × show days), not a guess.

- **Driver:** total cards scanned (cumulative, storage never shrinks), not MAU directly.
- **Estimate (assumed inputs):** if an active user scans ~**40 cards/mo** (ASSUMED) → `0.3 MB × 40 = 12 MB/user/mo`, **cumulative**.
- **Relation to MAU (cumulative over `M` months of operation):**
  `GB_files ≈ MAU × cards_per_user_per_mo × avg_card_MB / 1024 × M_months`
- **Worked with assumed 0.3 MB & 40/mo — 1,000 MAU, 12 months:** `1000 × 12 MB × 12 / 1024 ≈ 141 GB` → over the 100 GB included → `(141-100)×0.021 ≈ $0.86/mo`. Storage is **cheap**; matters only at very high cumulative card counts. **Recompute once `avg_card_MB` and `cards_per_user_per_mo` are measured.**

#### 2.1b `GB_egress` — Bandwidth
Egress is dominated by **(1)** clients downloading card images (signed URLs, 1-hr TTL —
`captures.ts`/`contacts.ts:543`), **(2)** the initial drift `catchUpAll()` sync that pulls every row
on login/resume (`sync_provider.dart:71`), and **(3)** realtime row payloads. The local-first drift DB
means steady-state browsing is *not* re-downloading data, so egress is front-loaded at sync + image views.

- **Estimate per active user/mo:** initial + delta sync of ~10 tables (a few MB of rows) + viewing card
  images (each viewed image ≈ its card size, possibly re-fetched after the 1-hr signed URL expires) + realtime deltas.

> ⚠️ **ASSUMED: ~100 MB/active user/mo (range 50–150 MB) — Kind-B, NOT measurable pre-launch.** Egress depends on
> real usage patterns that don't exist until the app ships. **Pre-launch:** estimate it bottom-up from Kind-A
> per-unit costs you *can* measure — `egress/user ≈ initial_sync_payload + (cards_viewed × avg_card_MB) + realtime_deltas`
> (capture each piece locally with the browser/dio network inspector on one device). **Post-pilot:** read the true
> figure from **Supabase → Reports → Bandwidth ÷ active users**. Until a pilot, carry this as a modeled range, not a fact.

- **Relation to MAU (assumed input):** `GB_egress ≈ MAU × 0.1 GB/mo` (× a re-view multiplier if users browse card images heavily).
- **Worked with assumed 100 MB — 1,000 MAU →** `~100 GB/mo` → under the 250 GB included → **$0**. At **3,000 MAU** → ~300 GB → `(300-250)×0.09 ≈ $4.50/mo`. **Replace the 0.1 GB/mo with the dashboard figure.**

#### 2.1c `GB_db` — Database size
~30 tables; the row-heavy ones are `contacts`, `captures`, `interactions`, `follow_ups`, `contact_events`,
`email_drafts`, `messages` (chat). A contact + its capture + a few interactions/follow-ups is on the order
of **a few KB of row data + indexes**; enrichment text and chat messages add more.

> ⚠️ **Two different unknowns here — handle separately:**
> - **Per-row size (~5 KB) — Kind-A, measurable NOW.** Create ~20 contacts + their captures/enrichments by hand
>   in a local/staging DB, then `SELECT pg_total_relation_size('contacts') / count(*) FROM contacts;` (repeat per
>   heavy table). Gives true bytes/row incl. indexes & TOAST — no real users required.
> - **Contacts per user per month (~40) — Kind-B, NOT measurable pre-launch.** This is volume; set it from your
>   launch scenario, not a guess. (Post-pilot: `count(*)::float / count(DISTINCT user_id) ... created_at > now()-interval '30 days'`.)

- **Relation to MAU (cumulative, assumed inputs):** `GB_db ≈ MAU × contacts_per_user_per_mo × bytes_per_contact × M_months / 1e9`
- **Worked with assumed 5 KB & 40/mo — 1,000 MAU, 12 months:** `1000 × 40 × 5 KB × 12 / 1e6 ≈ 2.4 GB` → **under 8 GB included → $0**. The DB likely stays free until ~**3,000+ MAU sustained for a year** — **confirm with the two queries above.**

#### 2.1d Realtime — the real scaling constraint (peak **concurrent** connections, cap 500)
**This is the variable most likely to force an overage, well before storage/DB/egress do.** The code
opens, per logged-in user:

| When | Channels opened | Source |
|---|---|---|
| **Always, while the app is foregrounded** | **10** — one Realtime channel **per synced table** (`events, contacts, captures, targetCompanies, contactEvents, eventGoals, emailDrafts, interactions, followUps, targetCompanyMet`) | `sync_provider.dart:46-57` + `synced_repository.dart:137` |
| Chat screen open | **+1** (`messages:{conversationId}`) | `chat_provider.dart:279` |
| During a **live event** | **+5** (`captures, event_goals, target_companies, contact_events, contacts`) | `live_event_provider.dart:49-55,205` |

So a single active user holds **~10 concurrent connections** baseline, **11** with chat open, and **up to
~15** during a live event (live channels are scoped to live mode — opened in `_enterLiveMode`, torn down in
`_leaveLiveMode`, `live_event_provider.dart:182-189`).

The **per-user channel counts (10 / +1 / +5) are MEASURED from code, not assumed.** What's assumed is the
**human behaviour**: how many users are foregrounded at once, and what fraction are in a live event / chat.

> ⚠️ **ASSUMED: peak concurrent users and the live/chat fractions — Kind-B, NOT measurable pre-launch.** The
> connections-per-user multiplier (10–15) is **code-derived and exact**; the number of *simultaneous* users is a
> business-scenario input, not a measurement. **Pre-launch:** set it from your launch plan (*"one exhibition team
> of T reps, all live on the show floor at once"* → peak ≈ T×15) and compute the range. **Post-pilot:** read the
> true peak off **Supabase → Reports → Realtime** during a real show day. Don't fabricate a user count — name the scenario.

- **Concurrent connections ≈ (peak simultaneously-active users) × 10** (→ ×15 if many are in a live event at once — the realistic worst case for an *exhibition* CRM, where the whole team is live on the show floor together).
- **The 500 included connections are exhausted at only ~50 simultaneously-active users** (~33 if all are in live mode) — a **code-derived** figure (500 ÷ 10), independent of the behaviour assumptions. This is **far** below the MAU at which any other Supabase resource costs money.
- **Overage:** Supabase Pro bills **$10 per additional 1,000 peak connections**.
- **Realtime formula:**
  `peak_connections ≈ peak_concurrent_users × (10 + 5·fraction_in_live_event + 1·fraction_in_chat)`
  `realtime_overage = max(peak_connections − 500, 0) / 1000 × 10`
- **Worked: 200 concurrent users, 50% in a live event →** `200 × (10 + 5×0.5) = 2,500` peak connections → `(2500-500)/1000 × 10 = $20/mo`. At **500 concurrent live users** → `500 × 12.5 ≈ 6,250` → `~$57.50/mo`.

> **Bottom line on Supabase relations:** at the scales this app realistically hits, **storage, DB, and
> egress stay inside the free Pro allotments into the low-thousands of MAU.** The first thing to cost money
> is **realtime peak connections**, because every foregrounded user pins ~10 channels — see §6 for the fix.

### 2.2 Google Gemini API (`gemini-3.1-flash-lite`) — usage (tokens)
**Why:** Gemini is invoked on **five** distinct paths in code:

1. **Business-card extraction** — 1 call per scanned card (`analyzeCard.ts:10`).
2. **Voice transcription** — 1 multimodal call (audio→text) per non-silent recording
   (`litellm-service.ts:transcribeAudio`, model hard-coded `gemini-3.1-flash-lite`). Called from
   `ai.ts:156` and `captures.ts:59`, **gated by a server-side silence check** (`ai.ts:113-152`)
   so silent clips cost nothing.
3. **Contact enrichment** — Tavily search **then** `AIService.generateCompletion(...)` to structure
   the result (`contacts.ts:785,799`). **1 Gemini call per enrichment.**
4. **Company / event enrichment + talking points + prep** — Tavily **then** `llm.generateCompletion(...)`
   (`companies.ts:162`, `events.ts:1119,1445,1630`). **1+ Gemini call per enrichment/generation.**
5. **AI assistant agentic loop** — `query_crm`, `web_search`, `describe_model` tools (`assistant.ts`).
   **N Gemini calls per user message** (one per tool step; typically 2–5).

- **Pricing (Flash-Lite tier):** Input **$0.10 / 1M tokens**, Output **$0.40 / 1M tokens**.
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
> **Pre-launch (Kind-A — no traffic needed):** trigger **one** of each path once — scan a card, transcribe a clip,
> enrich a contact and a company, send one assistant message — and read the logged `usageMetadata`. That gives real
> `card_prompt`, `audio_tokens`, `enrich_prompt`, and `avg_prompt × steps` per message directly. The only Kind-B
> piece is *how many* of each happen per month (set by scenario). **Until the per-call tokens are logged, no dollar
> estimate for Gemini is given** — the formula is correct but its per-unit inputs are unmeasured. (Card images and
> audio bill as multimodal tokens; the SDK already counts them.)

- Pricing: https://ai.google.dev/gemini-api/docs/pricing

### 2.3 Tavily Search API — tier + usage (credits)
**Why:** Web enrichment for contacts/companies/events and the assistant's `web_search` tool (`tavily-service.ts`).

**Credit cost per user action is EXACT from code** — credit = `1` for `basic`, `2` for `advanced`
(`tavily-service.ts:39`, `max_results` does **not** change the credit cost, only result count). Every call
site enumerated:

| Action | Route | Searches fired | Credits |
|---|---|---|---|
| Enrich a **contact** (with company) | `contacts.ts:785` → `searchContact` (`tavily-service.ts:80-92`) | 2 basic (person + company) | **2** |
| Enrich a **contact** (independent / no company) | same | 1 basic (person only) | **1** |
| Enrich a **company** | `companies.ts:130-132` | 1 advanced + 1 basic | **3** |
| Company **briefing** | `companies.ts:238-244` | 2 basic | **2** |
| **Event** company prep / talking points | `events.ts:1108`, `events.ts:1408-1409` | 1–2 basic | **1–2** |
| Assistant **`web_search`** tool | `assistant.ts:1219-1221` | 1 per tool call, depth chosen by the model (defaults basic) | **1–2 each** |

- **Free (Researcher):** 1,000 credits/mo, no card. **Researcher paid:** $30/mo ($25 annual). **Project:** 4,000 credits/mo. **Startup:** $100/mo (~15,000 searches). **PAYG:** **$0.008/credit** once the plan allotment is exhausted. Credits **do not roll over**.
- **Cost variables:** all are **Kind-B volume** — `contact_enrich/mo`, `company_enrich/mo`, `briefings/mo`, `event_preps/mo`, `assistant_web_searches/mo`. The per-action credits above are fixed.
- **Formula (monthly):**
  `credits = 2·contact_enrich + 3·company_enrich + 2·briefings + ~1.5·event_preps + ~1.5·assistant_searches`
  `cost = plan_fee + max(credits − plan_credits, 0) × 0.008`
- **Concrete break-even on the free tier:** 1,000 credits ÷ 3 (a company enrich) = **~333 company enrichments/mo**, or ÷2 = **500 contact enrichments/mo**, before any PAYG. At 2,000 company enrichments/mo → `(2000×3 − 1000)×0.008 = $40/mo` PAYG (or move to the $30 Researcher / $100 Startup plan).
- **No assumption needed for per-action cost** — only the monthly counts, which come from your launch scenario (§0 Kind-B).
- Pricing: https://www.tavily.com/pricing · credits: https://docs.tavily.com/documentation/api-credits

### 2.4 Vercel (backend hosting) — fixed + usage
**Why:** Hosts the entire Express API. **Code fact:** `backend/src/server.ts` does `export default app`
and `backend/vercel.json` routes **all** paths (`/(.*)`) to `src/server.ts` via `@vercel/node` — so the
**whole Express app is one Fluid Compute function**, invoked once per API request.

- **Plan:** Pro **$20/mo per seat**, includes **$20/mo usage credit**, **1 TB** Fast Data Transfer, **10M** edge requests. **Hobby is not allowed** — Vercel ToS restricts it to non-commercial use (a CRM is commercial), so Pro is the floor.
- **Usage rates (Fluid Compute, 2026):**
  - **Active CPU $0.128 / CPU-hour** — billed **only while your code actively runs**, *not* during I/O waits (DB queries, Gemini/Tavily HTTP calls). This matters a lot here: most request time is **waiting on Gemini/Tavily/Supabase**, which is **not** billed as Active CPU. The OCR (`tesseract.js`) and JSON work **is** billed.
  - **Provisioned Memory $0.0106 / GB-hour.**
  - **Fast Data Transfer (egress) $0.15/GB** over the 1 TB included.
  - Invocations counted per request.
- **Cost variables (Kind-B volume):** requests/mo, **active-CPU seconds per request** (high for OCR routes, near-zero for proxy routes that just await Gemini/Tavily), response payload size, seats.
- **Formula (monthly):**
  `20 + max( (active_CPU_hours×0.128) + (mem_GB_hours×0.0106) + max(egress_GB−1000,0)×0.15 − 20, 0 ) + 20×(extra_seats)`
- **Kind-A you can measure now:** the **active-CPU seconds of each route** — log `process.hrtime()` around the handler body locally, especially `/ai/analyze-card` (OCR is CPU-heavy) vs `/ai/assistant` (mostly I/O wait). This tells you which routes actually burn the $0.128/CPU-hr.
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
- **Cost variables:** measured vCPU/RAM the container holds (Kind-A — read it, don't assume), uptime hours, egress GB.
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
- **Cost variables (Kind-B volume):** monthly web sessions and how many are cold (cache-empty) loads. Bundle size is **Kind-A — measurable now**: `du -sh build/web` after `flutter build web`.
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
- **Cost variables:** error events/mo (Kind-B), **replays/mo ≈ app sessions/mo while sampleRate=1.0** (Kind-B), seats.
- **Formula (monthly):**
  `plan_fee + max(errors − errors_incl, 0)×err_rate + max(replays − replays_incl, 0)×0.00375`
  with `replays ≈ total_app_sessions` while `sessionSampleRate = 1.0`.
- **Concrete risk:** at 100% replay sampling, replays = **every session**. 500 included (Team) is gone at ~17 sessions/day. At, say, 30,000 sessions/mo → `(30000−500)×0.00375 ≈ $111/mo` in **replay alone**, on top of error spend. **The fix is config, not money** — see §6.
- Pricing: https://sentry.io/pricing/ · https://docs.sentry.io/pricing/quotas/manage-replay-quota/

### 2.9 UXCam (mobile session analytics / replay) — **currently $0 (not wired)**
**Why intended:** mobile session recording + screen analytics. The SDK is initialized in
`analytics_service.dart:22` (`FlutterUxcam.startWithConfiguration`), **but with the literal placeholder key**
`static const String _uxcamKey = 'YOUR_UXCAM_APP_KEY';` (`analytics_service.dart:15`).

- **Code fact:** with a placeholder key, UXCam **does not authenticate / record** → **$0 today, and $0 of value** (the SDK ships in the app binary, adding size, but sends nothing). This overlaps with Sentry mobile replay (§2.8) and Firebase Analytics (§2.10) — **three** session/event tools, one of them inert.
- **Pricing (what's public, 2026):** **Free plan = 3,000 sessions/mo + 3,000 videos/mo**, resets monthly, never expires; **when 3,000 sessions is exceeded, recording simply STOPS** (it does not auto-bill). **Starter / Growth / Enterprise are sales-quote only** — UXCam does **not** publish a per-1,000-session overage rate; overages are toggled in-dashboard at a rate you negotiate.
- **Cost variables:** sessions/mo (Kind-B). Below 3,000 sessions/mo the paid tiers are irrelevant — it stays free (and capped).
- **Formula:** **$0** while the key is a placeholder. If wired: **$0 up to 3,000 sessions/mo**, then either recording stops (Free) or a **negotiated** per-session rate (Growth+) — **not derivable from code or public pricing; requires a sales quote.**
- **Decision needed (not a cost estimate):** either (a) set a real key and accept the 3,000-session free cap / get a Growth quote, or (b) **remove `flutter_uxcam`** entirely since Sentry replay + Firebase Analytics already cover replay + events. See §6.
- Pricing: https://uxcam.com/plans/ (Free tier public; paid tiers sales-led)

### 2.10 Codemagic (iOS CI) — usage / fixed
**Why:** Builds the unsigned iOS IPA on `mac_mini_m2`, 60-min cap (`codemagic.yaml`).

- **Free:** 500 M2 minutes/mo (personal accounts only). **PAYG:** $0.095/min. **Team fixed:** $399/mo unlimited.
- **Cost variables:** builds/mo × minutes/build (~15–30 min).
- **Formula:** `max(total_build_minutes - 500, 0) * 0.095` (personal) — likely **$0** at low cadence.
- Pricing: https://codemagic.io/pricing/

### 2.11 In-process libraries — $0 (no external billing)
Tesseract.js (OCR), `exceljs`/`xlsx`/`papaparse` (import/export), `pdf-parse`/`mammoth` (doc parsing),
`cheerio`, `image_picker`/`camera`, `drift`/`sqflite` (local DB), `flutter_uxcam` SDK (inert),
`google_fonts` (Google's free font CDN). No API cost — they consume Vercel/Railway compute already counted.

---

## 3. Backend scaling estimate (per typical user action)

The *per-action shape* is determinable from code; absolute volumes (users, cards, messages, clips)
**cannot be determined from code — user input required.**

| User action | Vercel API calls | Gemini calls | Tavily credits | Supabase ops | Storage growth |
|---|---|---|---|---|---|
| Scan business card | 1 (`/captures`) + 1 (`/ai analyze-card`) | **1** (extract) | 0 | 1 storage upload + few DB writes | ~0.1–0.5 MB/image |
| Record a voice note | 1 (`/ai/transcribe` or `/captures/voice-transcribe`) | **1** (audio→text, skipped if silence-gate trips) | 0 | 1 write | 0 (audio not persisted) |
| Enrich a contact | 1 | **1** (structure result) | **~2** (basic) | reads + 1 write | 0 |
| Enrich a company | 1 | **1** | **~3** (1 advanced + 1 basic) | reads + write | 0 |
| Enrich an event / talking points / prep | 1 | **1–2** | **~2** (basic) | reads + write | 0 |
| Ask AI assistant 1 question | 1 (then SSE) | **N** (1 per tool step; typ. 2–5) | 0–N (only if it calls `web_search`) | Slayer `/query` per step + writes if action approved | 0 |
| Send a chat message | 1 (then SSE) | **N** (assistant agentic loop) | 0–N | 1 write + realtime broadcast | 0 (attachment upload exists server-side but is **not wired in the app**) |
| Normal browsing | served from local **drift** DB; realtime keeps it synced | 0 | 0 | realtime connection (counts vs 500 cap) | 0 |
| Import file (CSV/XLSX) | 1 (parsed in-process) | 0 | 0 | bulk writes | 0 |

**Realtime is the silent scaler (and the first cost ceiling — see §2.1d):** every foregrounded user
pins **~10 concurrent channels** (one per synced table, `sync_provider.dart:46`), +1 with chat open,
+5 during a live event. The Pro plan's **500 concurrent connections are spent at only ~50 simultaneously
active users** — long before MAU drives any storage/DB/egress cost. Overage is **$10 / extra 1,000 peak connections**.

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
| UXCam | $0 (not wired) |
| Codemagic | $0 (within 500 free min) |
| **Floor total** | **~$50–65/mo** before any AI/search/MAU usage |

### Annual
`~$600–780/yr` baseline (+ usage). Codemagic Team ($3,990/yr) only if you outgrow free build minutes — not currently needed.

### Usage-based (the variable layer)
Gemini tokens (extraction + transcription + enrichment + assistant), Tavily credits,
Supabase MAU/egress/storage, Vercel compute/egress, Railway resources.

---

## 5. Spreadsheet-ready table

| Service | Feature Used | Pricing Model | Current Price | Unit | Free Tier | Monthly Cost Formula | Official Pricing URL |
|---|---|---|---|---|---|---|---|
| Supabase | DB + Auth + Storage + Realtime | Fixed + usage | $25 base; $0.00325 MAU; $0.09 BW; $0.125 DB; $0.021 file; $10/1k realtime conns | per MAU / per GB / per 1k conns | 100K MAU, 8GB DB, 100GB file, 250GB BW, 500 conns | `25 + max(MAU-1e5,0)*0.00325 + max(BWgb-250,0)*0.09 + max(DBgb-8,0)*0.125 + max(filegb-100,0)*0.021 + max(peak_conns-500,0)/1000*10` | https://supabase.com/pricing |
| Google Gemini | `gemini-3.1-flash-lite`: card extraction, voice transcription, enrichment, assistant | Usage | $0.10 in / $0.40 out | per 1M tokens | Flash-Lite free w/ rate limits | `(in/1e6*0.10)+(out/1e6*0.40)` | https://ai.google.dev/gemini-api/docs/pricing |
| Tavily | enrichment (contact 2 / company 3 / briefing 2 / event 1–2 credits) + assistant `web_search` | Tier + PAYG | $0.008/credit over plan; Researcher $30 / Startup $100 | per credit (basic=1, advanced=2) | 1,000 credits/mo | `plan_fee + max(credits-plan_credits,0)*0.008` | https://www.tavily.com/pricing |
| Vercel | whole Express app = 1 Fluid function | Fixed + usage | $20 base; CPU $0.128/CPU-hr; mem $0.0106/GB-hr; egress $0.15/GB | per seat / CPU-hr / GB-hr / GB | 1TB BW, 10M edge req, $20 credit | `20 + max(cpu_hr*0.128 + mem_GBhr*0.0106 + max(egressGB-1000,0)*0.15 - 20, 0)` | https://vercel.com/docs/functions/usage-and-pricing |
| Railway | Slayer NL→SQL container (always-on 24/7) | Fixed + usage | $5 base; $20/vCPU-mo; $10/GB-mo | per vCPU-mo / GB-mo | $5 usage credit | `5 + max(vCPU*20 + RAMgb*10 + egress$ - 5, 0)` | https://railway.com/pricing |
| Firebase Hosting | Flutter web bundle (static) | Free / usage | storage $0.026/GB; egress $0.15/GB | per GB | 10GB store + 10GB/mo egress free | `max(storeGB-10,0)*0.026 + max(egressGB-10,0)*0.15` | https://firebase.google.com/docs/hosting/usage-quotas-pricing |
| Firebase Analytics | Event analytics | Free | $0 | — | Unlimited (500 events) | `0` | https://firebase.google.com/pricing |
| Sentry | error/crash events (tracing off) | Tier | $0 free / $26 Team | per error event | 5K errors (Free) / 50K (Team) | `plan_fee + max(errors-incl,0)*err_rate` | https://sentry.io/pricing/ |
| Sentry replay | mobile session replay @ 100% | Usage | ~$0.00375/replay | per replay | 50 (Free) / 500 (Team) | `max(replays-incl,0)*0.00375` where replays≈sessions | https://docs.sentry.io/pricing/quotas/manage-replay-quota/ |
| UXCam | mobile session analytics (inactive — placeholder key) | Free tier / sales quote | $0 today | per session | 3,000 sessions/mo (then recording stops) | `0 while key is placeholder; else $0 ≤3k sessions, quote above` | https://uxcam.com/plans/ |
| Codemagic | iOS CI builds | Usage / fixed | $0.095/min or $399 Team | per build-min | 500 M2 min/mo (personal) | `max(buildmin-500,0)*0.095` | https://codemagic.io/pricing/ |
| OpenAI | dormant LLM fallback | Usage | only if Gemini key unset | per 1M tokens | n/a | `0 while GEMINI_API_KEY set` | https://openai.com/api/pricing/ |

---

## 6. Cost-reduction opportunities & dead weight

1. **Collapse the 10-channels-per-user realtime fan-out — this is the #1 scaling cost.** Today each user
   opens one Realtime channel **per table** (`sync_provider.dart:46`, 10 channels), so 500 included
   connections run out at ~50 concurrent users. Two fixes: **(a)** subscribe to a **single** channel and
   multiplex all 10 tables through it (Supabase Realtime supports multiple `postgres_changes` bindings on
   one channel) — cuts connections ~10×, pushing the cap to ~500 concurrent users on the same plan; **(b)**
   only open realtime for the table(s) the current screen needs, and rely on the existing drift `catchUp`
   delta-sync on resume for the rest. Either keeps you on the $25 plan far longer. **Biggest lever.**

2. **Lower Sentry replay `sessionSampleRate` from 1.0 — a one-line change that can save $100+/mo.** At
   `replay.sessionSampleRate = 1.0` (`main.dart:93`) Sentry records **every app session** as a billable mobile
   replay; the 500 included (Team) are gone at ~17 sessions/day, and 30k sessions/mo ≈ **$111/mo in replay alone**.
   The code comment literally flags this as a testing-only setting. **Set it to ~0.1 (sample 10% of sessions) and
   keep `onErrorSampleRate` high** so you still capture replays around crashes. Pure config — no functionality lost.

3. **Decide UXCam vs Sentry replay — don't pay/ship for both.** UXCam ships in the binary but is inert
   (placeholder key → $0, zero value), and Sentry mobile replay already records sessions. You have **three**
   behaviour tools (UXCam, Sentry replay, Firebase Analytics) with overlapping jobs. **Remove `flutter_uxcam`**
   unless you specifically want UXCam's UX heatmaps — it shrinks the app and drops an unused vendor. Firebase
   Analytics (free) covers events; Sentry covers replay.

4. **Railway/Slayer is the most questionable fixed line item (~$10–20/mo for an always-on box).** Slayer is a
   read-only NL→SQL layer the assistant calls. If assistant traffic is low, an always-on container is
   wasteful. Options: (a) fold Slayer into a Vercel serverless function or the existing Express backend;
   (b) scale it to zero on Railway; (c) drop Slayer and have the assistant query Supabase via
   parameterized server-side SQL. Also see §7 (a single VPS hosts backend + Slayer for ~$5/mo).

5. **OpenAI SDK is dead weight in deps.** Only a fallback that never runs while `GEMINI_API_KEY` is set.
   Remove it or document it as intentional fallback.

6. **Enrichment burns Tavily AND Gemini per entity.** Company enrichment is **3 Tavily credits + 1 Gemini
   call**; contact enrichment **2 credits + 1 Gemini call** (exact, §2.3). The 1,000 free Tavily credits cover
   ~333 company / ~500 contact enrichments/mo. **Cache enrichment results** — the code already short-circuits
   when `enriched_at` is set (`companies.ts:114`); ensure the client doesn't force-refresh. Consider collapsing
   the 2 company queries into 1 (saves a credit) and dropping the company-briefing's overlap with enrich.

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
- **Express backend** — light: routing, Zod, Tavily/Gemini HTTP calls, and **OCR via `tesseract.js`** (runs
  in-process per request; CPU-spiky but short). No persistent heavy memory.
- **Slayer** (`Dockerfile.slayer`, `slayer/pyproject.toml`) — FastAPI + `uvicorn` + `pandas` + `duckdb` +
  `sqlglot` + `tantivy`/BM25 search. **No GPU, no torch, no embedding model loaded** (the `litellm`/`numpy`
  embedding extra is optional and search degrades to BM25 without it). Moderate RAM (~300–800 MB resident).
- **Verdict:** both fit comfortably in **2 vCPU / 4 GB RAM** on one box, with headroom. **1 vCPU / 2 GB** works
  for low traffic but leaves little margin for an OCR spike + a Slayer query at once. **Target: 2 vCPU / 4 GB.**

> ⚠️ **ASSUMED: Slayer ~300–800 MB resident, "2 vCPU / 4 GB fits both" — NOT measured.** Confirm before committing
> to a box size: run both with `docker stats` (shows live `MEM USAGE` / `CPU %` per container) under realistic load
> — fire a burst of card scans (OCR) while running assistant queries (Slayer). On Railway today the **Metrics tab**
> already graphs Slayer's real memory/CPU; read the peak off it. If peak RSS stays well under 2 GB and CPU rarely
> saturates, a 1 vCPU / 2 GB box (cheaper) is enough; size up only if the measurements say so.

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
avoid raw EC2/GCE due to egress pricing; Supabase + Gemini + Tavily stay exactly as they are regardless.

---

## 8. Items requiring your input (not determinable from code)
- **MAU, cards scanned/mo, voice clips/mo, enrichments/mo, assistant messages/mo, web traffic** → drive every usage formula.
- **Apple Developer account** ($99/yr) — CI builds unsigned, so unclear if a paid account is held.
- **UXCam plan** — inactive in code.
- **Slayer container size on Railway** (vCPU/RAM allocation) — set in Railway UI, not in repo.
- **Ops tolerance** — decides VPS (Hetzner, cheapest) vs managed PaaS (Railway-only, easiest); see §7.3.

---

**Sources (official only):**
[Supabase](https://supabase.com/pricing) ·
[Vercel](https://vercel.com/pricing) ·
[Vercel Hobby ToS](https://vercel.com/legal/terms) ·
[Gemini API](https://ai.google.dev/gemini-api/docs/pricing) ·
[Tavily](https://www.tavily.com/pricing) ·
[Railway](https://railway.com/pricing) ·
[Hetzner Cloud](https://www.hetzner.com/cloud) ·
[DigitalOcean Droplets](https://www.digitalocean.com/pricing/droplets) ·
[AWS Lightsail](https://aws.amazon.com/lightsail/pricing/) ·
[AWS EC2 on-demand](https://aws.amazon.com/ec2/pricing/on-demand/) ·
[GCP Compute Engine](https://cloud.google.com/products/compute/pricing) ·
[Firebase](https://firebase.google.com/pricing) ·
[Sentry](https://sentry.io/pricing/) ·
[Codemagic](https://codemagic.io/pricing/)
