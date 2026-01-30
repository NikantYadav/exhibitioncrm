import { NextRequest, NextResponse } from 'next/server';
import { createServerClient } from '@/lib/supabase/client';

export const dynamic = 'force-dynamic';

export async function GET(
    request: NextRequest,
    { params }: { params: { id: string } }
) {
    try {
        const eventId = params.id;
        const supabase = createServerClient();

        const { data, error } = await supabase
            .from('email_drafts')
            .select(`
                *,
                contacts (
                    *,
                    companies (*)
                )
            `)
            .eq('event_id', eventId)
            .order('created_at', { ascending: false });

        if (error) {
            console.error('Database error fetching drafts:', error);
            throw error;
        }

        console.log(`Fetched ${data?.length || 0} drafts for event ${eventId}`);
        return NextResponse.json({ data });
    } catch (error) {
        console.error('Fetch event emails error:', error);
        return NextResponse.json(
            { error: 'Failed to fetch email drafts' },
            { status: 500 }
        );
    }
}
