import { Router } from 'express';
import { supabase } from '../config/supabase';
import { requireAuth } from '../middleware/requireAuth';

const router = Router();
router.use(requireAuth);

router.get('/summary', async (req, res, next) => {
  try {
    const userId = req.user!.id;

    // Get Journey Stage Counts
    const { count: targetsCount } = await supabase
      .from('target_companies')
      .select('*, event:events!inner(user_id)', { count: 'exact', head: true })
      .eq('event.user_id', userId);

    const { count: capturesCount } = await supabase
      .from('captures')
      .select('*, event:events!inner(user_id)', { count: 'exact', head: true })
      .eq('event.user_id', userId);

    const { count: enrichedCount } = await supabase
      .from('contacts')
      .select('*', { count: 'exact', head: true })
      .eq('user_id', userId)
      .eq('enrichment_status', 'completed');

    const { count: draftsCount } = await supabase
      .from('email_drafts')
      .select('*, contact:contacts!inner(user_id)', { count: 'exact', head: true })
      .eq('contact.user_id', userId)
      .eq('status', 'draft');

    const { count: sentCount } = await supabase
      .from('email_drafts')
      .select('*, contact:contacts!inner(user_id)', { count: 'exact', head: true })
      .eq('contact.user_id', userId)
      .eq('status', 'sent');

    // Get Stage-specific Leads
    const { data: targetLeads } = await supabase
      .from('target_companies')
      .select('company:companies(id, name), event:events!inner(user_id)')
      .eq('event.user_id', userId)
      .limit(3);

    const { data: capturedLeads } = await supabase
      .from('captures')
      .select('contact:contacts!inner(id, first_name, last_name, user_id, company:companies(name))')
      .eq('contact.user_id', userId)
      .not('contact_id', 'is', null)
      .limit(3);

    const { data: enrichedLeads } = await supabase
      .from('contacts')
      .select('id, first_name, last_name')
      .eq('user_id', userId)
      .eq('enrichment_status', 'completed')
      .limit(3);

    const { data: draftLeads } = await supabase
      .from('email_drafts')
      .select('id, contact:contacts!inner(first_name, last_name, user_id, company:companies(name))')
      .eq('contact.user_id', userId)
      .eq('status', 'draft')
      .limit(3);

    const { data: sentLeads } = await supabase
      .from('email_drafts')
      .select('id, contact:contacts!inner(first_name, last_name, user_id, company:companies(name))')
      .eq('contact.user_id', userId)
      .eq('status', 'sent')
      .limit(3);

    // Get Upcoming Meetings
    const todayStart = new Date();
    todayStart.setHours(0, 0, 0, 0);

    const { data: upcomingMeetings } = await supabase
      .from('meeting_briefs')
      .select(`
        id,
        meeting_date,
        meeting_type,
        meeting_location,
        status,
        contact:contacts!inner(id, first_name, last_name, avatar_url, user_id, company:companies(name))
      `)
      .eq('contact.user_id', userId)
      .gte('meeting_date', todayStart.toISOString())
      .order('meeting_date', { ascending: true })
      .limit(20);

    // Get Recent Activity
    const { data: recentActivity } = await supabase
      .from('interactions')
      .select(`
        id,
        interaction_type,
        interaction_date,
        summary,
        contact:contacts!inner(id, first_name, last_name, avatar_url, user_id, company:companies(name))
      `)
      .eq('contact.user_id', userId)
      .order('interaction_date', { ascending: false })
      .limit(10);

    // Get Active Conversations
    const { data: activeContacts } = await supabase
      .from('contacts')
      .select(`
        id,
        first_name,
        last_name,
        avatar_url,
        job_title,
        company:companies(name)
      `)
      .eq('user_id', userId)
      .order('updated_at', { ascending: false })
      .limit(5);

    const getFirst = (item: any) => Array.isArray(item) ? item[0] : item;

    res.json({
      summary: {
        targets: targetsCount || 0,
        captured: capturesCount || 0,
        enriched: enrichedCount || 0,
        drafts: draftsCount || 0,
        sent: sentCount || 0,
      },
      stages: {
        targets: targetLeads?.map(t => {
          const company = getFirst(t.company);
          return { id: company?.id, name: company?.name, initials: company?.name?.[0] };
        }) || [],
        captured: capturedLeads?.map(c => {
          const contact = getFirst(c.contact);
          const company = getFirst(contact?.company);
          return {
            id: contact?.id,
            name: `${contact?.first_name || ''} ${contact?.last_name || ''}`.trim(),
            company: company?.name,
            initials: contact?.first_name?.[0]
          };
        }) || [],
        enriched: enrichedLeads?.map(e => ({ id: e.id, name: e.name, initials: e.name?.[0] })) || [],
        drafts: draftLeads?.map(d => {
          const contact = getFirst(d.contact);
          const company = getFirst(contact?.company);
          return {
            id: d.id,
            name: `${contact?.first_name || ''} ${contact?.last_name || ''}`.trim(),
            company: company?.name,
            initials: contact?.first_name?.[0]
          };
        }) || [],
        sent: sentLeads?.map(s => {
          const contact = getFirst(s.contact);
          const company = getFirst(contact?.company);
          return {
            id: s.id,
            name: `${contact?.first_name || ''} ${contact?.last_name || ''}`.trim(),
            company: company?.name,
            initials: contact?.first_name?.[0]
          };
        }) || [],
      },
      upcomingMeetings: upcomingMeetings || [],
      recentActivity: recentActivity || [],
      activeContacts: activeContacts || []
    });
  } catch (error) {
    console.error('Dashboard summary error:', error);
    res.status(500).json({ error: 'Failed to fetch dashboard summary' });
  }
});

// Returns counts for the home screen "Today's Priorities" tiles
router.get('/priorities', async (req, res, next) => {
  try {
    const userId = req.user!.id;

    // Follow-ups due: contacts with needs_followup / needs_follow_up status
    const { count: followUpsDue } = await supabase
      .from('contacts')
      .select('*', { count: 'exact', head: true })
      .eq('user_id', userId)
      .in('follow_up_status', ['needs_followup', 'needs_follow_up']);

    res.json({
      followUpsDue: followUpsDue ?? 0,
    });
  } catch (error) {
    console.error('Dashboard priorities error:', error);
    res.status(500).json({ error: 'Failed to fetch priorities' });
  }
});

export default router;
