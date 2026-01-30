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

        // Get ALL unique contacts for this event (not just card scans)
        const { data: eventContacts } = await supabase
            .from('contacts')
            .select('id, interactions!inner(event_id)')
            .eq('interactions.event_id', id);

        const contactsCount = eventContacts?.length || 0;

        // Get count of contacts who have been followed up for this event
        // Either via a sent email draft OR manually marked as followed_up
        const { data: followedContacts, error: followUpsError } = await supabase
            .from('contacts')
            .select('id, interactions!inner(event_id)')
            .eq('interactions.event_id', id)
            .eq('follow_up_status', 'followed_up');

        // We also need to check for sent emails in case follow_up_status isn't updated
        const { data: sentEmails } = await supabase
            .from('email_drafts')
            .select('contact_id')
            .eq('event_id', id)
            .eq('status', 'sent');

        const followedContactIds = new Set([
            ...(followedContacts?.map(c => c.id) || []),
            ...(sentEmails?.map(e => (e as any).contact_id) || [])
        ]);

        const followUpsCount = followedContactIds.size;

        if (targetsError || capturesError || followUpsError) {
            console.error('Stats fetch errors:', { targetsError, capturesError, followUpsError });
        }

        const stats = {
            targets: targetsCount,
            captures: capturesCount,
            contacts: contactsCount,
            followUps: followUpsCount
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
