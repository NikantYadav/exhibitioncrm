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
            You are an expert at extracting professional information from photos. 
            Analyze the attached image (which could be a business card, event badge, or document) and extract the contact information.
            
            Strict Guidelines:
            1. Identify the person's name, company, and job title from the text profile.
            2. For emails, ensure you include the domain (e.g., .com, .net) correctly.
            3. If the image is a badge, the most prominent name is usually the person.
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
            { error: error.message || 'Failed to process capture' },
            { status: 500 }
        );
    }
}
