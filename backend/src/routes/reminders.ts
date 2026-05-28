import { Router } from 'express';
import { supabase } from '../config/supabase';

const router = Router();

router.get('/', async (req, res, next) => {
  try {
    const { status = 'pending', limit = '50' } = req.query;

    const { data: reminders, error } = await supabase
      .from('reminders')
      .select(`
        *,
        contact:contacts(*),
        meeting_brief:meeting_briefs(*)
      `)
      .eq('status', status)
      .order('reminder_date', { ascending: true })
      .limit(parseInt(limit as string));

    if (error) {
      throw error;
    }

    res.json({ reminders });
  } catch (error) {
    console.error('Fetch reminders error:', error);
    res.status(500).json({ error: 'Failed to fetch reminders' });
  }
});

router.post('/', async (req, res, next) => {
  try {
    const {
      contact_id,
      event_id,
      meeting_brief_id,
      reminder_type,
      reminder_date,
      title,
      message,
      priority,
    } = req.body;

    if (!reminder_type || !reminder_date || !title) {
      return res.status(400).json({ error: 'Reminder type, date, and title are required' });
    }

    const { data: reminder, error: insertError } = await supabase
      .from('reminders')
      .insert({
        contact_id,
        event_id,
        meeting_brief_id,
        reminder_type,
        reminder_date,
        title,
        message,
        priority: priority || 'medium',
        status: 'pending',
      })
      .select()
      .single();

    if (insertError) {
      throw insertError;
    }

    res.status(201).json({ reminder });
  } catch (error) {
    console.error('Create reminder error:', error);
    res.status(500).json({ error: 'Failed to create reminder' });
  }
});

router.patch('/', async (req, res, next) => {
  try {
    const { id, status, snoozed_until } = req.body;

    if (!id) {
      return res.status(400).json({ error: 'Reminder ID is required' });
    }

    const updates: any = {};
    if (status) updates.status = status;
    if (snoozed_until) updates.snoozed_until = snoozed_until;
    if (status === 'sent') updates.sent_at = new Date().toISOString();

    const { data: reminder, error } = await supabase
      .from('reminders')
      .update(updates)
      .eq('id', id)
      .select()
      .single();

    if (error) {
      throw error;
    }

    res.json({ reminder });
  } catch (error) {
    console.error('Update reminder error:', error);
    res.status(500).json({ error: 'Failed to update reminder' });
  }
});

router.delete('/', async (req, res, next) => {
  try {
    const { id } = req.query;

    if (!id) {
      return res.status(400).json({ error: 'Reminder ID is required' });
    }

    const { error } = await supabase
      .from('reminders')
      .delete()
      .eq('id', id);

    if (error) {
      throw error;
    }

    res.json({ success: true });
  } catch (error) {
    console.error('Delete reminder error:', error);
    res.status(500).json({ error: 'Failed to delete reminder' });
  }
});

export default router;
