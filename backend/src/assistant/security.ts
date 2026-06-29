import { supabase as supabaseAdmin } from '../config/supabase';

// ─── Persistent rate limiter (Supabase-backed) ────────────────────────────────
// Uses assistant_rate_limits table — survives restarts, works across processes.
const RATE_WINDOW_MS = 60_000;
const RATE_MAX = 30;

export async function checkRateLimit(userId: string): Promise<{ ok: true } | { ok: false; retryAfterSeconds: number }> {
  const now = new Date();
  const windowStart = new Date(now.getTime() - RATE_WINDOW_MS);

  // Upsert: if no row exists, create with count=1.
  // If row exists and window has expired, reset it.
  // If row exists and within window, increment.
  const { data, error } = await supabaseAdmin.rpc('upsert_rate_limit', {
    p_user_id: userId,
    p_window_start: windowStart.toISOString(),
    p_max_requests: RATE_MAX,
  });

  if (error) {
    // On DB error, fail open (don't block the user)
    console.warn('Rate limit check failed, failing open:', error.message);
    return { ok: true };
  }

  if (data === false) {
    // Function returns false when limit exceeded
    const { data: row } = await supabaseAdmin
      .from('assistant_rate_limits')
      .select('window_start')
      .eq('user_id', userId)
      .maybeSingle();
    const resetAt = row ? new Date(row.window_start).getTime() + RATE_WINDOW_MS : now.getTime() + RATE_WINDOW_MS;
    return { ok: false, retryAfterSeconds: Math.ceil((resetAt - now.getTime()) / 1000) };
  }

  return { ok: true };
}

// ─── Prompt injection guard ───────────────────────────────────────────────────
const INJECTION_PATTERNS = [
  /ignore (previous|all|above|prior) instructions/i,
  /disregard (previous|all|above|prior)/i,
  /you are now/i,
  /new (persona|role|identity)/i,
  /system prompt/i,
  /\[INST\]/i,
  /<\|im_start\|>/i,
];

export function sanitiseUserInput(text: string, userId: string): string {
  const suspicious = INJECTION_PATTERNS.some((p) => p.test(text));
  if (suspicious) {
    console.warn(`[security] Possible prompt injection from user ${userId}: ${text.slice(0, 120)}`);
  }
  // Hard truncate — prevents context stuffing regardless
  return text.slice(0, 8000);
}
