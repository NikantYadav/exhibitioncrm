export interface Event {
    id: string;
    name: string;
    description?: string;
    location?: string;
    start_date: string;
    end_date?: string;
    event_type: 'exhibition' | 'conference' | 'meeting';
    status: 'upcoming' | 'ongoing' | 'completed';
    created_at: string;
    updated_at: string;
}

export interface Company {
    id: string;
    name: string;
    domain?: string;
    website?: string;
    industry?: string;
    description?: string;
    location?: string;
    region?: string;
    company_size?: string;
    products_services?: string;
    is_enriched: boolean;
    enrichment_confidence?: number;
    created_at: string;
    updated_at: string;
}

export interface Contact {
    id: string;
    company_id?: string;
    first_name: string;
    last_name?: string;
    email?: string;
    phone?: string;
    job_title?: string;
    linkedin_url?: string;
    notes?: string;
    avatar_url?: string;
    created_at: string;
    updated_at: string;
    // Relations
    company?: Company;
}

export interface Interaction {
    id: string;
    contact_id?: string;
    event_id?: string;
    interaction_type: 'capture' | 'meeting' | 'email' | 'note';
    interaction_date: string;
    summary?: string;
    details?: Record<string, any>;
    created_at: string;
    updated_at: string;
    // Relations
    contact?: Contact;
    event?: Event;
}

export interface Note {
    id: string;
    contact_id?: string;
    event_id?: string;
    interaction_id?: string;
    content: string;
    note_type: 'text' | 'voice' | 'photo';
    source_url?: string;
    created_at: string;
    updated_at: string;
    // Relations
    contact?: Contact;
    event?: Event;
}

export interface Document {
    id: string;
    contact_id?: string;
    company_id?: string;
    event_id?: string;
    file_name: string;
    file_type?: string;
    file_size?: number;
    storage_path: string;
    summary?: string;
    created_at: string;
    updated_at: string;
}

export interface Capture {
    id: string;
    event_id?: string;
    capture_type: 'card_scan' | 'qr_code' | 'manual' | 'badge_scan' | 'photo_upload';
    image_url?: string;
    raw_data?: Record<string, any>;
    extracted_data?: {
        name?: string;
        company?: string;
        email?: string;
        phone?: string;
        job_title?: string;
        [key: string]: any;
    };
    status: 'pending' | 'processing' | 'completed' | 'failed';
    contact_id?: string;
    created_at: string;
    updated_at: string;
    // Relations
    event?: Event;
    contact?: Contact;
}

export interface EnrichmentQueue {
    id: string;
    contact_id?: string;
    company_id?: string;
    status: 'pending' | 'processing' | 'completed' | 'failed';
    enrichment_type: 'company_info' | 'linkedin' | 'full';
    result?: Record<string, any>;
    error?: string;
    created_at: string;
    updated_at: string;
}

export interface EmailDraft {
    id: string;
    contact_id?: string;
    event_id?: string;
    email_type: 'pre_event' | 'follow_up' | 'pre_meeting';
    subject?: string;
    body?: string;
    status: 'draft' | 'sent' | 'archived';
    sent_at?: string;
    created_at: string;
    updated_at: string;
    // Relations
    contact?: Contact;
    event?: Event;
}

export interface TargetCompany {
    id: string;
    event_id: string;
    company_id: string;
    priority: 'low' | 'medium' | 'high';
    booth_location?: string;
    talking_points?: string;
    notes?: string;
    status: 'not_contacted' | 'contacted' | 'followed_up';
    created_at: string;
    updated_at: string;
    // Relations
    event?: Event;
    company?: Company;
}

// API Response Types
export interface ApiResponse<T> {
    data?: T;
    error?: string;
    message?: string;
}

// Form Types
export interface ContactFormData {
    first_name: string;
    last_name?: string;
    email?: string;
    phone?: string;
    job_title?: string;
    company_name?: string;
    notes?: string;
}

export interface EventFormData {
    name: string;
    description?: string;
    location?: string;
    start_date: string;
    end_date?: string;
    event_type: 'exhibition' | 'conference' | 'meeting';
}

export interface CompanyFormData {
    name: string;
    website?: string;
    industry?: string;
    description?: string;
    location?: string;
}

// Offline Sync Types
export interface SyncQueueItem {
    id: string;
    operation: 'create' | 'update' | 'delete';
    table: string;
    data: Record<string, any>;
    timestamp: number;
    status: 'pending' | 'syncing' | 'completed' | 'failed';
    retries: number;
}

export interface OfflineCache {
    events: Event[];
    contacts: Contact[];
    companies: Company[];
    lastSync: number;
}

export interface MeetingBrief {
    id: string;
    meeting_date: string;
    meeting_type: string;
    meeting_location?: string;
    ai_talking_points?: string;
    interaction_summary?: string;
    pre_meeting_notes?: string;
    post_meeting_notes?: string;
    status: string;
    contact: {
        id: string;
        first_name: string;
        last_name?: string;
        email?: string;
        job_title?: string;
        company?: {
            name: string;
            industry?: string;
            website?: string;
        };
        event?: Event;
    };
    company?: {
        name: string;
        industry?: string;
    };
    event?: Event;
    prep_data?: {
        who_is_this?: string;
        relationship_summary?: string;
        key_talking_points?: string[];
        interaction_highlights?: string;
    };
}
