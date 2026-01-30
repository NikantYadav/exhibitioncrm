import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';

export async function GET(
    request: NextRequest,
    { params }: { params: { id: string } }
) {
    try {
        const supabase = createClient();
        const { id } = params;

        const { data: targets, error } = await supabase
            .from('target_companies')
            .select(`
                *,
                company:companies(*)
            `)
            .eq('event_id', id)
            .order('priority', { ascending: false })
            .order('created_at', { ascending: false });

        if (error) {
            return NextResponse.json({ error: error.message }, { status: 400 });
        }

        return NextResponse.json({ data: targets || [] });
    } catch (error) {
        return NextResponse.json(
            { error: 'Failed to fetch target companies' },
            { status: 500 }
        );
    }
}

export async function POST(
    request: NextRequest,
    { params }: { params: { id: string } }
) {
    try {
        const supabase = createClient();
        const { id } = params;
        const body = await request.json();

        const { data: target, error } = await supabase
            .from('target_companies')
            .insert({
                event_id: id,
                ...body
            })
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
            { error: 'Failed to create target company' },
            { status: 500 }
        );
    }
}
