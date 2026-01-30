import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';

export async function GET(request: NextRequest) {
    try {
        const supabase = createClient();

        const searchParams = request.nextUrl.searchParams;
        const status = searchParams.get('status') || 'pending';
        const limit = parseInt(searchParams.get('limit') || '50');

        // Fetch reminders
        const { data: reminders, error } = await supabase
            .from('reminders')
            .select(`
                *,
                contact:contacts(*),
                meeting_brief:meeting_briefs(*)
            `)
            .eq('status', status)
            .order('reminder_date', { ascending: true })
            .limit(limit);

        if (error) {
            throw error;
        }

        return NextResponse.json({ reminders });
    } catch (error) {
        console.error('Fetch reminders error:', error);
        return NextResponse.json(
            { error: 'Failed to fetch reminders' },
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
            event_id,
            meeting_brief_id,
            reminder_type,
            reminder_date,
            title,
            message,
            priority,
        } = body;

        if (!reminder_type || !reminder_date || !title) {
            return NextResponse.json(
                { error: 'Reminder type, date, and title are required' },
                { status: 400 }
            );
        }

        // Create reminder
        const { data: reminder, error: insertError } = await supabase
            .from('reminders')
            .insert({
                contact_id,
                event_id,
                meeting_brief_id,
                reminder_type,
                reminder_date,
                title,
                message,
                priority: priority || 'medium',
                status: 'pending',
            })
            .select()
            .single();

        if (insertError) {
            throw insertError;
        }

        return NextResponse.json({ reminder }, { status: 201 });
    } catch (error) {
        console.error('Create reminder error:', error);
        return NextResponse.json(
            { error: 'Failed to create reminder' },
            { status: 500 }
        );
    }
}

export async function PATCH(request: NextRequest) {
    try {
        const supabase = createClient();

        const { id, status, snoozed_until } = await request.json();

        if (!id) {
            return NextResponse.json(
                { error: 'Reminder ID is required' },
                { status: 400 }
            );
        }

        const updates: any = {};
        if (status) updates.status = status;
        if (snoozed_until) updates.snoozed_until = snoozed_until;
        if (status === 'sent') updates.sent_at = new Date().toISOString();

        // Update reminder
        const { data: reminder, error } = await supabase
            .from('reminders')
            .update(updates)
            .eq('id', id)
            .select()
            .single();

        if (error) {
            throw error;
        }

        return NextResponse.json({ reminder });
    } catch (error) {
        console.error('Update reminder error:', error);
        return NextResponse.json(
            { error: 'Failed to update reminder' },
            { status: 500 }
        );
    }
}

export async function DELETE(request: NextRequest) {
    try {
        const supabase = createClient();

        const { searchParams } = request.nextUrl;
        const id = searchParams.get('id');

        if (!id) {
            return NextResponse.json(
                { error: 'Reminder ID is required' },
                { status: 400 }
            );
        }

        const { error } = await supabase
            .from('reminders')
            .delete()
            .eq('id', id);

        if (error) {
            throw error;
        }

        return NextResponse.json({ success: true });
    } catch (error) {
        console.error('Delete reminder error:', error);
        return NextResponse.json(
            { error: 'Failed to delete reminder' },
            { status: 500 }
        );
    }
}
