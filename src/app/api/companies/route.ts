import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

export async function GET(request: NextRequest) {
    try {
        const supabase = createClient();
        const { searchParams } = new URL(request.url);
        const search = searchParams.get('search');

        let query = supabase
            .from('companies')
            .select('*')
            .order('name', { ascending: true });

        if (search) {
            query = query.or(`name.ilike.%${search}%,website.ilike.%${search}%,industry.ilike.%${search}%`);
        }

        const { data: companies, error } = await query.limit(20);

        if (error) {
            return NextResponse.json({ error: error.message }, { status: 400 });
        }

        return NextResponse.json({ data: companies || [] });
    } catch (error) {
        return NextResponse.json(
            { error: 'Failed to fetch companies' },
            { status: 500 }
        );
    }
}

export async function POST(request: NextRequest) {
    try {
        const supabase = createClient();
        const body = await request.json();

        const { data: company, error } = await supabase
            .from('companies')
            .insert(body)
            .select()
            .single();

        if (error) {
            return NextResponse.json({ error: error.message }, { status: 400 });
        }

        return NextResponse.json({ data: company });
    } catch (error) {
        return NextResponse.json(
            { error: 'Failed to create company' },
            { status: 500 }
        );
    }
}
