import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';

export async function PATCH(request: NextRequest, { params }: { params: { id: string } }) {
    try {
        const supabase = createClient();
        const body = await request.json();
        const noteId = params.id;

        const { data: note, error } = await supabase
            .from('notes')
            .update(body)
            .eq('id', noteId)
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

export async function DELETE(request: NextRequest, { params }: { params: { id: string } }) {
    try {
        const supabase = createClient();
        const noteId = params.id;

        const { error } = await supabase
            .from('notes')
            .delete()
            .eq('id', noteId);

        if (error) {
            return NextResponse.json({ error: error.message }, { status: 400 });
        }

        return NextResponse.json({ success: true });
    } catch (error) {
        return NextResponse.json(
            { error: 'Failed to delete note' },
            { status: 500 }
        );
    }
}