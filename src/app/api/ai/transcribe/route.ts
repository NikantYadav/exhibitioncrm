import { NextRequest, NextResponse } from 'next/server';
import { litellm } from '@/lib/services/litellm-service';

export async function POST(request: NextRequest) {
    try {
        const { audio_data } = await request.json();

        if (!audio_data) {
            return NextResponse.json(
                { error: 'Audio data is required' },
                { status: 400 }
            );
        }

        const transcript = await litellm.transcribeAudio(audio_data);

        return NextResponse.json({ transcript });
    } catch (error: any) {
        console.error('Transcription error:', error);
        return NextResponse.json(
            { error: error.message || 'Failed to transcribe audio' },
            { status: 500 }
        );
    }
}
