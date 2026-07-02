import { Router } from 'express';
import rateLimit from 'express-rate-limit';
import { z } from 'zod';
import { Resend } from 'resend';
import { logError, logSuccess } from '../middleware/logger';
import { supabaseAdmin, supabaseAuthAdmin } from '../config/supabaseClients';

const router = Router();

// ─── Account deletion ─────────────────────────────────────────────────────────
//
// IMPORTANT — keep these lists in sync with the DB schema. Any table that gains a
// `user_id` column (or an existing one changes its FK delete rule) MUST be
// reflected here, or a deleted account will leave orphaned rows behind or the
// auth-user delete will fail on an FK violation. See backend/CLAUDE.md
// ("Account deletion — keeping the delete API in sync with the schema").
//
// Flow (see DELETE /account handler): all user content is FIRST soft-deleted
// (deleted_at set, where the column exists) so a mid-flight failure still leaves
// the data invisible, THEN every user-owned row is hard-deleted, THEN the
// auth.users row is removed.
//
// Tables with a `deleted_at` column — soft-deleted before the hard delete.
const CONTENT_TABLES_WITH_SOFT_DELETE = [
  'contacts', 'events', 'interactions', 'captures', 'email_drafts',
  'target_companies', 'contact_events', 'event_goals', 'target_company_met',
  'follow_ups', 'contact_documents',
];

// Every user-owned table that must be HARD-deleted (by `user_id`) before the
// auth.users row can be removed. This covers:
//   - the NO ACTION FK tables (would otherwise block auth-user deletion), and
//   - the CASCADE FK tables (deleting them explicitly is harmless — the cascade
//     would remove them anyway — and keeps this list a complete, auditable
//     inventory of user-owned data).
// `messages`/`conversations` and their children (message_attachments,
// document_chunks) are removed via the auth.users CASCADE + their own cascades,
// but we delete conversations explicitly too so nothing depends on delete order.
// Children are listed before parents to satisfy FK constraints on hard delete.
const USER_OWNED_TABLES_HARD_DELETE = [
  // NO ACTION tables (must be cleared or the auth-user delete fails):
  'target_company_met', 'follow_ups', 'contact_events', 'event_goals',
  'interactions', 'captures', 'email_drafts', 'contact_documents',
  'target_companies',
  // CASCADE tables (explicit delete for a complete inventory; safe either way):
  'assistant_pending_actions', 'assistant_rate_limits',
  'conversations', 'contacts', 'events', 'user_profiles',
];

const resend = process.env.RESEND_API_KEY ? new Resend(process.env.RESEND_API_KEY) : null;

const SUPPORT_FROM = 'Exono Support <support@exono.ai>';
const SUPPORT_TO = 'contact@exono.ai';

// Per-user, in-memory limiter — same tradeoffs noted in auth.ts (per-process,
// not shared across instances). Generous enough for real users, tight enough
// to stop a runaway client from spamming the support inbox.
const contactLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hour
  max: 5,
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: (req) => req.user?.id || req.ip || 'anonymous',
  message: { error: 'Too many support requests, please try again later.' },
});

const contactSchema = z.object({
  subject: z.string().trim().min(1).max(150),
  message: z.string().trim().min(1).max(5000),
});

// Mounted under requireAuth in routes/index.ts — req.user is always present here.
router.post('/contact', contactLimiter, async (req, res) => {
  try {
    if (!resend) {
      logError(new Error('RESEND_API_KEY not configured'), 'support');
      return res.status(503).json({ error: 'Support requests are temporarily unavailable.' });
    }

    const parsed = contactSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: parsed.error.errors[0]?.message || 'Invalid input' });
    }
    const { subject, message } = parsed.data;

    const userEmail = req.user?.email;
    const userId = req.user?.id || 'unknown';

    const { error } = await resend.emails.send({
      from: SUPPORT_FROM,
      to: SUPPORT_TO,
      replyTo: userEmail,
      subject: `[Support] ${subject}`,
      text: `From: ${userEmail || 'unknown'} (user_id: ${userId})\n\n${message}`,
    });

    if (error) {
      logError(new Error(error.message), 'support:resend');
      return res.status(502).json({ error: 'Failed to send support request. Please try again.' });
    }

    logSuccess(`Support request sent for user ${userId}`);
    res.json({ ok: true });
  } catch (err: any) {
    logError(err instanceof Error ? err : new Error(String(err)), 'support');
    res.status(500).json({ error: 'Failed to send support request.' });
  }
});

// A separate, tighter limiter for the irreversible delete path.
const deleteLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hour
  max: 3,
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: (req) => req.user?.id || req.ip || 'anonymous',
  message: { error: 'Too many attempts, please try again later.' },
});

/**
 * DELETE /api/support/account
 * Permanently deletes the authenticated user's account and all their data.
 *
 * Steps (in this order, so a mid-flight failure never leaves visible data):
 *   1. Soft-delete every content table that has a `deleted_at` column.
 *   2. Hard-delete every user-owned row across all tables (children first).
 *   3. Delete the auth.users row.
 *
 * Uses supabaseAdmin (service_role) — bypasses RLS by design, so ownership is
 * enforced in code by scoping every statement to `.eq('user_id', userId)`.
 */
router.delete('/account', deleteLimiter, async (req, res) => {
  const userId = req.user?.id;
  if (!userId) {
    return res.status(401).json({ error: 'Not authenticated' });
  }

  try {
    const nowIso = new Date().toISOString();

    // 1. Soft-delete content tables (best-effort visibility guard before hard delete).
    for (const table of CONTENT_TABLES_WITH_SOFT_DELETE) {
      const { error } = await supabaseAdmin
        .from(table)
        .update({ deleted_at: nowIso })
        .eq('user_id', userId)
        .is('deleted_at', null);
      if (error) {
        logError(new Error(`soft-delete ${table} failed: ${error.message}`), 'support:delete-account');
        return res.status(500).json({ error: 'Failed to delete account. Please try again.' });
      }
    }

    // 2. Hard-delete every user-owned row, children before parents.
    for (const table of USER_OWNED_TABLES_HARD_DELETE) {
      const { error } = await supabaseAdmin
        .from(table)
        .delete()
        .eq('user_id', userId);
      if (error) {
        logError(new Error(`hard-delete ${table} failed: ${error.message}`), 'support:delete-account');
        return res.status(500).json({ error: 'Failed to delete account. Please try again.' });
      }
    }

    // 3. Remove the auth user. All remaining CASCADE FKs (sessions, identities,
    //    messages, etc.) clear automatically.
    const { error: authError } = await supabaseAuthAdmin.auth.admin.deleteUser(userId);
    if (authError) {
      logError(new Error(`auth deleteUser failed: ${authError.message}`), 'support:delete-account');
      return res.status(500).json({ error: 'Failed to delete account. Please try again.' });
    }

    logSuccess(`Account deleted for user ${userId}`);
    res.json({ ok: true });
  } catch (err: any) {
    logError(err instanceof Error ? err : new Error(String(err)), 'support:delete-account');
    res.status(500).json({ error: 'Failed to delete account. Please try again.' });
  }
});

export default router;
