import { NextRequest, NextResponse } from 'next/server';
import { EnrichmentService } from '@/lib/services/enrichment-service';
import { createClient } from '@/lib/supabase/server';

export async function POST(request: NextRequest) {
    try {
        const body = await request.json();
        const { contactId, contactData } = body;

        if (!contactId && !contactData) {
            return NextResponse.json(
                { error: 'Contact ID or contact data required' },
                { status: 400 }
            );
        }

        const supabase = createClient();

        // If contactId provided, fetch contact data
        let dataToEnrich = contactData;
        if (contactId) {
            const { data: contact, error } = await supabase
                .from('contacts')
                .select('*, company:companies(*)')
                .eq('id', contactId)
                .single();

            if (error || !contact) {
                return NextResponse.json(
                    { error: 'Contact not found' },
                    { status: 404 }
                );
            }

            dataToEnrich = {
                name: `${contact.first_name} ${contact.last_name || ''}`.trim(),
                company: contact.company?.name,
                email: contact.email,
                job_title: contact.job_title
            };
        }

        // Run enrichment
        const enrichmentResult = await EnrichmentService.enrichContact(dataToEnrich);

        // If contactId provided, update the contact with suggestions
        if (contactId) {
            await supabase
                .from('contacts')
                .update({
                    enrichment_status: 'completed',
                    enrichment_suggestions: enrichmentResult,
                    enrichment_confidence: enrichmentResult.confidence,
                    last_enriched_at: new Date().toISOString()
                })
                .eq('id', contactId);
        }

        return NextResponse.json({
            success: true,
            enrichment: enrichmentResult
        });
    } catch (error) {
        console.error('Enrichment API error:', error);
        return NextResponse.json(
            { error: 'Failed to enrich contact' },
            { status: 500 }
        );
    }
}
