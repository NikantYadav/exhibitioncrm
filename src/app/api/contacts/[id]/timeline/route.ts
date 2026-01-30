import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';

export async function GET(
    request: NextRequest,
    { params }: { params: { id: string } }
) {
    try {
        const supabase = createClient();
        const { id } = params;
        const { searchParams } = new URL(request.url);
        const type = searchParams.get('type'); // filter by interaction type

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

        if (error) {
            return NextResponse.json({ error: error.message }, { status: 400 });
        }

        // Fetch notes if applicable
        let notes: any[] = [];
        if (!type || type === 'all' || type === 'note') {
            const { data: notesData } = await supabase
                .from('notes')
                .select('*')
                .eq('contact_id', id)
                .order('created_at', { ascending: false });
            notes = notesData || [];
        }

        // Fetch meeting briefs if applicable
        let meetings: any[] = [];
        if (!type || type === 'all' || type === 'meeting') {
            const { data: meetingsData } = await supabase
                .from('meeting_briefs')
                .select('*, event:events(*)')
                .eq('contact_id', id)
                .order('meeting_date', { ascending: false });
            meetings = meetingsData || [];
        }

        // Fetch captures for this contact to fill in missing image_urls
        const { data: captures } = await supabase
            .from('captures')
            .select('*')
            .eq('contact_id', id)
            .order('created_at', { ascending: false });

        // Filter out interactions that are duplicates of meeting briefs
        const meetingIds = new Set(meetings.map(m => m.id));
        const filteredInteractions = (interactions || []).filter(i => {
            if (i.interaction_type === 'meeting' && i.details?.meeting_id && meetingIds.has(i.details.meeting_id)) {
                return false;
            }
            return true;
        });

        // Combine and sort by date
        const timeline = [
            ...filteredInteractions.map((i: any) => {
                const item = {
                    ...i,
                    type: 'interaction',
                    date: i.interaction_date
                };

                // Data patching: if it's a capture and missing image_url in details, try to find it in captures table
                if (i.interaction_type === 'capture' && !i.details?.image_url && captures && captures.length > 0) {
                    // Try to find a matching capture by event and date proximity (wider window 30s)
                    let matchingCapture = captures.find((c: any) =>
                        c.event_id === i.event_id &&
                        Math.abs(new Date(c.created_at).getTime() - new Date(i.interaction_date).getTime()) < 30000
                    );

                    // Fallback: if no close match by event/time, just take the most recent capture for this contact
                    // (Most contacts are only captured once anyway)
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

        return NextResponse.json({ data: timeline });
    } catch (error) {
        return NextResponse.json(
            { error: 'Failed to fetch timeline' },
            { status: 500 }
        );
    }
}

export async function POST(
    request: NextRequest,
    { params }: { params: { id: string } }
) {
    try {
        const supabase = createClient();
        const { id } = params;
        const body = await request.json();

        const { data: interaction, error } = await supabase
            .from('interactions')
            .insert({
                contact_id: id,
                ...body
            })
            .select()
            .single();

        if (error) {
            return NextResponse.json({ error: error.message }, { status: 400 });
        }

        return NextResponse.json({ data: interaction });
    } catch (error) {
        return NextResponse.json(
            { error: 'Failed to create interaction' },
            { status: 500 }
        );
    }
}
