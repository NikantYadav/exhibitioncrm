import { NextRequest, NextResponse } from 'next/server';
import { litellm } from '@/lib/services/litellm-service';

export async function GET() {
    try {
        const testContent = "Had a call in evening, and discussed potential IT solutions";
        
        const prompt = `
            You are an intelligent CRM assistant analyzing a note about a business contact interaction.
            
            Analyze this note content and determine:
            1. Whether this represents actual contact/communication with the person
            2. What follow-up status should be set based on the interaction
            3. The urgency level of any needed follow-up
            
            Note content: "${testContent}"
            
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

        return NextResponse.json({
            testContent,
            rawAnalysis: analysis,
            parsedResult: result,
            hasApiKey: !!process.env.GEMINI_API_KEY || !!process.env.GOOGLE_API_KEY
        });

    } catch (error: any) {
        return NextResponse.json({
            error: error.message,
            hasApiKey: !!process.env.GEMINI_API_KEY || !!process.env.GOOGLE_API_KEY
        }, { status: 500 });
    }
}