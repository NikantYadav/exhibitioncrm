import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';

export async function DELETE(
    request: NextRequest,
    { params }: { params: { id: string } }
) {
    try {
        const supabase = createClient();
        const id = params.id;

        console.log('--- Draft Deletion Request ---');
        console.log('Draft ID:', id);
        console.log('Draft ID type:', typeof id);

        if (!id) {
            return NextResponse.json({ error: 'ID is required' }, { status: 400 });
        }

        // First, check if the draft exists
        const { data: existingDraft, error: fetchError } = await supabase
            .from('email_drafts')
            .select('*')
            .eq('id', id)
            .single();

        console.log('Existing draft check:', {
            found: !!existingDraft,
            error: fetchError?.message,
            draft: existingDraft
        });

        // Perform the deletion
        const { data, error } = await supabase
            .from('email_drafts')
            .delete()
            .eq('id', id)
            .select();

        if (error) {
            console.error('Database error during deletion:', error);
            return NextResponse.json({ error: error.message }, { status: 500 });
        }

        const deletedCount = data?.length || 0;
        console.log('Successfully processed deletion. Rows affected:', deletedCount);
        console.log('Deleted data:', data);

        // Even if 0 rows were deleted, we return success so the frontend remains in sync
        // unless there was an actual database error.
        return NextResponse.json({
            success: true,
            deleted: deletedCount,
            message: deletedCount > 0 ? 'Draft deleted' : 'Draft not found or already deleted'
        });
    } catch (error: any) {
        console.error('Unexpected delete draft error:', error);
        return NextResponse.json(
            { error: error.message || 'Failed to delete email draft' },
            { status: 500 }
        );
    }
}
