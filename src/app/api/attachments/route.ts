import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';

const MAX_FILE_SIZE = 10 * 1024 * 1024; // 10MB
const ALLOWED_FILE_TYPES = [
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'image/jpeg',
    'image/png',
    'image/gif',
    'text/plain',
];

export async function POST(request: NextRequest) {
    try {
        const supabase = createClient();

        // Check authentication
        const { data: { user }, error: authError } = await supabase.auth.getUser();
        if (authError || !user) {
            return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
        }

        const formData = await request.formData();
        const file = formData.get('file') as File;
        const email_draft_id = formData.get('email_draft_id') as string;
        const interaction_id = formData.get('interaction_id') as string;

        if (!file) {
            return NextResponse.json(
                { error: 'File is required' },
                { status: 400 }
            );
        }

        // Validate file size
        if (file.size > MAX_FILE_SIZE) {
            return NextResponse.json(
                { error: 'File size exceeds 10MB limit' },
                { status: 400 }
            );
        }

        // Validate file type
        if (!ALLOWED_FILE_TYPES.includes(file.type)) {
            return NextResponse.json(
                { error: 'File type not allowed' },
                { status: 400 }
            );
        }

        // Generate unique file path
        const timestamp = Date.now();
        const sanitizedFileName = file.name.replace(/[^a-zA-Z0-9.-]/g, '_');
        const storagePath = `attachments/${user.id}/${timestamp}_${sanitizedFileName}`;

        // Upload to Supabase Storage
        const { data: uploadData, error: uploadError } = await supabase.storage
            .from('attachments')
            .upload(storagePath, file, {
                contentType: file.type,
                upsert: false,
            });

        if (uploadError) {
            console.error('Upload error:', uploadError);
            return NextResponse.json(
                { error: 'Failed to upload file' },
                { status: 500 }
            );
        }

        // Create attachment record in database
        const { data: attachment, error: dbError } = await supabase
            .from('attachments')
            .insert({
                email_draft_id: email_draft_id || null,
                interaction_id: interaction_id || null,
                file_name: file.name,
                file_type: file.type,
                file_size: file.size,
                storage_path: storagePath,
            })
            .select()
            .single();

        if (dbError) {
            // Rollback: delete uploaded file
            await supabase.storage.from('attachments').remove([storagePath]);
            throw dbError;
        }

        // Get public URL
        const { data: { publicUrl } } = supabase.storage
            .from('attachments')
            .getPublicUrl(storagePath);

        return NextResponse.json({
            attachment: {
                ...attachment,
                url: publicUrl,
            },
        }, { status: 201 });
    } catch (error) {
        console.error('Attachment upload error:', error);
        return NextResponse.json(
            { error: 'Failed to upload attachment' },
            { status: 500 }
        );
    }
}

export async function GET(request: NextRequest) {
    try {
        const supabase = createClient();

        // Check authentication
        const { data: { user }, error: authError } = await supabase.auth.getUser();
        if (authError || !user) {
            return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
        }

        const searchParams = request.nextUrl.searchParams;
        const email_draft_id = searchParams.get('email_draft_id');
        const interaction_id = searchParams.get('interaction_id');

        let query = supabase.from('attachments').select('*');

        if (email_draft_id) {
            query = query.eq('email_draft_id', email_draft_id);
        } else if (interaction_id) {
            query = query.eq('interaction_id', interaction_id);
        }

        const { data: attachments, error } = await query;

        if (error) {
            throw error;
        }

        // Add public URLs
        const attachmentsWithUrls = attachments?.map(attachment => {
            const { data: { publicUrl } } = supabase.storage
                .from('attachments')
                .getPublicUrl(attachment.storage_path);

            return {
                ...attachment,
                url: publicUrl,
            };
        });

        return NextResponse.json({ attachments: attachmentsWithUrls });
    } catch (error) {
        console.error('Fetch attachments error:', error);
        return NextResponse.json(
            { error: 'Failed to fetch attachments' },
            { status: 500 }
        );
    }
}

export async function DELETE(request: NextRequest) {
    try {
        const supabase = createClient();

        // Check authentication
        const { data: { user }, error: authError } = await supabase.auth.getUser();
        if (authError || !user) {
            return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
        }

        const { searchParams } = request.nextUrl;
        const id = searchParams.get('id');

        if (!id) {
            return NextResponse.json(
                { error: 'Attachment ID is required' },
                { status: 400 }
            );
        }

        // Fetch attachment to get storage path
        const { data: attachment, error: fetchError } = await supabase
            .from('attachments')
            .select('storage_path')
            .eq('id', id)
            .single();

        if (fetchError || !attachment) {
            return NextResponse.json(
                { error: 'Attachment not found' },
                { status: 404 }
            );
        }

        // Delete from storage
        const { error: storageError } = await supabase.storage
            .from('attachments')
            .remove([attachment.storage_path]);

        if (storageError) {
            console.error('Storage deletion error:', storageError);
        }

        // Delete from database
        const { error: dbError } = await supabase
            .from('attachments')
            .delete()
            .eq('id', id);

        if (dbError) {
            throw dbError;
        }

        return NextResponse.json({ success: true });
    } catch (error) {
        console.error('Delete attachment error:', error);
        return NextResponse.json(
            { error: 'Failed to delete attachment' },
            { status: 500 }
        );
    }
}
