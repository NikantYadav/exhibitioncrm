import { NextRequest, NextResponse } from 'next/server';
import { EmailGeneratorService, EmailDraftOptions } from '@/lib/services/email-generator';
import { createServerClient } from '@/lib/supabase/client';

export async function POST(request: NextRequest) {
    try {
        const body = await request.json();
        const { contact_id, event_id, email_type, custom_context } = body;

        console.log('Generating draft for:', { contact_id, event_id, email_type });

        if (!contact_id || !email_type) {
            return NextResponse.json(
                { error: 'contact_id and email_type are required' },
                { status: 400 }
            );
        }

        const supabase = createServerClient();

        // Fetch contact with company
        const { data: contact } = await supabase
            .from('contacts')
            .select('*, company:companies(*)')
            .eq('id', contact_id)
            .single();

        if (!contact) {
            console.error('Contact not found:', contact_id);
            return NextResponse.json(
                { error: 'Contact not found' },
                { status: 404 }
            );
        }

        // Fetch event if provided
        let event = null;
        if (event_id) {
            const { data } = await supabase
                .from('events')
                .select('*')
                .eq('id', event_id)
                .single();
            event = data;
        }

        // Fetch notes for context
        const { data: notes } = await supabase
            .from('notes')
            .select('*')
            .eq('contact_id', contact_id)
            .order('created_at', { ascending: false })
            .limit(5);

        // Generate email based on type
        let emailDraft;
        const options: EmailDraftOptions = {
            type: email_type as 'pre_event' | 'follow_up' | 'pre_meeting',
            contact: contact as any,
            event: event || undefined,
            notes: notes || undefined,
            customContext: custom_context,
        };

        switch (email_type) {
            case 'pre_event':
                emailDraft = await EmailGeneratorService.generatePreEventEmail(options);
                break;
            case 'follow_up':
                emailDraft = await EmailGeneratorService.generateFollowUpEmail(options);
                break;
            case 'pre_meeting':
                emailDraft = await EmailGeneratorService.generatePreMeetingEmail(options);
                break;
            default:
                return NextResponse.json(
                    { error: 'Invalid email type' },
                    { status: 400 }
                );
        }

        // Save draft to database
        const { data: savedDraft, error } = await supabase
            .from('email_drafts')
            .insert({
                contact_id,
                event_id,
                email_type,
                subject: emailDraft.subject,
                body: emailDraft.body,
                status: 'draft',
            })
            .select()
            .single();

        if (error) {
            console.error('Save draft error:', error);
            // Even if save fails, we return the generated draft to the user
            // but the user won't see it on reload if it didn't save.
        } else {
            console.log('Draft saved successfully:', savedDraft?.id);
        }

        return NextResponse.json({
            data: emailDraft,
            draft_id: savedDraft?.id,
            message: 'Email draft generated successfully',
        });
    } catch (error) {
        console.error('Email generation error:', error);
        return NextResponse.json(
            { error: 'Failed to generate email' },
            { status: 500 }
        );
    }
}
