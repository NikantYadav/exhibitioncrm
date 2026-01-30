'use server';

import { CompanyResearchService, CompanyResearchResult } from '@/lib/services/company-research';
import { createClient } from '@/lib/supabase/server';
import { revalidatePath } from 'next/cache';

export interface ResearchState {
    result?: CompanyResearchResult;
    error?: string;
    loading: boolean;
}

export async function searchCompanyAction(queryInput: string | FormData): Promise<{ result?: CompanyResearchResult, error?: string }> {
    const query = typeof queryInput === 'string' ? queryInput : queryInput.get('query') as string;

    if (!query) {
        return { error: 'Please enter a company name or website' };
    }

    try {
        const isUrl = query.includes('.') && !query.includes(' ');
        const data = isUrl
            ? { name: query, website: query }
            : { name: query };

        const result = await CompanyResearchService.researchCompany(data);
        return { result };
    } catch (error) {
        console.error('Search action error:', error);
        return { error: 'Failed to perform research. Please try again.' };
    }
}

export async function addTargetCompany(eventId: string, companyData: any, researchResult: CompanyResearchResult) {
    const supabase = createClient();

    try {
        // 1. Check if company exists, create if not
        let companyId;

        // Use AI-determined name as source of truth
        const officialName = researchResult.companyName;

        // Simple check by name for now (ideal would be domain check)
        const { data: existingCompany } = await supabase
            .from('companies')
            .select('id')
            .ilike('name', officialName)
            .single();

        if (existingCompany) {
            companyId = existingCompany.id;
        } else {
            const { data: newCompany, error: createError } = await supabase
                .from('companies')
                .insert({
                    name: officialName,
                    industry: researchResult.industry,
                    description: researchResult.overview,
                    products_services: researchResult.products_services,
                    location: researchResult.location,
                    website: researchResult.website,
                    is_enriched: true,
                    enrichment_confidence: researchResult.confidence
                })
                .select('id')
                .single();

            if (createError) throw createError;
            companyId = newCompany.id;
        }

        // 2. Add to target_companies
        const { error: targetError } = await supabase
            .from('target_companies')
            .insert({
                event_id: eventId,
                company_id: companyId,
                priority: 'medium',
                status: 'not_contacted',
                // Store research summary in notes initially
                notes: `AI Insights: ${researchResult.keyInsights.join('\n- ')}`
            });

        if (targetError) {
            // Ignore duplicate key error (already a target)
            if (targetError.code !== '23505') throw targetError;
        }

        // 3. Cache research if needed (optional, skipping for now as we used direct insert)

        revalidatePath(`/events/${eventId}/preparation/targets`);
        return { success: true };
    } catch (error) {
        console.error('Add target error:', error);
        return { error: 'Failed to add company to targets' };
    }
}

export async function getTargets(eventId: string) {
    const supabase = createClient();

    const { data, error } = await supabase
        .from('target_companies')
        .select(`
            *,
            company:companies(*)
        `)
        .eq('event_id', eventId)
        .order('created_at', { ascending: false });

    if (error) {
        console.error('Get targets error:', error);
        return [];
    }

    return data;
}

export async function updateTargetPriority(targetId: string, priority: 'low' | 'medium' | 'high') {
    const supabase = createClient();

    const { error } = await supabase
        .from('target_companies')
        .update({ priority })
        .eq('id', targetId);

    if (error) {
        return { error: 'Failed to update priority' };
    }

    revalidatePath('/events/[id]/preparation/targets'); // Revalidate all target pages
    return { success: true };
}

export async function deleteTarget(targetId: string) {
    const supabase = createClient();

    const { error } = await supabase
        .from('target_companies')
        .delete()
        .eq('id', targetId);

    if (error) {
        return { error: 'Failed to delete target' };
    }

    revalidatePath('/events/[id]/preparation/targets');
    return { success: true };
}

export async function generateTalkingPointsAction(companyData: any) {
    const supabase = createClient();
    let memory = undefined;

    if (companyData.id) {
        try {
            // Fetch past interactions for this company
            const { data: interactions } = await supabase
                .from('interactions')
                .select('summary, interaction_type, interaction_date, contacts!inner(company_id)')
                .eq('contacts.company_id', companyData.id)
                .order('interaction_date', { ascending: false })
                .limit(5);

            // Fetch past notes for this company
            const { data: notes } = await supabase
                .from('notes')
                .select('content, note_type, contacts!inner(company_id)')
                .eq('contacts.company_id', companyData.id)
                .order('created_at', { ascending: false })
                .limit(5);

            if ((interactions && interactions.length > 0) || (notes && notes.length > 0)) {
                memory = {
                    pastInteractions: interactions?.map(i => `${i.interaction_date}: ${i.interaction_type} - ${i.summary}`),
                    previousNotes: notes?.map(n => n.content)
                };
            }
        } catch (memError) {
            console.error('Error fetching company memory:', memError);
            // Continue without memory if it fails
        }
    }

    try {
        const points = await CompanyResearchService.generateTalkingPoints(companyData, memory);
        return { points };
    } catch (error) {
        console.error('Talking points action error:', error);
        return { error: 'Failed to generate talking points' };
    }
}

export async function saveTalkingPoints(targetId: string, points: string[]) {
    const supabase = createClient();

    // Clean the points array - remove JSON artifacts and empty strings
    const cleanedPoints = points
        .filter(p => {
            const trimmed = p.trim();
            // Filter out JSON artifacts like "json", "[", "]", etc.
            return trimmed &&
                trimmed !== 'json' &&
                trimmed !== '[' &&
                trimmed !== ']' &&
                !trimmed.startsWith('```') &&
                trimmed.length > 2; // Ignore very short strings
        })
        .map(p => {
            // Remove leading dashes and clean up
            let cleaned = p.trim();
            cleaned = cleaned.replace(/^[-•*]\s*/, ''); // Remove bullet points
            cleaned = cleaned.replace(/^"(.*)"$/, '$1'); // Remove surrounding quotes
            return cleaned;
        });

    // Convert array to string for text field, or use JSON if DB supports it. 
    // Schema says `talking_points` is TEXT.
    const textPoints = cleanedPoints.map(p => `- ${p}`).join('\n');

    const { error } = await supabase
        .from('target_companies')
        .update({ talking_points: textPoints })
        .eq('id', targetId);

    if (error) return { error: 'Failed to save points' };
    revalidatePath('/events/[id]/preparation/targets');
    return { success: true };
}

import { EmailGeneratorService } from '@/lib/services/email-generator';

export async function generateEmailDraftAction(data: any) {
    try {
        let result;
        const options = {
            type: data.type,
            contact: data.contact, // Mock contact object
            event: data.event,     // Mock event object
            customContext: data.context
        };

        // Switch based on type (simplified for MVP)
        if (data.type === 'pre_event') {
            result = await EmailGeneratorService.generatePreEventEmail(options as any);
        } else if (data.type === 'follow_up') {
            result = await EmailGeneratorService.generateFollowUpEmail(options as any);
        } else {
            result = await EmailGeneratorService.generatePreMeetingEmail(options as any);
        }

        return { result };
    } catch (error) {
        console.error('Email generation error:', error);
        return { error: 'Failed to generate email' };
    }
}

export async function saveEmailDraftAction(draftData: any) {
    const supabase = createClient();

    // Check if contact exists, if not create one for this company? 
    // For MVP, we might skip strict contact linking if just drafting.
    // But schema requires contact_id.
    // We'll require user to provide contact details in UI and create lightweight contact if needed.

    let contactId = draftData.contactId;

    if (!contactId && draftData.contactName) {
        // Try to find or create contact
        const [first, ...rest] = draftData.contactName.split(' ');
        const last = rest.join(' ');

        const { data: newContact, error: contactError } = await supabase
            .from('contacts')
            .insert({
                company_id: draftData.companyId,
                first_name: first,
                last_name: last,
                email: draftData.contactEmail
            })
            .select('id')
            .single();

        if (!contactError) contactId = newContact.id;
    }

    if (!contactId) return { error: 'Contact required to save draft' };

    const { error } = await supabase
        .from('email_drafts')
        .insert({
            contact_id: contactId,
            event_id: draftData.eventId,
            email_type: draftData.type,
            subject: draftData.subject,
            body: draftData.body,
            status: 'draft'
        });

    if (error) {
        console.error('Save draft error:', error);
        return { error: 'Failed to save draft' };
    }

    return { success: true };
}


