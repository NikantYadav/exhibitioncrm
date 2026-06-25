// Backwards-compatible export used throughout existing routes.
// Note: this is an admin client (service role). For RLS-bound operations
// (like chat tables), use createSupabaseUserClient() from supabaseClients.
// `supabase` is kept as a backwards-compatible alias for the service_role client.
// Prefer importing `supabaseAdmin` explicitly so service_role usage is obvious at
// the call site; routes that handle tenant data should use req.supabase (RLS-enforced)
// instead. See ./supabaseClients and CYBERSECURITY.md.
export { supabaseAdmin, supabaseAdmin as supabase } from './supabaseClients';

