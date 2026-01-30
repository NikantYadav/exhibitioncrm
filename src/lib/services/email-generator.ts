import { AIService, AIMessage } from './ai';
import { Contact, Event, Interaction, Note } from '@/types';
import { getUserProfile, buildProfileContext } from './profile-service';

export interface EmailDraftOptions {
    type: 'pre_event' | 'follow_up' | 'pre_meeting';
    contact: Contact;
    event?: Event;
    interactions?: Interaction[];
    notes?: Note[];
    attachments?: string[];
    customContext?: string;
}

export class EmailGeneratorService {
    /**
     * Generate pre-event introduction email
     */
    static async generatePreEventEmail(options: EmailDraftOptions): Promise<{
        subject: string;
        body: string;
    }> {
        const { contact, event, customContext } = options;

        // Get user profile for context
        const profile = await getUserProfile();
        const profileContext = buildProfileContext(profile);

        const prompt = `Generate a warm, professional pre-event introduction email.

My Information:
${profileContext}

Recipient Information:
Contact: ${contact.first_name} ${contact.last_name || ''}
Company: ${contact.company?.name || 'Unknown'}
Job Title: ${contact.job_title || 'Unknown'}
Event: ${event?.name || 'upcoming event'}
Event Date: ${event?.start_date ? new Date(event.start_date).toLocaleDateString() : 'TBD'}
${customContext ? `Additional context: ${customContext}` : ''}`;

        try {
            const result = await AIService.extractStructuredData<{
                subject: string;
                body: string;
            }>(
                prompt,
                '{"subject": "string", "body": "string"}',
                '{"subject": "Connecting at [Event]", "body": "Dear [Name], ..."}'
            );

            return result;
        } catch (error) {
            console.error('Email generation error:', error);
            return this.getFallbackPreEventEmail(contact, event);
        }
    }

    /**
     * Generate follow-up email after event
     */
    static async generateFollowUpEmail(options: EmailDraftOptions): Promise<{
        subject: string;
        body: string;
    }> {
        const { contact, event, notes, customContext, attachments } = options;

        // Get user profile for context
        const profile = await getUserProfile();
        const profileContext = buildProfileContext(profile);

        const conversationSummary = notes
            ?.map(note => note.content)
            .join('\n') || 'Had a great conversation';

        let prompt = `Generate a personalized follow-up email after meeting at an event.

My Information:
${profileContext}

Recipient Information:
Contact: ${contact.first_name} ${contact.last_name || ''}
Company: ${contact.company?.name || 'Unknown'}
Event: ${event?.name || 'recent event'}
Conversation notes: ${conversationSummary}
${customContext ? `Additional context: ${customContext}` : ''}`;

        if (attachments && attachments.length > 0) {
            prompt += `\n\nI am attaching the following documents: ${attachments.join(', ')}. Please reference them in the email body naturally.`;
        }

        try {
            const result = await AIService.extractStructuredData<{
                subject: string;
                body: string;
            }>(
                prompt,
                '{"subject": "string", "body": "string"}',
                '{"subject": "Following up: [Event]", "body": "Dear [Name], It was great meeting you..."}'
            );

            return result;
        } catch (error) {
            console.error('Email generation error:', error);
            return this.getFallbackFollowUpEmail(contact, event);
        }
    }

    /**
     * Generate pre-meeting email
     */
    static async generatePreMeetingEmail(options: EmailDraftOptions): Promise<{
        subject: string;
        body: string;
    }> {
        const { contact, interactions, notes, customContext } = options;

        // Get user profile for context
        const profile = await getUserProfile();
        const profileContext = buildProfileContext(profile);

        const historyContext = this.buildHistoryContext(interactions, notes);

        const prompt = `Generate a pre-meeting email to confirm and prepare for an upcoming meeting.

My Information:
${profileContext}

Recipient Information:
Contact: ${contact.first_name} ${contact.last_name || ''}
Company: ${contact.company?.name || 'Unknown'}
Previous interactions: ${historyContext}
${customContext ? `Additional context: ${customContext}` : ''}`;

        try {
            const result = await AIService.extractStructuredData<{
                subject: string;
                body: string;
            }>(
                prompt,
                '{"subject": "string", "body": "string"}',
                '{"subject": "Meeting Confirmation: [Context]", "body": "Dear [Name], I wanted to confirm..."}'
            );

            return result;
        } catch (error) {
            console.error('Email generation error:', error);
            return this.getFallbackPreMeetingEmail(contact);
        }
    }

    /**
     * Improve an existing email draft
     */
    static async improveEmail(text: string, instructions?: string): Promise<{
        subject: string;
        body: string;
    }> {
        const profile = await getUserProfile();
        const profileContext = buildProfileContext(profile);

        const prompt = `Improve the following email draft. Make it more professional, engaging, and clear while maintaining the original intent.

My Profile Context:
${profileContext}

Current Draft:
${text}

${instructions ? `Improvement Instructions: ${instructions}` : ''}`;

        try {
            const result = await AIService.extractStructuredData<{
                subject: string;
                body: string;
            }>(
                prompt,
                '{"subject": "string", "body": "string"}',
                '{"subject": "Improved Subject", "body": "Improved Body..."}'
            );
            return result;
        } catch (error) {
            console.error('Email improvement error:', error);
            return {
                subject: 'Failed to improve email',
                body: text
            };
        }
    }

    /**
     * Build context from interaction history
     */
    private static buildHistoryContext(
        interactions?: Interaction[],
        notes?: Note[]
    ): string {
        if (!interactions?.length && !notes?.length) {
            return 'First interaction';
        }

        const parts: string[] = [];

        if (interactions?.length) {
            parts.push(`${interactions.length} previous interaction(s)`);
        }

        if (notes?.length) {
            const recentNotes = notes.slice(0, 2).map(n => n.content).join('; ');
            parts.push(`Recent notes: ${recentNotes}`);
        }

        return parts.join('. ');
    }

    /**
     * Fallback pre-event email template
     */
    private static getFallbackPreEventEmail(contact: Contact, event?: Event): {
        subject: string;
        body: string;
    } {
        return {
            subject: `Looking forward to connecting at ${event?.name || 'the event'}`,
            body: `Hi ${contact.first_name},

I hope this email finds you well. I'll be attending ${event?.name || 'the upcoming event'} and would love to connect with you there.

I'm interested in learning more about ${contact.company?.name || 'your company'} and exploring potential collaboration opportunities.

Would you be available for a quick chat at the event? I'd be happy to meet at your booth or grab a coffee during a break.

Looking forward to meeting you!

Best regards`,
        };
    }

    /**
     * Fallback follow-up email template
     */
    private static getFallbackFollowUpEmail(contact: Contact, event?: Event): {
        subject: string;
        body: string;
    } {
        return {
            subject: `Great meeting you at ${event?.name || 'the event'}`,
            body: `Hi ${contact.first_name},

It was great meeting you at ${event?.name || 'the event'}! I enjoyed our conversation about ${contact.company?.name || 'your work'}.

As discussed, I'd like to follow up on the topics we covered. I believe there are some interesting opportunities for us to explore together.

Would you be available for a call next week to discuss this further?

Looking forward to staying in touch!

Best regards`,
        };
    }

    /**
     * Fallback pre-meeting email template
     */
    private static getFallbackPreMeetingEmail(contact: Contact): {
        subject: string;
        body: string;
    } {
        return {
            subject: `Confirming our upcoming meeting`,
            body: `Hi ${contact.first_name},

I wanted to confirm our upcoming meeting and make sure we're aligned on what we'd like to discuss.

I'm looking forward to learning more about ${contact.company?.name || 'your company'} and exploring how we might work together.

Please let me know if there any specific topics you'd like to cover, and I'll make sure to prepare accordingly.

See you soon!

Best regards`,
        };
    }
}
