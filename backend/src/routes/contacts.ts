import { Router } from 'express';
import { supabase } from '../config/supabase';

const router = Router();

// GET /api/contacts
router.get('/', async (req, res, next) => {
  try {
    const { company_id } = req.query;

    let query = supabase
      .from('contacts')
      .select('*, company:companies(*)');

    if (company_id) {
      query = query.eq('company_id', company_id);
    }

    const { data, error } = await query.order('created_at', { ascending: false });

    if (error) throw error;

    res.json({ data });
  } catch (error) {
    next(error);
  }
});

// GET /api/contacts/:id
router.get('/:id', async (req, res, next) => {
  try {
    const { data, error } = await supabase
      .from('contacts')
      .select('*, company:companies(*)')
      .eq('id', req.params.id)
      .single();

    if (error) throw error;

    res.json({ data });
  } catch (error) {
    next(error);
  }
});

// POST /api/contacts
router.post('/', async (req, res, next) => {
  try {
    const body = req.body;
    let company_id = body.company_id;

    // Find or create company
    if (body.company_name && !company_id) {
      const { data: existingCompany } = await supabase
        .from('companies')
        .select('id')
        .eq('name', body.company_name)
        .single();

      if (existingCompany) {
        company_id = existingCompany.id;
      } else {
        const { data: newCompany } = await supabase
          .from('companies')
          .insert({ name: body.company_name })
          .select('id')
          .single();

        company_id = newCompany?.id;
      }
    }

    const { data, error } = await supabase
      .from('contacts')
      .insert({
        first_name: body.first_name,
        last_name: body.last_name,
        email: body.email,
        phone: body.phone,
        job_title: body.job_title,
        company_id,
        notes: body.notes,
      })
      .select()
      .single();

    if (error) throw error;

    // Create interaction if event_id provided
    if (body.event_id) {
      await supabase.from('interactions').insert({
        contact_id: data.id,
        event_id: body.event_id,
        interaction_type: 'capture',
        summary: 'Manually added during event',
        details: { source: 'manual_entry' }
      });

      await supabase.from('captures').insert({
        contact_id: data.id,
        event_id: body.event_id,
        capture_type: 'manual',
        status: 'completed',
        raw_data: { manual_data: body }
      });
    }

    // Link to target companies
    if (body.event_id && company_id) {
      const { data: targetMatch } = await supabase
        .from('target_companies')
        .select('id')
        .eq('event_id', body.event_id)
        .eq('company_id', company_id)
        .single();

      if (targetMatch) {
        await supabase
          .from('target_companies')
          .update({
            status: 'contacted',
            updated_at: new Date().toISOString()
          })
          .eq('id', targetMatch.id);

        console.log(`Auto-linked manual contact to target company: ${targetMatch.id}`);
      }
    }

    res.json({ data, message: 'Contact created successfully' });
  } catch (error) {
    next(error);
  }
});

// PATCH /api/contacts/:id
router.patch('/:id', async (req, res, next) => {
  try {
    const { data, error } = await supabase
      .from('contacts')
      .update(req.body)
      .eq('id', req.params.id)
      .select()
      .single();

    if (error) throw error;

    res.json({ data, message: 'Contact updated successfully' });
  } catch (error) {
    next(error);
  }
});

// PUT /api/contacts/:id
router.put('/:id', async (req, res, next) => {
  try {
    const { data, error } = await supabase
      .from('contacts')
      .update(req.body)
      .eq('id', req.params.id)
      .select(`
        *,
        company:companies(*)
      `)
      .single();

    if (error) throw error;

    res.json({ data });
  } catch (error) {
    next(error);
  }
});

// GET /api/contacts/:id/timeline
router.get('/:id/timeline', async (req, res, next) => {
  try {
    const { id } = req.params;
    const { type } = req.query;

    let query = supabase
      .from('interactions')
      .select(`
        *,
        event:events(*),
        contact:contacts(*)
      `)
      .eq('contact_id', id)
      .order('interaction_date', { ascending: false });

    if (type && type !== 'all') {
      query = query.eq('interaction_type', type);
    }

    const { data: interactions, error } = await query;

    if (error) throw error;

    // Fetch notes
    let notes: any[] = [];
    if (!type || type === 'all' || type === 'note') {
      const { data: notesData } = await supabase
        .from('notes')
        .select('*, event:events(*)')
        .eq('contact_id', id)
        .order('created_at', { ascending: false });
      notes = notesData || [];
    }

    // Fetch meetings
    let meetings: any[] = [];
    if (!type || type === 'all' || type === 'meeting') {
      const { data: meetingsData } = await supabase
        .from('meeting_briefs')
        .select('*, event:events(*)')
        .eq('contact_id', id)
        .order('meeting_date', { ascending: false });
      meetings = meetingsData || [];
    }

    // Fetch captures
    const { data: captures } = await supabase
      .from('captures')
      .select('*')
      .eq('contact_id', id)
      .order('created_at', { ascending: false });

    // Filter duplicates
    const meetingIds = new Set(meetings.map(m => m.id));
    const filteredInteractions = (interactions || []).filter(i => {
      if (i.interaction_type === 'meeting' && i.details?.meeting_id && meetingIds.has(i.details.meeting_id)) {
        return false;
      }
      return true;
    });

    // Combine timeline
    const timeline = [
      ...filteredInteractions.map((i: any) => {
        const item = {
          ...i,
          type: 'interaction',
          date: i.interaction_date
        };

        if (i.interaction_type === 'capture' && !i.details?.image_url && captures && captures.length > 0) {
          let matchingCapture = captures.find((c: any) =>
            c.event_id === i.event_id &&
            Math.abs(new Date(c.created_at).getTime() - new Date(i.interaction_date).getTime()) < 30000
          );

          if (!matchingCapture) {
            matchingCapture = captures[0];
          }

          if (matchingCapture) {
            item.details = {
              ...(i.details || {}),
              image_url: matchingCapture.image_url
            };
          }
        }
        return item;
      }),
      ...(notes || []).map((n: any) => ({
        ...n,
        type: 'note',
        date: n.created_at
      })),
      ...(meetings || []).map((m: any) => ({
        ...m,
        type: 'meeting',
        date: m.meeting_date
      }))
    ].sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime());

    res.json({ data: timeline });
  } catch (error) {
    next(error);
  }
});

// DELETE /api/contacts/:id
router.delete('/:id', async (req, res, next) => {
  try {
    const { error } = await supabase
      .from('contacts')
      .delete()
      .eq('id', req.params.id);

    if (error) throw error;

    res.json({ message: 'Contact deleted successfully' });
  } catch (error) {
    next(error);
  }
});

export default router;


// POST /api/contacts/:id/enrich
router.post('/:id/enrich', async (req, res, next) => {
  try {
    const { id } = req.params;
    const { EnrichmentService } = await import('../services/enrichment-service');

    // Fetch contact with company data
    const { data: contact, error: fetchError } = await supabase
      .from('contacts')
      .select(`
        *,
        company:companies(*)
      `)
      .eq('id', id)
      .single();

    if (fetchError || !contact) {
      return res.status(404).json({ error: fetchError?.message || 'Contact not found' });
    }

    // Perform AI Research
    const enrichResult = await EnrichmentService.enrichContact({
      name: `${contact.first_name} ${contact.last_name || ''}`.trim(),
      company: contact.company?.name,
      email: contact.email,
      job_title: contact.job_title
    });

    if (req.body.review_only) {
      return res.json({
        success: true,
        data: {
          enrichment: enrichResult
        }
      });
    }

    // Update Company data if applicable
    if (contact.company_id) {
      const companyUpdate = {
        industry: enrichResult.industry || contact.company.industry,
        description: enrichResult.description || contact.company.description,
        location: enrichResult.location || contact.company.location,
        region: enrichResult.region || contact.company.region,
        company_size: enrichResult.company_size || contact.company.company_size,
        products_services: enrichResult.products_services || contact.company.products_services,
        website: enrichResult.website || contact.company.website,
        is_enriched: true,
        enrichment_confidence: enrichResult.confidence.industry || 0.8
      };

      const { error: companyError } = await supabase
        .from('companies')
        .update(companyUpdate)
        .eq('id', contact.company_id);

      if (companyError) console.error('Error updating company enrichment:', companyError);
    }

    // Update Contact data (LinkedIn URL)
    if (enrichResult.linkedin_url && !contact.linkedin_url) {
      await supabase
        .from('contacts')
        .update({ linkedin_url: enrichResult.linkedin_url })
        .eq('id', id);
    }

    res.json({
      success: true,
      data: {
        ...contact,
        is_enriched: true,
        enrichment: enrichResult
      }
    });
  } catch (error: any) {
    console.error('Enrichment failed:', error);
    res.status(500).json({ error: error?.message || 'Failed to enrich contact' });
  }
});
