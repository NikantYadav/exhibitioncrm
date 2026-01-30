import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';

export async function PATCH(
    request: NextRequest,
    { params }: { params: { id: string } }
) {
    try {
        const supabase = createClient();
        const body = await request.json();
        const { id } = params;

        const { data: note, error } = await supabase
            .from('notes')
            .update(body)
            .eq('id', id)
            .select()
            .single();

        if (error) {
            return NextResponse.json({ error: error.message }, { status: 400 });
        }

        return NextResponse.json({ data: note });
    } catch (error) {
        return NextResponse.json(
            { error: 'Failed to update note' },
            { status: 500 }
        );
    }
}
