import { Router } from 'express';
import { z } from 'zod';
import { supabaseAdmin as supabase } from '../config/supabase';
import { LiteLLMService } from '../services/litellm-service';
import { ExaService } from '../services/exa-service';
import { requireAuth } from '../middleware/requireAuth';
import { checkScopedRateLimit } from '../utils/rateLimit';

const uuidSchema = z.string().uuid();
const optText = (max: number) => z.string().trim().max(max).optional().or(z.literal(''));

// Fields set on create — name + industry required, location/website optional hints for AI
const companyWriteSchema = z.object({
  name: z.string().trim().min(1).max(200),
  industry: z.string().trim().min(1, { message: 'Industry is required' }).max(150),
  location: optText(200),
  website: z.string().url().max(500).optional().or(z.literal('')),
});

// Only user-supplied context fields are patchable — AI-owned fields
// (name, industry, description, products_services, headquarters, etc.)
// are written exclusively by the enrich endpoint, never by the client.
const companyPatchSchema = z.object({
  location: optText(200),
  website: z.string().url().max(500).optional().or(z.literal('')),
  industry: optText(150), // allowed as a re-research hint; AI will overwrite on next enrich
});

// AI enrichment: 10 enrichments per user per hour
const ENRICH_SCOPE = 'company_enrich';
const ENRICH_MAX = 10;
const ENRICH_WINDOW_MS = 60 * 60 * 1000;

const router = Router();

// All company routes require a valid session
router.use(requireAuth);

router.get('/', async (req, res, next) => {
  try {
    const parsed = z.object({ q: z.string().trim().max(200).optional(), search: z.string().trim().max(200).optional() }).safeParse(req.query);
    if (!parsed.success) return res.status(400).json({ error: 'Invalid query parameters' });
    const searchTerm = parsed.data.q ?? parsed.data.search;

    let query = supabase
      .from('companies')
      .select('id, name, industry')
      .not('name', 'ilike', 'independent')
      .order('name', { ascending: true });

    if (searchTerm) {
      query = query.ilike('name', `%${searchTerm}%`);
    }

    const { data, error } = await query.limit(20);

    if (error) return res.status(400).json({ error: error.message });

    res.json({ data: data || [] });
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch companies' });
  }
});

router.get('/:id', async (req, res, next) => {
  try {
    const parsedId = uuidSchema.safeParse(req.params.id);
    if (!parsedId.success) return res.status(400).json({ error: 'Invalid company id' });

    const { data, error } = await supabase
      .from('companies')
      .select('*')
      .eq('id', parsedId.data)
      .single();

    if (error) return res.status(404).json({ error: 'Company not found' });

    res.json({ data });
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch company' });
  }
});

// POST /api/companies/:id/enrich
// Auto-enriches company profile with HQ, employee count, founded year, etc.
// Called on first open of company detail page. Skips if already enriched.
router.post('/:id/enrich', async (req, res, next) => {
  try {
    const parsedId = uuidSchema.safeParse(req.params.id);
    if (!parsedId.success) return res.status(400).json({ error: 'Invalid company id' });

    const { id } = req.params;
    const bodyParsed = z.object({ force: z.boolean().optional() }).safeParse(req.body ?? {});
    if (!bodyParsed.success) return res.status(400).json({ error: 'Invalid request body' });
    const { force } = bodyParsed.data;

    const rl = await checkScopedRateLimit(req.user!.id, ENRICH_SCOPE, ENRICH_MAX, ENRICH_WINDOW_MS);
    if (!rl.ok) return res.status(429).json({ error: `Too many enrichment requests. Try again in ${rl.retryAfterSeconds}s.` });

    const { data: company, error } = await supabase
      .from('companies')
      .select('*')
      .eq('id', id)
      .single();

    if (error || !company) return res.status(404).json({ error: 'Company not found' });

    // Skip if already enriched (unless forced)
    if (!force && company.enriched_at && !company.enrichment_failed) {
      return res.json({ data: company, cached: true });
    }

    const companyName = company.name || 'Unknown Company';
    const industry = company.industry || '';
    const location = company.location || '';
    const website = company.website || '';
    console.log(`[enrich] "${companyName}" — running Exa + AI enrichment`);

    // Build disambiguated search queries using any known context
    const disambig = [industry, location].filter(Boolean).join(' ');
    let websiteClue = '';
    if (website) {
      try { websiteClue = ` site:${new URL(website).hostname}`; } catch { /* invalid URL, skip */ }
    }
    const [overviewResults, detailResults] = await Promise.all([
      ExaService.search(`${companyName}${disambig ? ` ${disambig}` : ''} company overview headquarters employees founded${websiteClue}`, { maxResults: 5, searchDepth: 'advanced', category: 'company' }),
      ExaService.search(`${companyName}${disambig ? ` ${disambig}` : ''} company size LinkedIn stock ticker`, { maxResults: 5, searchDepth: 'basic', category: 'company' }),
    ]);
    const webContext = ExaService.formatForPrompt([...overviewResults, ...detailResults]);

    const knownContext = [
      industry && `Industry: ${industry}`,
      location && `Location/Country: ${location}`,
      website && `Website: ${website}`,
    ].filter(Boolean).join('\n');

    const prompt = `You are extracting factual company profile data for "${companyName}".
${knownContext ? `\nKnown details about this company:\n${knownContext}\n` : ''}
IMPORTANT: Only extract data that matches a company named "${companyName}"${location ? ` based in or associated with ${location}` : ''}${industry ? ` in the ${industry} industry` : ''}. If the web research appears to describe a different company (wrong country, wrong industry, or clearly a different entity), return all fields as null and set match_confidence to "low". Do not invent or hallucinate details.

${webContext ? `Web research:\n${webContext}\n\n` : ''}Extract and return ONLY a JSON object with these fields (use null for unknown):
{
  "match_confidence": "high | medium | low",
  "name": "official company name with correct capitalisation, or null if uncertain",
  "industry": "primary industry (specific, e.g. 'Insurance Brokerage' not just 'Finance') or null",
  "headquarters": "City, Country or null",
  "employee_count": "e.g. 10,000-50,000 or null",
  "founded_year": "e.g. 1984 or null",
  "linkedin_url": "full LinkedIn company URL or null",
  "ticker_symbol": "e.g. CSCO or null",
  "description": "1-2 sentence company description or null",
  "products_services": "brief summary of main products/services or null"
}
Return only valid JSON, no markdown.`;

    const llm = new LiteLLMService();
    const raw = await llm.generateCompletion([{ role: 'user', content: prompt }], { temperature: 0.2, jsonMode: true });
    const enriched = llm.cleanAndParseJSON<any>(raw);

    const matchConfidence: string = enriched.match_confidence || 'medium';
    const updates: any = {
      enriched_at: new Date().toISOString(),
      enrichment_failed: false,
      enrichment_confidence: matchConfidence,
    };
    // Only write AI-generated fields when confidence is not low
    if (matchConfidence !== 'low') {
      if (enriched.headquarters) updates.headquarters = enriched.headquarters;
      if (enriched.employee_count) updates.employee_count = enriched.employee_count;
      if (enriched.founded_year) updates.founded_year = String(enriched.founded_year);
      if (enriched.linkedin_url) updates.linkedin_url = enriched.linkedin_url;
      if (enriched.ticker_symbol) updates.ticker_symbol = enriched.ticker_symbol;
      // AI always owns these fields — user input is search context only
      if (enriched.name) updates.name = enriched.name;
      if (enriched.description) updates.description = enriched.description;
      if (enriched.industry) updates.industry = enriched.industry;
      if (enriched.products_services) updates.products_services = enriched.products_services;
    }

    const { data: updated, error: updateError } = await supabase
      .from('companies')
      .update(updates)
      .eq('id', id)
      .select()
      .single();

    if (updateError) throw updateError;

    console.log(`[enrich] "${companyName}" — enrichment saved`);
    res.json({ data: updated, cached: false });
  } catch (error) {
    console.error('[enrich] failed:', error);
    // Mark as failed so next open retries
    await supabase.from('companies').update({ enrichment_failed: true }).eq('id', req.params.id);
    res.status(500).json({ error: 'Failed to enrich company profile. Will retry on next visit.' });
  }
});

router.post('/', async (req, res, next) => {
  try {
    const parsed = companyWriteSchema.safeParse(req.body);
    if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });

    const { data, error } = await supabase
      .from('companies')
      .insert(parsed.data)
      .select()
      .single();

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    res.json({ data });
  } catch (error) {
    res.status(500).json({ error: 'Failed to create company' });
  }
});

router.patch('/:id', async (req, res, next) => {
  try {
    const parsedId = uuidSchema.safeParse(req.params.id);
    if (!parsedId.success) return res.status(400).json({ error: 'Invalid company id' });

    const parsed = companyPatchSchema.safeParse(req.body);
    if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });

    const { data, error } = await supabase
      .from('companies')
      .update(parsed.data)
      .eq('id', req.params.id)
      .select()
      .single();

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    res.json({ data });
  } catch (error) {
    res.status(500).json({ error: 'Failed to update company' });
  }
});

export default router;
