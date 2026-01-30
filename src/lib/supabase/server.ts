import { createClient as createSupabaseClient } from '@supabase/supabase-js';

// Server-side Supabase client
// Note: This is a simplified version. In production, use @supabase/ssr for proper server-side auth
export function createClient() {
    return createSupabaseClient(
        process.env.NEXT_PUBLIC_SUPABASE_URL!,
        process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
    );
}
