import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';

export async function POST(
    request: NextRequest,
    { params }: { params: { id: string } }
) {
    try {
        const supabase = createClient();
        const { id } = params;
        const body = await request.json();

        // Simple enrichment - in production, this would call LiteLLM/OpenAI
        // For now, we'll just mark the contact as enriched
        const enrichmentData = {
            is_enriched: true,
            enrichment_confidence: 0.85,
            ...body
        };

        const { data: contact, error } = await supabase
            .from('contacts')
            .update(enrichmentData)
            .eq('id', id)
            .select(`
                *,
                company:companies(*)
            `)
            .single();

        if (error) {
            return NextResponse.json({ error: error.message }, { status: 400 });
        }

        // Log enrichment in queue
        await supabase
            .from('enrichment_queue')
            .insert({
                contact_id: id,
                status: 'completed',
                enrichment_type: 'full',
                result: enrichmentData
            });

        return NextResponse.json({ data: contact });
    } catch (error) {
        return NextResponse.json(
            { error: 'Failed to enrich contact' },
            { status: 500 }
        );
    }
}
