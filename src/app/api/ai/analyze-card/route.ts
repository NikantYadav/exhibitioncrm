import { NextRequest, NextResponse } from 'next/server';
import { litellm } from '@/lib/services/litellm-service';

export const dynamic = 'force-dynamic';

export async function POST(request: NextRequest) {
    try {
        const { image } = await request.json();

        if (!image) {
            return NextResponse.json({ error: 'Image is required' }, { status: 400 });
        }

        const prompt = `
            You are an expert business card scanner. 
            Analyze the attached business card image and extract the following information.
            
            Strict Guidelines:
            1. If the font is stylized or script-like, pay extra attention to correctly identify the letters (e.g., thin fonts, cursive).
            2. For emails, ensure you include the domain (e.g., .com, .net) correctly.
            3. For names, look for the most prominent person's name on the card.
            4. If a field is not present, return null.
            5. Return ONLY a valid JSON object.
        `;

        const schema = `{
            "first_name": "string",
            "last_name": "string",
            "name": "string (full name)",
            "company": "string",
            "email": "string",
            "phone": "string",
            "job_title": "string",
            "website": "string",
            "address": "string"
        }`;

        const result = await litellm.analyzeImage<any>(image, prompt, schema);

        return NextResponse.json({ data: result });
    } catch (error: any) {
        console.error('AI Analysis Error:', error);
        return NextResponse.json(
            { error: error.message || 'Failed to analyze card with AI' },
            { status: 500 }
        );
    }
}
