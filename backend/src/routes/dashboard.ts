import { Router } from 'express';
import { supabase } from '../config/supabase';
import { requireAuth } from '../middleware/requireAuth';

const router = Router();
router.use(requireAuth);

// Returns counts for the home screen "Today's Priorities" tiles
router.get('/priorities', async (req, res, next) => {
  try {
    const userId = req.user!.id;

    // Follow-ups due: contacts with needs_followup / needs_follow_up status
    const { count: followUpsDue } = await supabase
      .from('contacts')
      .select('*', { count: 'exact', head: true })
      .eq('user_id', userId)
      .in('follow_up_status', ['needs_followup', 'needs_follow_up'])
      .is('deleted_at', null);

    res.json({
      followUpsDue: followUpsDue ?? 0,
    });
  } catch (error) {
    console.error('Dashboard priorities error:', error);
    res.status(500).json({ error: 'Failed to fetch priorities' });
  }
});

export default router;
