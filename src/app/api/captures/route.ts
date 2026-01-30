import { NextRequest, NextResponse } from 'next/server';
import { createServerClient } from '@/lib/supabase/client';


export async function POST(request: NextRequest) {
    try {
        const body = await request.json();
        const { image, capture_type, event_id, extracted_data, raw_text } = body;

        if (!image) {
            return NextResponse.json(
                { error: 'Image is required' },
                { status: 400 }
            );
        }

        const supabase = createServerClient();

        // Create capture record with client-provided OCR data
        // If extracted_data is missing (e.g. from old client), we save essentially empty OCR
        const { data: capture, error } = await supabase
            .from('captures')
            .insert({
                capture_type: capture_type || 'card_scan',
                event_id: event_id || null,
                image_url: image, // In a real app, we should upload this to storage first!
                raw_data: { ocr_text: raw_text || '' },
                extracted_data: extracted_data || {},
                status: 'completed',
            })
            .select()
            .single();

        if (error) {
            console.error('Database error:', error);
            return NextResponse.json(
                { error: 'Failed to save capture' },
                { status: 500 }
            );
        }

        // Try to create a contact from extracted data
        let contactId = null;
        const hasContactData = extracted_data && (extracted_data.first_name || extracted_data.name || extracted_data.email);

        if (!hasContactData) {
            return NextResponse.json(
                { error: 'Failed to find relevant data in the capture. Please try again with a clearer image.' },
                { status: 422 }
            );
        }

        try {
            const firstName = extracted_data.first_name || extracted_data.name?.split(' ')[0] || 'Unknown';
            const lastName = extracted_data.last_name || extracted_data.name?.split(' ').slice(1).join(' ') || '';

            // Fetch event name for context if event_id exists
            let eventName = 'an event';
            if (event_id) {
                const { data: eventData } = await supabase
                    .from('events')
                    .select('name')
                    .eq('id', event_id)
                    .single();
                if (eventData) eventName = eventData.name;
            }

            // Check if company exists, create if not
            let companyId = null;
            if (extracted_data.company) {
                const { data: existingCompany } = await supabase
                    .from('companies')
                    .select('id')
                    .ilike('name', extracted_data.company)
                    .single();

                if (existingCompany) {
                    companyId = existingCompany.id;
                } else {
                    const { data: newCompany } = await supabase
                        .from('companies')
                        .insert({ name: extracted_data.company })
                        .select('id')
                        .single();

                    if (newCompany) companyId = newCompany.id;
                }
            }

            // Create contact with follow-up status and event context
            const { data: contact, error: contactError } = await supabase
                .from('contacts')
                .insert({
                    first_name: firstName,
                    last_name: lastName,
                    email: extracted_data.email || null,
                    phone: extracted_data.phone || null,
                    job_title: extracted_data.job_title || extracted_data.title || null,
                    company_id: companyId,
                    notes: `${raw_text}\n\n[System Note: Captured at ${eventName}]`,
                    follow_up_status: 'needs_follow_up',
                    follow_up_urgency: 'medium'
                })
                .select()
                .single();

            if (!contactError && contact) {
                contactId = contact.id;

                // Link capture to contact
                await supabase
                    .from('captures')
                    .update({ contact_id: contact.id })
                    .eq('id', capture.id);

                // Create interaction history
                await supabase
                    .from('interactions')
                    .insert({
                        contact_id: contact.id,
                        event_id: event_id || null,
                        interaction_type: 'capture',
                        summary: `Captured via ${capture_type} at ${eventName}`,
                        details: {
                            source: capture_type,
                            raw_text: raw_text,
                            event_name: eventName,
                            image_url: image
                        }
                    });

                // --- LINK TO TARGET COMPANIES ---
                // If this company is a target for this event, we should mark the target as 'contacted'
                if (event_id && companyId) {
                    const { data: targetMatch } = await supabase
                        .from('target_companies')
                        .select('id')
                        .eq('event_id', event_id)
                        .eq('company_id', companyId)
                        .single();

                    if (targetMatch) {
                        await supabase
                            .from('target_companies')
                            .update({
                                status: 'contacted',
                                updated_at: new Date().toISOString()
                            })
                            .eq('id', targetMatch.id);

                        console.log(`Auto-linked capture to target company: ${targetMatch.id}`);
                    }
                }
                // --------------------------------
            } else if (contactError) {
                console.error('Contact creation error details:', contactError);
                throw contactError;
            }
        } catch (contactError) {
            console.error('Contact creation error:', contactError);
            return NextResponse.json(
                { error: 'Failed to create contact from capture data. Please try again.' },
                { status: 500 }
            );
        }

        return NextResponse.json({
            data: capture,
            contact_id: contactId,
            message: 'Lead captured and contact linked successfully',
        });
    } catch (error) {
        console.error('Capture error:', error);
        return NextResponse.json(
            { error: 'Internal server error' },
            { status: 500 }
        );
    }
}

export async function GET(request: NextRequest) {
    try {
        const supabase = createServerClient();
        const { searchParams } = new URL(request.url);
        const event_id = searchParams.get('event_id');

        let query = supabase
            .from('captures')
            .select('*')
            .order('created_at', { ascending: false });

        if (event_id) {
            query = query.eq('event_id', event_id);
        }

        const { data, error } = await query;

        if (error) {
            return NextResponse.json(
                { error: 'Failed to fetch captures' },
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
