import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';

export async function GET(
    request: NextRequest,
    { params }: { params: { id: string } }
) {
    try {
        const supabase = createClient();
        const { id } = params;
        const { searchParams } = new URL(request.url);
        const status = searchParams.get('status');

        let query = supabase
            .from('captures')
            .select(`
                *,
                contact:contacts(
                    *,
                    company:companies(*)
                )
            `)
            .eq('event_id', id)
            .order('created_at', { ascending: false });

        if (status) {
            query = query.eq('status', status);
        }

        const { data: captures, error } = await query;

        if (error) {
            return NextResponse.json({ error: error.message }, { status: 400 });
        }

        return NextResponse.json({ data: captures || [] });
    } catch (error) {
        return NextResponse.json(
            { error: 'Failed to fetch captures' },
            { status: 500 }
        );
    }
}
