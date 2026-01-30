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

        // Trigger intelligent status analysis for text notes
        if (note.contact_id && note.content && note.note_type === 'text') {
            // Background analysis - don't await to avoid blocking response
            fetch(`${process.env.NEXT_PUBLIC_APP_URL || 'http://localhost:3000'}/api/ai/analyze-note`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    noteId: note.id,
                    contactId: note.contact_id,
                    content: note.content
                })
            }).catch(err => console.error('Background note analysis failed:', err));
        }

        return NextResponse.json({ data: note });
    } catch (error) {
        return NextResponse.json(
            { error: 'Failed to create note' },
            { status: 500 }
        );
    }
}

export async function PATCH(request: NextRequest) {
    try {
        const supabase = createClient();
        const body = await request.json();
        const { id, ...updateData } = body;

        if (!id) {
            return NextResponse.json({ error: 'Note ID required' }, { status: 400 });
        }

        const { data: note, error } = await supabase
            .from('notes')
            .update(updateData)
            .eq('id', id)
            .select()
            .single();

        if (error) {
            return NextResponse.json({ error: error.message }, { status: 400 });
        }

        // Trigger intelligent status analysis for updated notes with content
        if (note.contact_id && note.content) {
            // Background analysis - don't await to avoid blocking response
            fetch(`${process.env.NEXT_PUBLIC_APP_URL || 'http://localhost:3000'}/api/ai/analyze-note`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    noteId: note.id,
                    contactId: note.contact_id,
                    content: note.content
                })
            }).catch(err => console.error('Background note analysis failed:', err));
        }

        return NextResponse.json({ data: note });
    } catch (error) {
        return NextResponse.json(
            { error: 'Failed to update note' },
            { status: 500 }
        );
    }
}