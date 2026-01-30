'use client';

import { useState, useEffect } from 'react';
import { useParams, useRouter } from 'next/navigation';
import { AppShell } from '@/components/layout/AppShell';
import { Button } from '@/components/ui/Button';
import { LoadingSpinner } from '@/components/ui/LoadingSpinner';
import { ContactTimeline } from '@/components/contacts/ContactTimeline';
import { ContactQuickActions } from '@/components/contacts/ContactQuickActions';
import { InlineNoteEditor } from '@/components/contacts/InlineNoteEditor';
import { VoiceNoteRecorder } from '@/components/capture/VoiceNoteRecorder';
import { Contact } from '@/types';
import { RelationshipMemory, MemoryContext } from '@/components/contacts/RelationshipMemory';
import { DocumentUpload } from '@/components/contacts/DocumentUpload';
import { getRelationshipMemoryAction } from '@/app/actions/memory';
import {
    ArrowLeft,
    Mail,
    Phone,
    Building2,
    Briefcase,
    Linkedin,
    Edit,
    Sparkles,
    Mic,
    FileText,
    Trash2
} from 'lucide-react';
import { Skeleton } from '@/components/ui/Skeleton';

// Add to types if not already present
interface ExtendedContact extends Contact {
    follow_up_status?: string;
    follow_up_urgency?: string;
}

import { toast } from 'sonner';

export default function ContactDetailPage() {
    const params = useParams();
    const router = useRouter();
    const contactId = params.id as string;

    const [contact, setContact] = useState<ExtendedContact | null>(null);
    const [timeline, setTimeline] = useState<any[]>([]);
    const [loading, setLoading] = useState(true);
    const [timelineFilter, setTimelineFilter] = useState<string>('all');
    const [showNoteEditor, setShowNoteEditor] = useState(false);
    const [showVoiceRecorder, setShowVoiceRecorder] = useState(false);
    const [enriching, setEnriching] = useState(false);
    const [deleting, setDeleting] = useState(false);

    // Memory & Documents state
    const [memory, setMemory] = useState<MemoryContext | undefined>(undefined);
    const [isGeneratingMemory, setIsGeneratingMemory] = useState(false);
    const [documents, setDocuments] = useState<any[]>([]);

    const handleGenerateMemory = async () => {
        setIsGeneratingMemory(true);
        const result = await getRelationshipMemoryAction(contactId);
        if (result.success && result.memory) {
            setMemory(result.memory);
        } else {
            toast.error('Failed to generate memory');
        }
        setIsGeneratingMemory(false);
    };

    const fetchDocuments = async () => {
        // Fetch documents logic here or use a hook
        const response = await fetch(`/api/documents?contact_id=${contactId}`);
        if (response.ok) {
            const data = await response.json();
            setDocuments(data.documents || []);
        }
    };

    useEffect(() => {
        if (contactId) {
            fetchContactData();
            fetchDocuments();
        }
    }, [contactId]);

    useEffect(() => {
        if (contactId) {
            fetchTimeline();
        }
    }, [contactId, timelineFilter]);

    const fetchContactData = async () => {
        try {
            // Fetch contact details
            const contactRes = await fetch(`/api/contacts/${contactId}`);
            const contactData = await contactRes.json();
            setContact(contactData.data);
        } catch (error) {
            console.error('Failed to fetch contact details:', error);
        }
    };

    const fetchTimeline = async () => {
        try {
            const timelineRes = await fetch(
                `/api/contacts/${contactId}/timeline?type=${timelineFilter}`
            );
            const timelineData = await timelineRes.json();
            setTimeline(timelineData.data || []);
        } catch (error) {
            console.error('Failed to fetch timeline:', error);
        } finally {
            setLoading(false);
        }
    };

    const getInitials = (firstName: string, lastName?: string) => {
        return `${firstName[0]}${lastName?.[0] || ''}`.toUpperCase();
    };

    const handleSaveNote = async (content: string) => {
        try {
            const response = await fetch('/api/notes', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    contact_id: contactId,
                    content,
                    note_type: 'text'
                })
            });

            if (response.ok) {
                setShowNoteEditor(false);
                toast.success('Note saved!');
                fetchTimeline(); // Refresh only the timeline
            } else {
                toast.error('Failed to save note');
            }
        } catch (error) {
            console.error('Failed to save note:', error);
            toast.error('Failed to save note');
        }
    };

    const handleEnrichContact = async () => {
        setEnriching(true);
        const enrichmentToast = toast.loading('Enriching contact data...');
        try {
            const response = await fetch(`/api/contacts/${contactId}/enrich`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({})
            });

            if (response.ok) {
                fetchContactData(); // Refresh contact data
                toast.success('Contact enriched successfully!', { id: enrichmentToast });
            } else {
                toast.error('Failed to enrich contact', { id: enrichmentToast });
            }
        } catch (error) {
            console.error('Failed to enrich contact:', error);
            toast.error('Failed to enrich contact', { id: enrichmentToast });
        } finally {
            setEnriching(false);
        }
    };

    const handleSaveVoiceNote = async (audioBlob: Blob, duration: number) => {
        const savingToast = toast.loading('Saving voice note...');
        try {
            // Convert blob to base64
            const reader = new FileReader();
            reader.readAsDataURL(audioBlob);
            reader.onloadend = async () => {
                const base64Audio = reader.result as string;

                try {
                    // 1. Save Note Immediately (without transcript initially)
                    const noteResponse = await fetch('/api/notes', {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({
                            contact_id: contactId,
                            note_type: 'voice',
                            audio_data: base64Audio,
                            content: `Voice note (${Math.floor(duration / 60)}:${(duration % 60).toString().padStart(2, '0')})`,
                            details: {
                                duration,
                                source: 'voice_recorder'
                            }
                        })
                    });

                    if (noteResponse.ok) {
                        const { data: savedNote } = await noteResponse.json();

                        setShowVoiceRecorder(false);
                        toast.success('Voice note saved! Transcribing in background...', { id: savingToast });
                        fetchTimeline(); // Show the audio note immediately

                        // 2. Background Transcription
                        // We don't await this block so usage isn't blocked
                        (async () => {
                            try {
                                const transcribeRes = await fetch('/api/ai/transcribe', {
                                    method: 'POST',
                                    headers: { 'Content-Type': 'application/json' },
                                    body: JSON.stringify({ audio_data: base64Audio })
                                });

                                if (transcribeRes.ok) {
                                    const { transcript } = await transcribeRes.json();

                                    // 3. Update Note with Transcript
                                    if (transcript) {
                                        await fetch(`/api/notes/${savedNote.id}`, {
                                            method: 'PATCH',
                                            headers: { 'Content-Type': 'application/json' },
                                            body: JSON.stringify({
                                                content: transcript,
                                                details: {
                                                    ...savedNote.details,
                                                    source_url: savedNote.details.source_url, // Ensure we preserve the audio
                                                    transcript: transcript
                                                }
                                            })
                                        });

                                        toast.success('Transcription complete!');
                                        fetchTimeline(); // Refresh to show transcript
                                    }
                                }
                            } catch (err) {
                                console.error('Background transcription failed:', err);
                                toast.error('Transcription failed, but audio is saved.');
                            }
                        })();

                    } else {
                        const errData = await noteResponse.json().catch(() => ({}));
                        toast.error(errData.error || 'Failed to save voice note', { id: savingToast });
                    }
                } catch (error) {
                    console.error('Save error:', error);
                    toast.error('Failed to save voice note', { id: savingToast });
                }
            };
        } catch (error) {
            console.error('Failed to save voice note:', error);
            toast.error('Failed to save voice note', { id: savingToast });
        }
    };

    const handleDeleteContact = async () => {
        if (!confirm(`Are you sure you want to delete ${contact?.first_name} ${contact?.last_name || ''}? This action cannot be undone.`)) {
            return;
        }

        setDeleting(true);
        const deleteToast = toast.loading('Deleting contact...');
        try {
            const response = await fetch(`/api/contacts/${contactId}`, {
                method: 'DELETE',
            });

            if (response.ok) {
                toast.success('Contact deleted successfully', { id: deleteToast });
                router.push('/contacts');
            } else {
                const error = await response.json();
                toast.error(error.error || 'Failed to delete contact', { id: deleteToast });
            }
        } catch (error) {
            console.error('Failed to delete contact:', error);
            toast.error('An error occurred while deleting the contact', { id: deleteToast });
        } finally {
            setDeleting(false);
        }
    };

    if (loading) {
        return (
            <AppShell>
                <div className="max-w-7xl mx-auto">
                    {/* Skeleton Header */}
                    <div className="flex items-center justify-between mb-8">
                        <Skeleton className="h-4 w-32" />
                        <div className="flex gap-3">
                            <Skeleton className="h-9 w-28 rounded-lg" />
                            <Skeleton className="h-9 w-32 rounded-lg" />
                        </div>
                    </div>

                    <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
                        {/* Left Column Skeleton */}
                        <div className="lg:col-span-1">
                            <div className="sticky top-20 space-y-6">
                                <div className="premium-card p-6 flex flex-col items-center">
                                    <Skeleton className="w-32 h-32 rounded-full mb-4" />
                                    <Skeleton className="h-6 w-48 mb-2" />
                                    <Skeleton className="h-4 w-32 mb-1" />
                                    <Skeleton className="h-4 w-40" />
                                </div>

                                <div className="premium-card p-6 space-y-4">
                                    <Skeleton className="h-3 w-20 mb-4" />
                                    <Skeleton className="h-4 w-full" />
                                    <Skeleton className="h-4 w-full" />
                                    <Skeleton className="h-4 w-full" />
                                </div>

                                <div className="premium-card p-6 space-y-4">
                                    <Skeleton className="h-3 w-24 mb-4" />
                                    <Skeleton className="h-10 w-full rounded-xl" />
                                    <Skeleton className="h-10 w-full rounded-xl" />
                                </div>
                            </div>
                        </div>

                        {/* Right Column Skeleton */}
                        <div className="lg:col-span-2">
                            <div className="premium-card p-6 space-y-8">
                                <div className="space-y-4">
                                    <Skeleton className="h-6 w-48" />
                                    <div className="flex gap-2">
                                        <Skeleton className="h-7 w-16 rounded-full" />
                                        <Skeleton className="h-7 w-20 rounded-full" />
                                        <Skeleton className="h-7 w-16 rounded-full" />
                                    </div>
                                </div>

                                <Skeleton className="h-20 w-full rounded-xl" />

                                <div className="space-y-6">
                                    {[1, 2, 3].map((i) => (
                                        <div key={i} className="flex gap-4">
                                            <Skeleton className="h-10 w-10 rounded-full shrink-0" />
                                            <div className="flex-1 space-y-2 pt-1">
                                                <Skeleton className="h-4 w-1/4" />
                                                <Skeleton className="h-16 w-full rounded-xl" />
                                            </div>
                                        </div>
                                    ))}
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </AppShell>
        );
    }

    if (!contact) {
        return (
            <AppShell>
                <div className="max-w-7xl mx-auto py-12 text-center">
                    <div className="premium-card p-12">
                        <p className="text-display text-gray-400">Contact not found</p>
                        <Button
                            variant="primary"
                            className="mt-4"
                            onClick={() => router.push('/contacts')}
                        >
                            Back to Contacts
                        </Button>
                    </div>
                </div>
            </AppShell>
        );
    }

    return (
        <AppShell>
            <div className="max-w-7xl mx-auto">
                {/* Header Actions */}
                <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 mb-8">
                    <Button
                        variant="ghost"
                        size="sm"
                        onClick={() => router.push('/contacts')}
                        className="hover:bg-transparent px-0 w-fit"
                    >
                        <ArrowLeft className="mr-2 h-4 w-4" />
                        Back to Contacts
                    </Button>

                    <div className="flex items-center gap-3">
                        <Button
                            variant="outline"
                            size="sm"
                            className="flex-1 sm:flex-none h-9 border-stone-200 text-stone-600 hover:bg-stone-50"
                        >
                            <Edit className="mr-2 h-4 w-4" />
                            Edit Contact
                        </Button>
                        <Button
                            variant="outline"
                            size="sm"
                            className="flex-1 sm:flex-none h-9 text-red-600 border-red-100 hover:bg-red-50 hover:text-red-700 hover:border-red-200"
                            onClick={handleDeleteContact}
                            disabled={deleting}
                        >
                            <Trash2 className="mr-2 h-4 w-4" />
                            {deleting ? 'Deleting...' : 'Delete Contact'}
                        </Button>
                    </div>
                </div>

                {/* Two-Column Layout */}
                <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
                    {/* Left Column - Profile */}
                    <div className="lg:col-span-1">
                        <div className="sticky top-20 space-y-6">
                            <div className="premium-card p-6">
                                {/* Avatar */}
                                <div className="flex flex-col items-center mb-6">
                                    <div
                                        className="w-32 h-32 rounded-full bg-gradient-to-br from-indigo-500 to-purple-600 flex items-center justify-center text-white text-3xl font-bold mb-4 shadow-lg"
                                    >
                                        {getInitials(contact.first_name, contact.last_name)}
                                    </div>

                                    <h1 className="text-xl font-bold text-gray-900 text-center">
                                        {contact.first_name} {contact.last_name || ''}
                                    </h1>
                                </div>

                                {contact.job_title && (
                                    <p className="text-body text-center mt-1">
                                        {contact.job_title}
                                    </p>
                                )}

                                {contact.company && (
                                    <p className="text-indigo-600 font-medium text-center mt-1">
                                        {contact.company.name}
                                    </p>
                                )}
                            </div>

                            {/* Contact Info */}
                            <div className="premium-card p-6 space-y-4">
                                {contact.email && (
                                    <div className="flex items-center gap-3 text-sm">
                                        <Mail className="h-4 w-4 text-gray-400" />
                                        <a
                                            href={`mailto:${contact.email}`}
                                            className="text-body hover:text-indigo-600 transition-colors"
                                        >
                                            {contact.email}
                                        </a>
                                    </div>
                                )}

                                {contact.phone && (
                                    <div className="flex items-center gap-3 text-sm">
                                        <Phone className="h-4 w-4 text-gray-400" />
                                        <a
                                            href={`tel:${contact.phone}`}
                                            className="text-body hover:text-indigo-600 transition-colors"
                                        >
                                            {contact.phone}
                                        </a>
                                    </div>
                                )}

                                {contact.company && (
                                    <div className="flex items-center gap-3 text-sm">
                                        <Building2 className="h-4 w-4 text-gray-400" />
                                        <span className="text-body">
                                            {contact.company.name}
                                        </span>
                                    </div>
                                )}

                                {contact.job_title && (
                                    <div className="flex items-center gap-3 text-sm">
                                        <Briefcase className="h-4 w-4 text-gray-400" />
                                        <span className="text-body">
                                            {contact.job_title}
                                        </span>
                                    </div>
                                )}

                                {contact.linkedin_url && (
                                    <div className="flex items-center gap-3 text-sm">
                                        <Linkedin className="h-4 w-4 text-gray-400" />
                                        <a
                                            href={contact.linkedin_url}
                                            target="_blank"
                                            rel="noopener noreferrer"
                                            className="text-blue-600 hover:underline"
                                        >
                                            LinkedIn Profile
                                        </a>
                                    </div>
                                )}
                            </div>

                            {/* Quick Actions */}
                            <div className="premium-card p-6">
                                <h3 className="text-xs font-semibold text-gray-500 uppercase tracking-wider mb-3">
                                    Quick Actions
                                </h3>
                                <ContactQuickActions
                                    email={contact.email}
                                    phone={contact.phone}
                                    onEmail={() => toast.info('Email composer coming soon')}
                                    onAddNote={() => setShowNoteEditor(true)}
                                    onScheduleMeeting={() => router.push(`/meetings/new?contactId=${contactId}`)}
                                />
                            </div>

                            {/* AI Enrichment */}
                            <div className="premium-card p-6">
                                <div className="flex items-center justify-between mb-3">
                                    <h3 className="text-xs font-semibold text-gray-500 uppercase tracking-wider">
                                        AI Enrichment
                                    </h3>
                                    <Sparkles className="h-4 w-4 text-purple-600" />
                                </div>

                                <div className="bg-gradient-to-r from-purple-50 to-indigo-50 rounded-lg p-4 border border-indigo-100">
                                    <p className="text-caption mb-3">
                                        Enhance this contact with AI-powered data enrichment
                                    </p>
                                    <Button
                                        size="sm"
                                        variant="outline"
                                        className="w-full bg-white border-indigo-200 hover:bg-indigo-50"
                                        onClick={handleEnrichContact}
                                        disabled={enriching}
                                    >
                                        <Sparkles className="mr-2 h-4 w-4 text-indigo-600" />
                                        {enriching ? 'Enriching...' : 'Enrich Contact'}
                                    </Button>
                                </div>
                            </div>

                        </div>
                    </div>

                    {/* Right Column - Timeline */}
                    <div className="lg:col-span-2">
                        <div className="premium-card p-6">
                            <div className="mb-6">
                                <h2 className="text-section-header mb-4">
                                    Interaction Timeline
                                </h2>

                                {/* Filter Buttons */}
                                <div className="flex gap-2 flex-wrap">
                                    {['all', 'meeting', 'email', 'note', 'capture'].map((filter) => (
                                        <button
                                            key={filter}
                                            onClick={() => setTimelineFilter(filter)}
                                            className={`px-3 py-1.5 rounded-full text-xs font-medium transition-colors ${timelineFilter === filter
                                                ? 'bg-indigo-100 text-indigo-700'
                                                : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
                                                }`}
                                        >
                                            {filter.charAt(0).toUpperCase() + filter.slice(1)}
                                        </button>
                                    ))}
                                </div>
                            </div>

                            {/* Timeline */}
                            {showNoteEditor && (
                                <div className="mb-6 border-b border-gray-100 pb-6">
                                    <InlineNoteEditor
                                        onSave={handleSaveNote}
                                        onCancel={() => setShowNoteEditor(false)}
                                        placeholder="Add a note about this contact..."
                                    />
                                </div>
                            )}

                            {showVoiceRecorder && (
                                <div className="mb-6 border-b border-gray-100 pb-6">
                                    <VoiceNoteRecorder
                                        onSave={handleSaveVoiceNote}
                                        onCancel={() => setShowVoiceRecorder(false)}
                                    />
                                </div>
                            )}

                            {/* Note Type Selector */}
                            {!showNoteEditor && !showVoiceRecorder && (
                                <div className="flex gap-3 mb-8 p-4 bg-gray-50 rounded-lg border border-dashed border-gray-300">
                                    <Button
                                        variant="ghost"
                                        size="sm"
                                        onClick={() => setShowNoteEditor(true)}
                                        className="flex-1 hover:bg-white hover:shadow-sm"
                                    >
                                        <FileText className="mr-2 h-4 w-4 text-gray-500" />
                                        Text Note
                                    </Button>
                                    <div className="w-px bg-gray-300"></div>
                                    <Button
                                        variant="ghost"
                                        size="sm"
                                        onClick={() => setShowVoiceRecorder(true)}
                                        className="flex-1 hover:bg-white hover:shadow-sm"
                                    >
                                        <Mic className="mr-2 h-4 w-4 text-gray-500" />
                                        Voice Note
                                    </Button>
                                </div>
                            )}

                            <ContactTimeline
                                timeline={timeline}
                                onAddNote={() => setShowNoteEditor(true)}
                            />
                        </div>
                    </div>
                </div>
            </div>
        </AppShell >
    );
}
