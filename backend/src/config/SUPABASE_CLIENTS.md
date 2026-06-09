# Supabase Clients — Rules for Devs

This project uses **two separate Supabase client instances**. Using the wrong one
will silently break data queries. Read this before touching anything that talks to
Supabase.

## The two clients (`supabaseClients.ts`)

| Client          | Key            | Use it for                                              |
| --------------- | -------------- | ------------------------------------------------------- |
| `supabaseAdmin` | service_role   | **All data queries** — `.from(...).select/insert/update/delete`. Re-exported as `supabase` from `config/supabase.ts`. |
| `supabaseAuth`  | anon           | **All auth operations** — `.auth.signInWithPassword`, `.auth.signUp`, `.auth.getUser`, `.auth.refreshSession`, `.auth.signOut`. |

## THE RULE

> **Never call `.auth.*` on `supabaseAdmin` / `supabase`. Only ever call `.auth.*` on `supabaseAuth`.**
>
> **Never run `.from(...)` data queries on `supabaseAuth`. Only ever run them on `supabaseAdmin` / `supabase`.**

## Why this matters (the bug it prevents)

`supabase-js` clients are **stateful singletons**. When you call an auth method like
`signInWithPassword()` or `getUser(token)` on a client, it **stores that user's
session on the client instance**. Every subsequent request from that same client then
sends the **logged-in user's `authenticated` JWT** as the auth header — instead of the
`service_role` key.

Because Row Level Security (RLS) is enabled on our tables and there is **no policy for
the `authenticated` role**, those queries return an **empty array with `error: null`** —
no crash, no warning, just silently zero rows.

This actually happened: after a `POST /api/auth/login`, `GET /api/events` started
returning `0 events` even though the rows existed. Root cause was `auth.ts` calling
`supabase.auth.signInWithPassword()` on the shared admin client, which poisoned every
later query on that client.

Keeping auth on a **separate instance** (`supabaseAuth`) guarantees `supabaseAdmin`
always queries as `service_role` and bypasses RLS as intended.

## When adding code

- Querying data? Import `supabase` (admin) and use `.from(...)`.
- Verifying a token / logging a user in/out? Import `supabaseAuth` and use `.auth.*`.
- If you ever see a query return `[]` with no error but you know rows exist —
  **suspect this**: an `.auth.*` call leaked onto the query client.

## Quick self-check before committing

```bash
# Should return NOTHING. Any hit is a bug waiting to happen:
grep -rn "\.auth\." backend/src --include="*.ts" | grep -v "supabaseAuth\.auth\."
```
