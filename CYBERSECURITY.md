# READ FIRST — Remediation framework (how to fix a finding like an attacker)

> **This section is mandatory for any LLM or engineer about to remediate a finding in this document.** Read it before touching code. It exists because on 2026-06-24 a "fix" that compiled cleanly and read correctly nonetheless *introduced* a live cross-tenant read+write hole (finding **B12**), which was caught only because the fix was attacked, not reasoned about. Fixing security is not the same as writing correct code. Adopt the mindset below.

## Prime directive: a vulnerability is not fixed until you have failed to exploit it

You do not get to *declare* something fixed. You get to *try to break it and fail*. "I added a check / the types pass / I read the code and it looks right" is **not** evidence — it is a hypothesis. The only evidence is an exploit attempt that is now blocked, run against something as close to production as you can reach. Security controls fail **silently** (RLS returns 0 rows; an auth check short-circuits; a filter quietly matches nothing) — so the absence of an error proves nothing. Prove the *negative*: the attack that worked before now returns blocked/empty/403, and the legitimate path still works.

## Think like the attacker, not the author

The author asks "does my change do what I intended?" The attacker asks "what does this change let me do that you didn't intend?" Always take the second view. For every fix, enumerate concretely:
- **Who is the adversary?** Usually a second authenticated tenant (User B) targeting User A. Sometimes `anon`, sometimes a malicious value in attacker-controlled data (an imported contact's `notes`, a filename, a JWT claim, a parsed document).
- **What do they know?** Assume they know resource UUIDs (IDOR), can read your client code, can craft arbitrary request bodies/headers/params, and can call any route in any order. Never rely on a value being "hard to guess" or "not exposed in the UI."
- **What is the crown-jewel action?** Cross-tenant *read* is bad; cross-tenant *write* is worse; privilege escalation / auth bypass is worst. Test the worst case, not just the obvious one.

## The remediation loop (run this for every finding)

1. **Reproduce the exploit first.** Before changing anything, demonstrate the hole as the attacker (DB role impersonation, or a real HTTP call as User B). If you cannot reproduce it, you do not understand it well enough to fix it — and you won't be able to prove the fix.
2. **Find the root cause, not the symptom.** Patching one route leaves the same class open in the next. Prefer *structural* fixes that make the whole class impossible (e.g. RLS enforcing tenancy in the database) over per-handler filters that drift. When you do a structural fix, see step 4 — structural changes have structural side effects.
3. **Apply the minimal correct change.** Don't expand blast radius. Preserve legitimate behaviour. Keep deliberate exceptions explicit and justified (e.g. a `service_role`/admin path) so the next reader doesn't mistake intent for oversight.
4. **Hunt for what the fix *activates or shifts*.** This is the step that catches B12-class bugs. Changing the enforcement layer can wake dormant misconfigurations:
   - Moving off a bypass-everything client (`service_role`/admin) **activates every previously-dormant RLS policy** — any permissive `USING(true)` policy granted to `public`/`anon`/`authenticated` becomes a live, table-wide hole the instant the scoped client touches that table.
   - Adding `WITH CHECK` makes inserts that omit the ownership column start *failing* (functional break, also worth catching).
   - Per-row RLS validates the *new row's* `user_id`, NOT body-supplied **foreign keys** — a route that inserts a row with the caller's `user_id` but an attacker-supplied `event_id`/`contact_id` passes RLS while still cross-linking another tenant's data (cf. R-02 / R-04). RLS is not foreign-key authorization.
   - Tightening one route can push attackers to a sibling route that shares the resource. Check siblings.
5. **Re-test: exploit blocked AND happy path intact.** Run the original exploit again — it must now fail. Then run the legitimate flow end-to-end — it must still succeed. Both halves are required; a fix that also breaks real usage is not done.
6. **Sweep for the whole class.** One instance found usually means siblings exist. After the fix, query/grep for the *pattern*, not the single case (see the standing checks below), and confirm the sweep comes back clean.
7. **Document honestly in this file.** Mark exactly what is fixed (with how it was verified), what the fix newly uncovered, and what remains open. **Never mark something fixed that you only reasoned about.** "Read-scoping is not write protection" — be precise about the boundary of what you actually closed.

## Verification techniques that actually prove things (Supabase/Postgres + Express)

- **DB-level tenant impersonation (fastest, most reliable for RLS):**
  ```sql
  begin;
  set local role authenticated;
  set local request.jwt.claims = '{"sub":"<VICTIM-or-ATTACKER-uuid>","role":"authenticated"}';
  -- now attempt the cross-tenant SELECT / UPDATE / INSERT and observe row counts / RLS errors
  rollback;
  ```
  This runs the exact policy stack the user client runs. A successful cross-tenant `UPDATE ... RETURNING` is a confirmed write hole; `new row violates row-level security policy` is a confirmed block.
- **Live HTTP pen-test:** mint two real JWTs (create confirmed users via the admin API, then log in through the app's own `/auth/login`), and replay the attack as User B against User A's resource over real routes. This catches route-layer issues RLS-only testing misses (wrong client used, missing middleware, error-status leaks, body-supplied FK not validated).
- **Standing sweeps after any access-control / RLS change — all must return empty:**
  - No permissive backdoor policy reachable by user roles:
    ```sql
    select tablename, policyname from pg_policies
    where schemaname='public' and (qual='true' or with_check='true')
      and ('public'=any(roles::text[]) or 'anon'=any(roles::text[]) or 'authenticated'=any(roles::text[]))
      and 'slayer_readonly' <> all(roles::text[]);
    ```
  - No tenant table left RLS-enabled-but-not-forced (owner bypasses RLS):
    ```sql
    select relname from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relkind='r' and c.relrowsecurity and not c.relforcerowsecurity;
    ```
  - No route still on the bypass client where it shouldn't be: `grep -rln "config/supabase'" backend/src/routes` should list only the deliberately-admin files.
- **Always clean up test artifacts** (throwaway users + their rows) and stop any server you started.

## Non-negotiables

- Don't weaken a control to make a test pass. Don't disable RLS "temporarily." Don't broaden a CORS/policy/scope to unblock a flow — fix the flow.
- Confirm before destructive or outward-facing actions; production DDL and data changes are real.
- Report faithfully: if you didn't run the HTTP test, say so; if a step was skipped, say so; if something is only *partially* fixed, label the exact residue. An overstated "fixed" is worse than an honest "open" because it stops anyone from looking again.

---

# Cybersecurity Audit — Exono CRM

**Scope:** Flutter client (`exono/`) + Express/Supabase backend (`backend/`) + Slayer semantic read layer (`slayer/`) + Supabase project `ezammzqvbjgpuzleqmla`.
**Standards:** **OWASP Top 10:2025** (web/API), OWASP API Security Top 10:2023, OWASP Mobile Top 10:2024, OWASP LLM Top 10.
**Audit date:** 2026-06-30 (full re-audit against the current codebase; supersedes the 2026-06-24/25/26 passes).
**Method:** Every backend route, the decomposed assistant module (`src/assistant/`), the Supabase live schema/policies/advisors (via MCP), `npm audit`, and the Flutter client were re-traced from facts. Live DB state was queried directly; nothing below is assumed.

## Remediation status at a glance (updated 2026-06-30)

| ID | Finding | Sev | Status | How verified |
|---|---|---|---|---|
| **B2** | `companies` write authorization wide open | 🔴 | ✅ Fixed | DB tenant-impersonation: attacker→403, owner→allowed; tsc clean |
| **B3** | Vulnerable deps (`xlsx` SheetJS, `uuid`) | 🟠 | ✅ Fixed | `xlsx` dropped for `exceljs` + proto-pollution guard; `npm audit` re-run |
| **B7** | Prompt injection in legacy LLM endpoints | 🟠 | ✅ Fixed | DB-derived text fenced via `fenceUntrusted`; tsc clean |
| **B9** | `SECURITY DEFINER` RPCs callable by anon | 🟡 | ✅ Fixed | Live `routine_privileges` query: anon revoked on all 5 |
| **B10** | File-upload validation / avatars bucket listing | 🟠 | ✅ Fixed | `/upload` stub removed; avatars listing policy dropped |
| **B11** | No rate limiting on `/auth/*` | 🟡 | ✅ Fixed (app-layer) | IP-keyed `express-rate-limit` on login/signup/refresh + `trust proxy`; tsc clean. *Leaked-password protection = console toggle, see note* |
| **B12** | `contact_events` allow-all policy | 🔴 | ✅ Fixed (prior) | Permissive-policy sweep empty |
| **B13** | `scoped_rate_limits` RLS-enabled-no-policy | 🟡 | ✅ Fixed | Explicit deny-all policy + comment |
| **B14** | 4 tenant tables not `FORCE`d | 🟡 | ✅ Fixed | No-FORCE sweep returns only the deny-all exception |
| **B15** | `vector` extension in `public` | 🟡 | ✅ Fixed | Moved to `extensions`; RAG operator smoke-tested |
| **B16** | Mutable `search_path` on 2 functions | 🟡 | ✅ Fixed | `pg_proc.proconfig` confirms pin |
| **C1** | Auth tokens in plaintext `SharedPreferences` | 🔴 | ✅ Fixed | `flutter_secure_storage`; plaintext-key sweep empty; analyze clean |
| **C2** | Offline Drift DB unencrypted | 🔴 | ✅ Fixed (device build pending) | SQLCipher + secure-storage key; analyze clean |
| **C7** | Import upload client-side caps | 🟡 | ✅ Fixed | Picker allowlist + 10 MB cap; analyze clean |
| **C8** | No binary hardening / tamper detection | 🟡 (info) | ✅ Fixed | Obfuscation in CI (root/jailbreak warning later removed per owner) |
| **C9** | Offline identity cache at-rest | 🟠 | ✅ Fixed | Identity cache moved to secure storage (with C1) |
| — | Standing sweeps (backdoor policy, no-FORCE) | — | ✅ Empty | Re-run post-fix; both clean |

**Open / not in this remediation pass (tracked, not fixed here):** B11 residuals — *leaked-password protection* (Supabase console toggle) and *security alerting* on auth anomalies (A09) remain; the rate limiter is in-memory (per-process) so a hard global cap needs a shared store. C4 (cert pinning) not added. C6 (Firebase rules / GCP API-key restrictions) require console verification. B2 still wants a live HTTP replay; C2 wants a physical-device smoke build to confirm SQLCipher native linkage. Create-path anti-junk on `POST /companies` deliberately deferred (residual abuse risk).

> **Severity legend:** 🔴 Critical · 🟠 High · 🟡 Medium · 🟢 Good practice / informational

## Executive summary — what changed since the last audit

The backend has matured substantially. The big structural wins from the 2026-06-24/25 remediation hold and have been **independently re-verified against the live database** on 2026-06-30:

- **RLS is the enforcement layer for tenant data.** 13 route files use the per-request RLS-bound user client (`req.supabase`). The permissive-backdoor sweep returns **empty** (B12 stays closed). Tenant tables are `FORCE ROW LEVEL SECURITY` (with a few new-table exceptions called out in B14).
- **IDOR class is closed structurally.** `contacts.ts` and `events.ts` both have `router.param('id')` ownership guards; the `captures`/contact-link **body-supplied-FK** holes (R-02/R-04) are closed with explicit ownership prechecks.
- **New defensive infrastructure exists** that did not at the last audit: a persistent scoped rate limiter (`utils/rateLimit.ts` + `scoped_rate_limits`), magic-byte image validation (`utils/imageValidation.ts`), DoS-guarded document extraction, prompt-injection sanitisation + untrusted-content fencing in the assistant (`assistant/security.ts`), a user-permission gate for all AI write tools, CORS fail-closed in production, a non-leaking error handler, and web frontend security headers (Firebase Hosting).
- **`npm audit` dropped from 15 → 3** (`ws` fixed). `xlsx` (high) remains unfixable via npm.

**The material risk now lives in two places:** (1) the **`companies` write path** (B2) is still wide open — any authenticated user can create/modify any company record as service_role with no ownership check; and (2) the **Flutter client at-rest storage** (C1/C2/C9) — auth tokens, the offline Drift DB, and the cached identity are all unencrypted `SharedPreferences`/plaintext SQLite. New, smaller items: a no-policy RLS table, new `SECURITY DEFINER` RPCs exposed to `anon`, and three tenant tables not `FORCE`d.

## OWASP Top 10:2025 — taxonomy used in this report

| 2025 ID | Category | Notable change from 2021 |
|---|---|---|
| A01:2025 | Broken Access Control | Still #1; **SSRF now folded in here** |
| A02:2025 | Security Misconfiguration | Up from #5 → #2 |
| A03:2025 | **Software Supply Chain Failures** | **New** (expands old "Vulnerable & Outdated Components") |
| A04:2025 | Cryptographic Failures | Down #2 → #4 |
| A05:2025 | Injection | Down #3 → #5 |
| A06:2025 | Insecure Design | — |
| A07:2025 | Authentication Failures | — |
| A08:2025 | Software or Data Integrity Failures | — |
| A09:2025 | Security Logging and Alerting Failures | Renamed; now includes alerting |
| A10:2025 | **Mishandling of Exceptional Conditions** | **New** — error handling, failing open, logic errors |

Sources: [OWASP Top 10:2025](https://owasp.org/Top10/2025/) · [OWASP API Security Top 10](https://owasp.org/API-Security/) · [OWASP Mobile Top 10](https://owasp.org/www-project-mobile-top-10/) · [OWASP LLM Top 10](https://genai.owasp.org/llm-top-10/)

---

## Architectural context (read first — current as of 2026-06-30)

The backend now runs **three** Supabase clients with deliberate, distinct roles ([backend/src/config/supabaseClients.ts](backend/src/config/supabaseClients.ts)):

1. **`req.supabase`** — a per-request **RLS-enforced** client running as the `authenticated` role, created in [requireAuth.ts](backend/src/middleware/requireAuth.ts) from the caller's bearer token. **This is the default for tenant data.** 13 route files use it: `events`, `contacts`, `captures` (reads), `emails`, `sync`, `import`, `export`, `dashboard`, `ai`, `followUps`, `attachments`, `documents`, `interactions`.
2. **`supabaseAuth`** — anon-key client used **only** for auth operations (`getUser`, `signIn`, `refresh`). Never runs `.from()` queries. Keeps auth session state off the admin client.
3. **`supabaseAdmin`** (aliased `supabase`) — **service_role, bypasses RLS entirely.** Deliberately retained for: `companies.ts` (shared-reference pool, no `user_id`), `auth.ts` (auth flows), `assistant.ts` + all `assistant/` executors (AI agent — ownership enforced in code, see "Assistant" section), `conversations.ts` partial paths, `captures.ts` company find-or-create (companies are global), the rate limiters, and enrichment. Every service_role write to tenant data MUST enforce ownership in code; RLS does not protect these paths.

**The single most important standing invariant:** any route on `req.supabase` is structurally tenant-isolated by RLS; any route on `supabaseAdmin` is only as safe as its hand-written ownership checks. The audit below is largely a check that (a) the right client is used per route, and (b) every `supabaseAdmin` tenant write has a correct ownership/FK guard.

All ~20 public tables have `rls_enabled: true`. The permissive-policy sweep is **empty** (verified 2026-06-30) — no `USING(true)`/`WITH CHECK(true)` policy is reachable by `public`/`anon`/`authenticated`.

---

# Backend findings

## 🔴 Critical

### B2. `companies` write authorization is wide open — **A01:2025** · API1/API3:2023 — ✅ **FIXED 2026-06-30 (PATCH linkage-gated; DB-impersonation verified)**

> **Fix applied & verified.** `PATCH /companies/:id` ([companies.ts](backend/src/routes/companies.ts)) now calls `ownsCompanyLinkage(companyId, userId, req)` at the top of the handler (using the RLS client `req.supabase`) and returns **403** unless the caller owns a `contact` (`company_id = :id`, not soft-deleted) **or** a `target_companies` row (`company_id = :id`) for that company. `companyPatchSchema` is unchanged (descriptive/enrichment fields stay AI-only). `POST /companies` deliberately stays open (shared pool; unbounded-create residual abuse risk accepted per decision). **Verified by DB tenant impersonation (rolled back):** as the attacker tenant the linkage query returned **0/0** → 403; as the owning tenant it returned **1** → allowed. `npx tsc --noEmit` clean. Coupled B7 fencing applied (see below). *Residual:* live HTTP replay with two real JWTs still recommended to close the loop end-to-end at the route layer.

Original finding (for reference):
This is the most serious remaining backend hole. [backend/src/routes/companies.ts:199-243](backend/src/routes/companies.ts#L199-L243):
- `POST /companies` and `PATCH /companies/:id` both run on `supabaseAdmin as supabase` (**service_role, RLS bypassed**) with **no ownership or linkage check** — only Zod body validation and a UUID check on `:id`.
- The `companies` table has **no `user_id` column** and is a single global shared pool. Reads were RLS-scoped during the migration (2 SELECT policies, verified: a user sees only companies linked via an owned `contact`/`target_company`), but **writes were never scoped**.

**Attack — LIVE-EXPLOITED 2026-06-30 (DB tenant impersonation, rolled back):** using two real tenants from the live project, I proved the exact read/write asymmetry:
- As tenant B (RLS-enforced `authenticated` role, the stack `req.supabase` uses), `SELECT` of tenant A's company `a1c4b9b0-…` ("Alphabet") returned **0 rows** — reads are protected.
- As tenant B via the RLS user client, `UPDATE companies … WHERE id=A's-company` touched **0 rows** — RLS would block it *if the route used `req.supabase`*.
- But the route uses **service_role**. Running the handler's literal statement `update companies set description='PWNED-by-tenantB-no-ownership-check' where id='a1c4b9b0-…'` under the RLS-bypassing (service_role-equivalent) role **succeeded — 1 row updated**, returning the poisoned "Alphabet" record. Transaction rolled back; no data harmed.

So any authenticated user can `PATCH /companies/:id` for *any* company UUID and overwrite its `name`, `description`, `website`, enrichment fields, etc. Because company descriptions/enrichment text flow into AI briefings and insight prompts (see B7), this is also a **stored-prompt-injection delivery vector into another tenant's LLM context**. A user can also create unbounded junk companies.

**Impact:** cross-tenant data **integrity** compromise (poisoning shared records, confirmed live) + a cross-tenant prompt-injection channel. Not a direct PII *read* (reads are scoped), but a write/integrity + AI-injection hole.

**Agreed fix (2026-06-30) — shared-reference table with linkage-gated hint writes:**

The descriptive/enrichment fields (`description`, `products_services`, `headquarters`, etc.) are **already** AI-system-managed — `companyPatchSchema` ([companies.ts:23](backend/src/routes/companies.ts#L23)) only exposes `location`, `website`, `industry`, which are user-supplied **re-research hints** consumed by `POST /:id/enrich`. (Confirmed: both Flutter callers — [company_detail_screen.dart:164](exono/lib/screens/company_detail_screen.dart#L164) and [target_company_prep_screen.dart:187](exono/lib/screens/target_company_prep_screen.dart#L187) — send exactly `{industry, location, website}` then immediately force a re-enrich, which overwrites the descriptive fields.) So the route can never set descriptive fields today; the raw-SQL `description` write in the exploit above is reachable only with direct service_role/DB access, not over the route.

PATCH is **in active use** (the hint path), so it is NOT removed. Instead:

1. **Authorize the hint PATCH by linkage.** Add `ownsCompanyLinkage(companyId, userId, req.supabase)` and call it at the top of `PATCH /companies/:id` — return 403 unless the caller owns a `target_company` OR a `contact` whose `company`/`company_id` points at `:id`. This mirrors the existing companies **read** RLS policy's join (the user may only edit hints for a company they already see). Keep the body on `companyPatchSchema` so descriptive/enrichment fields stay AI-only and unwritable by any user.
2. **Keep `POST /companies` open (shared pool).** No `user_id`/ownership check on create — companies are a common pool, and a new company has no linkage to check yet. **No new anti-junk controls are being added** (decision 2026-06-30): create stays as-is.
3. **B7 stays mandatory, coupled.** Because create remains a shared-table write reachable by any tenant, the `name`/`industry`/`website`/hint text a user supplies can still reach *another* tenant's enrich/briefing prompt once both link to the same company. Ownership gating does NOT make the create path injection-safe — so **company-derived text must still be run through `fenceUntrusted` in the legacy enrich/briefing/insight prompts** (B7). The two findings close together or not at all.

*Rejected alternatives:* removing PATCH (rejected — it is actively used as the hint path); per-tenant `user_id` on `companies` (rejected — loses the shared dedupe pool); anti-junk dedupe/rate-limit/provenance on create (deferred by decision — left as-is for now, tracked as residual abuse risk: unbounded create is still possible).

---

## 🟠 High

### B3. Vulnerable / outdated dependencies — **A03:2025 Software Supply Chain Failures** — ✅ **FIXED 2026-06-30 (`xlsx` dropped; Dependabot + npm-audit CI added)**

> **Fix applied & verified.** **`xlsx` (SheetJS) removed entirely** — both import paths ([import.ts](backend/src/routes/import.ts), [events.ts](backend/src/routes/events.ts) `/:id/targets/import`) and document extraction ([document-extraction.ts](backend/src/services/document-extraction.ts)) now parse spreadsheets with **`exceljs`** (`wb.xlsx.load()` + `eachRow()`). **Prototype-pollution guard:** row objects built with `Object.create(null)` and keys in `{__proto__, constructor, prototype}` skipped. `grep -rn "XLSX\.|require('xlsx')" src` → none; `xlsx` gone from `package-lock.json`. **`npm audit --omit=dev`: 3 → 2** (the high-severity SheetJS Prototype-Pollution + ReDoS are gone). **CI added:** [.github/dependabot.yml](.github/dependabot.yml) (npm for `/` and `/backend` + github-actions, weekly, grouped patch/minor) and [.github/workflows/npm-audit.yml](.github/workflows/npm-audit.yml) (fails the build on high/critical prod vulns on dep changes + weekly cron). `npx tsc --noEmit` clean. **Residual (open, tracked):** the remaining **2 moderate** are the transitive `uuid < 11.1.1` pulled in by `exceljs@4.4.0` — the only npm fix is a breaking `exceljs@3.4.0` downgrade, deliberately NOT applied; track for an upstream exceljs patch. (Note: Dependabot has no Dart/pub support, so `exono/` deps are still hand-watched via `flutter pub outdated`.)

Original finding (for reference):
`npm audit --omit=dev` on `backend/` (run 2026-06-30) now reports **3 vulnerabilities (2 moderate, 1 high)** — down from 15 at the last audit.
- **`ws`** — ✅ **FIXED** (cleared by the earlier `npm audit fix`; no longer in the report).
- **`xlsx` / SheetJS (HIGH)** — ⚠️ **STILL OPEN.** Prototype Pollution ([GHSA-4r6h-8v6p-xvw6](https://github.com/advisories/GHSA-4r6h-8v6p-xvw6)) + ReDoS ([GHSA-5pgg-2g8v-p4x9](https://github.com/advisories/GHSA-5pgg-2g8v-p4x9)). **No npm fix.** `xlsx@^0.18.5` is still a direct dependency ([backend/package.json](backend/package.json)) and is reachable from the import path (B10) and document extraction (xlsx/csv branch). Note: `exceljs@^4.4.0` is *also* a dependency — the import/extract paths should migrate fully to `exceljs` and drop `xlsx`, or pin the patched SheetJS CDN build.
- **`uuid <11.1.1` (MODERATE)** + **`exceljs` depends on vulnerable `uuid`** — `uuid` missing-buffer-bounds-check ([GHSA-w5hq-g745-h8pq](https://github.com/advisories/GHSA-w5hq-g745-h8pq)). `npm audit fix --force` would downgrade `exceljs` to 3.4.0 (breaking) — needs a deliberate upgrade, not a blind fix.

**Fix:** drop `xlsx` in favour of `exceljs` for both import and extraction and sanitize parsed objects against prototype pollution; bump `exceljs`/`uuid` to patched majors with a test pass. CI already has a schema-drift workflow ([.github/workflows](.github/workflows)) — **add `npm audit`/Dependabot** so supply-chain drift fails the build (A03 is top-3).

### B7. Prompt injection via LLM endpoints — **A05:2025 Injection / LLM01** — ✅ **FIXED 2026-06-30 (legacy endpoints now fence DB-derived text; coupled with B2)**

> **Fix applied.** The legacy non-assistant LLM endpoints now route DB-derived free text through `fenceUntrusted(content, kind)` from [assistant/security.ts](backend/src/assistant/security.ts): in `POST /companies/:id/enrich` the company DB-hints block and the Exa web-research block are fenced; in `GET /contacts/:id/insights` the company DB record (shared-table fields) and the contact timeline are fenced. Instruction/JSON-schema text stays outside the fence. Pairs with B2 (PATCH now linkage-gated, so cross-tenant company text can no longer be freely injected). `npx tsc --noEmit` clean.

Original finding (for reference):
The assistant now has real defenses ([backend/src/assistant/security.ts](backend/src/assistant/security.ts)):
- **`sanitiseUserInput`** flags ~11 injection patterns, hard-truncates to 8000 chars, and prepends a SECURITY marker telling the model to treat the text as data.
- **`fenceUntrusted`** wraps external/DB-derived content (parsed documents, web-search results) in DATA-ONLY delimiters and **strips attacker-supplied copies of the fence markers** so the boundary can't be spoofed/closed early.
- The system prompt has a SECURITY block these markers reference; the DOCUMENTS section is only included when a document is actually attached.

**Residual (real):** the legacy non-assistant LLM endpoints (`GET /contacts/:id/insights`, company briefings/enrichment) concatenate DB-controlled strings into prompts. Because the shared `companies` create/hint path lets any tenant influence company text (B2), a malicious company record can still reach *another* tenant's briefing prompt without going through the assistant's fencing. **Fix B2 first**, then route all DB-derived free text in the legacy endpoints through `fenceUntrusted` too, not just the assistant path.

> ✅ **`POST /events/:id/ask` removed 2026-06-30.** This legacy unfenced event-Q&A endpoint (which concatenated event/target/Exa text into a prompt) was **dead** — its only client wrapper `askEventQuestion` had zero callers (event-scoped Q&A now goes through the unified assistant `/assistant/respond` + `ExoChatSheet`/`ExoDockBar`). Deleted the route ([events.ts](backend/src/routes/events.ts)) and the `askEventQuestion` wrapper ([api_service.dart](exono/lib/services/api_service.dart)) rather than retrofit fencing onto an unused path. `npx tsc --noEmit` and `flutter analyze` both clean; `ExaService`/`LiteLLMService` imports retained (still used by the company-briefing endpoints).

### B10. File-upload validation — mostly fixed; bucket-listing remains — **A02:2025 / A05:2025** — 🟡 **PARTIAL**
- ✅ **Image uploads are now validated by magic bytes**, not the client MIME ([utils/imageValidation.ts](backend/src/utils/imageValidation.ts)): SVG/GIF excluded (stored-XSS / decompression risks), 5 MB hard cap, sniffed type only. Used by the card-scan / capture / vision paths.
- ✅ **Document extraction is DoS-guarded** ([services/document-extraction.ts](backend/src/services/document-extraction.ts)): 15 MB pre-parse cap, 2M-char extracted-text cap, 1000-page PDF cap, magic-byte sniff (no format reaches a parser it wasn't sniffed as).
- ✅ **`POST /upload` stub removed 2026-06-30.** It accepted any file into memory and returned a fake `https://placeholder.com/...` URL with no validation. Confirmed **dead** — no Flutter caller referenced `/api/upload` (real uploads go via `captures` and `POST /conversations/:id/attachments/upload`). Deleted `routes/upload.ts` and its import/mount in [routes/index.ts](backend/src/routes/index.ts); `npx tsc --noEmit` clean, no remaining references.
- ✅ **`contact-avatars` bucket listing closed 2026-06-30.** Dropped the broad `"Public read contact avatars"` SELECT policy on `storage.objects` (it granted `public` SELECT over the whole bucket → enabled `LIST`/enumeration, [lint 0025](https://supabase.com/docs/guides/database/database-linter?lint=0025_public_bucket_allows_listing)). The bucket stays `public=true`, so individual avatar **object URLs** (`getPublicUrl`, the only access the Flutter client uses — confirmed by grep: no `.list()` call) are still served directly by storage. Net effect: object-URL access intact, bucket enumeration removed. (Good: `contact-cards` and `chat-attachments` are private.)

---

## 🟡 Medium

### B9. `SECURITY DEFINER` RPCs callable by `anon`/`authenticated` — **A02:2025 Security Misconfiguration** — ✅ **FIXED 2026-06-30 (anon revoked on all 5; authenticated revoked on the 2 server-only funcs)**

> **Fix applied & verified (live `pg_proc`/`routine_privileges` query, not the cached advisor).** `REVOKE EXECUTE FROM anon` on all 5 RPCs; additionally `REVOKE EXECUTE FROM authenticated` on `pgrst_reload_schema` + `upsert_scoped_rate_limit` (server-only). The 3 `*_target_company_note` RPCs **keep** `authenticated` (called via `req.supabase` user-client in the notes routes) — their cross-tenant safety still rests on the internal `user_id = p_user_id` check (footgun, tracked). Post-fix grant query returns **only** the 3 note→authenticated grants; zero anon grants remain. *Note:* the Supabase advisor still shows stale anon warnings (cached pre-migration; it even reports the old arg signature) — ground-truth catalog query confirms the revokes landed.

Original finding (for reference):
Supabase advisor flags **5** `SECURITY DEFINER` functions executable via `/rest/v1/rpc/...` by `anon` and `authenticated` (verified 2026-06-30):
- `pgrst_reload_schema()` — any anon client can trigger schema reloads (original B9).
- `upsert_scoped_rate_limit(...)` — backs the rate limiter; takes `p_user_id` as a **parameter** (not `auth.uid()`). An anon caller could write/inflate arbitrary rate-limit rows.
- `append_target_company_note` / `update_target_company_note` / `delete_target_company_note` — **internally enforce `... and user_id = p_user_id`**, so they cannot cross-tenant *write*. **Attack-verified 2026-06-30:** as `anon`, calling `append_target_company_note(A's-target, B's-user-id, …)` raised `target not found or not owned` — the cross-tenant write was **blocked**. But they take `p_user_id` as a caller-supplied parameter and are exposed to `anon` — unnecessary attack surface and a footgun if the internal check is ever loosened.

**Chosen fix (2026-06-30): Option A — revoke EXECUTE, scoped per function.** Confirmed by grep that **none of the 5 are called from the Flutter client** (zero `.rpc(` calls in `exono/lib`), so removing `anon` access breaks nothing. But the revoke is **not** a blanket "anon + authenticated on all five" — the call sites differ (verified):

| Function | Called as | Revoke `anon` | Revoke `authenticated` |
|---|---|---|---|
| `pgrst_reload_schema` | service_role only ([server.ts:89](backend/src/server.ts#L89)) | ✅ | ✅ |
| `upsert_scoped_rate_limit` | service_role only ([rateLimit.ts:32](backend/src/utils/rateLimit.ts#L32)) | ✅ | ✅ |
| `append_target_company_note` | **authenticated** ([events.ts:1329](backend/src/routes/events.ts#L1329)) + service_role ([targets.ts:351](backend/src/assistant/tools/executors/targets.ts#L351)) | ✅ | ❌ **keep** — the notes route calls it as the user |
| `update_target_company_note` | **authenticated** ([events.ts:1361](backend/src/routes/events.ts#L1361)) | ✅ | ❌ **keep** |
| `delete_target_company_note` | **authenticated** ([events.ts:1389](backend/src/routes/events.ts#L1389)) | ✅ | ❌ **keep** |

So: `REVOKE EXECUTE FROM anon` on **all 5**; additionally `REVOKE EXECUTE FROM authenticated` on **`pgrst_reload_schema` and `upsert_scoped_rate_limit`** only (those are server-only). The three note functions must keep `authenticated` because the `events.ts` notes routes call them through `req.supabase!` (the user client) — a blanket revoke from `authenticated` would break add/edit/delete note. Their cross-tenant safety still rests on the internal `user_id = p_user_id` check (attack-verified above), so they remain a footgun until refactored. ([lint 0028/0029](https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable))

### B11. Auth-flow rate limiting + alerting still absent — **A07:2025 / A09:2025** — 🟡 **RATE LIMITING FIXED 2026-06-30; alerting + leaked-password toggle still open**

> **Rate limiting applied.** Added `express-rate-limit`. [auth.ts](backend/src/routes/auth.ts) now applies an IP-keyed `authLimiter` (10 / 15 min) to `/login` + `/refresh` and a tighter `signupLimiter` (5 / 60 min) to `/signup`; `/logout`, `/session`, `/complete-profile` are intentionally unlimited. [server.ts:24](backend/src/server.ts#L24) sets `app.set('trust proxy', 1)` so `req.ip` is the real client IP behind Vercel/Firebase. tsc clean for these files. **Caveat (documented in code):** the default store is per-process memory, so on serverless the effective cap is `max × instances` — a hard global cap needs a shared (Redis/Postgres) store; in-memory is a large improvement over nothing as a first pass. **Still open:** (1) **leaked-password protection** (HaveIBeenPwned) is a Supabase **console** toggle — enable at Auth → Password settings ([docs](https://supabase.com/docs/guides/auth/password-security)); not togglable from this repo. (2) **Security alerting** on repeated auth failures / anomalous access (A09) — not implemented.

Original finding (for reference):
- ✅ **AI / upload abuse is now rate-limited.** The assistant has a persistent per-user limiter (`assistant_rate_limits`, 30/min, [assistant/security.ts](backend/src/assistant/security.ts)) and there is a generic scoped limiter (`scoped_rate_limits`) for image upload (40/min) and doc upload (20/min) ([utils/rateLimit.ts](backend/src/utils/rateLimit.ts)). Both **fail open** on DB error (deliberate availability choice — acceptable, but means a DB outage disables the limit).
- ❌ **`/auth/login`, `/auth/signup`, `/auth/refresh` have NO rate limiting** — open to credential stuffing / brute force / mass-account-creation. Verified 2026-06-30: all three ([auth.ts:186](backend/src/routes/auth.ts#L186), [:38](backend/src/routes/auth.ts#L38), [:305](backend/src/routes/auth.ts#L305)) go straight to Supabase with only Zod validation; `express-rate-limit` is not a dependency and no rate-limit middleware is applied at the server or auth-router level. The existing `scoped_rate_limits` helper is keyed by `user_id`, so it **cannot** cover pre-login auth (no user yet) — these need an **IP-keyed** limiter.

  **Fix (documented; not yet applied):**
  1. `npm install express-rate-limit` in `backend/`.
  2. In [auth.ts](backend/src/routes/auth.ts), add an IP-keyed limiter and apply it **only** to the brute-forceable routes (`/login`, `/signup`, `/refresh`) — NOT `/logout` or `/session`:
     ```ts
     import rateLimit from 'express-rate-limit';
     const authLimiter = rateLimit({
       windowMs: 15 * 60 * 1000,        // 15 min
       max: 10,                          // per IP per window (login/refresh)
       standardHeaders: true, legacyHeaders: false,
       message: { error: 'Too many attempts, please try again later.' },
     });
     // Use authLimiter on /login and /refresh; a tighter limiter (e.g. max 5/hour)
     // on /signup to curb mass-account-creation.
     router.post('/login', authLimiter, async (req, res) => { /* ... */ });
     ```
  3. In [server.ts](backend/src/server.ts) add `app.set('trust proxy', 1);` — behind Vercel/Firebase, `req.ip` is the proxy IP unless `X-Forwarded-For` is trusted; without this the limiter is bypassable or causes shared-bucket false lockouts.
  4. **Recommended limits:** login/refresh ~10 per IP / 15 min; signup ~5 per IP / hour.
  5. **Caveat:** `express-rate-limit`'s default store is per-process memory, so on serverless/multi-instance the effective limit is `max × instances`. For a hard global cap, back it with a shared store (Redis, or a Postgres-backed store mirroring `scoped_rate_limits` but keyed by IP). In-memory is still a large improvement over nothing for a first pass. Supabase Auth's built-in throttling is a backstop, not the primary control.
- ❌ **No security alerting** on repeated auth failures / anomalous access — the colored request logger ([middleware/logger.ts](backend/src/middleware/logger.ts)) redacts `password`/`token`/`refresh_token` (good) but A09:2025 wants alerting, not just logging.
- ❌ Supabase advisor: **leaked-password protection (HaveIBeenPwned) is disabled** — enable it ([password-security](https://supabase.com/docs/guides/auth/password-security)).

### B13. `scoped_rate_limits` has RLS enabled but no policy — **A02:2025** — ✅ **FIXED 2026-06-30 (explicit deny-all policy + table comment)**

> **Fix applied & verified.** Added `scoped_rate_limits_deny_all` (`FOR ALL TO authenticated, anon USING(false) WITH CHECK(false)`) + a `COMMENT ON TABLE` recording the deny-all intent. The table is written ONLY via the `SECURITY DEFINER` `upsert_scoped_rate_limit` RPC (which is now also anon-revoked, see B9). `pg_policies` confirms the policy exists. The table is intentionally left non-`FORCE`d (deny-all bookkeeping exception, consistent with B14).

Original finding (for reference):
Advisor lint `rls_enabled_no_policy`: `public.scoped_rate_limits` has RLS on but **zero policies**, so the `authenticated`/`anon` roles can neither read nor write it directly (deny-by-default). That's actually *safe* for confidentiality — but it's load-bearing only because all access goes through the `SECURITY DEFINER` `upsert_scoped_rate_limit` RPC (which bypasses RLS). The deny-all is currently *implicit* (looks like a forgotten policy), so the real risk is a future "fix the lint" migration adding a permissive policy and accidentally exposing the table.

**Chosen fix (2026-06-30): Option 2 — explicit deny policy.** Add a policy that grants nothing (so the table visibly *has* a policy and the lint clears, while still admitting no user), plus a comment recording the intent:
```sql
-- Deny-all by design. The table is written ONLY by the SECURITY DEFINER
-- upsert_scoped_rate_limit RPC (which bypasses RLS). This explicit policy
-- exists so the table clearly has a policy and nobody "fixes the linter"
-- by adding a permissive one.
CREATE POLICY scoped_rate_limits_deny_all
  ON public.scoped_rate_limits
  FOR ALL
  TO authenticated, anon
  USING (false)
  WITH CHECK (false);

COMMENT ON TABLE public.scoped_rate_limits IS
  'Deny-all by design (see scoped_rate_limits_deny_all policy). Accessed only via the SECURITY DEFINER upsert_scoped_rate_limit RPC. Do NOT add a permissive policy.';
```
`USING (false)` blocks all reads/updates/deletes; `WITH CHECK (false)` blocks all inserts — for the `authenticated`/`anon` roles only (service_role and the DEFINER RPC are unaffected). Pairs with B9: also `REVOKE EXECUTE ... FROM anon` on `upsert_scoped_rate_limit` so the whole table+function stays strictly server-side.

### B14. Three tenant-adjacent tables are RLS-enabled but NOT `FORCE`d — **A02:2025 / defense-in-depth** — ✅ **FIXED 2026-06-30 (FORCE applied to the 4 tables)**

> **Fix applied & verified.** `FORCE ROW LEVEL SECURITY` set on `assistant_pending_actions`, `document_chunks`, `follow_ups`, `target_company_met`. Post-fix the no-FORCE sweep returns only `scoped_rate_limits` (the deliberate deny-all exception, B13). No legitimate path breaks (service_role is exempt even under FORCE; the pre-flight policy-coverage check in this finding held).

Original finding (for reference):
Verified 2026-06-30 — these have `relrowsecurity=true` but `relforcerowsecurity=false`, meaning the **table owner bypasses RLS** (a defense-in-depth gap; the service_role paths already bypass RLS anyway, but `FORCE` is the standing invariant the audit framework checks):
- `assistant_pending_actions` (only a SELECT policy exists)
- `document_chunks` (RAG chunk store — INSERT/SELECT/DELETE policies)
- `follow_ups`, `target_company_met`, `scoped_rate_limits` (the last has no policy — see B13)

**Pre-flight check done (2026-06-30) — FORCE is safe on all four; no legitimate path breaks.** Verified each table's policies vs. the client the backend actually uses to write it (service_role is exempt even under FORCE; only non-service_role/user-client paths must be policy-covered):

| Table | Policies | Backend access | FORCE safe? |
|---|---|---|---|
| `assistant_pending_actions` | **SELECT only** (`pending_actions_select_own`) | **100% `supabaseAdmin`** — all reads+writes ([assistant.ts:339/391/431/454](backend/src/routes/assistant.ts#L339), [loop.ts:277](backend/src/assistant/loop.ts#L277), [conversations.ts:186](backend/src/routes/conversations.ts#L186)); the app never touches it via a user client, so the missing write policies are irrelevant | ✅ yes |
| `document_chunks` | full CRUD, `user_id = auth.uid()` | insert via `supabaseAdmin` ([conversations.ts:348](backend/src/routes/conversations.ts#L348)); user-client reads covered by the SELECT policy | ✅ yes |
| `follow_ups` | full CRUD, `user_id = auth.uid()` | `req.supabase` (routes/services) + `supabaseAdmin` (assistant executors) — user-client writes fully covered by INSERT/UPDATE/DELETE policies | ✅ yes |
| `target_company_met` | full CRUD, `user_id = auth.uid()` | `req.supabase` ([events.ts:393/975/1420](backend/src/routes/events.ts#L393)) — fully covered | ✅ yes |

Note the one I'd flagged as risky (`assistant_pending_actions`, SELECT-only) is in fact the *safest* — it's never accessed through a user client, so FORCE constrains nothing the app relies on.

**Fix (documented; not yet applied):**
```sql
ALTER TABLE public.assistant_pending_actions FORCE ROW LEVEL SECURITY;
ALTER TABLE public.document_chunks           FORCE ROW LEVEL SECURITY;
ALTER TABLE public.follow_ups                FORCE ROW LEVEL SECURITY;
ALTER TABLE public.target_company_met        FORCE ROW LEVEL SECURITY;
```
(Skip `scoped_rate_limits` per B13's deny-all approach.) After applying, re-run the no-FORCE sweep from the framework section — it must return empty.

### B15. `vector` extension installed in `public` schema — **A02:2025** — ✅ **FIXED 2026-06-30 (moved to `extensions` schema; RAG smoke-tested)**

> **Fix applied & verified.** Created `extensions` schema (granted USAGE to authenticated/anon/service_role), `ALTER EXTENSION vector SET SCHEMA extensions`, re-pinned `match_document_chunks` search_path to `'public','extensions','pg_temp'`, and `NOTIFY pgrst`. Post-fix `pg_extension` shows `vector` in `extensions`. **RAG smoke test:** calling `match_document_chunks(..., zero-vector, 5)` executes without error (the `<=>` operator still resolves after the move) — returns 0 rows on the currently-empty chunk store, proving operator resolution, not data.

Original finding (for reference):
Advisor lint `extension_in_public`: `vector` (pgvector **0.8.0**, in `public`) backs the `document_chunks` RAG store. Mixing a third-party extension's objects (the `vector` type, its `<=>` operators/functions) into the shared `public` schema is a hygiene/hardening gap ([lint 0014](https://supabase.com/docs/guides/database/database-linter?lint=0014_extension_in_public)).

**Dependency surface (verified 2026-06-30 — this is why it's NOT a blind one-liner):**
- **1 column:** `document_chunks.embedding vector(768)` uses the type.
- **1 function:** `match_document_chunks(... p_query_embedding vector ...)` ([documents.ts:40](backend/src/assistant/tools/executors/documents.ts#L40) calls it) uses the `<=>` distance operator and pins `SET search_path = 'public', 'pg_temp'` — it does **not** currently include an `extensions` schema. **If `vector`/`<=>` move out of `public`, this function stops resolving the operator and RAG retrieval silently breaks.**
- App code only touches pgvector via that RPC + the `embedding` column write ([conversations.ts:346](backend/src/routes/conversations.ts#L346)); no raw `<=>` in TypeScript. No SQL migration files in the repo — schema is managed directly on Supabase, so this is a manual migration.

**Fix (documented; not yet applied) — move the extension AND update every dependent's search_path in one migration:**
```sql
-- 1. Dedicated schema for extensions
CREATE SCHEMA IF NOT EXISTS extensions;
GRANT USAGE ON SCHEMA extensions TO authenticated, anon, service_role;

-- 2. Relocate pgvector (type, operators, functions move with it)
ALTER EXTENSION vector SET SCHEMA extensions;

-- 3. Re-pin match_document_chunks so it still finds the vector operators.
--    Recreate it (its body is search_path-sensitive for the `<=>` operator):
ALTER FUNCTION public.match_document_chunks(uuid, uuid, vector, integer)
  SET search_path = 'public', 'extensions', 'pg_temp';

-- 4. Reload PostgREST so the API picks up the moved type
NOTIFY pgrst, 'reload schema';
```
**Verify after:** the advisor `extension_in_public` lint clears; `match_document_chunks` still returns rows for a real attachment (RAG smoke test); the `document_chunks.embedding` column type still resolves. **Pre-flight caution:** `ALTER EXTENSION ... SET SCHEMA` on an in-use extension can fail if any object can't be relocated — test on a Supabase branch first. Low security impact, so sequence it deliberately rather than rushing.

### B16. `function_search_path_mutable` on two functions — **A02:2025** — ✅ **FIXED 2026-06-30 (search_path pinned on both)**

> **Fix applied & verified.** `ALTER FUNCTION ... SET search_path = pg_catalog, public` on `pgrst_reload_schema()` and `follow_ups_set_updated_at()`. Post-fix `pg_proc.proconfig` shows `search_path=pg_catalog, public` on both. No behavioural change.

Original finding (for reference):
Advisor lint 0011. Verified 2026-06-30 — both have `proconfig = null` (no pinned `search_path`), so they inherit the caller's path and a referenced name (`now()`, etc.) could in principle be hijacked by an object earlier in the path:
- **`pgrst_reload_schema()`** — `SECURITY DEFINER` (runs with elevated privilege → higher impact if a referenced object is hijacked). Body is just `NOTIFY pgrst, 'reload schema'`.
- **`follow_ups_set_updated_at()`** — a `BEFORE UPDATE` trigger function (`plpgsql`, not DEFINER) that calls `now()` and sets `new.updated_at`.

(Confirmed the siblings are already safe: `upsert_scoped_rate_limit`, `match_document_chunks`, and the three `*_target_company_note` RPCs all pin `search_path`.)

**Fix (documented; not yet applied) — pin the path on both:**
```sql
ALTER FUNCTION public.pgrst_reload_schema()       SET search_path = pg_catalog, public;
ALTER FUNCTION public.follow_ups_set_updated_at() SET search_path = pg_catalog, public;
```
`pg_catalog` first guarantees built-ins (`now()`, `NOTIFY` internals) resolve to the real ones regardless of caller path. Safe, instant, no behavioural change — the trigger and the reload still work identically. **Verify after:** advisor lint 0011 clears for both; a `follow_ups` UPDATE still stamps `updated_at`. (If B9's revoke + a later DEFINER→INVOKER refactor touches `pgrst_reload_schema`, re-apply the pin in the new definition.)

---

## ✅ Backend findings now CLOSED (re-verified 2026-06-30)

| ID | Finding | Verification |
|---|---|---|
| **B1 / R-01** | IDOR on `GET /contacts/:id/timeline` & sub-resources | `contacts.ts` has `router.param('id')` ownership guard ([contacts.ts:46](backend/src/routes/contacts.ts#L46)) + uses `req.supabase` (RLS). `events.ts` likewise. |
| **B4** | 500 error handler leaked Postgres/Supabase internals | [errorHandler.ts](backend/src/middleware/errorHandler.ts) returns generic `"Internal server error"` + correlation ID; details only in `development`. |
| **B5** | Cross-tenant write via unscoped `contactId` in follow-ups | `events.ts` on `req.supabase`; RLS `WITH CHECK` blocks foreign writes. |
| **B6** | Mass-assignment in `PUT /follow-ups/:id` | `followUpUpdateSchema` with Zod `.strict()` ([followUps.ts:12](backend/src/routes/followUps.ts#L12)) + RLS user client. |
| **B8** | CORS failed open when `ALLOWED_ORIGINS` unset | [server.ts](backend/src/server.ts) fails **closed** in production; dev-only allow-all. |
| **B12** | `contact_events` `{public}` allow-all policy | Dropped; permissive-policy sweep returns **empty** (verified 2026-06-30). |
| **R-02** | Cross-tenant event-name leak + capture cross-link | `captures.ts` adds `.eq('user_id', userId)` + explicit `event_id` ownership precheck ([captures.ts:135](backend/src/routes/captures.ts#L135)). |
| **R-04** | Body-supplied FK cross-link on event/contact link routes | Explicit FK ownership prechecks added; `documents.ts`/`attachments.ts` use `ownsContact`. |
| **H2** | CSV export formula injection | [export.ts](backend/src/routes/export.ts) quotes every field (doubles `"`) + prefixes `= + - @`/tab/CR with `'`. |

**Assistant (AI agent) — reviewed, defenses verified:**
- Write tools run on `supabaseAdmin` (RLS bypassed by design) but **enforce ownership in code**: `resolve*Id` filter by `user_id`; `assertOwnsEvent/Contact/Attachment` guard raw FK use ([assistant/tools/resolvers.ts](backend/src/assistant/tools/resolvers.ts)); `stripImmutable` + `IMMUTABLE_FIELDS` prevent LLM mass-assignment of `user_id`/`id`.
- **All write tools are gated behind a user-permission card** (`WRITE_TOOL_NAMES` pauses the loop → `assistant_pending_actions` → `/resume`). A write tool missing from this set would execute without consent — the checklist in [backend/CLAUDE.md](backend/CLAUDE.md) enforces it; the CI drift-check catches unclassified writable-table columns.
- **`parse_document`** is a READ tool; ownership walks attachment → message → `user_id`; oversized retrieval uses `match_document_chunks` scoped to BOTH `p_user_id` AND `p_attachment_id` (can't reach another user's/document's chunks).
- **Slayer read path** ([services/slayer-client.ts](backend/src/services/slayer-client.ts)): model allowlist (`ALLOWED_MODELS`), `user_id` ownership + `deleted_at` filters auto-injected (flags auto-derived from live schema at boot via `introspect_public_columns()`), hallucinated `user_id` filters stripped, Slayer connects read-only with RLS as a second check.
- **No SSRF** in the outbound paths reviewed: Exa search posts to a fixed `https://api.exa.ai/search` ([services/exa-service.ts](backend/src/services/exa-service.ts)); LiteLLM/Gemini use configured base URLs; no user-supplied URL is fetched server-side (enrichment uses Exa, not a raw `website` fetch).

**Good baseline (unchanged):** `helmet()` on the API with strong defaults; 2 MB JSON body cap; broad Zod validation on write bodies; `.env`/`backend/.env` gitignored (only `.env.example` tracked); no service-role key in the Flutter client; `package-lock.json` committed.

---

# Web frontend (served HTML/JS) findings

### H1. Web frontend security headers — ✅ **FIXED (Firebase Hosting), verify on deploy**
The Flutter **web** build is served from **Firebase Hosting** (project `exono-ad7a4`). [exono/firebase.json](exono/firebase.json) now sets, on `source: "**"`: HSTS (preload), `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, `Referrer-Policy: strict-origin-when-cross-origin`, `Permissions-Policy` (camera/mic `self`, geolocation off), and a Flutter-web-tuned CSP (`script-src 'self' 'wasm-unsafe-eval'`, `worker-src 'self' blob:`, `connect-src` for the API + `*.supabase.co` + `*.googleapis.com` + `*.firebaseio.com` + `*.firebaseapp.com`, `frame-ancestors 'none'`, `object-src 'none'`).
**Residual:** confirm against a live deploy that the app loads (wasm + drift worker + Firebase SDK), then tighten `connect-src`/`img-src` to the real runtime origins (currently `img-src 'self' data: https:` is broad).

---

# Client (Flutter) findings — OWASP Mobile Top 10:2024

## 🔴 Critical

### C1. Auth tokens stored in plaintext `SharedPreferences` — **M9 / M1** — ✅ **FIXED 2026-06-30 (`flutter_secure_storage`; flutter analyze clean)**

> **Fix applied & verified.** Added `flutter_secure_storage: ^9.2.2` (resolved 9.2.4). [auth_provider.dart](exono/lib/providers/auth_provider.dart) now stores `access_token` + `refresh_token` (C1) **and** `cached_user`/`cached_profile`/`session_last_verified_ms` (C9 residual) in `FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true))` — iOS Keychain / Android Keystore-backed EncryptedSharedPreferences. A one-time `_migrateFromPrefsIfNeeded()` (called in `initialize()` before the first token read) copies any surviving plaintext values into secure storage and removes them from prefs, so existing sessions are NOT logged out. `_clearSession()` deletes all five keys from secure storage. **Sweep:** zero `prefs.get/set/remove` calls remain for any sensitive key (the only `getString` left is inside the migration helper reading the legacy value to copy it); the non-sensitive `selected_mode` UI flag correctly stays in prefs. `flutter analyze lib`: no issues.

Original finding (for reference):
[auth_provider.dart](exono/lib/providers/auth_provider.dart) writes `access_token` and `refresh_token` to unencrypted `SharedPreferences` (≈12 call sites). `flutter_secure_storage` is **not** in [exono/pubspec.yaml](exono/pubspec.yaml). Recoverable on rooted/jailbroken devices or via backup extraction; the refresh token grants long-lived account takeover.
**Fix:** add `flutter_secure_storage` (Keychain / Android Keystore `EncryptedSharedPreferences`) and move both tokens there. Do this together with C9.

### C2. Offline Drift/SQLite DB is unencrypted — **M9** — ✅ **FIXED 2026-06-30 (SQLCipher; flutter analyze clean)**

> **Fix applied & verified.** Added `sqlcipher_flutter_libs: ^0.6.0` (resolved 0.6.8). [connection_native.dart](exono/lib/db/connection/connection_native.dart) opens the Drift `NativeDatabase.createInBackground` with a `setup:` callback that runs `PRAGMA key`. The 256-bit key is generated once (`Random.secure`, base64Url), stored in `FlutterSecureStorage` under `db_encryption_key`, and reused on every open (key never leaves secure storage). The old-Android SQLCipher `.so` workaround (`applyWorkaroundToOpenSqlCipherOnOldAndroidVersions`) is correctly placed in **`isolateSetup`** so it runs on the same background isolate `createInBackground` opens on (the original agent draft had it on the main isolate — fixed after checking the Drift encryption docs). **Plaintext-DB migration:** the lazy opener checks the file's first 16 bytes for the `"SQLite format 3 "` magic; a legacy un-encrypted DB is deleted before open (the local DB is a sync cache — re-syncs from server), so `AppDatabase()` self-heals with **no caller wiring required** (a redundant `openOrRecreate()` factory also exists). `flutter analyze lib`: no issues. **Android release-build fix (2026-06-30):** removed `sqlite3_flutter_libs` from pubspec — it ships the same `Sqlite3FlutterLibsPlugin` as `sqlcipher_flutter_libs`, so keeping both caused an R8 "Type … defined multiple times" failure; `sqlcipher_flutter_libs` is the drop-in replacement (only one may be present). *Residual:* SQLCipher native linkage / actual on-disk encryption can only be fully confirmed by running on a physical Android + iOS device.

Original finding (for reference):
[exono/lib/db/app_database.dart](exono/lib/db/app_database.dart) opens the local DB via a plain `openConnection()` with no SQLCipher / encrypted executor. The full offline CRM mirror (contacts, companies, interactions, email drafts, notes) sits in a plaintext SQLite file. Also M6 (PII at rest).
**Fix:** SQLCipher (`sqlcipher_flutter_libs` + Drift `NativeDatabase` with a key) with the key in secure storage (C1).

---

## 🟠 High

### C9. Offline session restore from cached identity — **M9 / M1** — ✅ **FIXED 2026-06-30 (identity cache moved to secure storage, with C1)**

> **At-rest residual closed.** `cached_user`, `cached_profile`, and `session_last_verified_ms` now live in `FlutterSecureStorage` (see C1), not plaintext `SharedPreferences` — so they are no longer attacker-writable on a rooted device via a plain prefs file. The in-code mitigations (network-failure-only offline restore, 7-day grace window, fail-closed on garbled timestamps, server re-verification on next online request) were already in place and are unchanged.

Original finding (for reference):
Offline-resume restores a session from cached identity only when the session check failed due to *no connectivity* (network failures are tagged `'network': true`; a server rejection still routes to `_clearSession()` → logout). A 7-day offline grace window (`session_last_verified_ms`) bounds offline lifetime; fail-closed on missing/garbled/rolled-back timestamps. The backend re-verifies every token on the next online request, so offline-restore grants **no new server access**.
**Residual (the C1 follow-up):** `cached_user`, `cached_profile`, and `session_last_verified_ms` live in plaintext `SharedPreferences` and are attacker-writable on a rooted device (tampering impact limited to client-side navigation — zero server access, since the backend never trusts client state). The grace-window timestamp is editable, so it's a speed bump, not a cryptographic control. **Fix with C1/C2** — move tokens + identity cache into secure storage.

---

## 🟡 Medium / informational

### C3. Base URL scheme — ✅ **FIXED**
[api_config.dart](exono/lib/config/api_config.dart) default is `https://exhibitioncrm.vercel.app/api`; `assertSecure()` asserts an absolute `https://` (or localhost `http`) at startup.

### C4. Cleartext / ATS / pinning — 🟡 **PARTIAL**
✅ `android:usesCleartextTraffic="false"` set ([AndroidManifest.xml:14](exono/android/app/src/main/AndroidManifest.xml#L14)). ✅ iOS ATS default-deny in force (no `NSAllowsArbitraryLoads`). ⚠️ **Cert pinning NOT added** — still recommended for the API host given the PII threat model.

### C5. `url_launcher` scheme allowlist — ✅ **FIXED**
Both `_launchUrl` ([contact_detail_screen.dart:174](exono/lib/screens/contact_detail_screen.dart#L174)) and `_openAsset` reject any scheme outside `{http, https, mailto, tel}` before `launchUrl`.

### C6. Firebase API keys committed — informational (unchanged)
`AIza...` keys in [firebase_options.dart](exono/lib/firebase_options.dart) are **client identifiers, not secrets**. Security depends on Firebase Security Rules + Google Cloud API-key restrictions (by package/SHA). **Verify those are locked down** — if rules are open this becomes critical.

### C7. Import upload — client-side caps still recommended — ✅ **FIXED 2026-06-30 (picker constrained + 10 MB client cap)**

> **Fix applied & verified.** Both import pickers ([pre_event_prep_screen.dart:374](exono/lib/screens/pre_event_prep_screen.dart#L374), [contacts_screen.dart:624](exono/lib/screens/contacts_screen.dart#L624)) now use `FileType.custom` + `allowedExtensions: ['csv','xlsx','xls']` and reject files over `10 * 1024 * 1024` bytes with a toast before upload (mounted-guarded). `flutter analyze` on both files: no issues. The server (B10) remains the real boundary — this is UX + defense-in-depth.

Original finding (for reference):
The import path posts raw bytes; the **server** now caps size and sniffs type (B10), so the critical gap is closed server-side. Adding a client-side size/extension check is a UX/defense-in-depth nicety, not load-bearing.

**Verified gap (2026-06-30):** both import pickers use `FileType.any` with no extension allowlist and no size check — [pre_event_prep_screen.dart:374](exono/lib/screens/pre_event_prep_screen.dart#L374) and [contacts_screen.dart:624](exono/lib/screens/contacts_screen.dart#L624). (Contrast: the chat-attachment picker already does it right — `FileType.custom` + `allowedExtensions`, [exo_chat_view.dart:486](exono/lib/widgets/exo_chat_view.dart#L486).)

**Fix (documented; not yet applied):**
1. Constrain the picker to the formats the importer accepts:
   ```dart
   await FilePicker.platform.pickFiles(
     type: FileType.custom,
     allowedExtensions: ['csv', 'xlsx', 'xls'],
     withData: true,
   );
   ```
2. After picking, reject oversized files **before** uploading, with a friendly message — mirror the server cap so the two agree (server import cap; image cap is `MAX_IMAGE_BYTES` = 5 MB, docs `MAX_DOC_BYTES` = 15 MB in [document-extraction.ts](backend/src/services/document-extraction.ts)):
   ```dart
   const maxImportBytes = 10 * 1024 * 1024; // keep <= the server import cap
   if ((file.size) > maxImportBytes) { showAppToast(context, 'File too large (max 10 MB)'); return; }
   ```
This is UX + defense-in-depth only — the server (B10) remains the real boundary; a client that bypasses the app still hits the server caps/sniffing.

### C8. No binary hardening / tamper detection — M7 — ✅ **FIXED 2026-06-30 (obfuscation; root/jailbreak detection later removed)**

> **Step 1 (obfuscation) applied.** The release iOS build in [codemagic.yaml](codemagic.yaml) now runs `flutter build ios --release --no-codesign --obfuscate --split-debug-info=build/debug-symbols ...` (the only release build in the file). YAML re-validated. **This is the active mitigation.**
> **Step 2 (root/jailbreak detection) — applied then REMOVED 2026-06-30.** A soft `DeviceIntegrityService.isCompromised()` (`flutter_jailbreak_detection`) warning was wired into [splash_screen.dart](exono/lib/screens/splash_screen.dart), then **removed at the owner's request**: the `flutter_jailbreak_detection` dependency, `device_integrity_service.dart`, and the splash-screen warning dialog are all gone (`grep -rn "jailb\|DeviceIntegrity" lib/` → none; dep dropped from [pubspec.yaml](exono/pubspec.yaml); `flutter analyze` clean). It was always a soft, defeatable signal that fixed no specific vulnerability (the real at-rest protection is C1/C2/C9 — tokens + offline DB + identity cache in secure storage, all still in place). Binary hardening for C8 now rests solely on Step 1 (obfuscation).

Original finding (for reference):
No obfuscation / root-jailbreak detection. Lower priority than C1/C2 (fix those first — they protect the actual at-rest data). Verified 2026-06-30: the CI release build ([codemagic.yaml:38](codemagic.yaml#L38)) runs `flutter build ios --release` **without** `--obfuscate --split-debug-info`.

**Fix (documented; not yet applied) — two independent, optional steps:**
1. **Dart obfuscation** — add the flags to every release build in [codemagic.yaml](codemagic.yaml) (and any local release command):
   ```sh
   flutter build ios --release --obfuscate --split-debug-info=build/debug-symbols ...
   flutter build apk --release --obfuscate --split-debug-info=build/debug-symbols ...
   ```
   `--split-debug-info` writes the symbol map separately so YOU can still de-obfuscate crash reports (keep `build/debug-symbols` as a CI artifact, don't ship it). Scrambles identifiers so a pulled APK/IPA is far harder to reverse. No code change, just build flags.
2. **Root / jailbreak detection (optional, heavier)** — add a package such as `flutter_jailbreak_detection` and, on startup, warn or restrict on a compromised device. This is a soft signal (defeatable), so use it to *raise effort*, not as a hard gate — e.g. surface a warning rather than hard-blocking, to avoid false-positive lockouts.

Both raise attacker effort but fix no specific vulnerability; **do C1/C2 (encrypt tokens + offline DB) first.** Note: obfuscation does NOT protect the shipped Firebase/anon keys (those are public client identifiers anyway — see C6).

### Client good practices (verified)
401 handling centralized → forced logout; no token/body logging; idempotency keys on mutating POSTs; Supabase anon key + API base injected via `--dart-define`; query params encoded.

---

# Remediation priority (2026-06-30)

1. **B2 — `companies` write authorization (A01:2025, Critical).** Design agreed (shared-reference + linkage-gated hint PATCH): add `ownsCompanyLinkage` to gate `PATCH /companies/:id` (descriptive fields already AI-only), keep `POST` open, couple with B7 fencing. Create-path anti-junk deferred (residual abuse risk). See B2 above.
2. **C1 / C2 / C9 — Encrypt tokens, offline DB, and identity cache on the client.** `flutter_secure_storage` + SQLCipher; do all three together.
3. **B3 — Supply chain (A03:2025).** Replace `xlsx` with `exceljs` (or pin patched SheetJS); bump `uuid`/`exceljs`; add `npm audit`/Dependabot to CI.
4. **B11 — Rate-limit `/auth/*` + enable leaked-password protection + add abuse alerting (A07/A09).**
5. **B9 / B13 / B10 — Revoke `SECURITY DEFINER` RPCs from anon; document/lock `scoped_rate_limits`; lock the avatars bucket SELECT (A02:2025).** (`/upload` stub already removed.)
6. **B14 / B15 / B16 — `FORCE` RLS on the 4 new tenant tables; move `vector` out of `public`; pin function `search_path` (A02:2025, defense-in-depth).**
7. **B7 — Route legacy LLM-endpoint DB text through `fenceUntrusted` (after B2) (A05:2025/LLM01).**
8. **H1 residual — verify web headers on a live deploy and tighten `connect-src`/`img-src`.**
9. **C4 — Evaluate cert pinning (M5).**
10. **C6 / C8 — Confirm Firebase rules + API-key restrictions; optional binary hardening.**

---

# Items requiring further verification (not closed by this pass)

- **B2 — DB-level exploit done; HTTP replay still recommended.** B2 was live-exploited at the DB layer (service_role-equivalent UPDATE landed on a non-owned company). Replaying it over a real `PATCH /api/companies/:id` HTTP call with User B's JWT would close the loop end-to-end, and the same call must return 403 after the fix.
- **Firebase Security Rules + Google Cloud API-key restrictions** (C6) — not inspectable from this repo; verify in the Firebase/GCP console.
- **Web headers on a live Firebase deploy** (H1 residual) — verify with `curl -I` against the deployed origin.
- **`exceljs` import/extraction path** — confirm it applies the same formula guard as `/export/csv` (H2 was CSV-only) and that dropping `xlsx` doesn't regress parsing.
- **Rate-limiter fail-open** — both limiters fail open on DB error; confirm that's acceptable for the auth/abuse threat model or add a circuit breaker.
