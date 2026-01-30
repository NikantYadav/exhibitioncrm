/**
 * Profile Service - Fetch and cache user profile data
 */

import { createClient } from '@/lib/supabase/server';
import { UserProfile } from '@/app/actions/profile-actions';
import { EmbeddingsService } from './embeddings';

let cachedProfile: UserProfile | null = null;
let lastFetch: number = 0;
const CACHE_DURATION = 5 * 60 * 1000; // 5 minutes

/**
 * Get user profile with caching
 */
export async function getUserProfile(): Promise<UserProfile | null> {
    const now = Date.now();

    // Return cached profile if still valid
    if (cachedProfile && (now - lastFetch) < CACHE_DURATION) {
        return cachedProfile;
    }

    const supabase = createClient();

    try {
        const { data, error } = await supabase
            .from('user_profiles')
            .select('*')
            .single();

        if (error) {
            // If no profile exists, return null
            if (error.code === 'PGRST116') {
                cachedProfile = null;
                lastFetch = now;
                return null;
            }
            throw error;
        }

        cachedProfile = data;
        lastFetch = now;
        return data;
    } catch (error) {
        console.error('Get profile error:', error);
        return null;
    }
}

/**
 * Clear profile cache (call after updates)
 */
export function clearProfileCache() {
    cachedProfile = null;
    lastFetch = 0;
}

/**
 * Build AI context string from user profile
 */
export function buildProfileContext(profile: UserProfile | null): string {
    if (!profile) return '';

    const parts: string[] = [];

    // Basic info
    if (profile.profile_type === 'company') {
        parts.push(`I represent ${profile.name}`);
    } else if (profile.profile_type === 'employee') {
        parts.push(`I am ${profile.name} from ${profile.representing_company || profile.name}`);
        if (profile.employee_role) parts.push(`working as ${profile.employee_role}`);
    } else {
        parts.push(`I am ${profile.name}`);
    }

    // Industry and location
    if (profile.industry) parts.push(`in the ${profile.industry} industry`);
    if (profile.location) parts.push(`based in ${profile.location}`);

    // Value proposition
    if (profile.value_proposition) {
        parts.push(`\nOur value proposition: ${profile.value_proposition}`);
    }

    // Products/services
    if (profile.products_services) {
        parts.push(`\nWe offer: ${profile.products_services}`);
    }

    // Target audience
    if (profile.target_audience) {
        parts.push(`\nOur target audience: ${profile.target_audience}`);
    }

    // Key differentiators
    if (profile.key_differentiators) {
        parts.push(`\nWhat sets us apart: ${profile.key_differentiators}`);
    }

    // Additional context
    if (profile.additional_context) {
        parts.push(`\nAdditional context: ${profile.additional_context}`);
    }

    return parts.join('. ');
}

/**
 * Get comprehensive context (Profile + RAG Global Context)
 */
export async function getFullAIContext(): Promise<string> {
    const profile = await getUserProfile();
    const profileContext = buildProfileContext(profile);

    try {
        const ragContext = await EmbeddingsService.getGlobalContext();
        return `${profileContext}${ragContext}`;
    } catch (error) {
        console.error('Failed to get RAG context for profile:', error);
        return profileContext;
    }
}
