# Pre-Launch Cost Modeling Guide — How to Estimate Every Usage Number *Before* You Have Users

**Who this is for:** you are building your first startup, the app is **not live yet**, you have **zero
real users**, and you need a credible monthly-cost estimate anyway — for a budget, a pitch deck, or just
to know your runway.

**The core truth up front:** you **cannot measure** how many users you'll have or how much they'll use
the app before they exist. Anyone who hands you a single "we'll cost $X/mo" number pre-launch is guessing.
The honest, professional way to do this is:

> **Model from your go-to-market plan, produce a range (conservative / expected / aggressive), and treat
> every number as a decision you own — not a fact you discovered.**

This guide shows you how to turn *your business plan* into every usage number the cost formulas need. It
is the pre-launch mirror of measuring from live dashboards (which you'll do later, after a pilot).

> **What you CAN measure now vs. what you must MODEL now:**
> - **Per-unit costs** (MB per card, tokens per AI message, RAM the server holds) — these you **measure
>   today** on one device with a handful of hand-made records. They don't need users. The main doc calls
>   this **PLAN-A**; go do those first, they turn formula constants into facts.
> - **Volume/behaviour** (how many users, how many cards each, peak simultaneous users) — these are
>   **unknowable** pre-launch. This guide is entirely about modeling *these*.
>
> This guide assumes you've already got the per-unit numbers (or are using the main doc's assumed ones)
> and focuses on the volumes.

---

## 0. The one idea everything is built on: derive volume from a business scenario

Every volume number in this whole analysis descends from **one sentence** you write about how you go to
market. The main doc states it directly:

> *"We onboard **N** exhibition teams of **T** reps; a rep scans ~**C** cards per show day over **D** show
> days per month."*

Once you commit to that sentence, almost every usage number is arithmetic:
- `MAU = N × T`
- `cards/user/mo = C × D`
- `total cards/mo = N × T × C × D`

You are not "guessing" `cards_per_user_per_mo = 40` out of thin air — you are *deciding* "our reps work
~4 show days a month and scan ~10 cards a day." That's a claim you can defend, revise, and be held to.
**State the sentence explicitly in your budget** so every number traces back to it.

### Always model three scenarios, never one point

A single number is a lie by omission — you don't know it. Instead pick three versions of your scenario:

| Scenario | Meaning | Use it for |
|---|---|---|
| **Conservative** | Slow adoption, light usage. The "did we waste money?" floor. | Worst-case runway |
| **Expected** | Your honest best guess. | The headline budget number |
| **Aggressive** | Fast growth, heavy usage. The "can we afford success?" ceiling. | Stress-testing / fundraising |

Plug each into the formulas → you get a **low–mid–high cost band**. That band *is* the honest answer.

---

## 1. The worked example scenario used throughout this guide

To make every section concrete, this guide carries **one invented scenario**. **Replace these numbers
with your own plan** — they are placeholders to show the method, not predictions about your business.

> **Our go-to-market sentence (invented):** *"In year one we onboard exhibition sales teams. Each team is
> ~10 reps. A rep works ~4 exhibition days per month and scans ~10 business cards per show day. Reps
> enrich about half the contacts they scan, ask the AI assistant a few questions per active day, and
> occasionally attach a document to a chat."*

From that sentence, three scenarios (differing mainly in **how many teams** we sign and **how hard** each
rep uses the app):

| Input (per the sentence) | Conservative | Expected | Aggressive |
|---|---|---|---|
| Teams signed (N) | 2 | 10 | 40 |
| Reps per team (T) | 10 | 10 | 10 |
| **MAU = N×T** | **20** | **100** | **400** |
| Show days/rep/mo (D) | 2 | 4 | 6 |
| Cards/show day (C) | 6 | 10 | 15 |
| **Cards/user/mo = C×D** | **12** | **40** | **90** |
| Enrichments/user/mo (~half of cards) | 6 | 20 | 45 |
| Assistant messages/user/mo | 5 | 20 | 60 |
| Chat attachments/user/mo | 0.5 | 2 | 5 |
| App opens (sessions)/user/mo | 8 | 20 | 40 |
| Peak % of MAU active at once (show day) | 60% | 70% | 80% |
| Fraction of active users with chat open | 20% | 25% | 40% |
| Months of operation modeled (M) | 12 | 12 | 12 |

Everything below plugs these into the cost formulas. **Your job:** rewrite this table with your own
scenario, then follow the same steps.

> **Where each row comes from — so you can justify yours:**
> - **Teams (N)** = your actual sales pipeline / signed LOIs. This is the number you have the most real
>   control over — use your pipeline, not hope.
> - **Reps per team (T)** = ask one target customer how big their exhibition team is.
> - **Show days (D) & cards/day (C)** = the nature of the job. Ask a rep, or look at an exhibition
>   calendar. This is domain knowledge, not math.
> - **Enrichment / assistant / attachment rates** = *feature-adoption assumptions*. These are the softest
>   numbers; keep the conservative/aggressive spread wide here because you genuinely don't know how much
>   people will lean on AI features until they do.
> - **Peak % & chat fraction** = crowd behaviour on a show day. Model from the event shape ("one team all
>   on the floor at once" → peak ≈ the whole team).

---

## 2. Modeling each parameter, category by category

For each category: the parameter to model, **how to reason about it from your scenario**, the formula,
and the worked result for all three scenarios.

Per-unit constants used below (from the main doc's PLAN-A assumptions — **replace with your measured
ones**): `avg_card_MB ≈ 0.12` (post-compression), `avg_attachment_MB ≈ 2` (document-heavy),
`bytes_per_contact ≈ 5 KB`.

---

### 2.1 MAU — Monthly Active Users

**The master number. Everything else scales off it.**

**How to model it:** `MAU = teams_signed × reps_per_team`. Do **not** pull MAU from "the market is 100,000
exhibition reps, we'll get 1%." That top-down method is fiction pre-launch. Use **bottom-up**: how many
teams can your sales effort actually sign and onboard in the period? That's a number you own.

- Conservative: 2 × 10 = **20**
- Expected: 10 × 10 = **100**
- Aggressive: 40 × 10 = **400**

> **Reality check on the free tiers:** Supabase includes 100,000 MAU. You are *nowhere near* paying for
> auth. MAU matters here not because auth costs money, but because it multiplies every *other* usage
> number.

---

### 2.2 Cards scanned per user per month

**How to model it:** `cards/user/mo = show_days_per_month × cards_per_show_day`. Both come straight from
the job: how often is a rep at an exhibition, and how many cards do they collect there? This is the single
most important volume number for storage and for Gemini card-scan tokens.

- Conservative: 2 × 6 = **12/user/mo**
- Expected: 4 × 10 = **40/user/mo**
- Aggressive: 6 × 15 = **90/user/mo**

**Total cards/mo = MAU × cards/user/mo:**
- Conservative: 20 × 12 = **240**
- Expected: 100 × 40 = **4,000**
- Aggressive: 400 × 90 = **36,000**

> **Note the burstiness:** exhibitions are seasonal. A rep may scan 40 cards in a show month and 0 in a
> quiet month. Modeling a flat monthly average is fine for budgeting, but expect real months to spike.

---

### 2.3 Attachments per user per month

**How to model it:** this is a *feature-adoption* guess, not a job fact — you don't know how much reps
will attach files to AI chats. Anchor it as a **small fraction of assistant messages**: most messages have
no attachment. Keep a wide spread because it's genuinely uncertain.

- Conservative: **0.5/user/mo** · Expected: **2/user/mo** · Aggressive: **5/user/mo**

> **Honesty flag:** if you have no basis at all, say so in the budget ("attachments modeled at 2/user/mo,
> pure assumption, revisit after pilot") rather than dressing it up as known. The conservative case
> protects you if it's higher than expected.

---

### 2.4 Contacts created per user per month (drives DB size)

**How to model it:** essentially equals cards scanned (each scanned card becomes a contact), plus any
manually-added contacts. For simplicity, model `contacts/user/mo ≈ cards/user/mo`.

- Conservative: **12** · Expected: **40** · Aggressive: **90**

---

### 2.5 Enrichments per user per month (drives Exa + some Gemini)

**How to model it:** a fraction of contacts get enriched (the rep taps "enrich" to pull web data). Model
as a fraction of cards — the sentence says "about half."

- Conservative: **6** · Expected: **20** · Aggressive: **45** per user/mo

---

### 2.6 Assistant messages per user per month (drives most Gemini tokens)

**How to model it:** `messages/user/mo ≈ active_days × messages_per_active_day`. The AI assistant is
usually the biggest token consumer, so this number matters a lot for the Gemini bill.

- Conservative: **5** · Expected: **20** · Aggressive: **60** per user/mo

---

### 2.7 Sessions (app opens) per user per month (drives Sentry replay + UXCam)

**How to model it:** how many times does a rep open the app in a month? On show days, several times a day;
on quiet days, rarely. Model `sessions/user/mo`.

- Conservative: **8** · Expected: **20** · Aggressive: **40** per user/mo

**Total sessions/mo = MAU × sessions/user/mo:**
- Conservative: 20 × 8 = **160** · Expected: 100 × 20 = **2,000** · Aggressive: 400 × 40 = **16,000**

> **Why this one is dangerous:** Sentry currently records a replay for **every** session (§2.11). At the
> aggressive 16,000 sessions/mo, that's 16,000 billable replays. Model it now so it doesn't surprise you.

---

### 2.8 Peak concurrent users & fraction-in-chat (drives Supabase Realtime)

**These are the trickiest to model** because they're about *simultaneity*, not totals. You don't model
them from monthly volume — you model them from **crowd behaviour on the busiest moment**.

**How to reason:** the busiest instant is a show day when a whole team is on the floor using the app at
once. So:
- `peak_concurrent_users ≈ MAU × peak_active_fraction` (what share of all users are online at the peak
  moment). For a single-region, single-event product, the peak is roughly "one big team all active."
- `fraction_in_chat` = what share of those have a chat screen open (each adds a 2nd connection).

Then the code-derived rule (exact, no modeling needed): each user = 1 connection, +1 if chat is open.

```
peak_connections ≈ peak_concurrent_users × (1 + fraction_in_chat)
```

| | Conservative | Expected | Aggressive |
|---|---|---|---|
| MAU | 20 | 100 | 400 |
| peak active fraction | 60% | 70% | 80% |
| peak_concurrent_users | 12 | 70 | 320 |
| fraction_in_chat | 20% | 25% | 40% |
| **peak_connections** | 12×1.2 = **14** | 70×1.25 = **88** | 320×1.4 = **448** |

> **Reality check:** Supabase includes **500** concurrent connections. Even the aggressive case (448) is
> under it → **realtime is $0** across all three scenarios. Realtime only bites in the low thousands of
> simultaneous users. Good to know you don't need to worry about it yet.

---

## 3. Plugging the modeled volumes into every cost formula

Now combine the modeled volumes with the known rates and free tiers. Fixed fees first, then each usage
meter, for all three scenarios.

### 3.0 Fixed costs (don't scale with users — from your INFRASTRUCTURE_ANALYSIS.md)

| Fixed cost | Amount | As $/mo |
|---|---|---|
| Google Play (one-time) | $25 | ~$2/mo over year 1 |
| Apple Developer | $99/yr | ~$8.25/mo |
| Domain | ~$200/yr | ~$16.67/mo |
| **Fixed subtotal** | | **~$27/mo** (year 1) |

### 3.1 Supabase (base $25/mo)

```
supabase = 25
  + max(MAU−100000,0)×0.00325
  + max(GB_egress−250,0)×0.09
  + max(GB_db−8,0)×0.125
  + max(GB_files−100,0)×0.021
  + max(peak_conns−500,0)/1000×10
```

**GB_files** = `MAU × M × (cards/user × avg_card_MB + attach/user × avg_attach_MB) / 1024`
(contact-documents term is 0 until that feature ships — see your analysis):
- Conservative: 20 × 12 × (12×0.12 + 0.5×2) / 1024 = 20×12×2.44/1024 ≈ **0.57 GB**
- Expected: 100 × 12 × (40×0.12 + 2×2) / 1024 = 100×12×8.8/1024 ≈ **10.3 GB**
- Aggressive: 400 × 12 × (90×0.12 + 5×2) / 1024 = 400×12×20.8/1024 ≈ **97.5 GB**
→ all **under 100 GB free → $0 storage** in every scenario.

**GB_db** = `MAU × contacts/user × bytes_per_contact × M / 1e9`:
- Conservative: 20×12×5000×12/1e9 ≈ **0.014 GB**
- Expected: 100×40×5000×12/1e9 ≈ **0.24 GB**
- Aggressive: 400×90×5000×12/1e9 ≈ **2.16 GB**
→ all **under 8 GB free → $0 DB**.

**GB_egress** ≈ `MAU × 0.1 GB/mo` (replace 0.1 with your PLAN-A composed figure):
- Conservative: **2 GB** · Expected: **10 GB** · Aggressive: **40 GB**
→ all **under 250 GB free → $0 egress**.

**Realtime:** peak_connections 14 / 88 / 448 → all **under 500 → $0**.

**Supabase total = $25/mo flat in all three scenarios** (you're inside every free tier).

### 3.2 Gemini (usage only)

You need per-call token counts (PLAN-A — measure these). Once you have them, total tokens =
`Σ (action_count × tokens_per_action)`. With the free tier and Flash-Lite's low rates ($0.10/1M in,
$0.40/1M out), at these volumes Gemini is **single-digit dollars to low-tens** even in the aggressive
case — the assistant messages dominate. **Do not report a Gemini dollar figure until you've logged
per-call tokens** (main doc §2.2); the formula is ready, the per-unit input is the missing piece.

Modeled action counts to multiply (per month):

| Action | Conservative | Expected | Aggressive |
|---|---|---|---|
| Card scans (MAU×cards/user) | 240 | 4,000 | 36,000 |
| Enrichments (MAU×enrich/user) | 120 | 2,000 | 18,000 |
| Assistant messages (MAU×msgs/user) | 100 | 2,000 | 24,000 |

Multiply each by its measured tokens/call, sum input and output separately, apply the rate.

### 3.3 Exa (usage only)

```
searches ≈ 2×contact_enrich + 2×company_enrich + ~1.5×event_preps + ~1.5×assistant_searches
cost = max(searches − 20000, 0) × 0.007
```
Approximating enrichments as ~2 searches each:
- Conservative: 120×2 = **240 searches** · Expected: 2,000×2 = **4,000** · Aggressive: 18,000×2 = **36,000**
→ Conservative & Expected are **under the 20,000 free tier → $0**. Aggressive:
`(36,000 − 20,000) × $0.007 = $112/mo`. So only the aggressive scenario pays anything, and only once
you're doing ~18,000 enrichments/month (400 users each enriching 45 contacts). A comfortable free ride
until then.

### 3.4 Deployment — single server (your chosen model)

Flat **~$5/mo** (e.g. Hetzner CX22, 2 vCPU / 4 GB, ~20 TB egress) hosting backend + Slayer together. No
per-request billing, effectively uncapped egress. **Same $5 in all three scenarios** — that's the point of
choosing a flat VPS over per-usage PaaS. (If you instead stayed on Vercel+Railway: ~$40/mo base regardless
of scenario.)

### 3.5 Sentry replay (the one to watch)

```
replays ≈ total sessions/mo   (while sessionSampleRate = 1.0)
cost = plan_fee + max(replays − replays_included, 0) × 0.00375
```
Sessions/mo: 160 / 2,000 / 16,000. On the Team plan (500 replays included):
- Conservative: 160 → under 500 → **$0 replay** (just plan fee)
- Expected: (2,000−500)×0.00375 ≈ **$5.6/mo**
- Aggressive: (16,000−500)×0.00375 ≈ **$58/mo**

> **This is avoidable.** Lowering `sessionSampleRate` to 0.1 cuts these by 10× (main doc §6). Model it
> both ways and decide before launch.

### 3.6 Firebase Hosting / Analytics / UXCam / Codemagic

- **Firebase Hosting:** egress = cold web loads × bundle size; a mobile-first CRM stays **$0** (10 GB free
  ≈ 1,000 web loads/mo).
- **Firebase Analytics:** **$0**, always free.
- **UXCam:** free to 3,000 sessions/mo, then recording *stops* (no auto-bill). Conservative/Expected are
  under 3,000; Aggressive (16,000) would hit the cap → either accept capped recording or negotiate a paid
  tier. Model as **$0** unless you sign a contract.
- **Codemagic:** driven by release cadence (your decision), not users. A few builds/mo → **$0** (500 free
  minutes).

---

## 4. The bottom line — your modeled cost band

| Line item | Conservative | Expected | Aggressive |
|---|---|---|---|
| Fixed (Play/Apple/domain, amortized) | ~$27 | ~$27 | ~$27 |
| Supabase | $25 | $25 | $25 |
| Deployment (single VPS) | $5 | $5 | $5 |
| Exa | $0 | $0 | ~$112 |
| Sentry (plan + replay @ 100%) | ~$0–26 | ~$32 | ~$84 |
| Gemini | *measure tokens first* | *measure tokens first* | *measure tokens first* |
| Firebase / UXCam / Codemagic | $0 | $0 | $0 |
| **Modeled total (ex-Gemini)** | **~$57–83/mo** | **~$89/mo** | **~$253/mo** |

**Add Gemini once you've logged per-call tokens** — likely single-digit to low-tens of dollars until the
aggressive scenario. The headline for a budget: **"~$90/mo expected, ranging ~$60–250/mo depending on how
many teams we sign and how heavily they use AI features, plus Gemini token usage (pending measurement)."**

That sentence — a **range tied to a stated scenario**, not a single fabricated number — is the correct
pre-launch answer.

---

## 5. What to do with this

1. **Rewrite §1's scenario table with your real go-to-market plan.** Every downstream number recomputes.
2. **Measure the per-unit constants now** (PLAN-A, main doc §0) — `avg_card_MB`, tokens/call,
   `bytes_per_contact`, server RAM. These replace the placeholder constants and cost nothing to get.
3. **Report the range, name the scenario, flag the assumptions.** Don't claim precision you don't have.
4. **Decide the two config levers before launch:** Sentry `sessionSampleRate` (§3.5) and UXCam-vs-Sentry
   (you're recording on both). Both are free savings.
5. **After your first pilot exhibition, switch to live measurement** — read the real numbers off the
   dashboards and replace the whole model with facts. Until then, this modeled band is your best honest
   estimate.

---

**See also:** [`INFRASTRUCTURE_COSTS.md`](INFRASTRUCTURE_COSTS.md) (full per-service breakdown + PLAN-A
per-unit measurement methods) and [`INFRASTRUCTURE_ANALYSIS.md`](INFRASTRUCTURE_ANALYSIS.md) (your own
condensed analysis with the fixed costs, contact-documents storage term, and single-server deployment
decision this guide follows).
