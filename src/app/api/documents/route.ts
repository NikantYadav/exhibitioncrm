import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { PrepService } from '@/lib/services/prep-service';

export async function POST(request: NextRequest) {
    try {
        const body = await request.json();
        const { contact_id, name, file_url, description } = body;

        const supabase = createClient();

        // 1. Save document record
        const { data: doc, error } = await supabase
            .from('contact_documents')
            .insert({
                contact_id,
                name,
                file_url,
                description,
                file_type: 'pdf'
            })
            .select()
            .single();

        if (error) {
            console.error('Doc save error:', error);
            return NextResponse.json({ error: 'Failed to save document' }, { status: 500 });
        }

        // 2. Generate summary (background process in real app, simplified here)
        // Fetch document content (mocked for now as we don't have real file access)
        const summary = await PrepService.summarizeDocument("Mock document content for " + name);

        // Update doc with summary
        await supabase
            .from('contact_documents')
            .update({ summary })
            .eq('id', doc.id);

        // 3. Log interaction
        await supabase.from('interactions').insert({
            contact_id,
            interaction_type: 'document_upload',
            summary: `Shared Document: ${name}`,
            details: {
                document_id: doc.id,
                file_url
            }
        });

        return NextResponse.json({ success: true, document: { ...doc, summary } });

    } catch (error) {
        console.error('Documents API error:', error);
        return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
    }
}

export async function GET(request: NextRequest) {
    try {
        const { searchParams } = new URL(request.url);
        const contact_id = searchParams.get('contact_id');

        if (!contact_id) {
            return NextResponse.json({ error: 'Contact ID required' }, { status: 400 });
        }

        const supabase = createClient();
        const { data: documents, error } = await supabase
            .from('contact_documents')
            .select('*')
            .eq('contact_id', contact_id)
            .order('created_at', { ascending: false });

        if (error) {
            return NextResponse.json({ error: 'Failed to fetch' }, { status: 500 });
        }

        return NextResponse.json({ documents });
    } catch (error) {
        return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
    }
}
