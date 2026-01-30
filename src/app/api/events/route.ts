import { NextRequest, NextResponse } from 'next/server';
import { createServerClient } from '@/lib/supabase/client';

export async function GET(request: NextRequest) {
    try {
        const supabase = createServerClient();

        const { data, error } = await supabase
            .from('events')
            .select('*')
            .order('start_date', { ascending: false });

        const now = new Date();
        const updatedData = (data || []).map(event => {
            const start = new Date(event.start_date);
            const end = event.end_date ? new Date(event.end_date) : start;

            // Set end of day for end date comparison
            end.setHours(23, 59, 59, 999);

            let status = 'upcoming';
            if (now >= start && now <= end) {
                status = 'ongoing';
            } else if (now > end) {
                status = 'completed';
            }

            return { ...event, status };
        });

        return NextResponse.json({ data: updatedData });
    } catch (error) {
        console.error('Fetch error:', error);
        return NextResponse.json(
            { error: 'Internal server error' },
            { status: 500 }
        );
    }
}

export async function POST(request: NextRequest) {
    try {
        const body = await request.json();
        const supabase = createServerClient();

        const { data, error } = await supabase
            .from('events')
            .insert({
                name: body.name,
                description: body.description,
                location: body.location,
                start_date: body.start_date,
                end_date: body.end_date,
                event_type: body.event_type || 'exhibition',
                status: body.status || 'upcoming',
            })
            .select()
            .single();

        if (error) {
            return NextResponse.json(
                { error: 'Failed to create event' },
                { status: 500 }
            );
        }

        return NextResponse.json({ data, message: 'Event created successfully' });
    } catch (error) {
        console.error('Create error:', error);
        return NextResponse.json(
            { error: 'Internal server error' },
            { status: 500 }
        );
    }
}
