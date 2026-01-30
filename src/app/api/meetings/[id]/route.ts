import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';

export async function GET(
    request: NextRequest,
    { params }: { params: { id: string } }
) {
    try {
        const supabase = createClient();
        const { id } = params;

        // Fetch meeting brief with all related data
        const { data: meeting, error } = await supabase
            .from('meeting_briefs')
            .select(`
                *,
                contact:contacts(*,company:companies(*)),
                company:companies(*),
                event:events(*)
            `)
            .eq('id', id)
            .single();

        if (error || !meeting) {
            return NextResponse.json(
                { error: 'Meeting not found' },
                { status: 404 }
            );
        }

        // Fetch interaction history
        const { data: interactions } = await supabase
            .from('interactions')
            .select('*')
            .eq('contact_id', meeting.contact_id)
            .order('interaction_date', { ascending: false });

        // Fetch reminders for this meeting
        const { data: reminders } = await supabase
            .from('reminders')
            .select('*')
            .eq('meeting_brief_id', id)
            .order('reminder_date', { ascending: true });

        return NextResponse.json({
            meeting,
            interactions: interactions || [],
            reminders: reminders || [],
        });
    } catch (error) {
        console.error('Fetch meeting error:', error);
        return NextResponse.json(
            { error: 'Failed to fetch meeting' },
            { status: 500 }
        );
    }
}

export async function PATCH(
    request: NextRequest,
    { params }: { params: { id: string } }
) {
    try {
        const supabase = createClient();
        const { id } = params;
        const updates = await request.json();

        // Update meeting brief
        const { data: meeting, error } = await supabase
            .from('meeting_briefs')
            .update(updates)
            .eq('id', id)
            .select()
            .single();

        if (error) {
            throw error;
        }

        return NextResponse.json({ meeting });
    } catch (error) {
        console.error('Update meeting error:', error);
        return NextResponse.json(
            { error: 'Failed to update meeting' },
            { status: 500 }
        );
    }
}

export async function DELETE(
    request: NextRequest,
    { params }: { params: { id: string } }
) {
    try {
        const supabase = createClient();
        const { id } = params;

        const { error } = await supabase
            .from('meeting_briefs')
            .delete()
            .eq('id', id);

        if (error) {
            throw error;
        }

        return NextResponse.json({ success: true });
    } catch (error) {
        console.error('Delete meeting error:', error);
        return NextResponse.json(
            { error: 'Failed to delete meeting' },
            { status: 500 }
        );
    }
}
