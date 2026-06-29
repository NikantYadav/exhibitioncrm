import { supabase as supabaseAdmin } from '../config/supabase';

// Persistent, per-user, per-scope sliding-window rate limiter backed by the
// scoped_rate_limits table (survives restarts, works across processes). Mirrors
// the assistant limiter but keyed by (user_id, scope) so independent limits can
// coexist. On DB error it fails OPEN — availability over enforcement.
export type RateLimitResult = { ok: true } | { ok: false; retryAfterSeconds: number };

// Image upload / vision budget. A single business-card scan costs one
// analyze-card call plus one capture, so a shared per-user bucket of 40/min is
// generous for real use while blocking scripted abuse of storage / vision quota.
export const IMAGE_UPLOAD_SCOPE = 'image_upload';
export const IMAGE_UPLOAD_MAX = 40;
export const IMAGE_UPLOAD_WINDOW_MS = 60_000;

// Chat document-upload / extraction budget. Each upload can trigger a vision
// call and/or embeddings, so a tighter per-user bucket blocks abuse of those
// quotas while staying generous for real "attach a few files" use.
export const DOC_UPLOAD_SCOPE = 'doc_upload';
export const DOC_UPLOAD_MAX = 20;
export const DOC_UPLOAD_WINDOW_MS = 60_000;

export async function checkScopedRateLimit(
  userId: string,
  scope: string,
  maxRequests: number,
  windowMs: number,
): Promise<RateLimitResult> {
  const now = new Date();
  const windowStart = new Date(now.getTime() - windowMs);

  const { data, error } = await supabaseAdmin.rpc('upsert_scoped_rate_limit', {
    p_user_id: userId,
    p_scope: scope,
    p_window_start: windowStart.toISOString(),
    p_max_requests: maxRequests,
  });

  if (error) {
    console.warn(`Rate limit check failed for scope "${scope}", failing open:`, error.message);
    return { ok: true };
  }

  if (data === false) {
    const { data: row } = await supabaseAdmin
      .from('scoped_rate_limits')
      .select('window_start')
      .eq('user_id', userId)
      .eq('scope', scope)
      .maybeSingle();
    const resetAt = row
      ? new Date(row.window_start).getTime() + windowMs
      : now.getTime() + windowMs;
    return { ok: false, retryAfterSeconds: Math.max(1, Math.ceil((resetAt - now.getTime()) / 1000)) };
  }

  return { ok: true };
}
