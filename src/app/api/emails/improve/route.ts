import { NextRequest, NextResponse } from 'next/server';
import { EmailGeneratorService } from '@/lib/services/email-generator';

export async function POST(request: NextRequest) {
    try {
        const body = await request.json();
        const { text, instructions } = body;

        if (!text) {
            return NextResponse.json(
                { error: 'Original text is required' },
                { status: 400 }
            );
        }

        const result = await EmailGeneratorService.improveEmail(text, instructions);

        return NextResponse.json({
            data: result,
            message: 'Email draft improved successfully',
        });
    } catch (error) {
        console.error('Email refinement error:', error);
        return NextResponse.json(
            { error: 'Failed to refine email' },
            { status: 500 }
        );
    }
}
