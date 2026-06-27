import { Router, Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { TavilyService } from '../services/tavily-service';
import { requireAuth } from '../middleware/requireAuth';
import { supabase as supabaseAdmin } from '../config/supabase';
import { decodeAndValidateImage } from '../utils/imageValidation';
import { upsertFollowUp } from '../services/followUps';

const CARD_BUCKET = 'contact-cards';

const uuidSchema = z.string().uuid();
const optUrl = z.string().url().max(500).optional().or(z.literal(''));

const contactWriteSchema = z.object({
  first_name: z.string().trim().min(1).max(100),
  last_name: z.string().trim().max(100).optional().or(z.literal('')),
  email: z.string().trim().email().max(254).optional().or(z.literal('')),
  phone: z.string().trim().max(30).optional().or(z.literal('')),
  job_title: z.string().trim().max(150).optional().or(z.literal('')),
  linkedin_url: optUrl,
  notes: z.string().trim().max(5000).optional().or(z.literal('')),
  company_id: uuidSchema.optional(),
  company_name: z.string().trim().max(200).optional(),
  event_id: uuidSchema.optional(),
});

const contactPatchSchema = contactWriteSchema.partial();

const duplicateCheckSchema = z.object({
  name: z.string().trim().max(200).optional(),
  email: z.string().trim().email().max(254).optional().or(z.literal('')),
  phone: z.string().trim().max(30).optional(),
}).refine(d => d.name || d.email || d.phone, { message: 'At least one of name, email, or phone is required' });

const router = Router();

// Apply auth middleware to all routes in this file
router.use(requireAuth);

// Verify the contact identified by :id belongs to the authenticated user.
// Runs automatically before any handler that has an :id param. This is a
// route-layer ownership guard (defense-in-depth on top of RLS) that also
// closes the IDOR on sub-resource reads like /:id/timeline, which query
// child tables (interactions/captures) by contact_id.
router.param('id', async (req: Request, res: Response, next: NextFunction, id: string) => {
  try {
    const supabase = req.supabase!;
    const { data: contact } = await supabase
      .from('contacts')
      .select('id, user_id')
      .eq('id', id)
      .is('deleted_at', null)
      .maybeSingle();

    if (!contact) {
      return res.status(404).json({ error: 'Contact not found' });
    }

    if (contact.user_id !== req.user!.id) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    next();
  } catch {
    res.status(500).json({ error: 'Failed to verify contact ownership' });
  }
});

// Strips spaces/dashes/etc, keeping a leading "+" (country code marker), so
// scanned numbers ("+91-9876543210") match manually typed ones during
// duplicate detection and stay consistent when stored.
function normalizePhone(phone: string): string {
  const hasPlus = phone.trim().startsWith('+');
  const digits = phone.replace(/\D/g, '');
  return hasPlus ? `+${digits}` : digits;
}

// GET /api/contacts
router.get('/', async (req, res, next) => {
  try {
    const supabase = req.supabase!;
    const { company_id } = req.query;

    let query = supabase
      .from('contacts')
      .select('*, company:companies(*)')
      .eq('user_id', req.user!.id)
      .is('deleted_at', null);

    if (company_id) {
      query = query.eq('company_id', company_id);
    }

    const { data, error } = await query.order('created_at', { ascending: false });

    if (error) {
      console.error('Supabase error:', error);
      throw error;
    }

    res.json({ data: data || [] });
  } catch (error) {
    next(error);
  }
});

// POST /api/contacts/check-duplicate
router.post('/check-duplicate', async (req, res, next) => {
  try {
    const supabase = req.supabase!;
    const parsed = duplicateCheckSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: parsed.error.flatten() });
    }
    const { name, email, phone } = parsed.data;

    let query = supabase
      .from('contacts')
      .select('*, company:companies(*)')
      .eq('user_id', req.user!.id)
      .is('deleted_at', null);

    const normalizedPhone = phone ? normalizePhone(phone) : undefined;

    if (email && normalizedPhone) {
      // Phone is compared in app code below (stored numbers may contain
      // spaces/dashes), so the query only needs to narrow by email here.
      query = query.or(`email.eq.${email},phone.not.is.null`);
    } else if (email) {
      query = query.eq('email', email);
    } else if (normalizedPhone) {
      query = query.not('phone', 'is', null);
    } else if (name) {
      const nameParts = name.trim().split(/\s+/);
      const firstName = nameParts[0];
      const lastName = nameParts.slice(1).join(' ');
      if (lastName) {
        query = query.or(`first_name.ilike.%${firstName}%,last_name.ilike.%${lastName}%`);
      } else {
        query = query.or(`first_name.ilike.%${firstName}%,last_name.ilike.%${firstName}%`);
      }
    }

    const { data, error } = await query.limit(name && !email && !normalizedPhone ? 5 : 200);

    if (error) throw error;

    let matches = data || [];

    if (normalizedPhone) {
      matches = matches.filter((c: any) =>
        (c.email && email && c.email === email) ||
        (c.phone && normalizePhone(c.phone) === normalizedPhone)
      );
      matches = matches.slice(0, 5);
    }

    res.json({ data: matches, has_duplicates: matches.length > 0 });
  } catch (error) {
    next(error);
  }
});

// GET /api/contacts/:id
router.get('/:id', async (req, res, next) => {
  try {
    const supabase = req.supabase!;
    const { data, error } = await supabase
      .from('contacts')
      .select('*, company:companies(*)')
      .eq('id', req.params.id)
      .eq('user_id', req.user!.id)
      .is('deleted_at', null)
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
    const supabase = req.supabase!;
    const parsed = contactWriteSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: parsed.error.flatten() });
    }
    const body = parsed.data;
    const idempotencyKey = req.headers['idempotency-key'] as string | undefined;
    let company_id = body.company_id;

    // Idempotency: if a contact with this client_op_id already exists for this user, return it.
    if (idempotencyKey) {
      const { data: existing } = await supabase
        .from('contacts')
        .select()
        .eq('client_op_id', idempotencyKey)
        .eq('user_id', req.user!.id)
        .is('deleted_at', null)
        .maybeSingle();
      if (existing) {
        return res.json({ data: existing });
      }
    }

    // Find or create company
    const companyName = body.company_name || 'INDEPENDENT';

    if (!company_id) {
      const { data: existingCompany } = await supabase
        .from('companies')
        .select('id')
        .eq('name', companyName)
        .maybeSingle();

      if (existingCompany) {
        company_id = existingCompany.id;
      } else {
        const { data: newCompany, error: insertError } = await supabase
          .from('companies')
          .insert({ name: companyName })
          .select('id')
          .single();

        if (insertError) {
          console.error('Error creating company:', insertError);
        } else {
          company_id = newCompany?.id;
        }
      }
    }

    const { data, error } = await supabase
      .from('contacts')
      .insert({
        first_name: body.first_name,
        last_name: body.last_name,
        email: body.email,
        phone: body.phone ? normalizePhone(body.phone) : body.phone,
        job_title: body.job_title,
        linkedin_url: body.linkedin_url,
        company_id,
        notes: body.notes,
        user_id: req.user!.id,
        ...(idempotencyKey ? { client_op_id: idempotencyKey } : {}),
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
        details: { source: 'manual_entry' },
        user_id: req.user!.id,
      });

      await supabase.from('captures').insert({
        contact_id: data.id,
        event_id: body.event_id,
        capture_type: 'manual',
        status: 'completed',
        raw_data: { manual_data: body },
        user_id: req.user!.id,
      });
    }

    // Follow-up trigger #1 (manual add): seed a 'new' record keyed to the event
    // (or general). The interaction this route inserts directly bypasses the
    // /interactions route, so we seed here rather than rely on that trigger.
    try {
      await upsertFollowUp(supabase, req.user!.id, {
        contactId: data.id,
        eventId: body.event_id ?? null,
        seedStatus: 'new',
      });
    } catch (e) {
      console.error('follow_up upsert (manual contact) failed:', e);
    }

    // Link to target companies
    if (body.event_id && company_id) {
      const { data: targetMatch } = await supabase
        .from('target_companies')
        .select('id')
        .eq('event_id', body.event_id)
        .eq('company_id', company_id)
        .is('deleted_at', null)
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
// Supports optional `company_name` field: finds or creates the company and
// re-points company_id — never renames an existing company record.
router.patch('/:id', async (req, res, next) => {
  try {
    const supabase = req.supabase!;
    const parsedId = uuidSchema.safeParse(req.params.id);
    if (!parsedId.success) return res.status(400).json({ error: 'Invalid contact id' });

    const parsedBody = contactPatchSchema.safeParse(req.body);
    if (!parsedBody.success) return res.status(400).json({ error: parsedBody.error.flatten() });

    const { company_name, ...contactFields } = parsedBody.data as any;

    if (contactFields.phone) {
      contactFields.phone = normalizePhone(contactFields.phone);
    }

    if (company_name !== undefined) {
      const normalizedName = (company_name as string).trim() || 'INDEPENDENT';

      const { data: existingCompany } = await supabase
        .from('companies')
        .select('id')
        .ilike('name', normalizedName)
        .maybeSingle();

      if (existingCompany) {
        contactFields.company_id = existingCompany.id;
      } else {
        const { data: newCompany, error: createErr } = await supabase
          .from('companies')
          .insert({ name: normalizedName })
          .select('id')
          .single();
        if (createErr) throw createErr;
        contactFields.company_id = newCompany.id;
      }
    }

    const { data, error } = await supabase
      .from('contacts')
      .update(contactFields)
      .eq('id', req.params.id)
      .eq('user_id', req.user!.id)
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
    const supabase = req.supabase!;
    const parsedId = uuidSchema.safeParse(req.params.id);
    if (!parsedId.success) return res.status(400).json({ error: 'Invalid contact id' });

    const parsedBody = contactWriteSchema.safeParse(req.body);
    if (!parsedBody.success) return res.status(400).json({ error: parsedBody.error.flatten() });

    const safeBody = parsedBody.data;
    if (safeBody.phone) {
      (safeBody as any).phone = normalizePhone(safeBody.phone);
    }

    const { data, error } = await supabase
      .from('contacts')
      .update(safeBody)
      .eq('id', req.params.id)
      .eq('user_id', req.user!.id)
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
    const supabase = req.supabase!;
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
      .is('deleted_at', null)
      .order('interaction_date', { ascending: false });

    if (type && type !== 'all') {
      query = query.eq('interaction_type', type);
    }

    const { data: interactions, error } = await query;

    if (error) throw error;

    // Fetch captures
    const { data: captures } = await supabase
      .from('captures')
      .select('*')
      .eq('contact_id', id)
      .is('deleted_at', null)
      .order('created_at', { ascending: false });

    // Combine timeline
    const timeline = [
      ...(interactions || []).map((i: any) => {
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
    ].sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime());

    res.json({ data: timeline });
  } catch (error) {
    next(error);
  }
});

// GET /api/contacts/:id/card-url
// Returns a short-lived signed URL for the contact's most recent scanned/
// uploaded business card image, or 404 if the contact has none. Ownership is
// enforced by RLS (req.supabase) on the captures lookup; signing is done with
// the admin client since the bucket is private. Cross-tenant access is not
// possible: the capture must belong to the caller for the lookup to return it.
router.get('/:id/card-url', async (req, res, next) => {
  try {
    const supabase = req.supabase!;
    const { id } = req.params;

    const { data: capture, error } = await supabase
      .from('captures')
      .select('image_url')
      .eq('contact_id', id)
      .in('capture_type', ['card_scan', 'file_scan'])
      .not('image_url', 'is', null)
      .is('deleted_at', null)
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle();

    if (error) return res.status(400).json({ error: error.message });
    if (!capture?.image_url) {
      return res.status(404).json({ error: 'No card image for this contact' });
    }

    const stored: string = capture.image_url;

    // A real storage path looks like "{userId}/{captureId}.{ext}". Legacy rows
    // instead hold an inline image: an http URL or (older clients) bare base64 /
    // a data: URI. Only sign true storage paths.
    const isStoragePath = /^[^/]+\/[^/]+\.[a-z0-9]+$/i.test(stored);

    if (!isStoragePath) {
      // Pass through trusted remote URLs untouched.
      if (stored.startsWith('http')) {
        return res.json({ data: { url: stored } });
      }

      // Inline data (legacy bare base64 or data: URI). Never trust a stored
      // data: prefix — it could be data:text/html / data:image/svg+xml (stored
      // XSS). Decode, sniff the real magic bytes, and re-emit only a known
      // raster type. Anything else is rejected.
      try {
        const { buffer, type } = decodeAndValidateImage(stored);
        return res.json({ data: { url: `data:${type.mime};base64,${buffer.toString('base64')}` } });
      } catch {
        return res.status(404).json({ error: 'No card image for this contact' });
      }
    }

    const { data: signed, error: signErr } = await supabaseAdmin.storage
      .from(CARD_BUCKET)
      .createSignedUrl(stored, 60 * 60);

    if (signErr || !signed) {
      return res.status(500).json({ error: signErr?.message || 'Failed to sign card URL' });
    }

    res.json({ data: { url: signed.signedUrl } });
  } catch (error) {
    next(error);
  }
});

// DELETE /api/contacts/:id
router.delete('/:id', async (req, res, next) => {
  try {
    const supabase = req.supabase!;
    const { error } = await supabase
      .from('contacts')
      .update({ deleted_at: new Date().toISOString() })
      .eq('id', req.params.id)
      .eq('user_id', req.user!.id);

    if (error) throw error;

    res.json({ message: 'Contact deleted successfully' });
  } catch (error) {
    next(error);
  }
});

// ─── Gemini 2.5 Pro context budget ───────────────────────────────────────────
// Input limit: 1,048,576 tokens ≈ 4,194,304 chars (4 chars/token estimate)
// We use 80% of that for timeline content, leaving room for prompt + response.
const GEMINI_25_PRO_INPUT_TOKENS = 1_048_576;
const CHARS_PER_TOKEN = 4;
const TIMELINE_BUDGET_CHARS = Math.floor(GEMINI_25_PRO_INPUT_TOKENS * 0.80 * CHARS_PER_TOKEN); // ~3.36M chars
const RECENT_WINDOW_CHARS = Math.floor(TIMELINE_BUDGET_CHARS * 0.30);                           // ~1M chars kept as "recent"

// GET /api/contacts/:id/insights
// Returns AI-generated insights. Uses cached version unless contact/company/timeline changed.
// Implements rolling-summary context management for Gemini 2.5 Pro's 1M token window.
router.get('/:id/insights', async (req, res, next) => {
  try {
    const supabase = req.supabase!;
    const { id } = req.params;

    // Fetch contact with company — scoped to this user
    const { data: contact, error: contactError } = await supabase
      .from('contacts')
      .select('*, company:companies(*)')
      .eq('id', id)
      .eq('user_id', req.user!.id)
      .is('deleted_at', null)
      .single();

    if (contactError || !contact) {
      return res.status(404).json({ error: 'Contact not found' });
    }

    const contactName = `${contact.first_name} ${contact.last_name || ''}`.trim();
    console.log(`[insights] ${contactName} (${id}) — checking cache`);

    // ── Cache validity check ─────────────────────────────────────────────────
    const latestInteraction = await supabase.from('interactions').select('updated_at').eq('contact_id', id)
      .is('deleted_at', null)
      .order('updated_at', { ascending: false }).limit(1).maybeSingle();

    const insightsTs = contact.ai_insights_generated_at ? new Date(contact.ai_insights_generated_at).getTime() : 0;
    const contactTs = new Date(contact.updated_at).getTime();
    const interactionTs = latestInteraction.data ? new Date(latestInteraction.data.updated_at).getTime() : 0;
    const latestActivityTime = Math.max(contactTs, interactionTs);

    console.log(`[insights]   ai_insights_generated_at : ${contact.ai_insights_generated_at ?? 'none'}`);
    console.log(`[insights]   contact.updated_at       : ${contact.updated_at}${contactTs > insightsTs ? '  ← NEWER' : ''}`);
    console.log(`[insights]   latest interaction       : ${latestInteraction.data?.updated_at ?? 'none'}${interactionTs > insightsTs ? '  ← NEWER' : ''}`);

    if (
      contact.ai_insights &&
      contact.ai_insights_generated_at &&
      insightsTs >= latestActivityTime
    ) {
      console.log(`[insights] ✓ CACHE HIT — returning stored insights, no AI call`);
      return res.json({ data: contact.ai_insights, cached: true });
    }

    const reason = !contact.ai_insights
      ? 'no insights stored yet'
      : !contact.ai_insights_generated_at
        ? 'generated_at timestamp missing'
        : `data changed after last generation (delta: +${Math.round((latestActivityTime - insightsTs) / 1000)}s)`;
    console.log(`[insights] ✗ CACHE MISS — calling AI (reason: ${reason})`);

    // ── Fetch full timeline (no artificial limit) ────────────────────────────
    const interactionsRes = await supabase.from('interactions')
      .select('interaction_type, summary, details, interaction_date, event:events(name)')
      .eq('contact_id', id)
      .is('deleted_at', null)
      .order('interaction_date', { ascending: true });

    type TimelineEntry = { text: string; date: string };

    const allTimeline: TimelineEntry[] = (interactionsRes.data || []).map((i: any) => {
        const note = i.details?.note ? ` Note: ${i.details.note}` : '';
        // Give the AI the event context: a follow-up completion log reads as
        // "Follow up to {event}"; any other event-linked interaction notes the
        // event it happened at. Resolved from the live event join (never stale).
        const eventName = i.event?.name as string | undefined;
        let eventCtx = '';
        if (eventName) {
          eventCtx = i.details?.follow_up_log === true
            ? ` (Follow up to ${eventName})`
            : ` (at ${eventName})`;
        }
        return {
          text: `[${i.interaction_type}] ${(i.summary || '').slice(0, 1000)}${note}${eventCtx} (${i.interaction_date?.slice(0, 10)})`,
          date: i.interaction_date || '',
        };
      })
      .filter(item => item.text.trim() && item.date)
      .sort((a, b) => a.date.localeCompare(b.date));

    // ── Links & files context ────────────────────────────────────────────────
    const assets: any[] = contact.contact_assets || [];
    const assetsContext = assets.length > 0
      ? `\nLinks & Files shared with contact:\n${assets.map((a: any) => `  - [${a.type}] ${a.title}: ${a.url}`).join('\n')}`
      : '';

    // ── Rolling summary context management ───────────────────────────────────
    const fullTimelineStr = allTimeline.map(t => t.text).join('\n');
    let timelineContext: string;

    const totalTimelineChars = fullTimelineStr.length;
    const totalTimelineTokensEst = Math.round(totalTimelineChars / CHARS_PER_TOKEN);
    console.log(`[insights] timeline size: ${allTimeline.length} items, ~${totalTimelineChars.toLocaleString()} chars (~${totalTimelineTokensEst.toLocaleString()} tokens)`);

    if (totalTimelineChars <= TIMELINE_BUDGET_CHARS) {
      // Fits within Gemini 2.5 Pro budget — use everything as-is
      console.log(`[insights] timeline fits in budget (limit: ~${(TIMELINE_BUDGET_CHARS / 1_000_000).toFixed(1)}M chars) — sending verbatim`);
      timelineContext = fullTimelineStr;
    } else {
      // Over budget: split into "old" (to summarise) + "recent" (verbatim)
      let recentChars = 0;
      let recentStartIdx = allTimeline.length;

      for (let i = allTimeline.length - 1; i >= 0; i--) {
        const len = allTimeline[i].text.length + 1;
        if (recentChars + len > RECENT_WINDOW_CHARS) break;
        recentChars += len;
        recentStartIdx = i;
      }

      const recentItems = allTimeline.slice(recentStartIdx);
      const oldItems = allTimeline.slice(0, recentStartIdx);

      const existingSummary = contact.ai_context_summary as string | null;
      const summarizedThrough = contact.ai_context_summarized_through as string | null;
      const lastOldDate = oldItems.length > 0 ? oldItems[oldItems.length - 1].date : null;
      const summaryCoversAll = existingSummary && summarizedThrough && lastOldDate
        && summarizedThrough >= lastOldDate;

      let historySummary: string;

      console.log(`[insights] timeline EXCEEDS budget — activating rolling summary`);
      console.log(`[insights]   old items: ${oldItems.length}, recent items: ${recentItems.length}`);

      if (summaryCoversAll) {
        // Existing rolling summary is still current — reuse it
        historySummary = existingSummary!;
        console.log(`[insights]   rolling summary: REUSED (covers up to ${summarizedThrough}) — no extra AI call`);
      } else {
        // Need to (re)generate summary for old items
        console.log(`[insights]   rolling summary: STALE or missing — calling AI to regenerate summary`);
        const { AIService: AI } = await import('../config/ai');
        const name = `${contact.first_name} ${contact.last_name || ''}`.trim();
        const oldContent = oldItems.map(t => t.text).join('\n');

        // Summarise in chunks if old content itself is massive
        const SUMMARY_CHUNK = 800_000; // chars
        let summaryInput = oldContent;
        if (oldContent.length > SUMMARY_CHUNK && existingSummary && summarizedThrough) {
          // Combine old summary with newly unsummarised chunk
          const newChunk = oldItems
            .filter(t => t.date > summarizedThrough!)
            .map(t => t.text).join('\n');
          summaryInput = `Previous summary:\n${existingSummary}\n\nNew activity to incorporate:\n${newChunk}`;
        }

        const summaryPrompt =
          `You are a CRM assistant. Summarise the engagement history for ${name} into a concise factual paragraph (max 600 words). ` +
          `Preserve: key decisions, relationship sentiment, topics discussed, commitments made, and any important context a salesperson needs to know.\n\n` +
          summaryInput;

        const summaryRaw = await AI.generateCompletion(
          [{ role: 'user', content: summaryPrompt }],
          { temperature: 0.2 }
        );
        historySummary = summaryRaw.trim();

        // Persist rolling summary (does NOT bump updated_at — trigger excludes AI columns)
        await supabase.from('contacts').update({
          ai_context_summary: historySummary,
          ai_context_summarized_through: lastOldDate,
        }).eq('id', id);
      }

      const recentStr = recentItems.map(t => t.text).join('\n');
      timelineContext =
        `[HISTORICAL SUMMARY (older interactions condensed)]\n${historySummary}` +
        (recentStr ? `\n\n[RECENT ACTIVITY (verbatim)]\n${recentStr}` : '');
    }

    // ── Build final prompt ───────────────────────────────────────────────────
    const name = `${contact.first_name} ${contact.last_name || ''}`.trim();
    const company = contact.company;
    const isIndependent = !company || !company.name || company.name.toUpperCase() === 'INDEPENDENT';

    const companyContext = isIndependent
      ? `Company: This person is an independent professional or freelancer — not affiliated with any company.`
      : `Company:
- Name: ${company.name}
- Industry: ${company.industry || 'Unknown'}
- Description: ${company.description || 'Not available'}
- Location: ${company.location || 'Unknown'}
- Size: ${company.company_size || 'Unknown'}
- Products/Services: ${company.products_services || 'Unknown'}
- Website: ${company.website || 'Not available'}`;

    let prompt =
      `You are a CRM assistant helping a sales professional understand a contact.\n\n` +
      `Contact:\n` +
      `- Name: ${name}\n` +
      `- Job Title: ${contact.job_title || 'Unknown'}\n` +
      `- LinkedIn: ${contact.linkedin_url || 'Not provided'}\n` +
      `- Follow-up Status: ${contact.follow_up_status || 'not_contacted'}\n\n` +
      `${companyContext}\n` +
      (assetsContext ? `${assetsContext}\n` : '') +
      `\nEngagement History:\n${timelineContext || 'No prior engagement recorded.'}\n\n` +
      `Return ONLY a single-line minified JSON with exactly these keys. No literal newlines inside string values:\n` +
      `{"briefing_items":["up to 3 short bullets"],"buying_authority":"Decision Maker|Influencer|Evaluator|Gatekeeper|Unknown","current_sentiment":"Hot Lead|Warm Opportunity|Evaluating|Cold|Unknown","primary_pain_point":"one sentence","ai_insights":["up to 3 insights"],"strategic_context":"one sentence","key_markets":["up to 3 markets"],"decision_structure":"one sentence"}`;

    // ── Tavily web search for real-time grounding ────────────────────────────
    console.log(`[insights] → running Tavily web search for "${name}"`);
    const webContext = await TavilyService.searchContact({
      name,
      company: isIndependent ? undefined : company?.name,
      jobTitle: contact.job_title,
    });
    if (webContext) {
      prompt += `\n\n## Live Web Research (Tavily)\n${webContext}`;
    }

    const promptChars = prompt.length;
    console.log(`[insights] → calling Gemini AI (prompt: ~${promptChars.toLocaleString()} chars / ~${Math.round(promptChars / CHARS_PER_TOKEN).toLocaleString()} tokens)`);
    const t0 = Date.now();

    const { AIService, litellm } = await import('../config/ai');
    const raw = await AIService.generateCompletion(
      [{ role: 'user', content: prompt }],
      { temperature: 0.4, jsonMode: true }
    );

    console.log(`[insights] ← AI responded in ${Date.now() - t0}ms`);
    const insights = litellm.cleanAndParseJSON(raw);

    await supabase.from('contacts').update({
      ai_insights: insights,
      ai_insights_generated_at: new Date().toISOString(),
    }).eq('id', id);

    console.log(`[insights] insights saved to DB — next open will be a cache hit`);
    return res.json({ data: insights, cached: false });
  } catch (error) {
    // AI call failed — fall back to stale cached insights if available, otherwise return null
    console.error('AI completion error:', error);
    try {
      const supabase = req.supabase!;
      const { data: contact } = await supabase
        .from('contacts')
        .select('ai_insights')
        .eq('id', req.params.id)
        .is('deleted_at', null)
        .single();
      if (contact?.ai_insights) {
        console.log(`[insights] AI failed — returning stale cached insights`);
        return res.json({ data: contact.ai_insights, cached: true, stale: true });
      }
    } catch (_) {}
    return res.json({ data: null });
  }
});

// GET /api/contacts/:id/events
// Returns distinct events this contact has been linked to (via interactions OR contact_events).
router.get('/:id/events', async (req, res, next) => {
  try {
    const supabase = req.supabase!;
    // Verify contact ownership first.
    const { data: contactCheck } = await supabase
      .from('contacts').select('id').eq('id', req.params.id).eq('user_id', req.user!.id).is('deleted_at', null).maybeSingle();
    if (!contactCheck) return res.status(403).json({ error: 'Forbidden' });

    const [interactionsRes, contactEventsRes] = await Promise.all([
      supabase.from('interactions').select('event:events(*)').eq('contact_id', req.params.id).not('event_id', 'is', null).is('deleted_at', null),
      supabase.from('contact_events').select('event:events(*)').eq('contact_id', req.params.id).is('deleted_at', null),
    ]);

    if (interactionsRes.error) throw interactionsRes.error;

    // event:events(*) is a left join and can't filter the embedded row's deleted_at
    // inline; drop soft-deleted events here instead.
    const seen = new Set<string>();
    const events = [
      ...(interactionsRes.data || []).map((r: any) => r.event),
      ...(contactEventsRes.data || []).map((r: any) => r.event),
    ].filter((e: any) => e && e.deleted_at == null && !seen.has(e.id) && seen.add(e.id));

    res.json({ data: events });
  } catch (error) {
    next(error);
  }
});

// POST /api/contacts/:id/events
// Links contact to an event by creating an event_link interaction.
// Body: { event_id: string }
router.post('/:id/events', async (req, res, next) => {
  try {
    const supabase = req.supabase!;
    const parsed = z.object({ event_id: uuidSchema }).safeParse(req.body);
    if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });
    const { event_id } = parsed.data;

    // Verify contact ownership.
    const { data: contactCheck } = await supabase
      .from('contacts').select('id').eq('id', req.params.id).eq('user_id', req.user!.id).is('deleted_at', null).maybeSingle();
    if (!contactCheck) return res.status(403).json({ error: 'Forbidden' });

    // Verify the body-supplied event is also owned by the caller — RLS on
    // `interactions` only checks the new row's user_id, not the foreign event_id,
    // so without this a user could link their contact to another tenant's event.
    const { data: eventCheck } = await supabase
      .from('events').select('id').eq('id', event_id).eq('user_id', req.user!.id).is('deleted_at', null).maybeSingle();
    if (!eventCheck) return res.status(403).json({ error: 'Forbidden' });

    // Upsert: if already linked via event_link interaction, skip.
    const { data: existing } = await supabase
      .from('interactions')
      .select('id')
      .eq('contact_id', req.params.id)
      .eq('event_id', event_id)
      .eq('interaction_type', 'event_link')
      .is('deleted_at', null)
      .maybeSingle();

    if (existing) return res.json({ data: existing, already_linked: true });

    const { data, error } = await supabase
      .from('interactions')
      .insert({
        contact_id: req.params.id,
        event_id,
        interaction_type: 'event_link',
        interaction_date: new Date().toISOString(),
        summary: 'Contact linked to event',
        user_id: req.user!.id,
      })
      .select()
      .single();

    if (error) throw error;
    res.json({ data });
  } catch (error) {
    next(error);
  }
});

// DELETE /api/contacts/:id/events/:event_id
// Unlinks a contact from an event (removes event_link interaction).
router.delete('/:id/events/:event_id', async (req, res, next) => {
  try {
    const supabase = req.supabase!;
    // Verify contact ownership.
    const { data: contactCheck } = await supabase
      .from('contacts').select('id').eq('id', req.params.id).eq('user_id', req.user!.id).is('deleted_at', null).maybeSingle();
    if (!contactCheck) return res.status(403).json({ error: 'Forbidden' });

    const { error } = await supabase
      .from('interactions')
      .update({ deleted_at: new Date().toISOString() })
      .eq('contact_id', req.params.id)
      .eq('event_id', req.params.event_id)
      .eq('interaction_type', 'event_link');

    if (error) throw error;
    res.json({ message: 'Unlinked successfully' });
  } catch (error) {
    next(error);
  }
});

export default router;
