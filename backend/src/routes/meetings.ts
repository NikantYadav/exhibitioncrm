import { Router } from 'express';
import { supabase } from '../config/supabase';
import { AIService } from '../config/ai';

const router = Router();

router.get('/', async (req, res, next) => {
  try {
    const { status } = req.query;

    let query = supabase
      .from('meeting_briefs')
      .select(`
        *,
        contact:contacts(*,company:companies(*)),
        company:companies(*)
      `)
      .order('meeting_date', { ascending: true });

    if (status) {
      query = query.eq('status', status);
    }

    const { data: meetings, error } = await query;

    if (error) {
      // Handle table not found gracefully
      if (error.code === 'PGRST205') {
        return res.json({ meetings: [] });
      }
      throw error;
    }

    res.json({ meetings });
  } catch (error) {
    console.error('Fetch meetings error:', error);
    res.status(500).json({ error: 'Failed to fetch meetings' });
  }
});

router.post('/', async (req, res, next) => {
  try {
    const {
      contact_id,
      company_id,
      event_id,
      meeting_date,
      meeting_type,
      meeting_location,
      pre_meeting_notes,
    } = req.body;

    if (!contact_id || !meeting_date) {
      return res.status(400).json({ error: 'Contact ID and meeting date are required' });
    }

    // Fetch contact and company data
    const { data: contact } = await supabase
      .from('contacts')
      .select('*, company:companies(*)')
      .eq('id', contact_id)
      .single();

    // Fetch interaction history
    const { data: interactions } = await supabase
      .from('interactions')
      .select('*')
      .eq('contact_id', contact_id)
      .order('interaction_date', { ascending: false })
      .limit(10);

    // Generate AI talking points
    let aiTalkingPoints = '';
    let interactionSummary = '';

    if (contact && contact.company) {
      try {
        const prompt = `Generate 3-5 concise talking points for a meeting with ${contact.company.name}.
Company Industry: ${contact.company.industry || 'Unknown'}
Company Description: ${contact.company.description || 'No description'}
Products/Services: ${contact.company.products_services || 'Unknown'}

Return as a JSON array of strings.`;

        const result = await AIService.extractStructuredData<string[]>(
          prompt,
          'Array of talking point strings'
        );

        aiTalkingPoints = result.join('\n• ');

        // Generate interaction summary
        if (interactions && interactions.length > 0) {
          interactionSummary = `Previous interactions (${interactions.length}):\n${interactions
            .slice(0, 5)
            .map(i => {
              const type = i.interaction_type
                .replace(/_/g, ' ')
                .split(' ')
                .map((w: string) => w.charAt(0).toUpperCase() + w.slice(1))
                .join(' ');
              return `• ${type}: ${i.summary || 'No summary'}`;
            })
            .join('\n')}`;
        }
      } catch (error) {
        console.error('AI generation error:', error);
      }
    }

    // Create meeting brief
    const { data: meeting, error: insertError } = await supabase
      .from('meeting_briefs')
      .insert({
        contact_id,
        company_id: company_id || contact?.company_id,
        event_id,
        meeting_date,
        meeting_type: meeting_type || 'in_person',
        meeting_location,
        ai_talking_points: aiTalkingPoints,
        interaction_summary: interactionSummary,
        pre_meeting_notes,
        status: 'scheduled',
      })
      .select()
      .single();

    if (insertError) {
      throw insertError;
    }

    res.status(201).json({ meeting });
  } catch (error) {
    console.error('Create meeting error:', error);
    res.status(500).json({ error: 'Failed to create meeting' });
  }
});

router.get('/:id', async (req, res, next) => {
  try {
    const { id } = req.params;

    // Fetch meeting brief with all related data
    const { data: meeting, error } = await supabase
      .from('meeting_briefs')
      .select(`
        *,
        contact:contacts(*,company:companies(*)),
        company:companies(*),
        event:events(*)
      `)
      .eq('id', id)
      .single();

    if (error || !meeting) {
      return res.status(404).json({ error: 'Meeting not found' });
    }

    // Fetch interaction history
    const { data: interactions } = await supabase
      .from('interactions')
      .select('*, event:events(*)')
      .eq('contact_id', meeting.contact_id)
      .order('interaction_date', { ascending: false });

    // Find the original capture event
    const captureInteraction = interactions?.find(i => i.interaction_type === 'capture' && i.event);
    if (captureInteraction && !meeting.event) {
      meeting.event = captureInteraction.event;
    }

    // Fetch reminders
    const { data: reminders } = await supabase
      .from('reminders')
      .select('*')
      .eq('meeting_brief_id', id)
      .order('reminder_date', { ascending: true });

    res.json({
      meeting,
      interactions: interactions || [],
      reminders: reminders || [],
    });
  } catch (error) {
    console.error('Fetch meeting error:', error);
    res.status(500).json({ error: 'Failed to fetch meeting' });
  }
});

router.patch('/:id', async (req, res, next) => {
  try {
    const { id } = req.params;
    const updates = req.body;

    // Fetch current meeting
    const { data: currentMeeting, error: fetchError } = await supabase
      .from('meeting_briefs')
      .select('*')
      .eq('id', id)
      .single();

    if (fetchError || !currentMeeting) {
      return res.status(404).json({ error: 'Meeting not found' });
    }

    const finalUpdates = { ...updates };
    let completionDate = new Date().toISOString();

    // Apply smart date logic if completing
    if (updates.status === 'completed' && currentMeeting.status !== 'completed') {
      const scheduledDate = new Date(currentMeeting.meeting_date);
      const now = new Date();

      if (now < scheduledDate) {
        finalUpdates.meeting_date = now.toISOString();
        completionDate = now.toISOString();
      } else {
        completionDate = currentMeeting.meeting_date;
      }
    }

    // Update meeting brief
    const { data: meeting, error } = await supabase
      .from('meeting_briefs')
      .update(finalUpdates)
      .eq('id', id)
      .select()
      .single();

    if (error) throw error;

    // Log interaction if completed
    if (updates.status === 'completed' && currentMeeting.status !== 'completed') {
      const humanMeetingType = (meeting.meeting_type || 'in_person')
        .replace(/_/g, ' ')
        .split(' ')
        .map((w: string) => w.charAt(0).toUpperCase() + w.slice(1))
        .join(' ');

      await supabase
        .from('interactions')
        .insert({
          contact_id: meeting.contact_id,
          interaction_type: 'meeting',
          summary: `Completed meeting: ${humanMeetingType}`,
          interaction_date: completionDate,
          details: {
            meeting_id: meeting.id,
            notes: updates.post_meeting_notes || meeting.post_meeting_notes
          }
        });
    }

    res.json({ meeting });
  } catch (error) {
    console.error('Update meeting error:', error);
    res.status(500).json({ error: 'Failed to update meeting' });
  }
});

router.delete('/:id', async (req, res, next) => {
  try {
    const { id } = req.params;

    const { error } = await supabase
      .from('meeting_briefs')
      .delete()
      .eq('id', id);

    if (error) {
      throw error;
    }

    res.json({ success: true });
  } catch (error) {
    console.error('Delete meeting error:', error);
    res.status(500).json({ error: 'Failed to delete meeting' });
  }
});

export default router;


// POST /api/meetings/:id/prep
router.post('/:id/prep', async (req, res, next) => {
  try {
    const { id } = req.params;

    // Fetch meeting info
    const { data: meeting, error: meetingError } = await supabase
      .from('meeting_briefs')
      .select('*, contact:contacts(*, company:companies(*))')
      .eq('id', id)
      .single();

    if (meetingError || !meeting) {
      return res.status(404).json({ error: 'Meeting not found' });
    }

    // Fetch interaction history
    const { data: interactions } = await supabase
      .from('interactions')
      .select('*')
      .eq('contact_id', meeting.contact_id)
      .order('interaction_date', { ascending: false })
      .limit(10);

    // Fetch notes
    const { data: notes } = await supabase
      .from('notes')
      .select('*')
      .eq('contact_id', meeting.contact_id)
      .order('created_at', { ascending: false })
      .limit(10);

    // Generate prep data using AI
    const prompt = `Generate meeting preparation intelligence for:
Contact: ${meeting.contact.first_name} ${meeting.contact.last_name}
Company: ${meeting.contact.company?.name || 'Unknown'}
Job Title: ${meeting.contact.job_title || 'Unknown'}

Previous Interactions: ${interactions?.length || 0}
Notes: ${notes?.length || 0}

Generate:
1. Key talking points (3-5 items)
2. Relationship summary
3. Recommended discussion topics
4. Potential concerns or interests

Return as JSON.`;

    const prepDataText = await AIService.generateCompletion([
      { role: 'system', content: 'You are a meeting preparation assistant.' },
      { role: 'user', content: prompt }
    ]);

    const prepData = {
      key_talking_points: ['Generated talking point 1', 'Generated talking point 2'],
      relationship_summary: prepDataText.substring(0, 500),
      recommended_topics: ['Topic 1', 'Topic 2'],
      potential_concerns: ['Concern 1']
    };

    // Update meeting brief
    const { error: updateError } = await supabase
      .from('meeting_briefs')
      .update({
        prep_data: prepData,
        ai_talking_points: prepData.key_talking_points.join('\n'),
        interaction_summary: prepData.relationship_summary
      })
      .eq('id', id);

    if (updateError) {
      throw updateError;
    }

    res.json({ prep_data: prepData });
  } catch (error) {
    console.error('Meeting prep generation error:', error);
    res.status(500).json({ error: 'Failed to generate meeting intelligence' });
  }
});
