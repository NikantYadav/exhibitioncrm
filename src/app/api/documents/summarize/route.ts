import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { DocumentParser } from '@/lib/services/document-parser';

export async function POST(request: NextRequest) {
    try {
        const supabase = createClient();

        // Check authentication
        const { data: { user }, error: authError } = await supabase.auth.getUser();
        if (authError || !user) {
            return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
        }

        const { documentId, style } = await request.json();

        if (!documentId) {
            return NextResponse.json(
                { error: 'Document ID is required' },
                { status: 400 }
            );
        }

        // Fetch document from database
        const { data: document, error: docError } = await supabase
            .from('documents')
            .select('*')
            .eq('id', documentId)
            .single();

        if (docError || !document) {
            return NextResponse.json(
                { error: 'Document not found' },
                { status: 404 }
            );
        }

        // Download file from Supabase Storage
        const { data: fileData, error: downloadError } = await supabase.storage
            .from('documents')
            .download(document.storage_path);

        if (downloadError || !fileData) {
            return NextResponse.json(
                { error: 'Failed to download document' },
                { status: 500 }
            );
        }

        // Convert blob to buffer
        const arrayBuffer = await fileData.arrayBuffer();
        const buffer = Buffer.from(arrayBuffer);

        // Parse document
        const parsed = await DocumentParser.parseDocument(buffer, document.file_type);

        // Generate summary
        const summary = await DocumentParser.summarizeDocument(parsed.text, {
            style: style || 'brief',
            maxLength: 500,
        });

        // Update document with summary
        const { error: updateError } = await supabase
            .from('documents')
            .update({
                ai_summary: summary,
                summary_generated_at: new Date().toISOString(),
                summary_model: 'gemini-2.5-flash',
                summary_confidence: 0.85,
            })
            .eq('id', documentId);

        if (updateError) {
            console.error('Failed to update document:', updateError);
        }

        return NextResponse.json({
            success: true,
            summary,
            metadata: parsed.metadata,
        });
    } catch (error) {
        console.error('Document summarization error:', error);
        return NextResponse.json(
            { error: 'Failed to summarize document' },
            { status: 500 }
        );
    }
}
