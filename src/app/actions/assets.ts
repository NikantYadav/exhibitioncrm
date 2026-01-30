'use server';

import { createClient } from '@/lib/supabase/server';
import { createClient as createSupabaseClient } from '@supabase/supabase-js';
import { revalidatePath } from 'next/cache';

export interface MarketingAsset {
    id: string;
    name: string;
    description?: string;
    file_url: string;
    file_size?: number;
    is_active: boolean;
    created_at: string;
}

export async function getAssets() {
    const supabase = createClient();
    const { data: assets, error } = await supabase
        .from('marketing_assets')
        .select('*')
        .order('created_at', { ascending: false });

    if (error) {
        console.error('Fetch assets error:', error);
        return [];
    }
    return assets as MarketingAsset[];
}

import { DocumentProcessor } from '@/lib/services/document-processor';
import { EmbeddingsService } from '@/lib/services/embeddings';

export async function createAsset(data: Partial<MarketingAsset>) {
    const supabase = createClient();

    const { data: asset, error } = await supabase
        .from('marketing_assets')
        .insert(data)
        .select()
        .single();

    if (error) {
        console.error('[createAsset] Insert Error:', error);
        return { error: error.message };
    }

    // Trigger RAG Processing
    if (asset) {
        try {
            // This runs asynchronously to not block the UI completely if we wanted, 
            // but for now we await to ensure it works.
            const text = await DocumentProcessor.processAsset(asset as MarketingAsset);
            if (text) {
                const chunks = DocumentProcessor.chunkText(text);
                await EmbeddingsService.storeChunks(asset.id, chunks);
            }
        } catch (ragError) {
            console.error('RAG Processing failed (continuing anyway):', ragError);
        }
    }

    revalidatePath('/settings');
    return { success: true, asset: asset as MarketingAsset };
}

export async function updateAsset(id: string, data: Partial<MarketingAsset>) {
    const supabase = createClient();
    const { error } = await supabase
        .from('marketing_assets')
        .update(data)
        .eq('id', id);
    if (error) return { error: error.message };
    revalidatePath('/settings');
    return { success: true };
}


export async function deleteAsset(id: string) {
    const supabase = createClient();

    // 1. Get the asset to find the file URL
    const { data: asset, error: fetchError } = await supabase
        .from('marketing_assets')
        .select('file_url')
        .eq('id', id)
        .single();

    if (fetchError) {
        console.error('Fetch asset for deletion error:', fetchError);
        return { error: 'Could not find asset to delete' };
    }

    // 2. Delete the file from Supabase Storage using Admin Client
    if (asset?.file_url) {
        try {
            const supabaseAdmin = createSupabaseClient(
                process.env.NEXT_PUBLIC_SUPABASE_URL!,
                process.env.SUPABASE_SERVICE_ROLE_KEY!
            );

            // Extract filename from URL (e.g., .../marketing-assets/filename)
            const urlParts = asset.file_url.split('/');
            const fileName = urlParts[urlParts.length - 1];

            if (fileName) {
                const { error: storageError } = await supabaseAdmin.storage
                    .from('marketing-assets')
                    .remove([fileName]);

                if (storageError) {
                    console.error('Storage deletion error:', storageError);
                    // We continue even if storage deletion fails, to ensure DB stays in sync
                }
            }
        } catch (e) {
            console.error('Failed to clean up storage:', e);
        }
    }

    // 3. Delete from DB
    const { error } = await supabase
        .from('marketing_assets')
        .delete()
        .eq('id', id);

    if (error) return { error: error.message };
    revalidatePath('/settings');
    return { success: true };
}
