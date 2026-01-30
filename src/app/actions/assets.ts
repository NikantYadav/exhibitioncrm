'use server';

import { createClient } from '@/lib/supabase/server';
import { revalidatePath } from 'next/cache';

export interface MarketingAsset {
    id: string;
    name: string;
    description?: string;
    file_url: string;
    asset_type: 'brochure' | 'catalog' | 'whitepaper' | 'other';
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

export async function createAsset(data: Partial<MarketingAsset>) {
    const supabase = createClient();
    const { error } = await supabase.from('marketing_assets').insert(data);
    if (error) return { error: error.message };
    revalidatePath('/settings');
    return { success: true };
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
    const { error } = await supabase
        .from('marketing_assets')
        .delete()
        .eq('id', id);
    if (error) return { error: error.message };
    revalidatePath('/settings');
    return { success: true };
}
