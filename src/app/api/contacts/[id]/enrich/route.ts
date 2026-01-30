import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { EnrichmentService } from '@/lib/services/enrichment-service';

export async function POST(
    request: NextRequest,
    { params }: { params: { id: string } }
) {
    try {
        const supabase = createClient();
        const { id } = params;

        // 1. Fetch contact with company data
        const { data: contact, error: fetchError } = await supabase
            .from('contacts')
            .select(`
                *,
                company:companies(*)
            `)
            .eq('id', id)
            .single();

        if (fetchError || !contact) {
            return NextResponse.json({ error: fetchError?.message || 'Contact not found' }, { status: 404 });
        }

        // 2. Perform AI Research
        const enrichResult = await EnrichmentService.enrichContact({
            name: `${contact.first_name} ${contact.last_name || ''}`.trim(),
            company: contact.company?.name,
            email: contact.email,
            job_title: contact.job_title
        });

        const body = await request.json().catch(() => ({}));
        if (body.review_only) {
            return NextResponse.json({
                success: true,
                data: {
                    enrichment: enrichResult
                }
            });
        }

        // 3. Update Company data if applicable (Direct update mode)
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

        // 4. Update Contact data (LinkedIn URL)
        if (enrichResult.linkedin_url && !contact.linkedin_url) {
            await supabase
                .from('contacts')
                .update({ linkedin_url: enrichResult.linkedin_url })
                .eq('id', id);
        }

        // 5. Build Enrichment Log
        await supabase
            .from('enrichment_queue')
            .insert({
                contact_id: id,
                company_id: contact.company_id,
                status: 'completed',
                enrichment_type: 'full',
                result: enrichResult
            });

        return NextResponse.json({
            success: true,
            data: {
                ...contact,
                is_enriched: true,
                enrichment: enrichResult
            }
        });
    } catch (error: any) {
        console.error('Enrichment failed:', error);
        return NextResponse.json(
            { error: error?.message || 'Failed to enrich contact' },
            { status: 500 }
        );
    }
}
