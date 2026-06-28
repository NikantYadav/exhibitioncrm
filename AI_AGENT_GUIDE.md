# How the Exono AI Assistant Works (Backend + Slayer)

A beginner-friendly, end-to-end guide to the AI agent that powers the chat in the
Exono CRM. This focuses on the **backend** and the **Slayer semantic layer** — the
parts that actually do the thinking, reading, and writing. The Flutter app
(phone UI) is treated as a thin "messenger" and mostly ignored here.

If you read this top to bottom, you'll understand: what an "AI agent" actually is,
how it reads your database, how it writes to it safely, and how every guardrail
fits together.

---

## Table of contents

1. [The 30-second mental model](#1-the-30-second-mental-model)
2. [The cast of characters (who does what)](#2-the-cast-of-characters-who-does-what)
3. [What "an AI agent" really means here](#3-what-an-ai-agent-really-means-here)
4. [The big journey: one message, start to finish](#4-the-big-journey-one-message-start-to-finish)
5. [Reading data: the Slayer layer explained](#5-reading-data-the-slayer-layer-explained)
6. [Writing data: tools, permission, and safety](#6-writing-data-tools-permission-and-safety)
7. [The agentic loop, step by step](#7-the-agentic-loop-step-by-step)
8. [Pausing for permission (how "Approve/Deny" works)](#8-pausing-for-permission-how-approvedeny-works)
9. [Every guardrail, and why it exists](#9-every-guardrail-and-why-it-exists)
10. [Keeping the AI in sync with the database](#10-keeping-the-ai-in-sync-with-the-database)
11. [Glossary](#11-glossary)
12. [Where everything lives (file map)](#12-where-everything-lives-file-map)

---

## 1. The 30-second mental model

You type a message like *"Who do I still need to follow up with for GITEX?"*

The system does this:

1. Your phone sends the text to the **backend** (a server program).
2. The backend asks an **LLM** (Google's Gemini AI model by default): *"Here's the user's
   question and a list of tools you can use. What should we do?"*
3. The LLM can't touch the database itself. Instead it replies *"please run the
   `query_crm` tool with these arguments"* — like a manager writing a work order.
4. The backend runs that tool. For **reading**, the tool asks **Slayer** (a
   separate program) to fetch the data from the database safely.
5. The backend feeds the data back to the LLM: *"here's what we found."*
6. The LLM writes a normal human reply: *"You have 3 people left for GITEX: ..."*
7. The backend saves that reply and sends it to your phone.

That loop — **ask the LLM → it requests a tool → run the tool → feed results
back → repeat until it produces a final answer** — is the whole "agent." That's
it. Everything else in this guide is detail and safety around that loop.

---

## 2. The cast of characters (who does what)

Think of it as a small company with strict roles:

| Character | What it is | Its job | Can it touch the DB? |
|-----------|-----------|---------|----------------------|
| **The phone app** | Flutter UI | Sends your text, shows replies | No |
| **The backend** | An Express/TypeScript server | The "office manager." Coordinates everything, enforces all the rules | Yes (carefully) |
| **The LLM** | An AI model called over the internet — Google **Gemini** by default (model `gemini-3.1-flash-lite`), with OpenAI as a fallback if no Gemini key is configured | The "brain." Decides what to do, writes the final reply. **It only outputs text and tool requests** | **No — never** |
| **Slayer** | A separate Python program | The "librarian." Safely turns read-requests into SQL and fetches data | Reads only |
| **Supabase** | The actual database (PostgreSQL) | Stores all your contacts, events, emails, messages | It *is* the data |

The single most important idea: **the AI brain never touches your database
directly.** It can only *ask* the backend to run specific, pre-approved tools.
The backend is the bouncer. This is what makes the whole thing safe even though
an AI (which can be unpredictable) is involved.

```
  You (phone)
      |  "Who do I follow up with for GITEX?"
      v
  +-----------------------------------------------+
  |  BACKEND  (the office manager / bouncer)      |
  |                                               |
  |   asks ->  LLM (Gemini)  "what should I do?"  |
  |   LLM says -> "run query_crm tool"            |
  |                                               |
  |   for READS  -> Slayer -> Supabase (database) |
  |   for WRITES -> Supabase directly             |
  +-----------------------------------------------+
      |  final reply
      v
  You (phone)
```

---

## 3. What "an AI agent" really means here

A plain chatbot just talks. An **agent** can also *act* — it can take steps in
the real world (here: read and change your CRM data). The trick that makes this
possible is called **tool calling** (sometimes "function calling").

Here's the key mental shift for a beginner:

- The LLM does **not** run code. It does **not** have a database connection.
- The backend hands the LLM a **menu of tools**, written in a structured format
  (JSON). Each tool has a name, a description, and a list of arguments it accepts.
- When the LLM "wants" to do something, it doesn't do it — it outputs a small
  message that means *"call the tool named `create_contact` with
  `{first_name: 'Sasha'}`."*
- The backend reads that request, decides whether to allow it, runs the real
  code, and hands the result back to the LLM.

So the LLM is like a smart assistant who can only fill out request forms. The
backend is the clerk who actually opens the filing cabinet. The clerk can refuse,
double-check, or ask you for permission first.

The menu of tools in Exono (defined in
[`backend/src/routes/assistant.ts`](backend/src/routes/assistant.ts)):

| Tool name | Type | What it does |
|-----------|------|--------------|
| `query_crm` | **read** | Look up anything: contacts, events, emails, stats. Goes through Slayer. |
| `describe_model` | **read (schema)** | Get one table's exact column names + types, on demand, before querying it (lazy schema — section 10.5). |
| `get_event_followups` | **read** | List contacts attached to one event (a convenience read). |
| `get_priorities` | **read** | How many follow-ups are currently due (the home "Today's Priorities" count). |
| `web_search` | external | Search the live internet (via a service called Tavily). |
| `create_contact` | **write** | Add a new contact. |
| `update_contact` | **write** | Change an existing contact. |
| `create_event` | **write** | Add a new event/exhibition. |
| `update_event` | **write** | Change an existing event. |
| `draft_email` | **write** | Save a draft email for a contact. |
| `log_interaction` | **write** | Record a call/meeting/note with a contact (also re-opens their follow-up to pending). |
| `set_follow_up_status` | **write** | Set a contact's follow-up status (new/pending/done/skipped), per-event or across all. |
| `set_follow_up_priority` | **write** | Flag/unflag a contact as a priority follow-up, per-event or global. |

Reads run instantly. **Writes always pause and ask you "Approve / Deny" first**
(explained in section 8).

---

## 4. The big journey: one message, start to finish

Let's follow the exact path of one message through the backend. The entry point
is the function that handles `POST /api/assistant/respond` in
[`assistant.ts`](backend/src/routes/assistant.ts) (around line 1265). Don't
worry about the code — here's what happens in order:

**Step 1 — Validate the request.**
The backend checks the incoming data has the right shape (a valid conversation
ID and non-empty text). Bad requests are rejected immediately. This is done with
a library called **Zod** (think: a form validator).

**Step 2 — Sanitize the text.**
`sanitiseUserInput()` truncates over-long input and logs anything that looks like
a "prompt injection" attack (e.g. text saying *"ignore all previous
instructions"*). This is a security log + a hard length cap.

**Step 3 — Rate limit.**
`checkRateLimit()` makes sure one user can't fire more than 30 messages per
60-second window (`RATE_MAX = 30`, `RATE_WINDOW_MS = 60_000`) — to control cost
and abuse. The count is stored in the database (`assistant_rate_limits`) so it
survives server restarts.

**Step 4 — Save your message.**
Your message is written to the `messages` table so the conversation has history.

**Step 5 — Build the "system prompt."**
This is the big instruction sheet handed to the LLM at the start of every turn.
It includes:
- Who the user is (pulled from `user_profiles` — name, role, their products).
- Today's date (so the AI knows what "today" means).
- A **table directory** — one line per queryable table with its name and a short
  description of what it holds (e.g. `contacts: people you have met...`), built by
  `buildModelDirectorySection()` from `MODEL_DIRECTORY`. **It does NOT list the
  columns.** When the AI needs a table's columns it calls the `describe_model`
  tool to fetch them on demand (see section 10.5 — this "lazy schema" approach is
  now implemented). This keeps the prompt small and shrinks the column-name
  surface the AI can hallucinate against.
- The rules of behavior (e.g. *"always look up a record before changing it",
  "never invent a date", "never put database IDs in your reply"*).

This is built by `buildSystemPrompt()`. The system prompt is the "training" for
this specific conversation — it's plain English instructions, regenerated every
turn.

**Step 6 — Load recent history.**
The last 20 messages of the conversation are loaded so the AI has context.

**Step 7 — Run the agentic loop.**
This is the heart of it (`runLoop()`). The backend repeatedly asks the LLM what
to do, runs the tools it requests, and feeds results back, until the LLM produces
a final text reply (or hits a write that needs your permission). Full detail in
section 7.

**Step 8 — Finalize.**
Once the LLM gives a final answer:
- `finalizeTurn()` saves the assistant's reply to the `messages` table.
- It attaches "linked entity cards" (the little tappable contact/event cards) by
  remembering which records the tools touched.
- `autoTitleConversation()` gives the conversation a short title.
- Everything is sent back to the phone.

**If anything failed**, the backend deletes your saved message so a retry doesn't
create duplicates, and returns an error.

---

## 5. Reading data: the Slayer layer explained

This is the part most people find mysterious, so we'll go slow.

### The problem Slayer solves

Databases speak **SQL** — a query language like
`SELECT * FROM contacts WHERE user_id = '...'`. We could let the AI write SQL
directly, but that's dangerous and error-prone:
- AI models frequently write slightly-wrong SQL.
- Raw SQL could accidentally (or maliciously) read another user's data.
- We'd have to trust the AI to always add the right security filters.

**Slayer is a "semantic layer."** Instead of writing SQL, you describe *what you
want* in a structured, safe way, and Slayer generates the correct SQL for you.

### What a Slayer request looks like

The AI doesn't say `SELECT ...`. It fills out the `query_crm` tool, e.g.:

```json
{
  "source_model": "contacts",
  "dimensions": ["first_name", "last_name", "email"],
  "filters": ["follow_up_status = 'needs_followup'"],
  "limit": 50
}
```

In plain English: *"From the contacts table, give me the first name, last name,
and email of everyone whose follow-up status is 'needs followup', up to 50
people."*

- `source_model` = which table.
- `dimensions` = which columns you want back.
- `filters` = conditions (the "WHERE" part).
- `measures` = math like counts/sums (e.g. `["*:count"]` to count rows).
- `limit` = max rows.

Slayer takes this description and produces the actual SQL. The AI never sees or
writes the SQL.

### The security magic: ownership injection

Before the request ever reaches Slayer, the backend file
[`slayer-client.ts`](backend/src/services/slayer-client.ts) does three
critical things in `applyOwnership()`:

1. **Strips any `user_id` filter the AI tried to set.** Even if the AI tried to
   peek at someone else's data, that filter is removed.
2. **Forces in the *real* logged-in user's filter:** `user_id = '<you>'`. So the
   query can only ever return *your* rows. This applies to every table that has a
   `user_id` column (the `USER_ID_TABLES` set).
3. **Hides deleted rows:** adds `deleted_at IS NULL` for tables that support soft
   deletion (the `SOFT_DELETE_TABLES` set), so the AI never sees trashed records.

There's also a second safety net: Slayer connects to the database as a special
**read-only** user (`slayer_readonly`) that physically *cannot write* and has
Postgres's own Row-Level Security on top. So even if the backend had a bug,
Slayer still couldn't damage or leak data.

### Two more clever bits

**Relative dates are computed by the backend, not the AI.** AI models are bad at
date math ("what's the date 7 days from now?"). So instead of letting the AI
write date filters, it picks a *name* like `date_window: "next_7_days"`, and the
backend function `expandDateWindow()` fills in the exact timestamps. This is why
"events this week" reliably works.

**Replica lag self-heal.** Slayer reads from a *copy* of the database that can
lag a fraction of a second behind. If you just created a contact and immediately
ask to see it, the copy might not have it yet. So if a read returns 0 rows right
after a write, the backend waits 350 milliseconds and tries once more. This
quietly fixes the "I just made it but the AI can't see it" problem.

### Slayer's "models"

Slayer knows about each table through small config files (YAML) in
`slayer/slayer_data/models/exono/` (e.g. `contacts.yaml`, `events.yaml`). These
describe each table's columns. They are **auto-generated** by Slayer scanning the
database — you don't hand-edit them; you re-run Slayer's ingestion if the schema
changes.

This is also where the AI gets a table's column names: the `describe_model` tool
(section 10.5) asks Slayer for one table's columns + types on demand, rather than
the system prompt listing every table's columns up front.

---

## 6. Writing data: tools, permission, and safety

Writing is more dangerous than reading (you can corrupt or overwrite real data),
so it's handled completely differently from reads. Writes do **not** go through
Slayer — Slayer is read-only. Writes go straight to the database (Supabase) via
the backend, using the **service-role** connection (a privileged connection),
which is exactly why every write is wrapped in a gauntlet of checks: the
connection itself is powerful, so the *code* must be the thing that restricts it.

Each write tool has a matching "executor" function in
[`assistant.ts`](backend/src/routes/assistant.ts): `execCreateContact`,
`execUpdateContact`, `execCreateEvent`, `execUpdateEvent`, `execDraftEmail`.
All of them are dispatched from one place, `executeTool()`, which routes a tool
name to its executor.

### 6.1 The seven layers a write passes through

A write travels through these in order. If any layer rejects, the write stops and
the AI is told why (and it's instructed not to blindly retry).

**Layer 0 — The "look it up first" rule (before any write is even attempted).**
The system prompt forces the AI to find a record before changing it: *"ALWAYS
call query_crm FIRST... Never assume you know an ID"* and *"if the user says
update/change/reschedule... query first, then update — NEVER call create_* for an
update."* This is behavioral (instructions to the AI), reinforced by Layer 3.

**Layer 1 — Permission pause (the big one).**
The very first time the AI wants to write anything, the whole turn **pauses** and
asks you to Approve or Deny. Nothing is written until you tap Approve. This is
the single most important write protection. (Full mechanics in section 8.)

**Layer 2 — Zod validation (per executor).**
When the write finally runs, the executor re-checks the AI's arguments against
strict rules the database itself can't enforce — a valid email format
(`z.string().email()`), a parseable date, a time-of-day in 24h `HH:MM` form
(`timeOfDay` regex), required fields present. Garbage is rejected here with a
clear message. The Zod schema is also the list of fields the executor will even
*look at* — anything the AI sends that isn't in the schema is dropped.

> **Heads-up — Zod is hand-written, per field, and is a manual step on every
> relevant schema change.** The database can store *a* string in an `email`
> column, but only the hand-written `z.string().email()` rule enforces it's a
> *valid* email; rules like "must be a parseable date" or "`end_time` after
> `start_time`" exist *only* in Zod, nowhere in the DB. So when you add a column
> the AI should write, you must add it to that executor's Zod schema (and the
> tool params). The CI drift-check (section 10) catches a forgotten *tool param*,
> but it does **not** verify the Zod rules themselves — those stay deliberately
> human-owned, because the valuable format rules can't be auto-derived from the
> database.

**Layer 3 — Name resolution that refuses to guess.**
For updates, the executor turns a name into an ID via `resolveContactId` /
`resolveEventId`. These query the **primary** database (not Slayer's possibly-
lagging copy) so a record created moments earlier in the same conversation is
visible. Crucially, they **never auto-pick**:
- 0 matches → error: *"No contact named X found"* (and a hint to list contacts).
- 2+ matches → error: *"Multiple contacts match X: ... Ask the user which one."*

So the AI can't silently edit the wrong "Sasha." It must come back and ask you.

**Layer 4 — The immutable-fields denylist.**
`IMMUTABLE_FIELDS` is a set of columns the AI may **never** write — identity/
ownership (`id`, `user_id`, `sender_user_id`), audit/soft-delete (`created_at`,
`updated_at`, `deleted_at`), sync bookkeeping (`client_op_id`), AI/enrichment-
generated fields (`ai_insights`, `enriched_at`, ...), media handled by upload
flows (`avatar_url`, `image_url`), and status timestamps the app maintains
(`sent_at`, `done_at`, ...). The function `stripImmutable()` deletes any of these
from the AI's data right before the DB call.

The design is **deny-list, not allow-list**: anything *not* on the denylist is
allowed through. The database rejects columns that don't actually exist, so a
normal new column auto-becomes settable — but a *dangerous* new column must be
added to the denylist explicitly. (This is the safety boundary that section 10's
CI check guards.)

**Layer 5 — Ownership scoping on the write itself.**
Every update is run with `.eq('user_id', userId)` (and `.is('deleted_at', null)`)
in the query. So even if the AI somehow had another user's record ID, the
`UPDATE` would match zero rows and fail with *"not found or access denied."* You
can only ever change your own, non-deleted data.

**Layer 6 — Linked-record ownership verification.**
When a write references another record (e.g. `create_contact` with an
`event_id`, or `draft_email` with a `contact_id`/`event_id`), the executor first
checks *that* record also belongs to you before proceeding. You can't attach your
new contact to someone else's event.

### 6.2 What each write executor actually does — as a conversation

This is the part most guides skip. A write is often more than a single `INSERT`.
To make it concrete, each tool below is told as a back-and-forth: **what the LLM
does**, then **what the system (backend) does** in response, then back to the LLM,
and so on. Remember the golden rule — the LLM only ever *requests*; the system is
what actually runs code and talks to the database.

(Everything before the tool even runs — the permission pause — is covered in
section 8. Here we pick up *after* you tapped Approve.)

---

#### `create_contact` → `execCreateContact`  ("Add Sasha from Acme, met at GITEX")

- **LLM:** First it follows the prompt's "look it up first" habit — it may call
  `query_crm` to check whether Sasha or the event already exist. Then it requests
  `create_contact` with `{ first_name: "Sasha", company_name: "Acme",
  event_id: <GITEX> }`.
- **System:** Pauses for your permission (section 8). You approve.
- **System:** Runs Zod validation — `first_name` is required, `email` (if given)
  must be a real email, etc. Bad input is rejected here.
- **System:** Sees `event_id` → checks *that event belongs to you*. If not, it
  stops with "Event not found or access denied."
- **System (a hidden second write):** Sees `company_name: "Acme"` and no
  `company_id` → searches the companies table for "Acme." If found, reuses it; if
  **not found, it creates a new company row** and uses that id.
- **System:** Copies the plain fields through, normalizes `scanned_details` (the
  flat business-card-extras map), runs `stripImmutable()` (drops `id`, `user_id`,
  timestamps, etc.), and **inserts the contact** with your `user_id`.
- **System (more hidden writes):** Because an `event_id` was linked, it also
  inserts an `interactions` row ("Added by assistant") and a `captures` row, so
  Sasha shows up in GITEX's activity. So this one tool call wrote to up to
  **four** tables: companies, contacts, interactions, captures.
- **System:** Returns the new contact object as the tool result.
- **LLM:** Sees "contact created successfully," and writes the final reply:
  *"Added Sasha from Acme to GITEX."* (plus a tappable Sasha card).

---

#### `update_contact` → `execUpdateContact`  ("Add a fax number for Sasha")

- **LLM:** Requests `update_contact` with `{ contact_name: "Sasha",
  scanned_details: [{ key: "fax", value: "+974..." }] }`. Note `scanned_details`
  is a **list of `{key, value}` pairs** in the tool API (see section 6.6 for why).
- **System:** Pauses for permission. You approve.
- **System:** Zod-validates the args, and **converts the `{key,value}` list into a
  flat `{ fax: "+974..." }` object** (the form the rest of the code and the DB
  use).
- **System (name resolution, Layer 3):** Turns "Sasha" into an id by querying the
  **primary** database. If 0 match → error "No contact named Sasha." If 2+ match
  → error "Multiple contacts match Sasha — ask the user." It **never guesses.**
- **System (merge, not overwrite):** For `scanned_details` it *loads the existing*
  business-card extras and merges the new `fax` key in (a pair whose value is `""`
  removes that key) via `mergeScannedDetails` — so adding a fax doesn't wipe the
  existing address/website. (`last_contacted_at`, if present, is converted to an
  ISO timestamp here too.)
- **System:** Runs `stripImmutable()`. If nothing valid is left to write, it
  errors instead of running an empty update. Otherwise it updates the row **with
  the ownership filter** (`WHERE id=... AND user_id=YOU AND deleted_at IS NULL`).
- **System:** Returns the updated contact.
- **LLM:** *"Added Sasha's fax number."*

---

#### `create_event` → `execCreateEvent`  ("Create an event called Web Summit")

- **LLM:** It needs a date and the prompt forbids inventing one. If you didn't
  give a date, the LLM does **not** call the tool yet — it replies with a
  question: *"What date is Web Summit?"* (Loop ends, waiting for you.)
- **You:** "November 3rd."
- **LLM:** Now requests `create_event` with `{ name: "Web Summit",
  start_date: "2026-11-03..." }`.
- **System:** Pauses for permission. You approve.
- **System:** Zod-validates; converts the date to ISO; validates the time range
  (`end_time` must be after `start_time`); **rejects a start date in the past.**
- **System (dedup):** Checks whether an event with the same name + start_date
  already exists for you. If it does, it **returns that existing event** instead
  of creating a duplicate.
- **System:** Otherwise inserts the new event with your `user_id`, returns it.
- **LLM:** *"Created Web Summit on Nov 3."* (plus an event card).

---

#### `update_event` → `execUpdateEvent`  ("Move GITEX to start at 9am")

- **LLM:** Requests `update_event` with `{ event_name: "GITEX",
  start_time: "09:00" }`.
- **System:** Pauses for permission → approve → Zod-validate.
- **System (name resolution):** Resolves "GITEX" to an id by name (same
  no-guessing 0/1/many rules as `update_contact`).
- **System:** Converts/validates any dates and the time range; **rejects a past
  start date**; strips immutables; errors if nothing valid remains; updates with
  the ownership filter.
- **System:** Returns the updated event.
- **LLM:** *"GITEX now starts at 9am."*

---

#### `draft_email` → `execDraftEmail`  ("Draft a follow-up to Sasha")

- **LLM:** Usually reads first (`query_crm`) to get Sasha's real `contact_id`,
  because `draft_email` requires a UUID, not a name. Then it writes the subject
  and body itself (using your products/tone from the profile in the system
  prompt) and requests `draft_email` with `{ contact_id, subject, body }`.
- **System:** Pauses for permission. You approve.
- **System:** Zod-validates (`contact_id` must be a UUID, subject ≤ 300 chars,
  body non-empty).
- **System:** Verifies the **contact is yours**; if an `event_id` was included,
  verifies that too.
- **System:** Inserts a row in `email_drafts` with `status: 'draft'` and your
  `user_id`. **It only ever creates a draft — it never sends anything.**
- **System:** Returns the draft.
- **LLM:** *"Drafted a follow-up to Sasha."* (plus a draft card you can open).

### 6.3 After the write: linking and finishing

Once an approved write returns, the loop continues. When the AI finally produces
its text reply, `finalizeTurn()`:
- Saves the assistant message.
- Builds **linked-entity cards** from what the tools touched — any contact/event/
  draft that was created, updated, or read as a single result becomes a tappable
  card under the reply (it stores their ids + display fields on the message's
  `linked_entities`). Note the AI is told **never to put raw database IDs in its
  text** — the cards carry identity instead.

### 6.4 The end-to-end picture of one write

For *"Mark Sasha as contacted today"*:

```
AI: query_crm(contacts, name~"Sasha")   -> runs immediately (read)
AI: update_contact(name="Sasha",
        last_contacted_at=today,
        follow_up_status="contacted")    -> WRITE -> loop PAUSES
                                            state saved to DB
                                            permission card shown to you
   ----------------------- you tap Approve -----------------------
backend resumes:
   resolveContactId("Sasha")             -> 1 match (else it asks you)
   Zod-validate args
   convert last_contacted_at -> ISO
   stripImmutable(...)
   UPDATE contacts SET ... WHERE id=... AND user_id=YOU AND deleted_at IS NULL
AI: "Done — marked Sasha as contacted today."  (final reply + a Sasha card)
```

### 6.5 How the LLM learns a tool's shape, and where SQL actually runs

Two things people assume are "magic" — let's make them explicit. Nothing here is
implied; this is exactly how it works in the code.

#### (a) How does the LLM know what `create_contact` accepts?

It is **told**, via the tool's **JSON Schema** — the `parameters` block in the
tool definition in [`assistant.ts`](backend/src/routes/assistant.ts). For
`create_contact` it literally includes:

```js
parameters: {
  type: 'object',
  properties: {
    first_name:   { type: 'string' },
    last_name:    { type: 'string' },
    email:        { type: 'string' },
    company_name: { type: 'string', description: 'Company name — will be created if not found' },
    event_id:     { type: 'string', description: 'Link contact to this event UUID' },
    // ...
  },
  required: ['first_name'],   // this is how the model knows first_name is mandatory
}
```

How that reaches the model on every turn:

- **System:** bundles all tools into `ALL_TOOLS` and passes them on each LLM call:
  `litellm.generateWithTools(systemPrompt, history, ALL_TOOLS)`.
- **System:** inside `litellm-service.ts`, `_geminiToolCall` converts each tool
  into the AI provider's **native function-calling** format (Gemini's
  `functionDeclarations`; the OpenAI path uses its `tools` array), passing through
  the `name`, `description`, and `parameters` unchanged.
- **LLM:** the provider shows the model these declarations. The model sees the
  field names, their types, which are `required`, and the human-readable
  descriptions (e.g. *"Company name — will be created if not found"*), and emits a
  function call whose `args` match that schema.

So the model is **not guessing** the shape — it's reading a contract. This is a
*separate* mechanism from the `query_crm` column-name dump in the system prompt
(section 4, step 5): read-table columns are described in prose in the prompt;
write-tool shapes are delivered as structured tool definitions.

**Critical distinction — JSON Schema is NOT the Zod schema.** They are two
different things doing two different jobs:

```
JSON Schema (teaches the LLM the shape)
        |
        v
LLM emits args  ->  Zod schema (the server RE-validates, distrusting the LLM)
```

- The **JSON Schema** is intentionally *loose* — `email: { type: 'string' }`. Its
  job is only to teach the model the field exists and is a string.
- The **Zod schema** in the `exec*` function is *strict* —
  `z.string().email()`. Its job is to *distrust* whatever the model sent and
  reject anything invalid before it reaches the database.

This is exactly why **both must be updated on a schema change** (section 10): the
JSON Schema so the model knows a new field exists, and the Zod schema so the
server safely accepts it.

#### (b) Where is the SQL actually run?

Short version: **our backend code never writes raw SQL strings — not for writes,
not for reads.** It expresses *intent*; something else turns that into SQL.

**Writes (`create_*` / `update_*`, name lookups, ownership checks):** the executor
calls the **Supabase client query builder**, not SQL. The real write in
`execCreateContact` is:

```js
const { data: contact, error } = await supabaseAdmin
  .from('contacts')
  .insert({ ...stripImmutable(insert), company_id, user_id: userId })
  .select('*')
  .single();
```

What happens under the hood, step by step:

- **System:** `supabaseAdmin` is the **service-role** Supabase client
  (`backend/src/config/supabaseClients.ts`).
- **System:** `.from('contacts').insert({...})` builds a request and sends it over
  HTTP to **PostgREST** — Supabase's auto-generated REST API that sits in front of
  the database.
- **PostgREST:** translates that request into a **parameterized SQL `INSERT`** and
  runs it on the Postgres database. (Updates become `UPDATE ... WHERE ...` the
  same way, from `.update({...}).eq('id', ...).eq('user_id', ...)`.)

So the component that literally executes write SQL is **PostgREST, inside
Supabase** — not your backend.

**Reads (`query_crm`):** the SQL is generated by **Slayer**, the semantic layer
(section 5). The backend sends Slayer a structured request over HTTP; Slayer
generates the SQL and runs it through its own **read-only** database connection.

Putting it together — who does what, for each kind of database access:

| Operation | Who BUILDS the SQL | Who RUNS it on Postgres | Raw SQL hand-written in our code? |
|-----------|--------------------|-------------------------|-----------------------------------|
| Reads (`query_crm`) | Slayer (Python service) | Slayer's read-only DB connection | No |
| Writes (`create_*`/`update_*`) | Supabase client → PostgREST | PostgREST (inside Supabase) | No |
| Name resolution / ownership checks | Supabase client → PostgREST | PostgREST (inside Supabase) | No |

In all three paths, **no one hand-writes raw SQL strings.** That is deliberate:
letting a library build parameterized queries is what makes SQL-injection
impossible and makes the ownership filters (`.eq('user_id', userId)`) reliable.
Our code only ever says *what* it wants — through a structured request (reads) or
a query builder (writes) — never *how* to fetch it as a SQL string.

### 6.6 A tool-shape gotcha: Gemini's schema subset and `scanned_details`

This is a small but real wrinkle worth knowing, because it shaped how one field
is designed.

The AI provider validates each tool's JSON Schema. **Gemini's function-calling
validator accepts only a restricted subset of JSON Schema** and returns a `400`
error on keywords it doesn't know — notably `additionalProperties`, `default`,
`$schema`, and a few others. (OpenAI's path accepts the full schema.)

Two defenses, working together:

1. **A sanitizer strips unsupported keywords on the Gemini path only.**
   `sanitiseGeminiSchema()` in
   [`litellm-service.ts`](backend/src/services/litellm-service.ts) recursively
   removes those keywords from each tool's `parameters` *just before* sending to
   Gemini. The original tool definitions are untouched (OpenAI still gets the
   full schema). Stripping a keyword like `additionalProperties` only removes a
   *hint* to the model — the real enforcement is Zod on the server (section 6.1,
   Layer 2), so safety is never affected.

2. **`scanned_details` was redesigned to avoid needing the keyword at all.**
   `scanned_details` is the "extra business-card fields" bag (address, fax,
   website…). The natural JSON Schema for "an object with arbitrary string keys"
   is `additionalProperties: { type: 'string' }` — exactly the keyword Gemini
   rejects. Rather than rely only on stripping it (which would leave the model
   with a vaguer hint), the tool exposes `scanned_details` as a **list of
   `{key, value}` pairs**, which Gemini's subset *can* fully describe:

   ```jsonc
   // what the LLM is asked to produce:
   "scanned_details": [
     { "key": "address", "value": "Doha, Qatar" },
     { "key": "website", "value": "acme.com" }
   ]
   ```

   The **Zod schema then transforms that list back into the flat object**
   (`{ address: "Doha, Qatar", website: "acme.com" }`) that the database column,
   `mergeScannedDetails`, and the card-scan UI all expect. So the on-disk shape
   and every downstream consumer are unchanged — only the *tool input shape* the
   LLM sees became array-of-pairs. (A pair with `value: ""` still means "remove
   this key" on update.)

The payoff: Gemini gets a **complete, formal contract** for `scanned_details`
instead of a stripped-down hint, which means the model produces the right shape
more reliably — verified live, the model emits the `{key, value}` list exactly as
intended.

---

## 7. The agentic loop, step by step

This is `runLoop()` in [`assistant.ts`](backend/src/routes/assistant.ts). It's
a loop that runs up to 6 times (`MAX_ITERATIONS`). Each pass:

1. **Ask the LLM.** Send it the system prompt + the conversation so far + the
   tool menu. (`litellm.generateWithTools()` — this is the actual call over the
   internet to Gemini.)

2. **Look at what the LLM returned.** It's one of two things:
   - **Plain text** → the AI is done thinking; this is the final answer. Exit the
     loop and return it.
   - **One or more tool requests** → the AI wants to do something. Continue.

3. **Check for writes.** If any requested tool is a write
   (`create_*`, `update_*`, `draft_email`), the loop **stops and pauses for
   permission** (section 8). Any *reads* the AI batched before the write still
   run; the write itself waits.

4. **Run the reads/searches.** Each tool is executed by `executeTool()`. Read
   results are collected.

5. **Feed results back.** The tool results are appended to the conversation
   history, and the loop goes back to step 1. Now the LLM can "see" what it found
   and decide the next step.

This repeat-until-done structure is why it's called *agentic*: the AI can chain
several steps. Example: *"Draft a follow-up email to the GITEX contact"* might be:
look up the event → look up the contact → draft the email → write the final
reply. Each is one pass of the loop, each result feeding the next decision.

**Safety stop:** if it somehow loops 6 times without finishing, the backend asks
the LLM for a one-line summary and ends, so it can never loop forever.

```
        +---------------------------+
        |  Ask the LLM what to do   | <-----------------+
        +---------------------------+                   |
                     |                                  |
        is the answer plain text? ---- yes ---> DONE (final reply)
                     |                                  |
                     no (it wants tools)                |
                     |                                  |
        is any tool a WRITE? ---- yes ---> PAUSE for permission
                     |                                  |
                     no                                 |
                     v                                  |
        +---------------------------+                   |
        |  run the read tools       |                   |
        |  feed results back        | ------------------+
        +---------------------------+
```

---

## 8. Pausing for permission (how "Approve/Deny" works)

This is the cleverest engineering piece, so here's the beginner version.

**The problem:** the AI is in the middle of a multi-step task and now wants to
write to your database. We must stop and ask you first — but the AI's "train of
thought" (all the steps and results so far) would be lost if we just stopped.

**The solution:** the backend takes a complete *snapshot* of the in-progress
task and saves it to a database table called `assistant_pending_actions`. Then it
sends your phone a "permission card" describing exactly what will change. Your
turn is literally frozen on the server, waiting.

Walk-through for *"Mark Sasha as contacted today"*:

1. The AI looks up Sasha (a read — runs fine), then requests `update_contact`.
2. `runLoop()` sees a write → returns `kind: 'paused'`.
3. `suspendForPermission()` saves the entire loop state (history + results +
   the exact write it wants to do) into `assistant_pending_actions`, and returns
   an "awaiting permission" response.
4. Your phone shows a card: **"Update · CONTACT · Sasha"** with the fields that
   will change. (The card is built generically — it shows whatever fields the AI
   is setting, so it never needs updating when columns change.)
5. **You tap Approve.** The phone calls `POST /api/assistant/resume`.
6. The backend loads the saved snapshot, runs the actual write (`executeTool` →
   `execUpdateContact` → all the safety layers from section 6), then **resumes
   the exact same loop** where it left off. The AI sees "the write succeeded" and
   writes a final confirmation.
7. **If you tap Deny** instead, the AI is told *"the user declined; don't retry"*
   and it continues gracefully without writing.

Because the whole state lives in a database row, this survives you backgrounding
the app, losing connection, or coming back later. There's even a
`GET /api/assistant/pending` endpoint so the app can re-show the card if it was
closed mid-decision.

**One important rule:** only the *first* write in a step pauses. If the AI tries
to batch several writes at once, they're handled one at a time, so you always
approve one concrete change at a time — never a blank check.

---

## 9. Every guardrail, and why it exists

A single reference table of all the safety mechanisms:

| Guardrail | Where | Protects against |
|-----------|-------|------------------|
| Input validation (Zod) | `respondSchema`, each `exec*` | Malformed requests, bad data shapes |
| Input sanitization | `sanitiseUserInput()` | Prompt-injection attempts, giant inputs |
| Rate limiting | `checkRateLimit()` | Abuse, runaway cost |
| LLM can't touch the DB | whole design | The AI doing anything unexpected directly |
| Ownership injection (reads) | `applyOwnership()` | Reading another user's data |
| Read-only Slayer DB user + RLS | Slayer config | Any read path bug causing a write or leak |
| Backend computes dates | `expandDateWindow()` | AI getting "today/this week" wrong |
| Permission pause on writes | `runLoop()` + `suspendForPermission()` | Unwanted/surprise data changes |
| Zod per-field rules (writes) | each `exec*` | Invalid emails/dates being saved |
| Immutable-fields denylist | `IMMUTABLE_FIELDS` + `stripImmutable()` | AI overwriting IDs/ownership/system data |
| Ownership filter on writes | `.eq('user_id', userId)` | Editing records you don't own |
| No-guessing resolvers | `resolveContactId/EventId` | Editing the wrong record on a name clash |
| Loop iteration cap | `MAX_ITERATIONS = 6` | Infinite loops / runaway cost |
| Rollback on failure | catch block in `/respond` | Half-finished turns leaving junk data |

The theme: **assume the AI might be wrong or manipulated, and make sure it
physically cannot do harm even if it tries.**

---

## 10. Keeping the AI in sync with the database

The AI's tools hardcode some knowledge about your database in TypeScript. When
you change the database schema (add/rename/remove a column), some of that has to
be kept in step. Two automated safety nets now help (see
[`backend/CLAUDE.md`](backend/CLAUDE.md) for the authoritative version):

**Auto-derived (you don't maintain these):**
- The lists of which tables have `user_id` and `deleted_at` columns
  (`USER_ID_TABLES`, `SOFT_DELETE_TABLES`) are now read from the live database at
  server startup by `initSchemaFlags()`. These are purely structural facts, so
  the database is the source of truth.

**Still a human decision (but now enforced):**
- Whether a new column is *AI-writable* or *system-managed* is a judgment call no
  database can make for you (e.g. `last_contacted_at` is writable but
  `enriched_at` is not — both are just timestamps).
- A **CI check** (`backend/scripts/check-schema-drift.ts`, run automatically by a
  GitHub Action) **fails the build** if a column on a writable table hasn't been
  classified as either AI-writable or system-managed. This makes it impossible to
  *silently forget* — the exact bug that once accidentally hid the `linkedin_url`
  field from the AI for a long time.

So: structural facts are automatic; the meaningful human decisions are now
forced to be made deliberately rather than forgotten.

### 10.5 Lazy ("just-in-time") schema loading — IMPLEMENTED

> **Status: implemented.** This is how the schema is delivered to the AI today.

**The problem it solved.** The system prompt used to stuff the full column-name
map of all ~17 tables (~200 names) into *every* request, even though a typical
question only touches one table. That spent tokens on every turn and gave the
model a large surface of column names to confuse or invent ("hallucinate")
against.

**What's now in the code (two parts):**

1. **The system prompt carries only a table *directory*** — one line per table:
   its name plus a short description of what it holds, with **no columns**. It is
   built by `buildModelDirectorySection()` from the `MODEL_DIRECTORY` map in
   [`assistant.ts`](backend/src/routes/assistant.ts). Example lines:
   ```
   - contacts: People you have met / your leads (name, email, phone, job, follow-up status).
   - events: Exhibitions / trade shows (name, location, start/end date & time).
   - email_drafts: Saved draft emails for contacts (subject, body, status).
   ```

2. **A `describe_model` tool fetches one table's columns on demand.** The system
   prompt instructs the AI: *before using a table's columns in `query_crm`, call
   `describe_model(source_model)` to get its exact column names and types — never
   guess.* The tool's executor (in `executeTool`) validates the table is
   allowlisted, then calls `slayerGetModelColumnsTyped(model)` in
   [`slayer-client.ts`](backend/src/services/slayer-client.ts), which fetches
   that one table's non-hidden columns (name + type) from Slayer. It returns the
   column list **plus a `filter_format` reminder** (how to write filter strings,
   to use `date_window` for relative dates, and that ownership filters are
   automatic). If Slayer is unreachable it returns a clean "try again" error.

**The new read flow, as a conversation:**

- **LLM:** reads the table directory, decides it needs `contacts`, and (if it
  isn't already sure of the columns) calls `describe_model("contacts")`.
- **System:** returns `contacts`' columns + types + the filter-format reminder.
- **LLM:** now builds a correct `query_crm` call using real column names.
- **System:** runs it through Slayer (with ownership injection) and returns rows.

Columns are fetched **on demand, one table at a time**, instead of all up front.

**The tradeoff we accepted (it's not a pure win):**
- It can add **one extra LLM round-trip** before a read (describe → then query) —
  slightly more latency and one more model call on the common read path. The
  prompt allows the AI to reuse a table's columns once fetched within a
  conversation, to limit repeat calls.
- A multi-table question may need several `describe_model` calls.
- It mainly fixes *invented column names*. The other real failure mode —
  **malformed filter strings** (the model leaking JSON punctuation into a filter)
  — is handled separately by `sanitiseFilter()` in `slayer-client.ts`; the
  `describe_model` response's `filter_format` hint also nudges the model toward
  correct filters.

**Why this is safe:** `describe_model` is a **read** (not in `WRITE_TOOL_NAMES`),
so it runs inline with no permission pause. It only ever returns *structure*
(column names + types) for allowlisted tables — never row data — and it cannot be
used to query another table or bypass the ownership rules that `query_crm`
enforces.

---

## 11. Glossary

- **LLM (Large Language Model):** the AI model that understands and generates
  text. The "brain." Here it's Google Gemini by default (`gemini-3.1-flash-lite`),
  with OpenAI as a fallback. Lives on the provider's servers; we call it over the
  internet.
- **Backend:** the server program we control (Express + TypeScript). The
  coordinator and rule-enforcer.
- **Tool / function calling:** the mechanism by which the LLM requests an action
  (it outputs a structured "call this tool" message; it never runs code itself).
- **Agent / agentic loop:** an LLM that takes multiple tool-using steps toward a
  goal, feeding each result back into its next decision.
- **System prompt:** the instruction sheet given to the LLM at the start of each
  turn (who the user is, the rules, today's date, the schema).
- **Slayer / semantic layer:** a separate program that turns safe, structured
  "what I want" descriptions into real SQL, so the AI never writes SQL.
- **SQL:** the language databases speak.
- **Supabase / PostgreSQL:** the actual database storing your data.
- **Zod:** a validation library that checks data has the right shape/format.
- **Soft delete (`deleted_at`):** marking a row as deleted by setting a timestamp
  instead of actually removing it, so it can be recovered. Hidden from the AI.
- **Ownership injection:** automatically forcing `user_id = you` into every query
  so you can only ever see/change your own data.
- **Prompt injection:** an attack where a user tries to trick the AI with text
  like "ignore your instructions." Logged and length-capped here.
- **Replica lag:** the brief delay before a read-copy of the database catches up
  to a recent write.
- **CI (Continuous Integration):** automated checks that run on every code change
  (here, via GitHub Actions) and can fail the build to block mistakes.

---

## 12. Where everything lives (file map)

| File | What's in it |
|------|--------------|
| [`backend/src/routes/assistant.ts`](backend/src/routes/assistant.ts) | **The heart.** Tool definitions, the system prompt, the agentic loop (`runLoop`), all write executors, the permission pause/resume, and the `/respond`, `/resume`, `/pending` endpoints. |
| [`backend/src/services/slayer-client.ts`](backend/src/services/slayer-client.ts) | Talks to Slayer for reads. Ownership injection, the user_id/deleted_at table sets, and the boot-time schema auto-derive. |
| [`backend/src/services/litellm-service.ts`](backend/src/services/litellm-service.ts) | Wraps the actual calls to the Gemini/OpenAI LLM (including tool-calling). Also sanitizes tool schemas for Gemini's restricted subset (section 6.6). |
| [`backend/src/services/schema-introspection.ts`](backend/src/services/schema-introspection.ts) | Reads the live DB column layout for the auto-derive. |
| [`backend/scripts/check-schema-drift.ts`](backend/scripts/check-schema-drift.ts) | The CI check that prevents schema/AI drift. |
| `slayer/slayer_data/models/exono/*.yaml` | Auto-generated descriptions of each table that Slayer uses. |
| [`backend/CLAUDE.md`](backend/CLAUDE.md) | The authoritative rules for keeping the AI and DB schema in sync. |

---

### A good way to learn it hands-on

1. Open `assistant.ts` and find `runLoop()` — read it alongside section 7 here.
2. Then read `buildSystemPrompt()` — that's literally the English instructions the
   AI follows. It's the most readable file in the whole system.
3. Then read `applyOwnership()` in `slayer-client.ts` — small, and it's the core
   of read security.

Those three functions are 80% of the system. Everything else is plumbing and
safety around them.
