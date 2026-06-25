import type { SupabaseClient, User } from '@supabase/supabase-js';

declare global {
  namespace Express {
    interface Request {
      user?: User;
      accessToken?: string;
      // RLS-enforced, per-request user-scoped client. Set by requireAuth.
      // Use this for all tenant data access; reserve supabaseAdmin (service_role)
      // for controlled paths that must bypass RLS (storage, shared-reference writes).
      supabase?: SupabaseClient;
    }
  }
}

export {};
