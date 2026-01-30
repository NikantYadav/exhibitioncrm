import { NextRequest, NextResponse } from 'next/server';
import { createServerClient } from '@/lib/supabase/client';

export async function DELETE(
    request: NextRequest,
    { params }: { params: { id: string } }
) {
    try {
        const supabase = createServerClient();
        const { id } = params;

        const { error } = await supabase
            .from('captures')
            .delete()
            .eq('id', id);

        if (error) {
            return NextResponse.json({ error: error.message }, { status: 400 });
        }

        return NextResponse.json({ message: 'Capture deleted successfully' });
    } catch (error) {
        return NextResponse.json(
            { error: 'Failed to delete capture' },
            { status: 500 }
        );
    }
}
