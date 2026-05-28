import { Router } from 'express';
import { supabase } from '../config/supabase';

const router = Router();

router.get('/', async (req, res, next) => {
  try {
    const { search } = req.query;

    let query = supabase
      .from('companies')
      .select('*')
      .order('name', { ascending: true });

    if (search) {
      query = query.or(`name.ilike.%${search}%,website.ilike.%${search}%,industry.ilike.%${search}%`);
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

router.post('/', async (req, res, next) => {
  try {
    const { data, error } = await supabase
      .from('companies')
      .insert(req.body)
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
    const { data, error } = await supabase
      .from('companies')
      .update(req.body)
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


// POST /api/companies/research
router.post('/research', async (req, res, next) => {
  try {
    const { companyId, forceRefresh } = req.body;

    if (!companyId) {
      return res.status(400).json({ error: 'Company ID is required' });
    }

    // Fetch company data
    const { data: company, error: companyError } = await supabase
      .from('companies')
      .select('*')
      .eq('id', companyId)
      .single();

    if (companyError || !company) {
      return res.status(404).json({ error: 'Company not found' });
    }

    // Check for cached research
    if (!forceRefresh) {
      const { data: cachedResearch } = await supabase
        .from('company_research')
        .select('*')
        .eq('company_id', companyId)
        .eq('research_type', 'overview')
        .single();

      if (cachedResearch) {
        const cacheAge = Date.now() - new Date(cachedResearch.created_at).getTime();
        if (cacheAge < 24 * 60 * 60 * 1000) { // 24 hours
          return res.json({
            research: cachedResearch.research_data,
            cached: true,
            cachedAt: cachedResearch.created_at,
          });
        }
      }
    }

    // Perform AI research
    const { EnrichmentService } = await import('../services/enrichment-service');
    const research = await EnrichmentService.enrichContact({
      name: company.name,
      company: company.name,
      email: '',
      job_title: ''
    });

    const researchData = {
      industry: research.industry,
      overview: research.description,
      confidence: research.confidence.industry || 0.7,
      sources: ['AI-generated']
    };

    // Cache the research results
    const expiresAt = new Date();
    expiresAt.setHours(expiresAt.getHours() + 24);

    await supabase
      .from('company_research')
      .upsert({
        company_id: companyId,
        research_type: 'overview',
        research_data: researchData,
        sources: researchData.sources,
        confidence_score: researchData.confidence,
        expires_at: expiresAt.toISOString(),
      }, {
        onConflict: 'company_id,research_type',
      });

    // Update company
    await supabase
      .from('companies')
      .update({
        industry: research.industry || company.industry,
        description: research.description || company.description,
        is_enriched: true,
        enrichment_confidence: research.confidence.industry || 0.7,
      })
      .eq('id', companyId);

    res.json({
      research: researchData,
      cached: false,
    });
  } catch (error) {
    console.error('Company research error:', error);
    res.status(500).json({ error: 'Failed to research company' });
  }
});
