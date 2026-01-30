import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { PrepService } from '@/lib/services/prep-service';

export async function POST(
    request: NextRequest,
    { params }: { params: { id: string } }
) {
    try {
        const supabase = createClient();
        const { id } = params;

        // 1. Fetch meeting info
        const { data: meeting, error: meetingError } = await supabase
            .from('meeting_briefs')
            .select('*, contact:contacts(*, company:companies(*))')
            .eq('id', id)
            .single();

        if (meetingError || !meeting) {
            return NextResponse.json({ error: 'Meeting not found' }, { status: 404 });
        }

        // 2. Fetch interaction history for this contact
        const { data: interactions } = await supabase
            .from('interactions')
            .select('*')
            .eq('contact_id', meeting.contact_id)
            .order('interaction_date', { ascending: false })
            .limit(10);

        // 3. Fetch notes for this contact
        const { data: notes } = await supabase
            .from('notes')
            .select('*')
            .eq('contact_id', meeting.contact_id)
            .order('created_at', { ascending: false })
            .limit(10);

        // 4. Generate prep data using AI
        const prepData = await PrepService.generateMeetingContext(
            meeting.contact,
            interactions || [],
            notes || [],
            meeting.pre_meeting_notes
        );

        // 4. Update the meeting brief with this data
        // We also update ai_talking_points and interaction_summary for backward compatibility
        const { error: updateError } = await supabase
            .from('meeting_briefs')
            .update({
                prep_data: prepData,
                ai_talking_points: prepData.key_talking_points.join('\n'),
                interaction_summary: prepData.relationship_summary
            })
            .eq('id', id);

        if (updateError) {
            throw updateError;
        }

        return NextResponse.json({ prep_data: prepData });
    } catch (error) {
        console.error('Meeting prep generation error:', error);
        return NextResponse.json(
            { error: 'Failed to generate meeting intelligence' },
            { status: 500 }
        );
    }
}
