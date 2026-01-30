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

        const { data: notes } = await supabase
            .from('notes')
            .select('*')
            .eq('contact_id', contactId)
            .order('created_at', { ascending: false });

        // Fetch meeting briefs
        const { data: meetings } = await supabase
            .from('meeting_briefs')
            .select('*')
            .eq('contact_id', contactId)
            .order('meeting_date', { ascending: false });

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
        const historyContext = this.buildHistoryContext(
            interactions || [],
            notes || [],
            meetings || [],
            documents || []
        );

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

    private static buildHistoryContext(interactions: any[], notes: any[], meetings: any[], documents: any[]): string {
        // Deduplicate interactions that are proxies for meetings
        const meetingIds = new Set(meetings.map(m => m.id));
        const filteredInteractions = interactions.filter(i => {
            if (i.interaction_type === 'meeting' && i.details?.meeting_id && meetingIds.has(i.details.meeting_id)) {
                return false;
            }
            return true;
        });

        const timeline: any[] = [
            ...filteredInteractions.map(i => ({ ...i, date: i.interaction_date, type: 'interaction' })),
            ...notes.map(n => ({ ...n, date: n.created_at, type: 'note' })),
            ...meetings.map(m => ({ ...m, date: m.meeting_date, type: 'meeting' }))
        ].sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime());

        let text = "Relationship Timeline (Most recent first):\n";

        timeline.slice(0, 20).forEach(item => {
            const date = new Date(item.date).toLocaleDateString();
            if (item.type === 'interaction') {
                text += `- ${date}: [${item.interaction_type}] ${item.summary || ''}\n`;
            } else if (item.type === 'note') {
                text += `- ${date}: [Note] ${item.content}\n`;
            } else if (item.type === 'meeting') {
                const notes = item.post_meeting_notes ? ` (Result: ${item.post_meeting_notes})` : ' (No notes yet)';
                text += `- ${date}: [Meeting] ${item.meeting_type} at ${item.meeting_location || 'unknown'}${notes}\n`;
            }
        });

        // Add Documents
        if (documents && documents.length > 0) {
            text += "\nShared Materials:\n";
            documents.forEach(d => {
                text += `- ${d.name}: ${d.summary || 'No summary'}\n`;
            });
        }

        return text;
    }
}
