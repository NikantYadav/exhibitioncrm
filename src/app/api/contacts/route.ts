import { NextRequest, NextResponse } from 'next/server';
import { createServerClient } from '@/lib/supabase/client';

export async function GET(request: NextRequest) {
    try {
        const supabase = createServerClient();

        const { searchParams } = new URL(request.url);
        const companyId = searchParams.get('company_id');

        let query = supabase
            .from('contacts')
            .select(`
                *,
                company:companies(*)
            `);

        if (companyId) {
            query = query.eq('company_id', companyId);
        }

        const { data, error } = await query
            .order('created_at', { ascending: false });

        if (error) {
            return NextResponse.json(
                { error: 'Failed to fetch contacts' },
                { status: 500 }
            );
        }

        return NextResponse.json({ data });
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

        // If company_name is provided, find or create company
        let company_id = body.company_id;
        if (body.company_name && !company_id) {
            const { data: existingCompany } = await supabase
                .from('companies')
                .select('id')
                .eq('name', body.company_name)
                .single();

            if (existingCompany) {
                company_id = existingCompany.id;
            } else {
                const { data: newCompany } = await supabase
                    .from('companies')
                    .insert({ name: body.company_name })
                    .select('id')
                    .single();

                company_id = newCompany?.id;
            }
        }

        const { data, error } = await supabase
            .from('contacts')
            .insert({
                first_name: body.first_name,
                last_name: body.last_name,
                email: body.email,
                phone: body.phone,
                job_title: body.job_title,
                company_id,
                notes: body.notes,
            })
            .select()
            .single();

        if (error) {
            return NextResponse.json(
                { error: 'Failed to create contact' },
                { status: 500 }
            );
        }

        // Create interaction if event_id is provided
        if (body.event_id) {
            await supabase
                .from('interactions')
                .insert({
                    contact_id: data.id,
                    event_id: body.event_id,
                    interaction_type: 'capture',
                    summary: 'Manually added during event',
                    details: {
                        source: 'manual_entry'
                    }
                });

            // Also create a capture record for stats consistency
            await supabase
                .from('captures')
                .insert({
                    contact_id: data.id,
                    event_id: body.event_id,
                    capture_type: 'manual',
                    status: 'completed',
                    raw_data: { manual_data: body }
                });
        }

        // --- LINK TO TARGET COMPANIES ---
        // If this company is a target for this event, we should mark the target as 'contacted'
        if (body.event_id && company_id) {
            const { data: targetMatch } = await supabase
                .from('target_companies')
                .select('id')
                .eq('event_id', body.event_id)
                .eq('company_id', company_id)
                .single();

            if (targetMatch) {
                await supabase
                    .from('target_companies')
                    .update({
                        status: 'contacted',
                        updated_at: new Date().toISOString()
                    })
                    .eq('id', targetMatch.id);

                console.log(`Auto-linked manual contact to target company: ${targetMatch.id}`);
            }
        }
        // --------------------------------

        return NextResponse.json({ data, message: 'Contact created successfully' });
    } catch (error) {
        console.error('Create error:', error);
        return NextResponse.json(
            { error: 'Internal server error' },
            { status: 500 }
        );
    }
}
