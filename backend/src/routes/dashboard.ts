import { Router } from 'express';
import { requireAuth } from '../middleware/requireAuth';

const router = Router();
router.use(requireAuth);

// Returns counts for the home screen "Today's Priorities" tiles
router.get('/priorities', async (req, res, next) => {
  try {
    const supabase = req.supabase!;
    const userId = req.user!.id;

    // Follow-ups due = New + Pending (both owe action), counted as DISTINCT
    // contacts so the number matches the collapsed home list (one row per
    // person) rather than per-event records. The inner join to contacts +
    // contact.deleted_at IS NULL excludes follow-ups whose contact was
    // soft-deleted, matching the local watchDueCount() definition so the home
    // stat doesn't flip between the seeded API value and the live stream.
    const { data: dueRows } = await supabase
      .from('follow_ups')
      .select('contact_id, contacts!inner(id)')
      .eq('user_id', userId)
      .in('status', ['new', 'pending'])
      .is('deleted_at', null)
      .is('contacts.deleted_at', null);

    const followUpsDue = new Set((dueRows ?? []).map((r: any) => r.contact_id)).size;

    res.json({
      followUpsDue,
    });
  } catch (error) {
    console.error('Dashboard priorities error:', error);
    res.status(500).json({ error: 'Failed to fetch priorities' });
  }
});

export default router;
