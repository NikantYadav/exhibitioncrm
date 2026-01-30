'use server';

import { createClient } from '@/lib/supabase/server';
import { revalidatePath } from 'next/cache';

export interface UserProfile {
    id?: string;
    profile_type: 'company' | 'individual' | 'employee';
    name: string;
    tagline?: string;
    industry?: string;
    location?: string;
    website?: string;
    products_services?: string;
    value_proposition?: string;
    target_audience?: string;
    key_differentiators?: string;
    company_size?: string;
    founded_year?: number;
    employee_role?: string;
    employee_department?: string;
    representing_company?: string;
    linkedin_url?: string;
    twitter_url?: string;
    facebook_url?: string;
    instagram_url?: string;
    email?: string;
    phone?: string;
    additional_context?: string;
    ai_tone?: 'professional' | 'casual' | 'formal' | 'friendly';
}

/**
 * Get the current user profile
 */
export async function getProfile(): Promise<{ profile?: UserProfile; error?: string }> {
    const supabase = createClient();

    try {
        const { data, error } = await supabase
            .from('user_profiles')
            .select('*')
            .single();

        if (error) {
            // If no profile exists, return empty
            if (error.code === 'PGRST116') {
                return { profile: undefined };
            }
            throw error;
        }

        return { profile: data };
    } catch (error) {
        console.error('Get profile error:', error);
        return { error: 'Failed to fetch profile' };
    }
}

/**
 * Update or create user profile
 */
export async function updateProfile(profileData: UserProfile): Promise<{ success?: boolean; error?: string }> {
    const supabase = createClient();

    try {
        // Check if profile exists
        const { data: existing } = await supabase
            .from('user_profiles')
            .select('id')
            .single();

        if (existing) {
            // Update existing profile
            const { error } = await supabase
                .from('user_profiles')
                .update(profileData)
                .eq('id', existing.id);

            if (error) throw error;
        } else {
            // Create new profile
            const { error } = await supabase
                .from('user_profiles')
                .insert(profileData);

            if (error) throw error;
        }

        revalidatePath('/profile');
        return { success: true };
    } catch (error) {
        console.error('Update profile error:', error);
        return { error: 'Failed to update profile' };
    }
}

/**
 * Delete user profile
 */
export async function deleteProfile(): Promise<{ success?: boolean; error?: string }> {
    const supabase = createClient();

    try {
        const { error } = await supabase
            .from('user_profiles')
            .delete()
            .neq('id', '00000000-0000-0000-0000-000000000000'); // Delete all profiles

        if (error) throw error;

        revalidatePath('/profile');
        return { success: true };
    } catch (error) {
        console.error('Delete profile error:', error);
        return { error: 'Failed to delete profile' };
    }
}
