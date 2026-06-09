// IMPORTANT: Two separate clients on purpose. Never call .auth.* on supabaseAdmin,
// and never run .from() queries on supabaseAuth. See ./SUPABASE_CLIENTS.md for why.
import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';

dotenv.config();

const supabaseUrl = process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL;
const supabaseServiceRoleKey =
  process.env.SUPABASE_SERVICE_ROLE_KEY ||
  process.env.SUPABASE_SERVICE_KEY;

const supabaseAnonKey =
  process.env.SUPABASE_ANON_KEY ||
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

if (!supabaseUrl) {
  throw new Error('Missing Supabase URL');
}

if (!supabaseServiceRoleKey) {
  throw new Error('Missing Supabase service role key');
}

if (!supabaseAnonKey) {
  throw new Error('Missing Supabase anon key');
}

export const supabaseAdmin = createClient(supabaseUrl, supabaseServiceRoleKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false,
    detectSessionInUrl: false,
  },
});

// Dedicated client for ALL auth operations (signInWithPassword, signUp, getUser,
// refreshSession, signOut). These calls store a user session on the client instance,
// which would otherwise make subsequent .from() queries run as that user (authenticated
// role) instead of service_role — silently returning 0 rows under RLS. Keeping auth on a
// separate instance ensures supabaseAdmin always queries as service_role. Uses the anon
// key since auth operations don't need (and shouldn't carry) the service-role key.
export const supabaseAuth = createClient(supabaseUrl, supabaseAnonKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false,
    detectSessionInUrl: false,
  },
});

export function createSupabaseUserClient(accessToken: string) {
  if (!supabaseAnonKey) {
    throw new Error('Missing Supabase anon key (required for user-scoped client)');
  }

  return createClient(supabaseUrl!, supabaseAnonKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
      detectSessionInUrl: false,
    },
    global: {
      headers: {
        Authorization: `Bearer ${accessToken}`,
      },
    },
  });
}
