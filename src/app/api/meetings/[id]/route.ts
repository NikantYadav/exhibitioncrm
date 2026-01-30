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
            .select('*, event:events(*)')
            .eq('contact_id', meeting.contact_id)
            .order('interaction_date', { ascending: false });

        // Find the original capture event for this contact
        const captureInteraction = interactions?.find(i => i.interaction_type === 'capture' && i.event);
        if (captureInteraction && !meeting.event) {
            meeting.event = captureInteraction.event;
        }

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

        // 1. Fetch current meeting first to check original time
        const { data: currentMeeting, error: fetchError } = await supabase
            .from('meeting_briefs')
            .select('*')
            .eq('id', id)
            .single();

        if (fetchError || !currentMeeting) {
            return NextResponse.json({ error: 'Meeting not found' }, { status: 404 });
        }

        const finalUpdates = { ...updates };
        let completionDate = new Date().toISOString(); // Default to now for logging

        // 2. Apply smart date logic if completing
        if (updates.status === 'completed' && currentMeeting.status !== 'completed') {
            const scheduledDate = new Date(currentMeeting.meeting_date);
            const now = new Date();

            // Only update time if completing BEFORE scheduled time
            if (now < scheduledDate) {
                finalUpdates.meeting_date = now.toISOString();
                completionDate = now.toISOString();
            } else {
                // Otherwise keep the original scheduled time
                completionDate = currentMeeting.meeting_date;
            }
        }

        // 3. Update meeting brief
        const { data: meeting, error } = await supabase
            .from('meeting_briefs')
            .update(finalUpdates)
            .eq('id', id)
            .select()
            .single();

        if (error) throw error;

        // 4. Log interaction if completed
        if (updates.status === 'completed' && currentMeeting.status !== 'completed') {
            const humanMeetingType = (meeting.meeting_type || 'in_person')
                .replace(/_/g, ' ')
                .split(' ')
                .map((w: string) => w.charAt(0).toUpperCase() + w.slice(1))
                .join(' ');

            await supabase
                .from('interactions')
                .insert({
                    contact_id: meeting.contact_id,
                    interaction_type: 'meeting',
                    summary: `Completed meeting: ${humanMeetingType}`,
                    interaction_date: completionDate, // Log with the effective meeting time
                    details: {
                        meeting_id: meeting.id,
                        notes: updates.post_meeting_notes || meeting.post_meeting_notes
                    }
                });
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
