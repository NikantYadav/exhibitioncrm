import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';

export async function POST(request: NextRequest) {
    try {
        const supabase = createClient();
        const body = await request.json();

        // For voice notes, store audio as base64 in source_url
        // In production, upload to Supabase Storage and store URL
        let noteData = { ...body };

        if (body.note_type === 'voice' && body.audio_data) {
            // Revert: Store base64 audio data in root source_url
            // The 'details' column does not exist on the notes table in the current schema.
            // Ensure the input blob isn't too large for the network/db limits.
            noteData.source_url = body.audio_data;
            delete noteData.audio_data;
        }

        const { data: note, error } = await supabase
            .from('notes')
            .insert(noteData)
            .select()
            .single();

        if (error) {
            return NextResponse.json({ error: error.message }, { status: 400 });
        }

        return NextResponse.json({ data: note });
    } catch (error) {
        return NextResponse.json(
            { error: 'Failed to create note' },
            { status: 500 }
        );
    }
}
