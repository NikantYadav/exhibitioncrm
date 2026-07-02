# PLAN-B Field Guide — How to Measure Your Real Infrastructure Costs After Launch

**Who this is for:** you have never done a cost analysis before, you have just run your first
real usage (one pilot exhibition, or the app has been live for a few weeks), and you now want to
replace every guessed number in [`INFRASTRUCTURE_COSTS.md`](INFRASTRUCTURE_COSTS.md) with a **real,
measured** one.

This guide only covers **PLAN-B** — measuring from live data. If the app is not live yet and you have
no real users, you cannot do PLAN-B; go measure the **PLAN-A** (per-unit) numbers first (see §0 of the
main doc) and *model* the volumes by scenario. Come back here once real traffic exists.

> **Two source docs, and how they differ.** [`INFRASTRUCTURE_COSTS.md`](INFRASTRUCTURE_COSTS.md) is the
> exhaustive AI-generated breakdown (every service, every code reference).
> [`INFRASTRUCTURE_ANALYSIS.md`](INFRASTRUCTURE_ANALYSIS.md) is *your own* condensed analysis derived from
> it — and it makes a few deliberate decisions this guide follows:
> - **Fixed costs you listed:** Google Play ($25 one-time), a domain (~$200/yr), Apple Developer ($99/yr).
>   These are separate from the monthly infrastructure bill — see §0.1 below.
> - **Contact Documents are in your storage formula.** Your `GB_files` formula includes a
>   `contact_documents` term, even though that upload path is not wired into the app yet (the AI doc
>   correctly notes it currently costs $0). This guide keeps it as a **planned** term so your forecast is
>   ready the day you wire it up — see §2.1a.
> - **Deployment is decided:** one server hosting both the backend and Slayer (not separate Vercel +
>   Railway). This guide's §2.4/§2.5 reflect that single-server model — see §2.4.

> **Read this once, top to bottom.** It is written so that if you follow it step by step you will end
> up with a filled-in spreadsheet and a real monthly bill estimate, without needing to already
> understand cloud billing.

---

## 0. The mental model (read this before anything else)

Every cloud bill in this project has the same shape:

```
monthly_cost  =  fixed_fee  +  (how_much_you_used  −  free_allowance)  ×  price_per_unit
```

- **fixed_fee** — a flat monthly subscription (e.g. Supabase Pro is $25). You pay it even at zero usage.
- **how_much_you_used** — the number you are here to *measure*. Examples: gigabytes stored, tokens sent
  to Gemini, search requests to Exa, peak simultaneous users.
- **free_allowance** — the amount included in the plan before they start charging (e.g. Supabase gives
  100 GB of storage free).
- **price_per_unit** — the overage rate (e.g. $0.021 per extra GB). These come from the vendor's pricing
  page and are already written into the formulas in the main doc — you do **not** measure these.

**Your entire job in PLAN-B is to measure the one variable per category: "how much you used."**
Everything else is already known.

There are two flavours of "how much you used":

| Flavour | What it means | Example | How PLAN-B measures it |
|---|---|---|---|
| **Per-unit** (Kind A) | the size/cost of **one** action | MB per card image, tokens per AI message | Usually already measured pre-launch (PLAN-A). PLAN-B just confirms it from the dashboard. |
| **Volume** (Kind B) | **how many** actions happened | cards scanned per user per month, peak users | This is the real PLAN-B work — read it off the dashboard or a database query. |

**The multiplication that produces a bill:** `per_unit × volume × users = total usage`. You measure both
halves and multiply. That's it.

---

### 0.1 Fixed costs that are NOT part of the monthly usage bill

Before the usage math, note the costs that don't move with users — from your
[`INFRASTRUCTURE_ANALYSIS.md`](INFRASTRUCTURE_ANALYSIS.md). You don't "measure" these; you just pay them.
List them separately so they don't get tangled up in the per-user forecasting:

| Fixed cost | Amount | Cadence | Notes |
|---|---|---|---|
| Google Play developer account | $25 | **one-time** | required to publish on Android |
| Apple Developer Program | $99 | per year | required to publish on iOS |
| Domain name | ~$200 | per year | varies by registrar/TLD |

Convert to a monthly figure for the total: `($99 + $200)/12 ≈ $25/mo amortized`, plus the one-time $25.
Everything from §1 onward is the *usage* bill on top of this.

---

## 1. Before you start — the two numbers you need for EVERYTHING

Almost every formula divides a total by your **active user count**. So first, get two anchor numbers.

### 1.1 MAU (Monthly Active Users)

**What it is:** the number of distinct people who used the app in a 30-day window. This is the master
scaling number — it appears in nearly every formula.

**How to measure it (pick one, they should roughly agree):**
- **Supabase dashboard:** open your project → **Authentication** → the dashboard shows active users.
  Supabase itself bills on MAU, so this is the authoritative number for the auth line item.
- **Firebase Analytics:** Firebase console → **Analytics** → **Active users** (28-day). Good cross-check.
- **UXCam:** dashboard → sessions/users. Another cross-check.

Write down: **MAU = _______ users** (use the last full 30-day period).

### 1.2 Sessions per month

**What it is:** the number of times the app was *opened* (one person opens the app 5 times = 5 sessions).
Needed specifically for **Sentry replay** and **UXCam**, which bill per session, not per user.

**How to measure it:**
- **Firebase Analytics** → **Engagement** → sessions count for the month, **or**
- **UXCam dashboard** → total sessions this month.

Write down: **sessions/mo = _______**.

> **Tip:** a rough shortcut is `sessions/mo ≈ MAU × (times a typical user opens the app per month)`.
> But you have the real number on the dashboard now — use that, not the shortcut.

---

## 2. Category-by-category PLAN-B instructions

Each category below tells you: **(a)** what to measure, **(b)** exactly where to click / what query to
run, **(c)** the formula to plug it into, and **(d)** how to sanity-check the result.

The categories match the main doc's section numbers so you can cross-reference.

---

### 2.1 Supabase — Database, Storage, Bandwidth, Realtime (§2.1)

Supabase has **four** separate usage meters. Measure each one. The fixed fee is **$25/mo** on the Pro plan.

The one formula that combines them all:

```
supabase_monthly =
    25
  + max(MAU − 100000, 0)        × 0.00325     (auth overage)
  + max(GB_egress − 250, 0)     × 0.09         (bandwidth overage)
  + max(GB_db − 8, 0)           × 0.125        (database-size overage)
  + max(GB_files − 100, 0)      × 0.021        (file-storage overage)
  + max(peak_conns − 500, 0)/1000 × 10         (realtime overage)
```

You need five measured numbers: `MAU` (done in §1.1), `GB_egress`, `GB_db`, `GB_files`, `peak_conns`.

---

#### 2.1a Storage — `GB_files` (the card images + chat attachments)

**What it is:** total gigabytes of files stored. This is *cumulative* — it only ever grows, because
storing a file never deletes it.

**Where to measure:**
1. Supabase dashboard → **Storage**.
2. Look at the `contact-cards` bucket and the `chat-attachments` bucket.
3. Read **total bytes stored** for each, and the **object count** (number of files).

**Two useful derived numbers:**
- **Total GB_files** = (contact-cards bytes + chat-attachments bytes) ÷ 1,073,741,824. Plug straight into
  the formula.
- **Average file size** = bucket total bytes ÷ object count. This *confirms* the per-unit `avg_card_MB`
  and `avg_attachment_MB` guesses in the main doc. If your measured average is very different from the
  assumed 0.12 MB/card, update the model.

**Also measure the volume (how fast it grows):**
```sql
-- cards created per active user in the last 30 days
SELECT count(*)::float / NULLIF(count(DISTINCT user_id), 0) AS cards_per_user
FROM captures
WHERE created_at > now() - interval '30 days';
```
Run this in Supabase → **SQL Editor**. This gives `cards_per_user_per_mo`.

For attachments, the equivalent table is `message_attachments`:
```sql
SELECT count(*)::float / NULLIF(count(DISTINCT user_id), 0) AS attachments_per_user
FROM message_attachments
WHERE created_at > now() - interval '30 days';
```

**Contact documents (planned — from your analysis).** Your `INFRASTRUCTURE_ANALYSIS.md` formula adds a
contact-documents term:
```
GB_files ≈ MAU × months_live × (cards_per_user × avg_card_MB
                                + attachments_per_user × avg_attachment_MB
                                + total_contact_document_cap) / 1024
```
Today this term is **0** — the `contact_documents` upload path is not wired into the app, so nothing is
stored (confirmed in the AI doc). Keep it in the formula as a **placeholder**: once you build the
uploader, set `total_contact_document_cap` to the per-user cap you decide (your analysis marks the total
cap as "to be decided"), and re-measure the `contact-documents` bucket exactly as you do for the other
two buckets above.

> **Sanity check:** does `GB_files` roughly equal `MAU × months_live × (cards_per_user × avg_card_MB +
> attachments_per_user × avg_attachment_MB + contact_doc_term) / 1024`? If yes, your numbers are
> internally consistent and you can now *project forward* by increasing MAU in that formula.

---

#### 2.1b Bandwidth / egress — `GB_egress`

**What it is:** gigabytes sent *out* of Supabase to users' devices (downloading card images, chat
attachments, and the initial data sync when someone logs in).

**Where to measure:**
- Supabase dashboard → **Reports** → **Bandwidth**. Read the total GB for the month.

**Per-user figure (for projecting):**
```
egress_per_user_per_mo = GB_egress ÷ MAU
```
The main doc assumes ~0.1 GB/user/mo. Replace that assumption with your measured number.

**Formula contribution:** `max(GB_egress − 250, 0) × 0.09`. (You get 250 GB free.)

> **Sanity check:** egress should be in the same ballpark as (initial sync size + card images viewed +
> attachments viewed). If it is *wildly* higher, users are re-downloading images a lot (signed URLs
> expire after 1 hour), which is normal but worth knowing.

---

#### 2.1c Database size — `GB_db`

**What it is:** how many gigabytes your Postgres database occupies (rows + indexes + the pgvector
document chunks). Also cumulative.

**Where to measure:**
- Supabase dashboard → **Reports** → **Database**, or **Settings** → **Usage** shows DB size directly.

**Two things to capture:**
1. **Total `GB_db`** → plug into the formula: `max(GB_db − 8, 0) × 0.125` (8 GB free).
2. **Bytes per contact and per-user contact volume**, so you can project growth:
```sql
-- bytes per row in the biggest table (repeat for captures, interactions, follow_ups, messages)
SELECT pg_total_relation_size('contacts')::float / NULLIF(count(*), 0) AS bytes_per_row
FROM contacts;

-- contacts created per active user in the last 30 days
SELECT count(*)::float / NULLIF(count(DISTINCT user_id), 0) AS contacts_per_user
FROM contacts
WHERE created_at > now() - interval '30 days';
```

**Projection formula:** `GB_db ≈ MAU × contacts_per_user_per_mo × bytes_per_contact × months_live / 1e9`.

> **Sanity check:** the main doc estimates ~2.4 GB at 1,000 MAU × 12 months — comfortably under the 8 GB
> free tier. If your measured DB size is far bigger at low MAU, something (likely `document_chunks`
> vectors from big chat attachments) is heavier than assumed — investigate that table specifically.

---

#### 2.1d Realtime — `peak_conns` (peak concurrent connections)

**What it is:** the *highest number of users connected at the same instant* during the month — NOT the
total for the month. Realtime is billed on the peak, because that's the capacity you reserve.

**The connections-per-user rule (already known from code, no need to measure):**
- Every foregrounded user = **1** connection.
- +1 more **if that user has a chat screen open**.
- Live events add **0** extra.

So: `peak_conns ≈ peak_concurrent_users × (1 + fraction_in_chat)`.

**Where to measure both pieces:**
- Supabase dashboard → **Reports** → **Realtime**. Read the **peak concurrent connections** for the
  month (the highest point on the graph — typically during a live exhibition day).
- **`fraction_in_chat`** = (number of concurrent `messages:{...}` channels at that peak) ÷ (total
  concurrent connections at that peak). The Realtime report breaks down channels; the chat channels are
  the ones named `messages:...`.

**Formula contribution:** `max(peak_conns − 500, 0) / 1000 × 10`. (500 concurrent connections free.)

> **Sanity check:** 500 free connections ≈ 250–500 simultaneously active users. If your pilot peaked at,
> say, 40 people on the show floor with a quarter of them in chat, that's `40 × 1.25 = 50` connections —
> nowhere near 500, so **$0**. Realtime only starts costing money in the low thousands of simultaneous
> users.

---

### 2.2 Google Gemini — AI tokens (§2.2)

**What it is:** you pay per *token* (a token ≈ 4 characters of text; images and audio also convert to
tokens). Gemini bills **input tokens** and **output tokens** at different rates.

```
gemini_monthly = (input_tokens / 1e6) × 0.10  +  (output_tokens / 1e6) × 0.40
               + embedding_tokens × embedding_rate   (usually tiny)
```

**The catch:** Gemini's dashboard gives you *total* tokens, but to project costs you want tokens *per
action* (per card scan, per AI message, etc.). Two ways to get there:

**Method 1 — total tokens off the dashboard (fastest, good enough to start):**
- Go to **Google AI Studio** (or Google Cloud Console → the billing/usage page for the Gemini API).
- Read **total input tokens** and **total output tokens** for the model `gemini-3.1-flash-lite` this month.
- Plug straight into the formula above. Done — that's your real Gemini bill.

**Method 2 — per-action tokens (better for forecasting):**
This is really a PLAN-A measurement (you can do it on one device), but you can also derive it live:
1. Count how many of each action happened this month, from the database:
```sql
-- cards scanned in last 30 days
SELECT count(*) FROM captures WHERE created_at > now() - interval '30 days';

-- enrichments in last 30 days (contacts + companies have an enriched_at timestamp)
SELECT count(*) FROM contacts  WHERE enriched_at > now() - interval '30 days';
SELECT count(*) FROM companies WHERE enriched_at > now() - interval '30 days';

-- assistant messages in last 30 days
SELECT count(*) FROM messages WHERE created_at > now() - interval '30 days';
```
2. Divide total dashboard tokens across these action counts (weighted by how token-heavy each is — a
   card scan with an image is much heavier than a short text message). For a first pass, the per-action
   token counts logged during PLAN-A (see main doc §2.2) are more precise; use those and multiply by the
   counts above.

**Which actions burn tokens (from code):** card scanning, voice transcription, contact enrichment,
company/event enrichment, every AI assistant message (2–5 internal steps each), and document embeddings
for oversized chat attachments.

> **Sanity check:** the AI assistant is usually the biggest token consumer because each user question
> triggers several internal calls. If total tokens seem huge relative to card scans, the assistant is
> the driver — that's expected.

**Free tier:** Flash-Lite has a free tier with daily rate limits, and the code rotates multiple API
keys. At low volume you may pay **$0** — check whether you actually crossed into paid usage before
worrying about this line.

Pricing to confirm: https://ai.google.dev/gemini-api/docs/pricing

---

### 2.3 Exa — web search (§2.3)

**What it is:** you pay per search *request*. The main doc verified the price empirically: **$0.007 per
search** for up to 10 results, and the `highlights` content this app uses adds **$0**.

**Where to measure:**
- **Exa dashboard** → requests this month. That's the authoritative count.
- **Cross-check from the database** — count the actions that trigger searches:
```sql
-- enrichments in last 30 days (each contact = 1–2 searches, each company = 2)
SELECT count(*) FROM contacts  WHERE enriched_at > now() - interval '30 days';
SELECT count(*) FROM companies WHERE enriched_at > now() - interval '30 days';
```
Then: `searches ≈ (2 × company_enrich) + (1–2 × contact_enrich) + (~1.5 × event_preps) + assistant_web_searches`.

**Formula:** `exa_monthly = max(searches − 20000, 0) × 0.007`.

> **Sanity check:** Exa gives **20,000 free requests/month**. That's roughly 10,000 company enrichments.
> For almost any early-stage volume this line is **$0**. Only revisit it if the Exa dashboard shows you
> crossing 20,000 requests in a month.

---

### 2.4 & 2.5 — Deployment (backend + Slayer)

> **You decided on a single server** (`INFRASTRUCTURE_ANALYSIS.md`: *"A server that hosts both the
> backend and slayer"*). That replaces the split Vercel-backend + Railway-Slayer setup the AI doc
> measures. **If you go with the single-server model, use §2.5b below and skip the separate Vercel/Railway
> meters.** The Vercel (§2.4) and Railway (§2.5) instructions are kept for reference in case you stay on
> the managed-PaaS split.

#### 2.5b Single VPS hosting both services (your chosen model)

**What it is:** one always-on virtual server (e.g. Hetzner CX22, 2 vCPU / 4 GB, ~$5/mo) running both the
Node backend and the Slayer container via Docker Compose. Because the two services talk over `localhost`,
there is **zero inter-service egress**, and the price is a **flat monthly fee** — there is almost nothing
to "measure" here, which is the whole point of choosing it.

```
vps_monthly = flat_plan_fee   (+ egress overage only if you blow past the included TB — very unlikely)
```

**Where to measure:**
- The VPS provider's dashboard shows the flat plan price directly — that's your number.
- Watch **RAM/CPU** with `docker stats` on the box (or the provider's metrics graph). This is a
  right-sizing check, not a billing one: if peak RAM stays well under the box's limit, you're fine; if it
  saturates during an OCR + Slayer-query burst, size up one tier.
- Egress: the provider's dashboard shows monthly transfer. Hetzner-class plans include ~20 TB, which this
  app will not approach, so this stays $0.

> **Sanity check:** the main doc §7 recommends **Hetzner CX22 at ~$5/mo** for exactly this — ~8× cheaper
> than the ~$40/mo Vercel + Railway split, with effectively uncapped egress. The trade-off is you own
> patching/TLS/backups (~an hour of setup). This single flat fee *replaces* both §2.4 and §2.5 below.

---

### 2.4 Vercel — backend hosting (§2.4) — only if you keep the PaaS split

**What it is:** $20/mo fixed (Pro, required for commercial use) **plus** usage — but usage is billed on
**Active CPU time**, meaning only the milliseconds your code is *actually computing*, NOT the time it
spends waiting on Gemini/Exa/Supabase to reply. Most of this app's request time is waiting, which is
free. The expensive part is OCR (Tesseract) on card scans.

```
vercel_monthly = 20 + max( active_CPU_hours × 0.128
                         + memory_GB_hours × 0.0106
                         + max(egress_GB − 1000, 0) × 0.15
                         − 20,  0 )        ← the $20 usage credit is subtracted here
```

**Where to measure:**
- Vercel dashboard → **Observability** (or **Usage**) → read **Active CPU**, **Provisioned Memory**,
  **Fast Data Transfer (egress)**, and **invocations** for the month.
- If you want per-route detail, Observability breaks CPU down per function — the OCR route
  (`/ai/analyze-card`) will dominate; the proxy routes that just await Gemini/Exa are near-zero.

> **Sanity check:** with the $20 monthly usage credit and mostly-waiting handlers, a low-traffic
> commercial CRM often stays at exactly the **$20 floor**. The first thing that pushes you over is heavy
> card-scanning (OCR CPU). If your Active CPU hours × $0.128 is under $20, you pay nothing extra.

---

### 2.5 Railway — Slayer container (§2.5) — only if you keep the PaaS split

**What it is:** an always-on 24/7 Python container. You pay for the CPU and RAM it *holds* every hour,
whether or not anyone is using it — **not** per request. $5/mo base includes a $5 usage credit.

```
railway_monthly = 5 + max( vCPU_held × 730 × 0.028
                         + RAM_GB_held × 730 × 0.014
                         + egress_cost
                         − 5,  0 )
```
(730 = hours in a month. $20/vCPU-month and $10/GB-month are the rates, converted to hourly here.)

**Where to measure — this one is readable RIGHT NOW, even pre-launch, because Slayer is already deployed:**
- Railway dashboard → your Slayer service → **Metrics** / **Usage**.
- Read the **actual vCPU and RAM the container holds**, and read the **invoice / Usage tab** for the real
  dollar figure.

> **Sanity check:** the main doc estimates ~$10–20/mo depending on allocation. This is often the *most
> questionable* line — an always-on box for a low-traffic read service. Read the real invoice number; if
> it's high relative to how much the AI assistant is actually used, see the main doc §6 and §7 for
> options (scale to zero, fold into the backend, or move to a cheap VPS).

---

### 2.6 Firebase Hosting — web bundle (§2.6)

**What it is:** hosts the static Flutter *web* build. Storage is tiny and fixed (it's just the app
bundle, ~10–30 MB, and does not grow with users). Egress = bundle size × how many people load the web
app fresh.

```
firebase_hosting_monthly = max(storage_GB − 10, 0) × 0.026 + max(egress_GB − 10, 0) × 0.15
```

**Where to measure:**
- Firebase console → **Hosting** → **Usage**: read **storage used** and **bandwidth (egress)** for the month.
- `cold_web_loads ≈ egress_GB ÷ bundle_GB` tells you how many fresh web loads happened.

> **Sanity check:** 10 GB/mo free egress ÷ a ~10 MB bundle ≈ **1,000 fresh web loads/month before any
> charge**. For a mobile-first CRM this is almost always **$0**. Only matters if you have heavy web usage.

---

### 2.7 Firebase Analytics (§2.7)

**Always free, unlimited.** Nothing to measure. **$0.** Skip it.

---

### 2.8 Sentry — errors + session replay (§2.8)

**Two separate meters:** error events, and **session replays**. The replay one is the dangerous line
because the code currently records a replay for **every single session** (`sessionSampleRate = 1.0`).

```
sentry_monthly = plan_fee
               + max(errors  − errors_included,  0) × error_rate
               + max(replays − replays_included, 0) × 0.00375
```
where `replays ≈ total sessions/mo` (because 100% of sessions are recorded).

**Where to measure:**
- Sentry dashboard → **Stats** / **Usage** → read **errors this month** and **replays this month** directly.
- Free tier: 5K errors + 50 replays. Team ($26–29/mo): 50K errors + 500 replays.

> **Sanity check — this is the biggest avoidable cost in the whole stack.** At 100% replay sampling,
> replays = sessions. 500 included replays run out at ~17 sessions/day. At 30,000 sessions/mo that's
> `(30000 − 500) × 0.00375 ≈ $111/mo` in replay *alone*. **The fix is a one-line config change**
> (lower `sessionSampleRate` to ~0.1) — see main doc §6 item 2. Measure your `sessions/mo` (from §1.2)
> and check whether you're about to hit this before it bills you.

---

### 2.9 UXCam — session recording (§2.9)

**What it is:** a second session recorder (running *alongside* Sentry replay). Free up to **3,000
sessions/month**, and when you exceed that on the free plan, recording simply **stops** — it does not
auto-charge you. Paid tiers are sales-negotiated, so there is no public per-session overage rate.

**Where to measure:**
- UXCam dashboard → **sessions this month**. Compare against the 3,000 free cap.

> **Sanity check:** because it auto-caps rather than auto-billing, UXCam's cost is **$0 unless you have
> signed a paid contract**. The real decision here isn't cost — it's that you're recording every session
> on *both* UXCam and Sentry (overlapping data). Pick one; see main doc §6 item 3.

---

### 2.10 Codemagic — iOS CI builds (§2.10)

**What it is:** you pay per build-minute on Mac hardware. Driven by your *release cadence* (a business
decision), not by user traffic.

```
codemagic_monthly = max(total_build_minutes − 500, 0) × 0.095
```
(500 free M2 minutes/mo on personal accounts.)

**Where to measure:**
- Codemagic dashboard → **Billing** → minutes used this month, and build history for the count.
- `minutes_per_build` = total minutes ÷ number of builds (typically 15–30 min/build).

> **Sanity check:** at a normal release cadence (a handful of builds/month) you stay under 500 free
> minutes → **$0**. Only the $399/mo Team plan matters if you're building constantly, which you're not
> at this stage.

---

## 3. Putting it all together — your filled-in monthly bill

After doing the measurements above, fill this table. Everything in **bold** is a number *you measured*;
the rest is fixed/known.

| Service | Your measured usage | Free allowance | Overage cost | This line's $/mo |
|---|---|---|---|---|
| Supabase base | — | — | — | $25.00 |
| Supabase auth | **MAU = ____** | 100,000 | $0.00325/MAU | |
| Supabase egress | **____ GB** | 250 GB | $0.09/GB | |
| Supabase DB | **____ GB** | 8 GB | $0.125/GB | |
| Supabase storage | **____ GB** | 100 GB | $0.021/GB | |
| Supabase realtime | **____ peak conns** | 500 | $10/1,000 | |
| Gemini | **____ in / ____ out tokens** | free-tier limits | $0.10 in / $0.40 out per 1M | |
| Exa | **____ searches** | 20,000 | $0.007/search | |
| **Deployment (single VPS)** — *your chosen model* | **flat plan** | ~20 TB egress | flat | ~$5.00 |
| *(alt: Vercel base — if PaaS split)* | — | — | — | $20.00 |
| *(alt: Vercel usage — if PaaS split)* | **____ CPU-hr, ____ GB egress** | $20 credit + 1 TB | see §2.4 | |
| *(alt: Railway — if PaaS split)* | **____ vCPU, ____ GB held** | $5 credit | see §2.5 | |
| Firebase Hosting | **____ GB egress** | 10 GB | $0.15/GB | |
| Firebase Analytics | — | unlimited | — | $0.00 |
| Sentry errors | **____ errors** | 5K / 50K | plan-dependent | |
| Sentry replay | **____ replays (≈sessions)** | 50 / 500 | $0.00375/replay | |
| UXCam | **____ sessions** | 3,000 | auto-caps (free) | $0.00 |
| Codemagic | **____ build-minutes** | 500 | $0.095/min | |
| **TOTAL** | | | | **$______/mo** |

**Expected floor at low volume:**
- **On your single-VPS deployment:** roughly **$25 (Supabase) + $5 (VPS) ≈ $30/mo**, plus the amortized
  fixed costs from §0.1 (~$25/mo). So ~**$55/mo all-in** before any usage overage or paid analytics.
- **On the managed-PaaS split (Vercel + Railway):** ~$50–65/mo of base fees instead of $30. That ~$35/mo
  gap is exactly what the single-server choice saves you.

If your total is far above the floor, look at the usual suspect first: **Sentry replay** (§2.8) — at 100%
session sampling it can silently add $100+/mo.

---

## 4. From "this month's bill" to "what it'll cost at 10× the users"

Measuring today's bill is step one. To forecast, take the **per-user** numbers you derived and multiply
by a bigger MAU:

1. Compute each per-user rate: `egress_per_user = GB_egress ÷ MAU`, `cards_per_user`, `tokens_per_user`,
   `sessions_per_user`, etc.
2. Pick a target MAU (e.g. 10× today).
3. Re-run every formula in §2 with the bigger MAU. Watch for the moment each meter crosses its free
   allowance — that's when a line item switches from $0 to a real cost.
4. Remember **storage and DB are cumulative** — multiply them by `months_of_operation`, not just the
   current month, because stored data never shrinks.

**The order things start costing money (from the main doc):**
1. **Sentry replay** — first and biggest, if `sessionSampleRate` isn't lowered. Fix it in config now.
2. **Railway/Slayer** — an always-on box; a fixed ~$10–20 regardless of users.
3. Then, in the low thousands of MAU: Supabase egress, DB, storage, and realtime roughly together.
4. Gemini scales smoothly with AI usage (no cliff, just linear).
5. Exa, Firebase, Codemagic stay ~$0 for a very long time.

---

## 5. Checklist — did you measure everything?

- [ ] MAU (Supabase Auth) — §1.1
- [ ] Sessions/mo (Firebase or UXCam) — §1.2
- [ ] Supabase storage GB + avg file size (Storage) — §2.1a
- [ ] Supabase egress GB (Reports → Bandwidth) — §2.1b
- [ ] Supabase DB size GB + bytes-per-row (Reports → Database) — §2.1c
- [ ] Supabase peak realtime connections + chat fraction (Reports → Realtime) — §2.1d
- [ ] Gemini total input/output tokens (AI Studio / Cloud billing) — §2.2
- [ ] Exa searches this month (Exa dashboard) — §2.3
- [ ] Deployment: single-VPS flat plan fee + peak RAM/CPU right-sizing check — §2.5b **(your model)**
- [ ] *(alt, only if PaaS split)* Vercel Active CPU + egress (Observability) — §2.4
- [ ] *(alt, only if PaaS split)* Railway vCPU/RAM held + invoice — §2.5
- [ ] Firebase Hosting egress (Hosting → Usage) — §2.6
- [ ] Sentry errors + replays (Stats/Usage) — §2.8
- [ ] UXCam sessions vs 3,000 cap (UXCam dashboard) — §2.9
- [ ] Codemagic build-minutes (Billing) — §2.10
- [ ] Filled the §3 table and got a total
- [ ] Forecasted at target MAU (§4)

---

**See also:** [`INFRASTRUCTURE_COSTS.md`](INFRASTRUCTURE_COSTS.md) for the full per-service breakdown,
the code evidence behind every number, the PLAN-A (pre-launch) measurement methods, and the hosting
(VPS vs PaaS) decision.
