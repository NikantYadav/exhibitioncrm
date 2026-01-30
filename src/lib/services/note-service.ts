import { AIService } from './ai';
import { createClient } from '@/lib/supabase/server';

export interface SuggestedNote {
    original_content: string;
    formatted_content: string;
    contact_id?: string;
    contact_name?: string;
    event_id?: string;
    event_name?: string;
    confidence: number;
}

export class NoteService {
    /**
     * Process a raw note to extract context (Contact, Event)
     */
    static async processSmartNote(content: string): Promise<SuggestedNote> {
        // 1. Get potential contacts and recent events for context
        const supabase = createClient();

        // Fetch contacts for context (limit to recent or commonly accessed for optimization in real app)
        const { data: contacts } = await supabase
            .from('contacts')
            .select('id, first_name, last_name, company:companies(name)')
            .limit(50); // Simple limit for MVP

        // Fetch recent events
        const { data: events } = await supabase
            .from('events')
            .select('id, name, start_date')
            .order('start_date', { ascending: false })
            .limit(10);

        const contextData = {
            contacts: contacts?.map(c => ({
                id: c.id,
                name: `${c.first_name} ${c.last_name || ''}`,
                company: Array.isArray(c.company) ? c.company[0]?.name : (c.company as any)?.name
            })),
            events: events?.map(e => ({
                id: e.id,
                name: e.name,
                date: e.start_date
            }))
        };

        const contextString = JSON.stringify(contextData);

        // 2. AI Analysis
        const prompt = `Analyze this note and link it to the correct contact and event from the provided context.

Note: "${content}"

Context Data:
${contextString}

Task:
1. Identify the contact mentioned (fuzzy match name/company).
2. Identify the event mentioned (or imply "today's meeting" if relevant).
3. If specific contact/event not found, leave fields null.
4. Format the note content to be professional (fix typos, grammar).

Return JSON.`;

        const schema = `{
            "formatted_content": "string",
            "contact_id": "string | null",
            "event_id": "string | null",
            "confidence": "number"
        }`;

        try {
            const result = await AIService.extractStructuredData<any>(prompt, schema);

            // Hydrate names for UI
            const contact = contextData.contacts?.find(c => c.id === result.contact_id);
            const event = contextData.events?.find(e => e.id === result.event_id);

            return {
                original_content: content,
                formatted_content: result.formatted_content,
                contact_id: result.contact_id,
                contact_name: contact ? `${contact.name} (${contact.company})` : undefined,
                event_id: result.event_id,
                event_name: event?.name,
                confidence: result.confidence || 0.8
            };
        } catch (error) {
            console.error('Smart note processing error:', error);
            // Fallback
            return {
                original_content: content,
                formatted_content: content,
                confidence: 0
            };
        }
    }

    /**
     * Save the finalized note
     */
    static async saveNote(note: SuggestedNote) {
        const supabase = createClient();

        // Save to notes
        const { data: savedNote, error } = await supabase
            .from('notes')
            .insert({
                contact_id: note.contact_id,
                event_id: note.event_id,
                content: note.formatted_content,
                note_type: 'smart_text'
            })
            .select()
            .single();

        if (error) throw error;

        return savedNote;
    }
}
