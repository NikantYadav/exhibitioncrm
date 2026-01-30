import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

export async function GET(request: NextRequest) {
    try {
        const supabase = createClient();
        const { searchParams } = new URL(request.url);
        const eventId = searchParams.get('event_id');
        const status = searchParams.get('status');

        let query;

        if (eventId) {
            // Filter contacts who have interactions at this event
            query = supabase
                .from('contacts')
                .select(`
                    *,
                    company:companies(*),
                    interactions!inner(id, event_id, interaction_type),
                    email_drafts(*)
                `)
                .eq('interactions.event_id', eventId);
        } else {
            query = supabase
                .from('contacts')
                .select(`
                    *,
                    company:companies(*),
                    interactions(id, interaction_type, event_id),
                    email_drafts(*)
                `);
        }

        const { data: contacts, error } = await query.order('created_at', { ascending: false });

        if (error) {
            return NextResponse.json({ error: error.message }, { status: 400 });
        }

        // Categorize contacts by follow-up status
        const categorized = {
            not_contacted: [] as any[],
            followed_up: [] as any[],
            needs_followup: [] as any[]
        };

        contacts?.forEach(contact => {
            const drafts = contact.email_drafts || [];
            const sentDrafts = drafts.filter((d: any) =>
                d.status === 'sent' && (!eventId || d.event_id === eventId)
            );
            const interactionCount = (contact.interactions as any[])?.length || 0;

            // Priority:
            // 1. Explicitly set follow_up_status
            // 2. Data-driven derivation (if follow_up_status is null)

            if (contact.follow_up_status) {
                if (contact.follow_up_status === 'followed_up') categorized.followed_up.push(contact);
                else if (contact.follow_up_status === 'needs_followup') categorized.needs_followup.push(contact);
                else categorized.not_contacted.push(contact);
            } else if (sentDrafts.length > 0) {
                categorized.followed_up.push(contact);
            } else if (interactionCount > 0) {
                categorized.needs_followup.push(contact);
            } else {
                categorized.not_contacted.push(contact);
            }
        });

        return NextResponse.json({ data: categorized });
    } catch (error) {
        return NextResponse.json(
            { error: 'Failed to fetch follow-ups' },
            { status: 500 }
        );
    }
}

export async function POST(request: NextRequest) {
    try {
        const supabase = createClient();
        const body = await request.json();

        // Create or update follow-up status
        const { data, error } = await supabase
            .from('interactions')
            .insert({
                contact_id: body.contact_id,
                interaction_type: 'email',
                interaction_date: new Date().toISOString(),
                summary: body.summary || 'Follow-up email',
                details: body.details
            })
            .select()
            .single();

        if (error) {
            return NextResponse.json({ error: error.message }, { status: 400 });
        }

        return NextResponse.json({ data });
    } catch (error) {
        return NextResponse.json(
            { error: 'Failed to create follow-up' },
            { status: 500 }
        );
    }
}
