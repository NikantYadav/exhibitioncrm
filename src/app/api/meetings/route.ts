import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { CompanyResearchService } from '@/lib/services/company-research';

export async function GET(request: NextRequest) {
    try {
        const supabase = createClient();

        const searchParams = request.nextUrl.searchParams;
        const status = searchParams.get('status') || 'scheduled';

        // Fetch meeting briefs
        const { data: meetings, error } = await supabase
            .from('meeting_briefs')
            .select(`
                *,
                contact:contacts(*,company:companies(*)),
                company:companies(*)
            `)
            .eq('status', status)
            .order('meeting_date', { ascending: true });

        if (error) {
            // Handle table not found (missing migration) gracefully
            if (error.code === 'PGRST205') {
                return NextResponse.json({ meetings: [] });
            }
            throw error;
        }

        return NextResponse.json({ meetings });
    } catch (error) {
        console.error('Fetch meetings error:', error);
        return NextResponse.json(
            { error: 'Failed to fetch meetings' },
            { status: 500 }
        );
    }
}

export async function POST(request: NextRequest) {
    try {
        const supabase = createClient();

        const body = await request.json();
        const {
            contact_id,
            company_id,
            event_id,
            meeting_date,
            meeting_type,
            meeting_location,
            pre_meeting_notes,
        } = body;

        if (!contact_id || !meeting_date) {
            return NextResponse.json(
                { error: 'Contact ID and meeting date are required' },
                { status: 400 }
            );
        }

        // Fetch contact and company data for AI generation
        const { data: contact } = await supabase
            .from('contacts')
            .select('*, company:companies(*)')
            .eq('id', contact_id)
            .single();

        // Fetch interaction history
        const { data: interactions } = await supabase
            .from('interactions')
            .select('*')
            .eq('contact_id', contact_id)
            .order('interaction_date', { ascending: false })
            .limit(10);

        // Generate AI talking points
        let aiTalkingPoints = '';
        let interactionSummary = '';

        if (contact) {
            try {
                const talkingPoints = await CompanyResearchService.generateTalkingPoints({
                    name: contact.company?.name || 'Unknown Company',
                    industry: contact.company?.industry,
                    description: contact.company?.description,
                });

                aiTalkingPoints = talkingPoints.join('\n• ');

                // Generate interaction summary
                if (interactions && interactions.length > 0) {
                    interactionSummary = `Previous interactions (${interactions.length}):\n${interactions
                        .slice(0, 5)
                        .map(i => {
                            const type = i.interaction_type
                                .replace(/_/g, ' ')
                                .split(' ')
                                .map((w: string) => w.charAt(0).toUpperCase() + w.slice(1))
                                .join(' ');
                            return `• ${type}: ${i.summary || 'No summary'}`;
                        })
                        .join('\n')}`;
                }
            } catch (error) {
                console.error('AI generation error:', error);
            }
        }

        // Create meeting brief
        const { data: meeting, error: insertError } = await supabase
            .from('meeting_briefs')
            .insert({
                contact_id,
                company_id: company_id || contact?.company_id,
                event_id,
                meeting_date,
                meeting_type: meeting_type || 'in_person',
                meeting_location,
                ai_talking_points: aiTalkingPoints,
                interaction_summary: interactionSummary,
                pre_meeting_notes,
                status: 'scheduled',
            })
            .select()
            .single();

        if (insertError) {
            throw insertError;
        }

        return NextResponse.json({ meeting }, { status: 201 });
    } catch (error) {
        console.error('Create meeting error:', error);
        return NextResponse.json(
            { error: 'Failed to create meeting' },
            { status: 500 }
        );
    }
}
