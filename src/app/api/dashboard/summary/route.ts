import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';

export async function GET(request: NextRequest) {
    try {
        const supabase = createClient();

        // 1. Get Journey Stage Counts
        const { count: targetsCount } = await supabase
            .from('target_companies')
            .select('*', { count: 'exact', head: true });

        const { count: capturesCount } = await supabase
            .from('captures')
            .select('*', { count: 'exact', head: true });

        const { count: enrichedCount } = await supabase
            .from('companies')
            .select('*', { count: 'exact', head: true })
            .eq('is_enriched', true);

        const { count: draftsCount } = await supabase
            .from('email_drafts')
            .select('*', { count: 'exact', head: true })
            .eq('status', 'draft');

        const { count: sentCount } = await supabase
            .from('email_drafts')
            .select('*', { count: 'exact', head: true })
            .eq('status', 'sent');

        // 2. Get Stage-specific Leads
        const { data: targetLeads } = await supabase
            .from('target_companies')
            .select('company:companies(id, name)')
            .limit(3);

        const { data: capturedLeads } = await supabase
            .from('captures')
            .select('contact:contacts(id, first_name, last_name, company:companies(name))')
            .not('contact_id', 'is', null)
            .limit(3);

        const { data: enrichedLeads } = await supabase
            .from('companies')
            .select('id, name')
            .eq('is_enriched', true)
            .limit(3);

        const { data: draftLeads } = await supabase
            .from('email_drafts')
            .select('id, contact:contacts(first_name, last_name, company:companies(name))')
            .eq('status', 'draft')
            .limit(3);

        const { data: sentLeads } = await supabase
            .from('email_drafts')
            .select('id, contact:contacts(first_name, last_name, company:companies(name))')
            .eq('status', 'sent')
            .limit(3);

        // 3. Get Upcoming Meetings
        const { data: upcomingMeetings, error: meetingError } = await supabase
            .from('meeting_briefs')
            .select(`
                id,
                meeting_date,
                meeting_type,
                meeting_location,
                contact:contacts(id, first_name, last_name, avatar_url, company:companies(name))
            `)
            .eq('status', 'scheduled')
            .gte('meeting_date', new Date().toISOString())
            .order('meeting_date', { ascending: true })
            .limit(5);

        if (meetingError && meetingError.code !== 'PGRST205') {
            throw meetingError;
        }

        // 4. Get Recent Activity
        const { data: recentActivity } = await supabase
            .from('interactions')
            .select(`
                id,
                interaction_type,
                interaction_date,
                summary,
                contact:contacts(id, first_name, last_name, avatar_url)
            `)
            .order('interaction_date', { ascending: false })
            .limit(10);

        // 5. Get Active Conversations
        const { data: activeContacts } = await supabase
            .from('contacts')
            .select('id, first_name, last_name, avatar_url')
            .order('updated_at', { ascending: false })
            .limit(5);

        const getFirst = (item: any) => Array.isArray(item) ? item[0] : item;

        return NextResponse.json({
            summary: {
                targets: targetsCount || 0,
                captured: capturesCount || 0,
                enriched: enrichedCount || 0,
                drafts: draftsCount || 0,
                sent: sentCount || 0,
            },
            stages: {
                targets: targetLeads?.map(t => {
                    const company = getFirst(t.company);
                    return { id: company?.id, name: company?.name, initials: company?.name?.[0] };
                }) || [],
                captured: capturedLeads?.map(c => {
                    const contact = getFirst(c.contact);
                    const company = getFirst(contact?.company);
                    return {
                        id: contact?.id,
                        name: `${contact?.first_name || ''} ${contact?.last_name || ''}`.trim(),
                        company: company?.name,
                        initials: contact?.first_name?.[0]
                    };
                }) || [],
                enriched: enrichedLeads?.map(e => ({ id: e.id, name: e.name, initials: e.name?.[0] })) || [],
                drafts: draftLeads?.map(d => {
                    const contact = getFirst(d.contact);
                    const company = getFirst(contact?.company);
                    return {
                        id: d.id,
                        name: `${contact?.first_name || ''} ${contact?.last_name || ''}`.trim(),
                        company: company?.name,
                        initials: contact?.first_name?.[0]
                    };
                }) || [],
                sent: sentLeads?.map(s => {
                    const contact = getFirst(s.contact);
                    const company = getFirst(contact?.company);
                    return {
                        id: s.id,
                        name: `${contact?.first_name || ''} ${contact?.last_name || ''}`.trim(),
                        company: company?.name,
                        initials: contact?.first_name?.[0]
                    };
                }) || [],
            },
            upcomingMeetings: upcomingMeetings || [],
            recentActivity: recentActivity || [],
            activeContacts: activeContacts || []
        });
    } catch (error) {
        console.error('Dashboard summary error:', error);
        return NextResponse.json(
            { error: 'Failed to fetch dashboard summary' },
            { status: 500 }
        );
    }
}
