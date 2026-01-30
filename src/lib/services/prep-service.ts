import { AIService } from './ai';
import { Contact, Interaction, MeetingBrief } from '@/types';
import { getUserProfile, buildProfileContext } from './profile-service';

export interface MeetingContext {
    who_is_this: string;
    relationship_summary: string;
    key_talking_points: string[];
    interaction_highlights: string;
}

export class PrepService {
    /**
     * Generate comprehensive meeting preparation context
     */
    static async generateMeetingContext(
        contact: Contact,
        interactions: Interaction[],
        documents: string[] = []
    ): Promise<MeetingContext> {
        const profile = await getUserProfile();
        const profileContext = buildProfileContext(profile);

        // Summarize interaction history
        const historyText = interactions
            .slice(0, 10) // Analysis last 10 interactions
            .map(i => `${i.interaction_date}: ${i.interaction_type} - ${i.summary}`)
            .join('\n');

        const prompt = `Prepare a briefing for an upcoming meeting.
        
My Profile:
${profileContext}

Meeting Participant:
Name: ${contact.first_name} ${contact.last_name || ''}
Title: ${contact.job_title || 'Unknown'}
Company: ${contact.company?.name || 'Unknown'}
Industry: ${contact.company?.industry || 'Unknown'}

Interaction History:
${historyText || 'No previous interactions.'}

Shared Documents:
${documents.length > 0 ? `The following documents have been shared: ${documents.join(', ')}` : 'No documents shared.'}

Task:
1. "Who is this": A 2-sentence professional bio of the participant.
2. "Relationship Summary": A brief summary of how we know them and our history.
3. "Key Talking Points": 3-5 suggested topics for the meeting based on history and their profile.
4. "Interaction Highlights": Key bullet points from past history (if any).

Return as structured JSON.`;

        const schema = `{
            "who_is_this": "string",
            "relationship_summary": "string",
            "key_talking_points": ["string"],
            "interaction_highlights": "string"
        }`;

        try {
            return await AIService.extractStructuredData<MeetingContext>(prompt, schema);
        } catch (error) {
            console.error('Prep context generation error:', error);
            return {
                who_is_this: 'Unable to generate bio.',
                relationship_summary: 'Unable to summarize relationship.',
                key_talking_points: ['Discuss current projects', 'Explore collaboration opportunities'],
                interaction_highlights: 'No highlights available.'
            };
        }
    }

    /**
     * Summarize a document (mock implementation for text content)
     */
    static async summarizeDocument(textContent: string): Promise<string> {
        const prompt = `Summarize the following document content into 3-4 key bullet points relevant for a meeting:
        
${textContent.substring(0, 5000)}...`; // Truncate for token limits

        try {
            return await AIService.generateCompletion([
                { role: 'user', content: prompt }
            ]);
        } catch (error) {
            console.error('Document summarization error:', error);
            return 'Unable to summarize document.';
        }
    }
}
