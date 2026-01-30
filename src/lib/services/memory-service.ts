import { AIService } from './ai';
import { Contact, Interaction, Note } from '@/types';
import { createServerClient } from '@/lib/supabase/client';

export interface MemoryContext {
    narrative_summary: string;
    key_facts: string[];
    last_interaction_context: string;
}

export class MemoryService {
    /**
     * Get comprehensive relationship memory
     */
    static async getRelationshipMemory(contactId: string): Promise<MemoryContext> {
        const supabase = createServerClient();

        // Fetch all interactions
        const { data: interactions } = await supabase
            .from('interactions')
            .select('*')
            .eq('contact_id', contactId)
            .order('interaction_date', { ascending: false });

        // Fetch notes
        const { data: notes } = await supabase
            .from('notes')
            .select('*')
            .eq('contact_id', contactId)
            .order('created_at', { ascending: false });

        // Fetch documents summaries
        const { data: documents } = await supabase
            .from('contact_documents')
            .select('name, summary')
            .eq('contact_id', contactId);

        // If no history, return empty
        if ((!interactions || interactions.length === 0) && (!notes || notes.length === 0)) {
            return {
                narrative_summary: "No relationship history recorded yet.",
                key_facts: [],
                last_interaction_context: "N/A"
            };
        }

        // Construct context for AI
        const historyContext = this.buildHistoryContext(interactions || [], notes || [], documents || []);

        const prompt = `Analyze this relationship history and generate a memory summary.

History:
${historyContext}

Task:
1. "Narrative Summary": A 2-3 sentence story of our relationship so far.
2. "Key Facts": Extract 3-5 permanent facts about the person (preferences, family, background) if present.
3. "Last Interaction Context": A one-sentence summary of where we left things.

Return as JSON.`;

        try {
            return await AIService.extractStructuredData<MemoryContext>(prompt, `{
                "narrative_summary": "string",
                "key_facts": ["string"],
                "last_interaction_context": "string"
            }`);
        } catch (error) {
            console.error('Memory generation error:', error);
            return {
                narrative_summary: "Unable to generate summary.",
                key_facts: [],
                last_interaction_context: "Error analyzing history."
            };
        }
    }

    private static buildHistoryContext(interactions: any[], notes: any[], documents: any[]): string {
        let text = "";

        // Add Interactions
        text += "Interactions:\n";
        interactions.slice(0, 15).forEach(i => {
            text += `- ${new Date(i.interaction_date).toLocaleDateString()}: ${i.interaction_type} - ${i.summary}\n`;
        });

        // Add Notes
        text += "\nNotes:\n";
        notes.slice(0, 5).forEach(n => {
            text += `- ${n.content}\n`;
        });

        // Add Documents
        if (documents && documents.length > 0) {
            text += "\nShared Documents:\n";
            documents.forEach(d => {
                text += `- ${d.name}: ${d.summary || 'No summary'}\n`;
            });
        }

        return text;
    }
}
