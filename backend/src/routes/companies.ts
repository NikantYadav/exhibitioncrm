import { Router } from 'express';
import { z } from 'zod';
import { supabaseAdmin as supabase } from '../config/supabase';
import { LiteLLMService } from '../services/litellm-service';
import { TavilyService } from '../services/tavily-service';

const uuidSchema = z.string().uuid();
const optText = (max: number) => z.string().trim().max(max).optional().or(z.literal(''));

const companyWriteSchema = z.object({
  name: z.string().trim().min(1).max(200),
  industry: optText(150),
  description: optText(2000),
  headquarters: optText(200),
  employee_count: optText(50),
  founded_year: optText(10),
  linkedin_url: z.string().url().max(500).optional().or(z.literal('')),
  ticker_symbol: optText(20),
  products_services: optText(2000),
  website: z.string().url().max(500).optional().or(z.literal('')),
});

const companyPatchSchema = companyWriteSchema.partial();

const router = Router();

router.get('/', async (req, res, next) => {
  try {
    const { search, q } = req.query;
    const searchTerm = q || search;

    let query = supabase
      .from('companies')
      .select('id, name, industry')
      .not('name', 'ilike', 'independent')
      .order('name', { ascending: true });

    if (searchTerm) {
      query = query.ilike('name', `%${searchTerm}%`);
    }

    const { data, error } = await query.limit(20);

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    res.json({ data: data || [] });
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch companies' });
  }
});

router.get('/:id', async (req, res, next) => {
  try {
    const { data, error } = await supabase
      .from('companies')
      .select('*')
      .eq('id', req.params.id)
      .single();

    if (error) {
      return res.status(400).json({ error: error.message });
    }

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
    const { force } = z.object({ force: z.boolean().optional() }).parse(req.body);

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
    console.log(`[enrich] "${companyName}" — running Tavily + AI enrichment`);

    // Run Tavily searches in parallel
    const [overviewResults, detailResults] = await Promise.all([
      TavilyService.search(`${companyName} company overview headquarters employees founded`, { maxResults: 4, searchDepth: 'advanced' }),
      TavilyService.search(`${companyName}${industry ? ` ${industry}` : ''} company size LinkedIn stock ticker`, { maxResults: 3, searchDepth: 'basic' }),
    ]);
    const webContext = TavilyService.formatForPrompt([...overviewResults, ...detailResults]);

    const prompt = `You are extracting factual company profile data for "${companyName}".

${webContext ? `Web research:\n${webContext}\n\n` : ''}Extract and return ONLY a JSON object with these fields (use null for unknown):
{
  "headquarters": "City, Country or null",
  "employee_count": "e.g. 10,000-50,000 or null",
  "founded_year": "e.g. 1984 or null",
  "linkedin_url": "full LinkedIn company URL or null",
  "ticker_symbol": "e.g. CSCO or null",
  "description": "1-2 sentence company description or null",
  "industry": "primary industry or null",
  "products_services": "brief summary of main products/services or null"
}
Return only valid JSON, no markdown.`;

    const llm = new LiteLLMService();
    const raw = await llm.generateCompletion([{ role: 'user', content: prompt }], { temperature: 0.2, jsonMode: true });
    const enriched = llm.cleanAndParseJSON<any>(raw);

    const updates: any = {
      enriched_at: new Date().toISOString(),
      enrichment_failed: false,
    };
    if (enriched.headquarters) updates.headquarters = enriched.headquarters;
    if (enriched.employee_count) updates.employee_count = enriched.employee_count;
    if (enriched.founded_year) updates.founded_year = String(enriched.founded_year);
    if (enriched.linkedin_url) updates.linkedin_url = enriched.linkedin_url;
    if (enriched.ticker_symbol) updates.ticker_symbol = enriched.ticker_symbol;
    if (enriched.description && !company.description) updates.description = enriched.description;
    if (enriched.industry && !company.industry) updates.industry = enriched.industry;
    if (enriched.products_services && !company.products_services) updates.products_services = enriched.products_services;

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

// POST /api/companies/:id/briefing
// Generates AI talking points, saves to DB, returns them.
router.post('/:id/briefing', async (req, res, next) => {
  try {
    const parsedId = uuidSchema.safeParse(req.params.id);
    if (!parsedId.success) return res.status(400).json({ error: 'Invalid company id' });

    const { id } = req.params;
    const bodyParsed = z.object({ notes: z.string().trim().max(5000).optional() }).safeParse(req.body);
    if (!bodyParsed.success) return res.status(400).json({ error: bodyParsed.error.flatten() });
    const { notes } = bodyParsed.data;
    const { data: company, error } = await supabase
      .from('companies')
      .select('*')
      .eq('id', id)
      .single();

    if (error) throw error;

    const companyName = company.name || 'Unknown Company';
    const industry = company.industry || '';
    const description = company.description || '';
    const headquarters = company.headquarters || '';
    const employeeCount = company.employee_count || '';

    console.log(`[briefing] → running Tavily search for company: "${companyName}"`);
    const [newsResults, overviewResults] = await Promise.all([
      TavilyService.search(`${companyName} latest news 2025`, { maxResults: 3, searchDepth: 'basic' }),
      TavilyService.search(`${companyName}${industry ? ` ${industry}` : ''} company products services strategy`, { maxResults: 3, searchDepth: 'basic' }),
    ]);
    const webContext = TavilyService.formatForPrompt([...overviewResults, ...newsResults]);

    let companyContext = `${companyName}${industry ? ` (${industry})` : ''}`;
    if (description) companyContext += `. ${description}`;
    if (headquarters) companyContext += `. HQ: ${headquarters}`;
    if (employeeCount) companyContext += `. Size: ${employeeCount} employees`;

    let prompt = `Generate 4 concise, specific talking points for a business networking conversation with someone from ${companyContext}.`;
    if (webContext) {
      prompt += `\n\nUse the following real-time web research to make the talking points current and specific:\n\n${webContext}`;
    }
    if (notes && notes.trim().length > 0) {
      prompt += `\n\nAlso take into account the following personal notes about this company when crafting the talking points:\n\n${notes.trim()}`;
    }
    prompt += `\n\nFormat: one talking point per line, no bullet points or numbering, plain text only.`;

    const llm = new LiteLLMService();
    const talkingPointsText = await llm.generateCompletion([{ role: 'user', content: prompt }]);
    const talkingPoints = talkingPointsText.split('\n').filter(s => s.trim().length > 0).map(s => s.trim());

    // Save talking points to DB
    await supabase.from('companies').update({ talking_points: talkingPoints }).eq('id', id);

    res.json({ data: { talking_points: talkingPoints } });
  } catch (error) {
    next(error);
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
