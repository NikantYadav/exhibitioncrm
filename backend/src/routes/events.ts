import { Router } from 'express';
import { supabase } from '../config/supabase';
import { LiteLLMService } from '../services/litellm-service';
import { TavilyService } from '../services/tavily-service';
import { requireAuth } from '../middleware/requireAuth';
import multer from 'multer';
import * as XLSX from 'xlsx';

const router = Router();

router.use(requireAuth);

const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 5 * 1024 * 1024 } });

// Supabase returns timestamps as "2026-06-08 00:00:00+00" (space, no colon in offset).
// new Date() requires ISO 8601 ("T" separator, "+00:00" offset) — fix both.
const parseTs = (s: string): Date =>
  new Date(s.replace(' ', 'T').replace(/([+-]\d{2})$/, '$1:00'));

const getEventStatus = (event: any): string => {
  const now = new Date();
  const start = parseTs(event.start_date);
  // Single-day event ends 24h after start; multi-day ends at end of end_date day.
  const end = event.end_date
    ? (() => { const d = parseTs(event.end_date); d.setUTCHours(23, 59, 59, 999); return d; })()
    : new Date(start.getTime() + 24 * 60 * 60 * 1000 - 1);
  if (now >= start && now <= end) return 'ongoing';
  if (now > end) return 'completed';
  return 'upcoming';
};

router.get('/', async (req, res, next) => {
  try {
    const userId = req.user!.id;

    const { data, error } = await supabase
      .from('events')
      .select('*')
      .eq('user_id', userId)
      .order('start_date', { ascending: false });

    if (error) throw error;

    const updatedData = (data || []).map(event => ({
      ...event,
      status: getEventStatus(event),
    }));

    console.log(`[GET /api/events] Returning ${updatedData.length} events`);
    res.json({ data: updatedData });
  } catch (error) {
    console.error(`[GET /api/events] Error:`, error);
    next(error);
  }
});

// GET /api/events/ongoing/current
// Returns the current ongoing event if any
router.get('/ongoing/current', async (req, res, next) => {
  try {
    const userId = req.user!.id;
    const { data: events, error } = await supabase
      .from('events')
      .select('*')
      .eq('user_id', userId)
      .order('start_date', { ascending: false });

    if (error) throw error;

    // Find the first ongoing event
    const ongoingEvent = (events || []).find(event => getEventStatus(event) === 'ongoing');

    if (!ongoingEvent) {
      res.status(404).json({ error: 'No ongoing event found' });
      return;
    }

    res.json({ data: { ...ongoingEvent, status: 'ongoing' } });
  } catch (error) {
    next(error);
  }
});

// GET /api/events/upcoming/next
// Returns the next upcoming event (soonest start_date in the future)
router.get('/upcoming/next', async (req, res, next) => {
  try {
    const userId = req.user!.id;
    const { data: events, error } = await supabase
      .from('events')
      .select('*')
      .eq('user_id', userId)
      .order('start_date', { ascending: true });

    if (error) throw error;

    const upcomingEvent = (events || []).find(event => getEventStatus(event) === 'upcoming');

    if (!upcomingEvent) {
      res.status(404).json({ error: 'No upcoming event found' });
      return;
    }

    res.json({ data: { ...upcomingEvent, status: 'upcoming' } });
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
      event.status = getEventStatus(event);
    }

    res.json({ data: event });
  } catch (error) {
    next(error);
  }
});

router.post('/', async (req, res, next) => {
  try {
    if (req.body.start_date) {
      const today = new Date(); today.setHours(0, 0, 0, 0);
      if (new Date(req.body.start_date) < today) {
        return res.status(400).json({ error: 'Event start date cannot be in the past.' });
      }
    }

    const { data, error } = await supabase
      .from('events')
      .insert({
        user_id: req.user!.id,
        name: req.body.name,
        description: req.body.description,
        location: req.body.location,
        start_date: req.body.start_date,
        end_date: req.body.end_date,
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
    if (req.body.start_date) {
      const today = new Date(); today.setHours(0, 0, 0, 0);
      if (new Date(req.body.start_date) < today) {
        return res.status(400).json({ error: 'Event start date cannot be in the past.' });
      }
    }

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
    const eventId = req.params.id;

    const { data: captures, error } = await supabase
      .from('captures')
      .select('*, contact:contacts(*)')
      .eq('event_id', eventId)
      .order('created_at', { ascending: false });

    if (error) throw error;

    res.json({ data: captures || [] });
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

    // Get total contacts via contact_events
    const { count: contactEventsCount } = await supabase
      .from('contact_events')
      .select('*', { count: 'exact', head: true })
      .eq('event_id', eventId);

    // Get total targets
    const { count: targetsCount } = await supabase
      .from('target_companies')
      .select('*', { count: 'exact', head: true })
      .eq('event_id', eventId);

    // Collect all unique contact IDs from both contact_events AND captures
    const [{ data: contactEventRows }, { data: captureRows }] = await Promise.all([
      supabase.from('contact_events').select('contact_id').eq('event_id', eventId),
      supabase.from('captures').select('contact_id').eq('event_id', eventId).eq('status', 'completed').not('contact_id', 'is', null),
    ]);

    const contactIds = Array.from(new Set([
      ...(contactEventRows?.map((c: any) => c.contact_id) || []),
      ...(captureRows?.map((c: any) => c.contact_id) || []),
    ]));

    let followUpsCount = 0;
    let skippedCount = 0;
    let doneCount = 0;
    if (contactIds.length > 0) {
      const [{ count: pending }, { count: skipped }, { count: done }] = await Promise.all([
        supabase.from('contacts').select('*', { count: 'exact', head: true })
          .in('id', contactIds).eq('follow_up_status', 'not_contacted'),
        supabase.from('contacts').select('*', { count: 'exact', head: true })
          .in('id', contactIds).eq('follow_up_status', 'needs_follow_up'),
        supabase.from('contacts').select('*', { count: 'exact', head: true })
          .in('id', contactIds).eq('follow_up_status', 'contacted'),
      ]);
      followUpsCount = pending || 0;
      skippedCount = skipped || 0;
      doneCount = done || 0;
    }

    // total_contacts = all unique people reached (contact_events union captures)
    const totalContacts = contactIds.length;

    // Calculate target reach: (unique contacts reached / total targets) * 100
    const targetReach = targetsCount && targetsCount > 0 ? Math.round(totalContacts / targetsCount * 100) : 0;

    res.json({
      data: {
        total_captures: capturesCount || 0,
        total_contacts: totalContacts,
        total_targets: targetsCount || 0,
        target_reach: targetReach,
        follow_ups_needed: followUpsCount,
        follow_ups_skipped: skippedCount,
        follow_ups_done: doneCount,
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

// GET /api/events/:id/targets/:targetId
router.get('/:id/targets/:targetId', async (req, res, next) => {
  try {
    const { data, error } = await supabase
      .from('target_companies')
      .select('*, company:companies(*)')
      .eq('id', req.params.targetId)
      .eq('event_id', req.params.id)
      .single();

    if (error) throw error;

    res.json({ data });
  } catch (error) {
    next(error);
  }
});

// GET /api/events/:id/live
router.get('/:id/live', async (req, res, next) => {
  try {
    const eventId = req.params.id;
    console.log(`[GET /events/:id/live] eventId: ${eventId}`);

    const [
      { data: event, error: eventError },
      { count: capturesCount },
      { count: targetsCount },
      { data: goalsData },
      { data: targetsRaw, error: targetsError },
      { data: contactEventRows, error: contactEventsError },
    ] = await Promise.all([
      supabase.from('events').select('*').eq('id', eventId).single(),
      supabase.from('captures').select('*', { count: 'exact', head: true }).eq('event_id', eventId),
      supabase.from('target_companies').select('*', { count: 'exact', head: true }).eq('event_id', eventId),
      supabase.from('event_goals').select('*').eq('event_id', eventId).order('created_at', { ascending: true }),
      supabase
        .from('target_companies')
        .select(`
          id, priority, booth_location, status, company_id, talking_points, notes, use_notes_for_briefing,
          company:companies(id, name)
        `)
        .eq('event_id', eventId)
        .limit(50),
      supabase
        .from('contact_events')
        .select(`
          id, contact_id, status, notes, talking_points, created_at,
          contact:contacts(id, first_name, last_name, job_title, company_id, company_name:companies(name))
        `)
        .eq('event_id', eventId)
        .order('created_at', { ascending: true }),
    ]);

    if (eventError || !event) {
      console.log(`[GET /events/:id/live] Event not found: ${eventId}`);
      res.status(404).json({ error: 'Event not found' });
      return;
    }
    if (targetsError) throw targetsError;
    if (contactEventsError) throw contactEventsError;

    const contactEventsCount = (contactEventRows || []).length;
    console.log(`[GET /events/:id/live] Event: ${event.name}, Stats - Scanned: ${capturesCount}, Targets: ${targetsCount}, Contacts: ${contactEventsCount}`);

    // Sort targets: high > medium > low
    const priorityOrder: Record<string, number> = { high: 0, medium: 1, low: 2 };
    const sortedTargets = (targetsRaw || []).sort((a: any, b: any) =>
      (priorityOrder[a.priority] ?? 3) - (priorityOrder[b.priority] ?? 3)
    );

    // Target companies — independent of contacts
    const priorityTargets = sortedTargets.map((target: any, index: number) => ({
      id: target.id,
      rank: index + 1,
      company_id: target.company_id ?? null,
      company_name: target.company?.name ?? '',
      booth: target.booth_location || '',
      status: target.status || 'not_contacted',
      priority: target.priority || 'medium',
      talking_points: target.talking_points || '',
      notes: target.notes || '',
      use_notes_for_briefing: target.use_notes_for_briefing ?? false,
    }));

    // Target contacts — independent list from contact_events
    const targetContacts = (contactEventRows || []).map((row: any) => {
      const c = (row as any).contact;
      const companyName = c?.company_name?.name ?? '';
      return {
        id: row.id,
        contact_id: row.contact_id,
        name: c ? `${c.first_name} ${c.last_name ?? ''}`.trim() : '',
        job_title: c?.job_title ?? '',
        company_name: companyName,
        status: row.status || 'not_contacted',
        notes: row.notes || '',
        talking_points: row.talking_points || '',
      };
    });

    // Pending follow-ups: target contacts not yet met
    const followUpsCount = targetContacts.filter((tc: any) => tc.status !== 'met').length;

    const tc = targetsCount || 0;
    const cc = contactEventsCount;
    const targetReach = tc > 0 ? Math.round((cc / tc) * 100) : 0;

    console.log(`[GET /events/:id/live] Returning ${priorityTargets.length} company targets, ${targetContacts.length} contact targets`);

    res.json({
      data: {
        event: {
          id: event.id,
          title: event.name,
          venue: event.venue || event.location || '',
          hall: event.hall || '',
        },
        stats: {
          target_reach: targetReach,
          scanned: capturesCount || 0,
          targets_left: Math.max(0, tc - cc),
          pending_follow_ups: followUpsCount,
          total_targets: tc,
        },
        goals: (goalsData || []).map((g: any) => ({
          id: g.id,
          label: g.label,
          current: g.current,
          total: g.total,
        })),
        targets: priorityTargets,
        target_contacts: targetContacts,
      },
    });
  } catch (error) {
    console.error(`[GET /events/:id/live] Error:`, error);
    next(error);
  }
});

// GET /api/events/:id/goals
router.get('/:id/goals', async (req, res, next) => {
  try {
    const { data, error } = await supabase
      .from('event_goals').select('*')
      .eq('event_id', req.params.id).order('created_at', { ascending: true });
    if (error) throw error;
    res.json({ data: data || [] });
  } catch (error) { next(error); }
});

// POST /api/events/:id/ask
router.post('/:id/ask', async (req, res, next) => {
  try {
    const { question } = req.body;
    if (!question) { res.status(400).json({ error: 'question required' }); return; }
    const [{ data: event }, { data: targets }] = await Promise.all([
      supabase.from('events').select('name, venue, location, description, start_date, end_date').eq('id', req.params.id).single(),
      supabase.from('target_companies').select('company:companies(name, industry), booth_location, status, priority').eq('event_id', req.params.id).limit(20),
    ]);
    if (!event) { res.status(404).json({ error: 'Event not found' }); return; }

    const eventName = event.name as string;
    const eventLocation = event.venue || event.location || '';
    const eventDates = event.start_date
      ? `${event.start_date.slice(0, 10)}${event.end_date ? ` to ${event.end_date.slice(0, 10)}` : ''}`
      : '';
    const targetSummary = (targets || []).map((t: any) =>
      `${t.company?.name} (${t.company?.industry || 'unknown'}, booth: ${t.booth_location || 'TBD'}, status: ${t.status})`
    ).join('\n');

    // Tavily search — include event name, location, schedule and the question
    let webContext = '';
    try {
      const searchQuery = [eventName, eventLocation, eventDates, question].filter(Boolean).join(' ');
      const results = await TavilyService.search(searchQuery, { maxResults: 4, searchDepth: 'basic' });
      webContext = TavilyService.formatForPrompt(results);
    } catch (_) { /* Tavily failure is non-fatal */ }

    const eventContext = [
      `Event: "${eventName}"`,
      eventLocation ? `Location: ${eventLocation}` : '',
      eventDates ? `Dates: ${eventDates}` : '',
      event.description ? `Description: ${event.description}` : '',
    ].filter(Boolean).join('\n');

    const llm = new LiteLLMService();
    const answer = await llm.generateCompletion([{
      role: 'user',
      content: `You are a smart assistant helping someone attending a live event.\n\n${eventContext}\n\nTarget companies:\n${targetSummary || 'None listed'}${webContext ? `\n\nReal-time web context:\n${webContext}` : ''}\n\nQuestion: ${question}\n\nAnswer in 2-3 sentences. Be specific and actionable.`
    }]);
    res.json({ answer });
  } catch (error) { next(error); }
});

// POST /api/events/:id/goals
router.post('/:id/goals', async (req, res, next) => {
  try {
    const { label, total } = req.body;
    if (!label) { res.status(400).json({ error: 'label required' }); return; }
    const { data, error } = await supabase
      .from('event_goals')
      .insert({ event_id: req.params.id, label, total: total ?? 1, current: 0 })
      .select().single();
    if (error) throw error;
    res.json({ data });
  } catch (error) { next(error); }
});

// PATCH /api/events/:id/goals/:goalId
router.patch('/:id/goals/:goalId', async (req, res, next) => {
  try {
    const updates: any = {};
    if (req.body.current !== undefined) updates.current = req.body.current;
    if (req.body.label !== undefined) updates.label = req.body.label;
    if (req.body.total !== undefined) updates.total = req.body.total;
    updates.updated_at = new Date().toISOString();
    const { data, error } = await supabase
      .from('event_goals')
      .update(updates)
      .eq('id', req.params.goalId)
      .eq('event_id', req.params.id)
      .select().single();
    if (error) throw error;
    res.json({ data });
  } catch (error) { next(error); }
});

// DELETE /api/events/:id/goals/:goalId
router.delete('/:id/goals/:goalId', async (req, res, next) => {
  try {
    const { error } = await supabase
      .from('event_goals')
      .delete()
      .eq('id', req.params.goalId)
      .eq('event_id', req.params.id);
    if (error) throw error;
    res.json({ message: 'Goal deleted' });
  } catch (error) { next(error); }
});

// POST /api/events/:id/targets/import
router.post('/:id/targets/import', upload.single('file'), async (req: any, res, next) => {
  try {
    const eventId = req.params.id;
    if (!req.file) {
      res.status(400).json({ error: 'No file uploaded' });
      return;
    }

    // Parse file (works for .xlsx, .xls, .csv)
    const workbook = XLSX.read(req.file.buffer, { type: 'buffer' });
    const sheetName = workbook.SheetNames[0];
    const sheet = workbook.Sheets[sheetName];
    const rows: Record<string, string>[] = XLSX.utils.sheet_to_json(sheet, { defval: '' });

    const results: { added: number; skipped: number; errors: string[] } = {
      added: 0,
      skipped: 0,
      errors: [],
    };

    for (const row of rows) {
      // Accept columns: name, company, company_name (case-insensitive)
      const rawName = (row['name'] || row['company'] || row['company_name'] || row['Company'] || row['Name'] || '').toString().trim();
      const industry = (row['industry'] || row['Industry'] || row['sector'] || row['Sector'] || '').toString().trim();
      const website = (row['website'] || row['Website'] || row['url'] || '').toString().trim();
      const description = (row['description'] || row['Description'] || '').toString().trim();

      if (!rawName) {
        results.skipped++;
        continue;
      }

      try {
        // Find or create company
        const { data: existing } = await supabase
          .from('companies')
          .select('id')
          .ilike('name', rawName)
          .limit(1)
          .single();

        let companyId: string;
        if (existing) {
          companyId = existing.id;
        } else {
          const { data: created, error: createError } = await supabase
            .from('companies')
            .insert({ name: rawName, industry: industry || null, website: website || null, description: description || null })
            .select('id')
            .single();
          if (createError || !created) {
            results.errors.push(`Failed to create company: ${rawName}`);
            continue;
          }
          companyId = created.id;
        }

        // Add as target (ignore duplicate)
        const { error: targetError } = await supabase
          .from('target_companies')
          .insert({ event_id: eventId, company_id: companyId, priority: 'medium', status: 'not_contacted' });

        if (targetError && targetError.code !== '23505') {
          results.errors.push(`Failed to add ${rawName} as target`);
        } else {
          results.added++;
        }
      } catch (e: any) {
        results.errors.push(e.message || `Error processing ${rawName}`);
      }
    }

    res.json({ data: results, message: `Import complete: ${results.added} added, ${results.skipped} skipped` });
  } catch (error) {
    next(error);
  }
});

// POST /api/events/:id/targets
router.post('/:id/targets', async (req, res, next) => {
  try {
    const { company_id, priority, notes, booth_location } = req.body;

    const { data, error } = await supabase
      .from('target_companies')
      .insert({
        event_id: req.params.id,
        company_id,
        priority: priority || 'medium',
        status: 'not_contacted',
        notes,
        booth_location: booth_location || null,
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

// POST /api/events/:id/targets/:targetId/briefing
router.post('/:id/targets/:targetId/briefing', async (req, res, next) => {
  try {
    const { targetId } = req.params;
    const { data: target, error } = await supabase
      .from('target_companies')
      .select('*, company:companies(*)')
      .eq('id', targetId)
      .single();
    if (error) throw error;

    const company = target.company as any;
    const companyName = company?.name || 'Unknown Company';
    const industry = company?.industry || '';
    const description = company?.description || '';

    // Tavily web search for real-time company grounding
    console.log(`[briefing] → running Tavily search for company: "${companyName}"`);
    const [newsResults, overviewResults] = await Promise.all([
      TavilyService.search(`${companyName} latest news`, { maxResults: 3, searchDepth: 'basic' }),
      TavilyService.search(`${companyName}${industry ? ` ${industry}` : ''} company products services overview`, { maxResults: 3, searchDepth: 'basic' }),
    ]);
    const webContext = TavilyService.formatForPrompt([...overviewResults, ...newsResults]);
    console.log(`[briefing] → Tavily returned ${overviewResults.length + newsResults.length} results`);

    let prompt = `Generate 4 concise, specific talking points for a business networking conversation with ${companyName}${industry ? ` (${industry})` : ''}${description ? `. Company description: ${description}` : ''}.`;
    if (webContext) {
      prompt += `\n\nUse the following real-time web research to make the talking points current and specific:\n\n${webContext}`;
    }
    prompt += `\n\nFormat: one talking point per line, no bullet points or numbering, plain text only.`;

    const llm = new LiteLLMService();
    const talkingPoints = await llm.generateCompletion([{ role: 'user', content: prompt }]);

    const { data: updated, error: updateError } = await supabase
      .from('target_companies')
      .update({ talking_points: talkingPoints, status: 'researched' })
      .eq('id', targetId)
      .select('*, company:companies(*)')
      .single();
    if (updateError) throw updateError;

    res.json({ data: updated });
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

// GET /api/events/:id/follow-ups
// Returns a merged list of:
//   1. Scanned contacts (contact_events) with their company + email draft
//   2. Targeted companies that were never scanned — surfaced as unmet targets
router.get('/:id/follow-ups', async (req, res, next) => {
  try {
    const eventId = req.params.id;

    // Fetch all four data sources in parallel
    const [
      { data: contactEvents, error: ceError },
      { data: captures,      error: capturesError },
      { data: drafts,        error: draftsError },
      { data: targets,       error: targetsError },
    ] = await Promise.all([
      supabase
        .from('contact_events')
        .select('contact:contacts(*, company:companies(id, name, industry))')
        .eq('event_id', eventId),
      supabase
        .from('captures')
        .select('contact:contacts(*, company:companies(id, name, industry))')
        .eq('event_id', eventId)
        .eq('status', 'completed')
        .not('contact_id', 'is', null),
      supabase
        .from('email_drafts')
        .select('*')
        .eq('event_id', eventId)
        .order('created_at', { ascending: false }),
      supabase
        .from('target_companies')
        .select('id, status, booth_location, company:companies(id, name, industry)')
        .eq('event_id', eventId),
    ]);

    if (ceError) throw ceError;
    if (capturesError) throw capturesError;
    if (draftsError) throw draftsError;
    if (targetsError) throw targetsError;

    // Index drafts by contact_id (latest first due to order above)
    const draftsMap = new Map<string, any>();
    for (const draft of drafts || []) {
      if (!draftsMap.has(draft.contact_id)) draftsMap.set(draft.contact_id, draft);
    }

    // Merge contact_events + captures, deduplicating by contact id
    const seenContactIds = new Set<string>();
    const allContacts: { contact: any; source: string }[] = [];

    for (const ce of (contactEvents || []) as any[]) {
      if (!ce.contact?.id) continue;
      if (seenContactIds.has(ce.contact.id)) continue;
      seenContactIds.add(ce.contact.id);
      allContacts.push({ contact: ce.contact, source: 'scanned' });
    }
    for (const cap of (captures || []) as any[]) {
      if (!cap.contact?.id) continue;
      if (seenContactIds.has(cap.contact.id)) continue;
      seenContactIds.add(cap.contact.id);
      allContacts.push({ contact: cap.contact, source: 'scanned' });
    }

    // Build scanned-contact entries; track which company IDs are covered
    const coveredCompanyIds = new Set<string>();
    const result: any[] = [];

    for (const { contact, source } of allContacts) {
      const company = contact?.company || null;
      if (company?.id) coveredCompanyIds.add(company.id);
      const draft = contact ? (draftsMap.get(contact.id) || null) : null;

      result.push({
        source,
        contact: contact ? {
          id: contact.id,
          first_name: contact.first_name,
          last_name: contact.last_name,
          email: contact.email,
          job_title: contact.job_title,
          follow_up_status: contact.follow_up_status,
          ai_insights: contact.ai_insights,
        } : null,
        email_draft: draft ? {
          id: draft.id,
          subject: draft.subject,
          body: draft.body,
          email_type: draft.email_type,
          status: draft.status,
        } : null,
        company: company ? {
          id: company.id,
          name: company.name,
          industry: company.industry,
        } : null,
      });
    }

    res.json({ data: result });
  } catch (error) {
    next(error);
  }
});

// PATCH /api/events/:id/follow-ups/:contactId
// Marks a contact as contacted and upserts the email draft as sent.
// Body: { subject?, body?, action: 'send' | 'skip' }
router.patch('/:id/follow-ups/:contactId', async (req, res, next) => {
  try {
    const { id: eventId, contactId } = req.params;
    const { subject, body, action } = req.body as {
      subject?: string;
      body?: string;
      action: 'send' | 'skip' | 'unskip';
    };

    if (!action) {
      res.status(400).json({ error: 'action is required (send | skip | unskip)' });
      return;
    }

    if (action === 'send') {
      // Mark contact as contacted
      await supabase
        .from('contacts')
        .update({
          follow_up_status: 'contacted',
          last_contacted_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        })
        .eq('id', contactId);

      // Upsert the draft as sent — update if exists, insert if not
      const { data: existing } = await supabase
        .from('email_drafts')
        .select('id')
        .eq('event_id', eventId)
        .eq('contact_id', contactId)
        .order('created_at', { ascending: false })
        .limit(1)
        .single();

      if (existing) {
        await supabase
          .from('email_drafts')
          .update({
            subject: subject ?? undefined,
            body: body ?? undefined,
            status: 'sent',
            sent_at: new Date().toISOString(),
            updated_at: new Date().toISOString(),
          })
          .eq('id', existing.id);
      } else {
        await supabase
          .from('email_drafts')
          .insert({
            event_id: eventId,
            contact_id: contactId,
            email_type: 'follow_up',
            subject: subject || 'Following up from our meeting',
            body: body || '',
            status: 'sent',
            sent_at: new Date().toISOString(),
          });
      }
    } else if (action === 'skip') {
      // skip — mark as needs_follow_up so it stays visible but deprioritised
      await supabase
        .from('contacts')
        .update({
          follow_up_status: 'needs_follow_up',
          updated_at: new Date().toISOString(),
        })
        .eq('id', contactId);
    } else {
      // unskip — revert to not_contacted so it appears in Pending again
      await supabase
        .from('contacts')
        .update({
          follow_up_status: 'not_contacted',
          updated_at: new Date().toISOString(),
        })
        .eq('id', contactId);
    }

    const messages: Record<string, string> = { send: 'Follow-up sent.', skip: 'Contact skipped.', unskip: 'Contact moved back to pending.' };
    res.json({ message: messages[action] });
  } catch (error) {
    next(error);
  }
});

// POST /api/events/:id/follow-ups/:contactId/draft
// Returns existing draft if one exists, otherwise generates via AI, saves, and returns it.
router.post('/:id/follow-ups/:contactId/draft', async (req, res, next) => {
  try {
    const { id: eventId, contactId } = req.params;

    // Return existing draft immediately if one exists
    const { data: existing } = await supabase
      .from('email_drafts')
      .select('subject, body')
      .eq('event_id', eventId)
      .eq('contact_id', contactId)
      .order('created_at', { ascending: false })
      .limit(1)
      .single();

    if (existing?.subject && existing?.body) {
      res.json({ subject: existing.subject, body: existing.body });
      return;
    }

    // No saved draft — generate via AI
    const [{ data: eventData }, { data: contactData }] = await Promise.all([
      supabase.from('events').select('name, location, start_date').eq('id', eventId).single(),
      supabase.from('contacts')
        .select('first_name, last_name, job_title, ai_insights, companies(name, industry, description)')
        .eq('id', contactId)
        .single(),
    ]);

    if (!contactData) { res.status(404).json({ error: 'Contact not found' }); return; }

    const firstName = contactData.first_name || '';
    const lastName = contactData.last_name || '';
    const jobTitle = contactData.job_title || '';
    const company = (contactData as any).companies as any;
    const companyName = company?.name || '';
    const companyIndustry = company?.industry || '';
    const insights = contactData.ai_insights as any;
    const eventName = eventData?.name || 'the event';

    const insightLines: string[] = [];
    if (insights?.strategic_context) insightLines.push(`Strategic context: ${insights.strategic_context}`);
    if (insights?.primary_pain_point) insightLines.push(`Pain point: ${insights.primary_pain_point}`);
    if (insights?.current_sentiment) insightLines.push(`Sentiment: ${insights.current_sentiment}`);
    if (insights?.buying_authority) insightLines.push(`Buying authority: ${insights.buying_authority}`);
    if (insights?.briefing_items?.length) insightLines.push(`Key notes: ${(insights.briefing_items as string[]).join('; ')}`);

    const prompt = `You are a professional relationship manager writing a follow-up email after a business event.

Contact details:
- Name: ${firstName}${lastName ? ' ' + lastName : ''}
- Title: ${jobTitle || 'Unknown'}
- Company: ${companyName || 'Unknown'}${companyIndustry ? ` (${companyIndustry})` : ''}
- Event met at: ${eventName}

${insightLines.length > 0 ? `AI-captured context:\n${insightLines.join('\n')}` : ''}

Write a short, warm, professional follow-up email. Rules:
- Do NOT include the sender's name or signature — the recipient will add it
- Address the contact by first name
- Reference the event and one specific insight if available
- Keep the body to 3-4 short paragraphs
- End with a clear but soft call to action (e.g. a quick call)
- Do NOT use generic filler phrases like "I hope this email finds you well"
- Do NOT include any placeholder text like [Your Name] or [Signature]

Respond in JSON with exactly two fields: "subject" (string) and "body" (string). Nothing else.`;

    const llm = new LiteLLMService();
    const raw = await llm.generateCompletion([{ role: 'user', content: prompt }]);

    let subject = `Following up — ${companyName || firstName}`;
    let body = raw;

    try {
      const jsonMatch = raw.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        const parsed = JSON.parse(jsonMatch[0]);
        if (parsed.subject) subject = parsed.subject;
        if (parsed.body) body = parsed.body;
      }
    } catch (_) { /* use raw body */ }

    // Save the generated draft so future calls skip AI entirely
    await supabase.from('email_drafts').insert({
      event_id: eventId,
      contact_id: contactId,
      email_type: 'follow_up',
      subject,
      body,
      status: 'draft',
    });

    res.json({ subject, body });
  } catch (error) {
    next(error);
  }
});

// GET /api/events/:id/targets/:targetId/contacts
router.get('/:id/targets/:targetId/contacts', async (req, res, next) => {
  try {
    const { id: eventId, targetId } = req.params;

    // Get the target to find company_id
    const { data: target, error: targetError } = await supabase
      .from('target_companies')
      .select('company_id')
      .eq('id', targetId)
      .single();
    if (targetError || !target) { res.status(404).json({ error: 'Target not found' }); return; }

    // Get all contacts for this company
    const { data: contacts, error: contactsError } = await supabase
      .from('contacts')
      .select('id, first_name, last_name, email, job_title')
      .eq('company_id', target.company_id)
      .order('first_name');
    if (contactsError) throw contactsError;

    // Get contacts already linked to this event
    const { data: linked } = await supabase
      .from('contact_events')
      .select('contact_id')
      .eq('event_id', eventId);
    const linkedIds = new Set((linked || []).map((l: any) => l.contact_id));

    const result = (contacts || []).map((c: any) => ({
      ...c,
      linked_to_event: linkedIds.has(c.id),
    }));

    res.json({ data: result });
  } catch (error) { next(error); }
});

// POST /api/events/:id/targets/:targetId/contacts
router.post('/:id/targets/:targetId/contacts', async (req, res, next) => {
  try {
    const { id: eventId } = req.params;
    const { contact_id } = req.body;
    if (!contact_id) { res.status(400).json({ error: 'contact_id required' }); return; }

    const { error } = await supabase
      .from('contact_events')
      .insert({ contact_id, event_id: eventId });

    if (error && error.code !== '23505') throw error; // ignore duplicate

    res.json({ message: 'Contact linked to event' });
  } catch (error) { next(error); }
});

// DELETE /api/events/:id/targets/:targetId/contacts/:contactId
router.delete('/:id/targets/:targetId/contacts/:contactId', async (req, res, next) => {
  try {
    const { id: eventId, contactId } = req.params;

    const { error } = await supabase
      .from('contact_events')
      .delete()
      .eq('contact_id', contactId)
      .eq('event_id', eventId);

    if (error) throw error;
    res.json({ message: 'Contact unlinked from event' });
  } catch (error) { next(error); }
});

// DELETE /api/events/:id/contacts/:contactId — unlink a contact from an event
router.delete('/:id/contacts/:contactId', async (req, res, next) => {
  try {
    const { error } = await supabase
      .from('contact_events')
      .delete()
      .eq('contact_id', req.params.contactId)
      .eq('event_id', req.params.id);
    if (error) throw error;
    res.json({ message: 'Contact removed from event' });
  } catch (error) { next(error); }
});

// GET /api/events/:id/contacts — list target contacts for an event
router.get('/:id/contacts', async (req, res, next) => {
  try {
    const { data, error } = await supabase
      .from('contact_events')
      .select(`
        id, contact_id, status, notes, talking_points, created_at,
        contact:contacts(id, first_name, last_name, job_title, company_name:companies(name))
      `)
      .eq('event_id', req.params.id)
      .order('created_at', { ascending: true });

    if (error) throw error;

    const contacts = (data || []).map((row: any) => {
      const c = row.contact;
      return {
        id: row.id,
        contact_id: row.contact_id,
        name: c ? `${c.first_name} ${c.last_name ?? ''}`.trim() : '',
        job_title: c?.job_title ?? '',
        company_name: c?.company_name?.name ?? '',
        status: row.status || 'not_contacted',
        notes: row.notes || '',
        talking_points: row.talking_points || '',
      };
    });

    res.json({ data: contacts });
  } catch (error) { next(error); }
});

// POST /api/events/:id/contacts — link a contact directly to an event
router.post('/:id/contacts', async (req, res, next) => {
  try {
    const { contact_id } = req.body;
    if (!contact_id) { res.status(400).json({ error: 'contact_id required' }); return; }

    const { error } = await supabase
      .from('contact_events')
      .insert({ contact_id, event_id: req.params.id });

    if (error && error.code !== '23505') throw error; // ignore duplicate

    res.json({ message: 'Contact linked to event' });
  } catch (error) { next(error); }
});

// PATCH /api/events/:id/contacts/:contactId — update target contact status/notes
router.patch('/:id/contacts/:contactId', async (req, res, next) => {
  try {
    const { id: eventId, contactId } = req.params;
    const { status, notes, talking_points } = req.body as {
      status?: string;
      notes?: string;
      talking_points?: string;
    };

    const updates: Record<string, any> = {};
    if (status !== undefined) updates.status = status;
    if (notes !== undefined) updates.notes = notes;
    if (talking_points !== undefined) updates.talking_points = talking_points;

    if (Object.keys(updates).length === 0) {
      res.status(400).json({ error: 'No fields to update' });
      return;
    }

    const { error } = await supabase
      .from('contact_events')
      .update(updates)
      .eq('contact_id', contactId)
      .eq('event_id', eventId);

    if (error) throw error;
    res.json({ message: 'Target contact updated' });
  } catch (error) { next(error); }
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
