import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { CompanyResearchService } from '@/lib/services/company-research';

export async function POST(request: NextRequest) {
    try {
        const supabase = createClient();

        // Check authentication
        const { data: { user }, error: authError } = await supabase.auth.getUser();
        if (authError || !user) {
            return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
        }

        const { companyId, forceRefresh } = await request.json();

        if (!companyId) {
            return NextResponse.json(
                { error: 'Company ID is required' },
                { status: 400 }
            );
        }

        // Fetch company data
        const { data: company, error: companyError } = await supabase
            .from('companies')
            .select('*')
            .eq('id', companyId)
            .single();

        if (companyError || !company) {
            return NextResponse.json(
                { error: 'Company not found' },
                { status: 404 }
            );
        }

        // Check for cached research (unless force refresh)
        if (!forceRefresh) {
            const { data: cachedResearch } = await supabase
                .from('company_research')
                .select('*')
                .eq('company_id', companyId)
                .eq('research_type', 'overview')
                .single();

            if (cachedResearch && CompanyResearchService.isCacheValid(new Date(cachedResearch.created_at))) {
                return NextResponse.json({
                    research: cachedResearch.research_data,
                    cached: true,
                    cachedAt: cachedResearch.created_at,
                });
            }
        }

        // Perform AI research
        const research = await CompanyResearchService.researchCompany({
            name: company.name,
            website: company.website || undefined,
            industry: company.industry || undefined,
            description: company.description || undefined,
        });

        // Cache the research results
        const expiresAt = new Date();
        expiresAt.setHours(expiresAt.getHours() + 24); // 24 hour cache

        const { error: cacheError } = await supabase
            .from('company_research')
            .upsert({
                company_id: companyId,
                research_type: 'overview',
                research_data: research,
                sources: research.sources,
                confidence_score: research.confidence,
                expires_at: expiresAt.toISOString(),
            }, {
                onConflict: 'company_id,research_type',
            });

        if (cacheError) {
            console.error('Failed to cache research:', cacheError);
        }

        // Update company with enriched data
        const { error: updateError } = await supabase
            .from('companies')
            .update({
                industry: research.industry || company.industry,
                description: research.overview || company.description,
                is_enriched: true,
                enrichment_confidence: research.confidence,
            })
            .eq('id', companyId);

        if (updateError) {
            console.error('Failed to update company:', updateError);
        }

        return NextResponse.json({
            research,
            cached: false,
        });
    } catch (error) {
        console.error('Company research error:', error);
        return NextResponse.json(
            { error: 'Failed to research company' },
            { status: 500 }
        );
    }
}
