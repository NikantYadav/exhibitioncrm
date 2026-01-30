/**
 * Intelligent Note Analysis API
 * 
 * This endpoint analyzes note content using AI to automatically determine:
 * 1. Whether the note represents actual contact/interaction with the person
 * 2. What follow-up status should be set (contacted, needs_followup, not_contacted, ignore)
 * 3. The urgency level of any needed follow-up (high, medium, low)
 * 
 * The AI looks for indicators like:
 * - Actual conversations: "spoke with John", "had a call", "met at the booth"
 * - Follow-up needs: "promised to send info", "wants a demo", "interested in pricing"
 * - No interaction: "research notes", "company background", "potential contact"
 * - No follow-up: "not interested", "already has solution", "do not contact"
 * 
 * When a contact's status is 'not_contacted' and the AI detects interaction,
 * it automatically updates the status to 'contacted' or 'needs_followup'.
 */
import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { litellm } from '@/lib/services/litellm-service';

export const dynamic = 'force-dynamic';

export async function POST(request: NextRequest) {
    try {
        const { noteId, contactId, content } = await request.json();

        if (!content || (!noteId && !contactId)) {
            return NextResponse.json(
                { error: 'Content and either noteId or contactId required' },
                { status: 400 }
            );
        }

        const supabase = createClient();

        // Get contact current status if contactId provided
        let currentContact = null;
        if (contactId) {
            const { data: contact } = await supabase
                .from('contacts')
                .select('follow_up_status, follow_up_urgency, first_name, last_name')
                .eq('id', contactId)
                .single();
            currentContact = contact;
        }

        // Analyze note content with AI
        const prompt = `
            You are an intelligent CRM assistant analyzing a note about a business contact interaction.
            
            Analyze this note content and determine:
            1. Whether this represents actual contact/communication with the person
            2. What follow-up status should be set based on the interaction
            3. The urgency level of any needed follow-up
            
            Note content: "${content}"
            
            Guidelines:
            - "contacted" = actual conversation, meeting, call, or meaningful exchange happened
            - "needs_followup" = contact made but requires follow-up action (they asked for info, promised to connect, etc.)
            - "not_contacted" = just notes about the person, no actual interaction yet
            - "ignore" = explicitly mentioned not to follow up or not interested
            
            Urgency levels:
            - "high" = time-sensitive, hot lead, requested immediate follow-up
            - "medium" = standard follow-up needed within a week
            - "low" = general follow-up, no rush
            
            Return ONLY valid JSON with no additional text.
        `;

        const schema = `{
            "status": "contacted | needs_followup | not_contacted | ignore",
            "urgency": "high | medium | low",
            "reasoning": "brief explanation of the decision",
            "interaction_detected": boolean,
            "follow_up_needed": boolean
        }`;

        interface AnalysisResult {
            status: 'contacted' | 'needs_followup' | 'not_contacted' | 'ignore';
            urgency: 'high' | 'medium' | 'low';
            reasoning: string;
            interaction_detected: boolean;
            follow_up_needed: boolean;
        }

        const analysis = await litellm.generateCompletion([
            {
                role: 'system',
                content: prompt
            },
            {
                role: 'user', 
                content: `Please analyze this and return JSON matching the schema: ${schema}`
            }
        ], { temperature: 0.3 });
        
        const result = litellm.cleanAndParseJSON<AnalysisResult>(analysis);

        console.log('=== AI ANALYSIS DEBUG ===');
        console.log('Note content:', content);
        console.log('AI raw response:', analysis);
        console.log('Parsed result:', result);
        console.log('Current contact:', currentContact);
        console.log('Contact ID:', contactId);

        // Update contact status if contactId provided and status should change
        if (contactId && currentContact) {
            const shouldUpdate = 
                currentContact.follow_up_status === 'not_contacted' && 
                (result.status === 'contacted' || result.status === 'needs_followup');

            console.log('Update conditions:');
            console.log('- Current status is not_contacted:', currentContact.follow_up_status === 'not_contacted');
            console.log('- Current status value:', currentContact.follow_up_status);
            console.log('- AI suggests contacted or needs_followup:', result.status === 'contacted' || result.status === 'needs_followup');
            console.log('- Should update:', shouldUpdate);

            if (shouldUpdate) {
                const updateData: any = {
                    follow_up_status: result.status === 'needs_followup' ? 'needs_follow_up' : result.status,
                    follow_up_urgency: result.urgency,
                    updated_at: new Date().toISOString()
                };

                // Set last_contacted_at if this represents actual contact
                if (result.status === 'contacted' || result.status === 'needs_followup') {
                    updateData.last_contacted_at = new Date().toISOString();
                }

                console.log('Updating contact with data:', updateData);

                const { error: updateError } = await supabase
                    .from('contacts')
                    .update(updateData)
                    .eq('id', contactId);

                if (updateError) {
                    console.error('Database update error:', updateError);
                } else {
                    console.log('✅ Contact status updated successfully');
                }
            } else {
                console.log('❌ No update needed or conditions not met');
            }
        } else {
            console.log('❌ Missing contactId or currentContact');
        }
        console.log('=== END DEBUG ===');

        return NextResponse.json({
            success: true,
            analysis: result,
            updated: currentContact?.follow_up_status === 'not_contacted' && 
                    (result.status === 'contacted' || result.status === 'needs_followup')
        });

    } catch (error: any) {
        console.error('Note analysis error:', error);
        return NextResponse.json(
            { error: error.message || 'Failed to analyze note' },
            { status: 500 }
        );
    }
}