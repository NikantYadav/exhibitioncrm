import { Router } from 'express';
import { supabase } from '../config/supabase';

const router = Router();

router.get('/', async (req, res, next) => {
  try {
    const { data, error } = await supabase
      .from('events')
      .select('*')
      .order('start_date', { ascending: false });

    if (error) throw error;

    const now = new Date();
    const updatedData = (data || []).map(event => {
      const start = new Date(event.start_date);
      const end = event.end_date ? new Date(event.end_date) : start;
      end.setHours(23, 59, 59, 999);

      let status = event.status || 'upcoming';
      if (now >= start && now <= end) {
        status = 'ongoing';
      } else if (now > end) {
        status = 'completed';
      }

      return { ...event, status };
    });

    res.json({ data: updatedData });
  } catch (error) {
    next(error);
  }
});

router.get('/:id', async (req, res, next) => {
  try {
    const { data: event, error } = await supabase
      .from('events')
      .select('*')
      .eq('id', req.params.id)
      .single();

    if (error) throw error;

    if (event) {
      const now = new Date();
      const start = new Date(event.start_date);
      const end = event.end_date ? new Date(event.end_date) : start;
      end.setHours(23, 59, 59, 999);

      let status = 'upcoming';
      if (now >= start && now <= end) {
        status = 'ongoing';
      } else if (now > end) {
        status = 'completed';
      }
      event.status = status;
    }

    res.json({ data: event });
  } catch (error) {
    next(error);
  }
});

router.post('/', async (req, res, next) => {
  try {
    const { data, error } = await supabase
      .from('events')
      .insert({
        name: req.body.name,
        description: req.body.description,
        location: req.body.location,
        start_date: req.body.start_date,
        end_date: req.body.end_date,
        event_type: req.body.event_type || 'exhibition',
        status: req.body.status || 'upcoming',
      })
      .select()
      .single();

    if (error) throw error;

    res.json({ data, message: 'Event created successfully' });
  } catch (error) {
    next(error);
  }
});

router.patch('/:id', async (req, res, next) => {
  try {
    const { data, error } = await supabase
      .from('events')
      .update(req.body)
      .eq('id', req.params.id)
      .select()
      .single();

    if (error) throw error;

    res.json({ data, message: 'Event updated successfully' });
  } catch (error) {
    next(error);
  }
});

router.put('/:id', async (req, res, next) => {
  try {
    const { data, error } = await supabase
      .from('events')
      .update(req.body)
      .eq('id', req.params.id)
      .select()
      .single();

    if (error) throw error;

    res.json({ data });
  } catch (error) {
    next(error);
  }
});

// GET /api/events/:id/captures
router.get('/:id/captures', async (req, res, next) => {
  try {
    const { data, error } = await supabase
      .from('captures')
      .select('*, contact:contacts(*)')
      .eq('event_id', req.params.id)
      .order('created_at', { ascending: false });

    if (error) throw error;

    res.json({ data: data || [] });
  } catch (error) {
    next(error);
  }
});

// GET /api/events/:id/stats
router.get('/:id/stats', async (req, res, next) => {
  try {
    const eventId = req.params.id;

    // Get total captures
    const { count: capturesCount } = await supabase
      .from('captures')
      .select('*', { count: 'exact', head: true })
      .eq('event_id', eventId);

    // Get total contacts
    const { count: contactsCount } = await supabase
      .from('interactions')
      .select('contact_id', { count: 'exact', head: true })
      .eq('event_id', eventId);

    // Get follow-ups needed
    const { data: contacts } = await supabase
      .from('interactions')
      .select('contact_id')
      .eq('event_id', eventId);

    const contactIds = Array.from(new Set(contacts?.map(c => c.contact_id) || []));

    let followUpsCount = 0;
    if (contactIds.length > 0) {
      const { count } = await supabase
        .from('contacts')
        .select('*', { count: 'exact', head: true })
        .in('id', contactIds)
        .eq('follow_up_status', 'needs_follow_up');
      followUpsCount = count || 0;
    }

    res.json({
      data: {
        total_captures: capturesCount || 0,
        total_contacts: contactIds.length,
        follow_ups_needed: followUpsCount
      }
    });
  } catch (error) {
    next(error);
  }
});

// GET /api/events/:id/emails
router.get('/:id/emails', async (req, res, next) => {
  try {
    const { data, error } = await supabase
      .from('email_drafts')
      .select('*, contact:contacts(*)')
      .eq('event_id', req.params.id)
      .order('created_at', { ascending: false });

    if (error) throw error;

    res.json({ data: data || [] });
  } catch (error) {
    next(error);
  }
});

// GET /api/events/:id/targets
router.get('/:id/targets', async (req, res, next) => {
  try {
    const { data, error } = await supabase
      .from('target_companies')
      .select('*, company:companies(*)')
      .eq('event_id', req.params.id)
      .order('priority', { ascending: true });

    if (error) throw error;

    res.json({ data: data || [] });
  } catch (error) {
    next(error);
  }
});

// POST /api/events/:id/targets
router.post('/:id/targets', async (req, res, next) => {
  try {
    const { company_id, priority, notes } = req.body;

    const { data, error } = await supabase
      .from('target_companies')
      .insert({
        event_id: req.params.id,
        company_id,
        priority: priority || 'medium',
        status: 'not_contacted',
        notes
      })
      .select('*, company:companies(*)')
      .single();

    if (error) throw error;

    res.json({ data });
  } catch (error) {
    next(error);
  }
});

// PUT /api/events/:id/targets/:targetId
router.put('/:id/targets/:targetId', async (req, res, next) => {
  try {
    const { data, error } = await supabase
      .from('target_companies')
      .update(req.body)
      .eq('id', req.params.targetId)
      .eq('event_id', req.params.id)
      .select('*, company:companies(*)')
      .single();

    if (error) throw error;

    res.json({ data });
  } catch (error) {
    next(error);
  }
});

// DELETE /api/events/:id/targets/:targetId
router.delete('/:id/targets/:targetId', async (req, res, next) => {
  try {
    const { error } = await supabase
      .from('target_companies')
      .delete()
      .eq('id', req.params.targetId)
      .eq('event_id', req.params.id);

    if (error) throw error;

    res.json({ message: 'Target removed successfully' });
  } catch (error) {
    next(error);
  }
});

router.delete('/:id', async (req, res, next) => {
  try {
    const { error } = await supabase
      .from('events')
      .delete()
      .eq('id', req.params.id);

    if (error) throw error;

    res.json({ message: 'Event deleted successfully' });
  } catch (error) {
    next(error);
  }
});

export default router;
