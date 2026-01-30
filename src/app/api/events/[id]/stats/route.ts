import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

export async function GET(
    request: NextRequest,
    { params }: { params: { id: string } }
) {
    try {
        const supabase = createClient();
        const { id } = params;
        console.log('Fetching stats for event ID:', id);

        // Get target companies count
        const { data: targetsData, error: targetsError } = await supabase
            .from('target_companies')
            .select('id')
            .eq('event_id', id);
        const targetsCount = targetsData?.length || 0;

        // Get all captures for this event to calculate stats accurately
        const { data: capturesData, error: capturesError } = await supabase
            .from('captures')
            .select('id, contact_id')
            .eq('event_id', id);

        const capturesCount = capturesData?.length || 0;
        // const uniqueContactIds = new Set(capturesData?.map(c => c.contact_id).filter(Boolean) || []); // This is no longer needed

        // Get ALL unique contacts for this event and their follow-up status
        const { data: eventContacts, error: contactsError } = await supabase
            .from('contacts')
            .select('id, follow_up_status, interactions!inner(event_id)')
            .eq('interactions.event_id', id);

        const contactsCount = eventContacts?.length || 0;

        // Calculate breakdown
        const followUpsCount = eventContacts?.filter(c => c.follow_up_status === 'followed_up').length || 0;
        const needsFollowupCount = eventContacts?.filter(c =>
            c.follow_up_status === 'needs_followup' || c.follow_up_status === 'needs_follow_up'
        ).length || 0;
        const notContactedCount = eventContacts?.filter(c => !c.follow_up_status || c.follow_up_status === 'not_contacted').length || 0;

        // We also need to check for sent emails in case follow_up_status isn't updated
        const { data: sentEmails } = await supabase
            .from('email_drafts')
            .select('contact_id')
            .eq('event_id', id)
            .eq('status', 'sent');

        // Adjust followed count if there are sent emails not yet marked in contact status
        const sentEmailContactIds = new Set(sentEmails?.map(e => e.contact_id) || []);
        const actualFollowedCount = new Set([
            ...(eventContacts?.filter(c => c.follow_up_status === 'followed_up').map(c => c.id) || []),
            ...Array.from(sentEmailContactIds)
        ]).size;

        if (targetsError || capturesError || contactsError) {
            console.error('Stats fetch errors:', { targetsError, capturesError, contactsError });
        }

        const stats = {
            targets: targetsCount,
            captures: capturesCount,
            contacts: contactsCount,
            followUps: actualFollowedCount,
            needsFollowup: needsFollowupCount,
            notContacted: notContactedCount
        };

        console.log('Stats calculation finished:', stats);

        return NextResponse.json({ data: stats });
    } catch (error) {
        return NextResponse.json(
            { error: 'Failed to fetch event stats' },
            { status: 500 }
        );
    }
}
