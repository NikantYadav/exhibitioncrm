import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';

export async function PUT(
    request: NextRequest,
    { params }: { params: { id: string; targetId: string } }
) {
    try {
        const supabase = createClient();
        const { targetId } = params;
        const body = await request.json();

        const { data: target, error } = await supabase
            .from('target_companies')
            .update(body)
            .eq('id', targetId)
            .select(`
                *,
                company:companies(*)
            `)
            .single();

        if (error) {
            return NextResponse.json({ error: error.message }, { status: 400 });
        }

        return NextResponse.json({ data: target });
    } catch (error) {
        return NextResponse.json(
            { error: 'Failed to update target company' },
            { status: 500 }
        );
    }
}

export async function DELETE(
    request: NextRequest,
    { params }: { params: { id: string; targetId: string } }
) {
    try {
        const supabase = createClient();
        const { targetId } = params;

        const { error } = await supabase
            .from('target_companies')
            .delete()
            .eq('id', targetId);

        if (error) {
            return NextResponse.json({ error: error.message }, { status: 400 });
        }

        return NextResponse.json({ message: 'Target company deleted successfully' });
    } catch (error) {
        return NextResponse.json(
            { error: 'Failed to delete target company' },
            { status: 500 }
        );
    }
}
