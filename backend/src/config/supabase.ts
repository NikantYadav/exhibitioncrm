// Backwards-compatible export used throughout existing routes.
// Note: this is an admin client (service role). For RLS-bound operations
// (like chat tables), use createSupabaseUserClient() from supabaseClients.
export { supabaseAdmin as supabase } from './supabaseClients';

