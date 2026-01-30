'use client';

import { useState, useEffect } from 'react';
import { useParams, useRouter } from 'next/navigation';
import { AppShell } from '@/components/layout/AppShell';
import { Button } from '@/components/ui/Button';
import { LoadingSpinner } from '@/components/ui/LoadingSpinner';
import { ContactTimeline } from '@/components/contacts/ContactTimeline';
import { EnrichmentPanel } from '@/components/contacts/EnrichmentPanel';
import { ContactQuickActions } from '@/components/contacts/ContactQuickActions';
import { InlineNoteEditor } from '@/components/contacts/InlineNoteEditor';
import { VoiceNoteRecorder } from '@/components/capture/VoiceNoteRecorder';
import { Contact } from '@/types';
import { cn } from '@/lib/utils';
import { RelationshipMemory, MemoryContext } from '@/components/contacts/RelationshipMemory';
import { DocumentUpload } from '@/components/contacts/DocumentUpload';
import { Modal } from '@/components/ui/Modal';
import { Input } from '@/components/ui/Input';
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
    Trash2,
    Loader2,
    Command,
    ArrowUpRight
} from 'lucide-react';
import { Skeleton } from '@/components/ui/Skeleton';
import { Badge } from '@/components/ui/Badge';

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
    const [showEditModal, setShowEditModal] = useState(false);
    const [editForm, setEditForm] = useState({
        first_name: '',
        last_name: '',
        email: '',
        phone: '',
        job_title: '',
        linkedin_url: ''
    });

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
            if (contactData.data) {
                setEditForm({
                    first_name: contactData.data.first_name || '',
                    last_name: contactData.data.last_name || '',
                    email: contactData.data.email || '',
                    phone: contactData.data.phone || '',
                    job_title: contactData.data.job_title || '',
                    linkedin_url: contactData.data.linkedin_url || ''
                });
            }
        } catch (error) {
            console.error('Failed to fetch contact details:', error);
        }
    };

    const handleUpdateContact = async (e: React.FormEvent) => {
        e.preventDefault();
        const updateToast = toast.loading('Updating contact...');
        try {
            const response = await fetch(`/api/contacts/${contactId}`, {
                method: 'PATCH',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(editForm),
            });

            if (response.ok) {
                toast.success('Contact updated', { id: updateToast });
                setShowEditModal(false);
                fetchContactData();
            } else {
                toast.error('Internal Server Error', { id: updateToast });
            }
        } catch (error) {
            console.error('Failed to update contact:', error);
            toast.error('Internal Server Error', { id: updateToast });
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
        const currentStatus = contact?.follow_up_status;

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
                window.dispatchEvent(new CustomEvent('timeline:refresh'));
                fetchTimeline(); // Refresh only the timeline

                // Check if status was updated by AI analysis after a short delay
                if (currentStatus === 'not_contacted') {
                    setTimeout(async () => {
                        try {
                            const contactRes = await fetch(`/api/contacts/${contactId}`);
                            const contactData = await contactRes.json();
                            const newStatus = contactData.data?.follow_up_status;

                            if (newStatus && newStatus !== currentStatus) {
                                const statusLabels = {
                                    'contacted': 'Contacted',
                                    'needs_followup': 'Needs Follow-up',
                                    'followed_up': 'Followed Up',
                                    'ignore': 'No Follow-up Needed'
                                };

                                toast.success(
                                    `AI detected interaction - Status updated to "${statusLabels[newStatus as keyof typeof statusLabels] || newStatus}"`,
                                    { duration: 4000 }
                                );

                                // Update local contact state
                                setContact(prev => prev ? { ...prev, follow_up_status: newStatus } : null);
                            }
                        } catch (error) {
                            console.error('Failed to check status update:', error);
                        }
                    }, 2000); // Wait 2 seconds for AI analysis to complete
                }
            } else {
                toast.error('Failed to save note');
            }
        } catch (error) {
            console.error('Failed to save note:', error);
            toast.error('Failed to save note');
        }
    };

    const [enrichmentSuggestions, setEnrichmentSuggestions] = useState<any | null>(null);
    const [showResearchModal, setShowResearchModal] = useState(false);

    const handleEnrichContact = async () => {
        setEnriching(true);
        setShowResearchModal(true);
        try {
            const response = await fetch(`/api/contacts/${contactId}/enrich`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ review_only: true }) // Request review instead of direct update
            });

            if (response.ok) {
                const result = await response.json();
                setEnrichmentSuggestions(result.data.enrichment);
            } else {
                toast.error('Failed to perform research');
                setShowResearchModal(false);
            }
        } catch (error) {
            console.error('Failed to enrich contact:', error);
            toast.error('Failed to perform research');
            setShowResearchModal(false);
        } finally {
            setEnriching(false);
        }
    };

    const handleAcceptSuggestion = async (field: string, value: string) => {
        // Optimistic update
        const updateToast = toast.loading(`Updating ${field}...`);
        try {
            const body: any = {};
            if (['industry', 'description', 'location', 'region', 'company_size', 'products_services', 'website'].includes(field)) {
                // These belong to company
                const companyRes = await fetch(`/api/companies/${contact?.company_id}`, {
                    method: 'PATCH',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ [field]: value })
                });
                if (!companyRes.ok) throw new Error('Failed to update company');
            } else {
                // This belongs to contact
                const contactRes = await fetch(`/api/contacts/${contactId}`, {
                    method: 'PATCH',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ [field]: value })
                });
                if (!contactRes.ok) throw new Error('Failed to update contact');
            }

            toast.success(`Updated ${field}`, { id: updateToast });
            fetchContactData(); // Refresh UI

            // Remove from suggestions
            const newSuggestions = { ...enrichmentSuggestions };
            delete newSuggestions[field];
            if (newSuggestions.confidence) delete newSuggestions.confidence[field];

            if (Object.keys(newSuggestions).filter(k => k !== 'confidence' && k !== 'sources').length === 0) {
                setEnrichmentSuggestions(null);
                setShowResearchModal(false);
            } else {
                setEnrichmentSuggestions(newSuggestions);
            }
        } catch (error) {
            toast.error(`Failed to update ${field}`, { id: updateToast });
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
                        window.dispatchEvent(new CustomEvent('timeline:refresh'));
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
                                        window.dispatchEvent(new CustomEvent('timeline:refresh'));
                                        fetchTimeline(); // Refresh to show transcript

                                        // Check if status was updated by AI analysis after transcription
                                        if (contact?.follow_up_status === 'not_contacted') {
                                            setTimeout(async () => {
                                                try {
                                                    const contactRes = await fetch(`/api/contacts/${contactId}`);
                                                    const contactData = await contactRes.json();
                                                    const newStatus = contactData.data?.follow_up_status;

                                                    if (newStatus && newStatus !== 'not_contacted') {
                                                        const statusLabels = {
                                                            'contacted': 'Contacted',
                                                            'needs_followup': 'Needs Follow-up',
                                                            'followed_up': 'Followed Up',
                                                            'ignore': 'No Follow-up Needed'
                                                        };

                                                        toast.success(
                                                            `AI detected interaction in voice note - Status updated to "${statusLabels[newStatus as keyof typeof statusLabels] || newStatus}"`,
                                                            { duration: 4000 }
                                                        );

                                                        // Update local contact state
                                                        setContact(prev => prev ? { ...prev, follow_up_status: newStatus } : null);
                                                    }
                                                } catch (error) {
                                                    console.error('Failed to check status update:', error);
                                                }
                                            }, 2000);
                                        }
                                    }
                                }
                            } catch (err) {
                                console.error('Background transcription failed:', err);
                                toast.error('Transcription failed, but audio is saved.');
                            }
                        })();

                    } else {
                        toast.error('Internal Server Error', { id: savingToast });
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
                toast.error('Internal Server Error', { id: deleteToast });
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
                                <div className="bg-white border border-stone-200/40 rounded-3xl p-6 flex flex-col items-center shadow-sm">
                                    <Skeleton className="w-32 h-32 rounded-full mb-4" />
                                    <Skeleton className="h-6 w-48 mb-2" />
                                    <Skeleton className="h-4 w-32 mb-1" />
                                    <Skeleton className="h-4 w-40" />
                                </div>

                                <div className="bg-white border border-stone-200/40 rounded-3xl p-6 space-y-4 shadow-sm">
                                    <Skeleton className="h-3 w-20 mb-4" />
                                    <Skeleton className="h-4 w-full" />
                                    <Skeleton className="h-4 w-full" />
                                    <Skeleton className="h-4 w-full" />
                                </div>

                                <div className="bg-white border border-stone-200/40 rounded-3xl p-6 space-y-4 shadow-sm">
                                    <Skeleton className="h-3 w-24 mb-4" />
                                    <Skeleton className="h-10 w-full rounded-xl" />
                                    <Skeleton className="h-10 w-full rounded-xl" />
                                </div>
                            </div>
                        </div>

                        {/* Right Column Skeleton */}
                        <div className="lg:col-span-2">
                            <div className="bg-white border border-stone-200/40 rounded-3xl p-6 space-y-8 shadow-sm">
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
            <div className="max-w-7xl mx-auto px-4 py-8">
                {/* Strategic Context Header */}
                <div className="flex flex-col md:flex-row md:items-center justify-between gap-6 mb-12">
                    <Button
                        variant="ghost"
                        size="sm"
                        onClick={() => router.push('/contacts')}
                        className="hover:bg-stone-50 text-stone-900 font-black uppercase tracking-widest text-[10px] px-0 h-10 w-fit group"
                    >
                        <ArrowLeft className="mr-3 h-4 w-4 transition-transform group-hover:-translate-x-1" strokeWidth={3} />
                        Contacts
                    </Button>

                    <div className="flex items-center gap-3">
                        <Button
                            onClick={handleEnrichContact}
                            disabled={enriching}
                            className="h-11 px-6 bg-stone-900 text-white hover:bg-stone-800 rounded-xl font-black uppercase tracking-widest text-[10px] transition-all shadow-xl shadow-stone-900/10 border-none"
                        >
                            {enriching ? (
                                <Loader2 className="mr-2 h-4 w-4 animate-spin" strokeWidth={2.5} />
                            ) : (
                                <Sparkles className="mr-2 h-4 w-4" strokeWidth={2.5} />
                            )}
                            {enriching ? 'Researching...' : 'AI Research'}
                        </Button>
                        <Button
                            variant="outline"
                            onClick={() => setShowEditModal(true)}
                            className="h-11 px-6 border-stone-200 text-stone-900 hover:bg-stone-50 rounded-xl font-black uppercase tracking-widest text-[10px] transition-all shadow-sm"
                        >
                            <Edit className="mr-2 h-4 w-4" strokeWidth={2.5} />
                            Edit Profile
                        </Button>
                        <Button
                            onClick={handleDeleteContact}
                            disabled={deleting}
                            className="h-11 px-6 bg-red-50 text-red-600 hover:bg-red-100 hover:text-red-700 rounded-xl font-black uppercase tracking-widest text-[10px] transition-all border-none"
                        >
                            <Trash2 className="mr-2 h-4 w-4" strokeWidth={2.5} />
                            {deleting ? 'Deleting...' : 'Delete'}
                        </Button>
                    </div>
                </div>

                {/* Strategic Context Header */}

                {/* Primary Data Grid */}
                <div className="grid grid-cols-1 lg:grid-cols-3 gap-10">
                    {/* Intelligence Profile */}
                    <div className="lg:col-span-1">
                        <div className="sticky top-24 space-y-8">
                            <div className="bg-white rounded-[3rem] border border-stone-100 shadow-sm p-10 flex flex-col items-center hover:shadow-md transition-shadow">
                                {/* Strategic Avatar */}
                                <div className="relative mb-8">
                                    <div className="w-32 h-32 rounded-[2.5rem] bg-stone-900 flex items-center justify-center text-white text-4xl font-black shadow-2xl shadow-stone-900/20 ring-8 ring-stone-50 group-hover:scale-105 transition-transform">
                                        {getInitials(contact.first_name, contact.last_name)}
                                    </div>
                                    {/* Connectivity Status */}
                                    <div className="absolute -bottom-1 -right-1 h-8 w-8 rounded-xl bg-white p-1.5 shadow-xl border border-stone-100">
                                        <div className={cn(
                                            "h-full w-full rounded-lg",
                                            contact.follow_up_status === 'contacted' ? "bg-stone-900 shadow-[0_0_10px_rgba(0,0,0,0.1)]" :
                                                contact.follow_up_status === 'needs_followup' ? "bg-stone-400" :
                                                    "bg-stone-200"
                                        )} />
                                    </div>
                                </div>

                                <div className="text-center">
                                    <h1 className="text-3xl font-black text-stone-900 tracking-tighter mb-2">
                                        {contact.first_name} {contact.last_name || ''}
                                    </h1>
                                    <div className="flex flex-col items-center gap-3">
                                        {contact.job_title && (
                                            <p className="text-xs font-black text-stone-400 uppercase tracking-[0.2em]">
                                                {contact.job_title}
                                            </p>
                                        )}
                                        {contact.company && (
                                            <div className="px-4 py-1.5 bg-stone-50 rounded-full border border-stone-100 flex items-center gap-2">
                                                <div className="h-1.5 w-1.5 rounded-full bg-stone-900" />
                                                <p className="text-[10px] font-black text-stone-900 uppercase tracking-widest">
                                                    {contact.company.name}
                                                </p>
                                            </div>
                                        )}
                                    </div>
                                </div>
                            </div>

                            {/* Communication Details */}
                            <div className="bg-white rounded-[2.5rem] border border-stone-100 shadow-sm p-8 space-y-6">
                                <h3 className="text-[10px] font-black text-stone-300 uppercase tracking-[0.3em] px-2">Details</h3>
                                <div className="space-y-4">
                                    {contact.email && (
                                        <div className="flex items-center gap-5 p-3 rounded-2xl hover:bg-stone-50 transition-colors group cursor-pointer border border-transparent hover:border-stone-100">
                                            <div className="h-11 w-11 rounded-xl bg-stone-900 text-white flex items-center justify-center shadow-lg group-hover:scale-110 transition-transform">
                                                <Mail className="h-5 w-5" strokeWidth={2.5} />
                                            </div>
                                            <div className="flex-1 min-w-0">
                                                <p className="text-[9px] font-black text-stone-400 uppercase tracking-widest mb-0.5">Email</p>
                                                <a href={`mailto:${contact.email}`} className="text-sm font-black text-stone-900 truncate block hover:text-stone-600 transition-colors">
                                                    {contact.email}
                                                </a>
                                            </div>
                                        </div>
                                    )}

                                    {contact.phone && (
                                        <div className="flex items-center gap-5 p-3 rounded-2xl hover:bg-stone-50 transition-colors group cursor-pointer border border-transparent hover:border-stone-100">
                                            <div className="h-11 w-11 rounded-xl bg-stone-900 text-white flex items-center justify-center shadow-lg group-hover:scale-110 transition-transform">
                                                <Phone className="h-5 w-5" strokeWidth={2.5} />
                                            </div>
                                            <div className="flex-1 min-w-0">
                                                <p className="text-[9px] font-black text-stone-400 uppercase tracking-widest mb-0.5">Phone</p>
                                                <a href={`tel:${contact.phone}`} className="text-sm font-black text-stone-900 truncate block hover:text-stone-600 transition-colors">
                                                    {contact.phone}
                                                </a>
                                            </div>
                                        </div>
                                    )}

                                    {contact.linkedin_url && (
                                        <div className="flex items-center gap-5 p-3 rounded-2xl hover:bg-stone-50 transition-colors group cursor-pointer border border-transparent hover:border-stone-100">
                                            <div className="h-11 w-11 rounded-xl bg-stone-900 text-white flex items-center justify-center shadow-lg group-hover:scale-110 transition-transform">
                                                <Linkedin className="h-5 w-5" strokeWidth={2.5} />
                                            </div>
                                            <div className="flex-1 min-w-0">
                                                <p className="text-[9px] font-black text-stone-400 uppercase tracking-widest mb-0.5">LinkedIn</p>
                                                <a
                                                    href={contact.linkedin_url.startsWith('http') ? contact.linkedin_url : `https://${contact.linkedin_url}`}
                                                    target="_blank"
                                                    rel="noopener noreferrer"
                                                    className="text-sm font-black text-stone-900 truncate block hover:text-blue-600 transition-colors"
                                                >
                                                    {contact.linkedin_url.replace(/^https?:\/\/(www\.)?linkedin\.com\/in\//, '').replace(/\/$/, '')}
                                                </a>
                                            </div>
                                        </div>
                                    )}

                                    {contact.company?.website && (
                                        <div className="flex items-center gap-5 p-3 rounded-2xl hover:bg-stone-50 transition-colors group cursor-pointer border border-transparent hover:border-stone-100">
                                            <div className="h-11 w-11 rounded-xl bg-stone-900 text-white flex items-center justify-center shadow-lg group-hover:scale-110 transition-transform">
                                                <ArrowUpRight className="h-5 w-5" strokeWidth={2.5} />
                                            </div>
                                            <div className="flex-1 min-w-0">
                                                <p className="text-[9px] font-black text-stone-400 uppercase tracking-widest mb-0.5">Corporate Website</p>
                                                <a
                                                    href={contact.company.website.startsWith('http')
                                                        ? contact.company.website
                                                        : `https://www.${contact.company.website.replace(/^www\./, '')}`}
                                                    target="_blank"
                                                    rel="noopener noreferrer"
                                                    className="text-sm font-black text-stone-900 truncate block hover:text-stone-600 transition-colors"
                                                >
                                                    www.{contact.company.website.replace(/^https?:\/\/(www\.)?/, '').replace(/\/$/, '')}
                                                </a>
                                            </div>
                                        </div>
                                    )}
                                </div>
                            </div>

                            {/* Company Details (Enriched AI Data) */}
                            {contact.company && (contact.company.industry || contact.company.location || contact.company.company_size || contact.company.products_services) && (
                                <div className="bg-white rounded-[2.5rem] border border-stone-100 shadow-sm p-8 space-y-6">
                                    <h3 className="text-[10px] font-black text-stone-300 uppercase tracking-[0.3em] px-2">Company Details</h3>
                                    <div className="grid grid-cols-2 gap-y-6 gap-x-4">
                                        {contact.company.industry && (
                                            <div>
                                                <p className="text-[9px] font-black text-stone-400 uppercase tracking-widest mb-1">Industry</p>
                                                <p className="text-xs font-black text-stone-900">{contact.company.industry}</p>
                                            </div>
                                        )}
                                        {contact.company.location && (
                                            <div>
                                                <p className="text-[9px] font-black text-stone-400 uppercase tracking-widest mb-1">HQ Location</p>
                                                <p className="text-xs font-black text-stone-900">{contact.company.location}</p>
                                            </div>
                                        )}
                                        {contact.company.company_size && (
                                            <div>
                                                <p className="text-[9px] font-black text-stone-400 uppercase tracking-widest mb-1">Scale</p>
                                                <p className="text-xs font-black text-stone-900 cursor-default" title="Estimated Employees">
                                                    {contact.company.company_size} People
                                                </p>
                                            </div>
                                        )}
                                        {contact.company.products_services && (
                                            <div className="col-span-2 border-t border-stone-50 pt-4">
                                                <p className="text-[9px] font-black text-stone-400 uppercase tracking-widest mb-2">Core Solutions</p>
                                                <p className="text-[11px] font-bold text-stone-600 leading-relaxed italic">
                                                    {contact.company.products_services}
                                                </p>
                                            </div>
                                        )}
                                    </div>
                                </div>
                            )}

                            {/* Quick Action Hub */}
                            <div className="bg-white rounded-[2.5rem] border border-stone-100 shadow-sm p-8 hover:shadow-md transition-shadow">
                                <h3 className="text-[10px] font-black text-stone-300 uppercase tracking-[0.3em] px-2 mb-6">Actions</h3>
                                <ContactQuickActions
                                    email={contact.email}
                                    phone={contact.phone}
                                    onEmail={() => toast.info('Protocol deployment coming soon')}
                                    onAddNote={() => setShowNoteEditor(true)}
                                    onScheduleMeeting={() => router.push(`/meetings/new?contactId=${contactId}`)}
                                />
                            </div>

                        </div>
                    </div>

                    {/* Operational Timeline */}
                    <div className="lg:col-span-2">
                        <div className="bg-white rounded-[3rem] border border-stone-100 shadow-sm p-10 min-h-[800px] hover:shadow-md transition-shadow">
                            <div className="flex flex-col xl:flex-row xl:items-center justify-between gap-8 mb-12">
                                <h2 className="text-2xl font-black text-stone-900 tracking-tighter">
                                    Timeline
                                </h2>

                                {/* Filter Management */}
                                <div className="flex gap-1 bg-stone-50 p-1.5 rounded-2xl w-fit border border-stone-100">
                                    {['all', 'meeting', 'email', 'note', 'capture'].map((filter) => (
                                        <button
                                            key={filter}
                                            onClick={() => setTimelineFilter(filter)}
                                            className={cn(
                                                "px-5 py-2.5 text-[10px] font-black uppercase tracking-widest rounded-xl transition-all duration-300",
                                                timelineFilter === filter
                                                    ? "bg-stone-900 text-white shadow-xl shadow-stone-900/10"
                                                    : "text-stone-400 hover:text-stone-600 hover:bg-white"
                                            )}
                                        >
                                            {filter}
                                        </button>
                                    ))}
                                </div>
                            </div>

                            {/* About Contact (Enriched AI Data) */}
                            {contact.bio && (
                                <div className="mb-12 p-8 bg-stone-900 rounded-[2.5rem] text-white shadow-2xl shadow-stone-900/10 relative overflow-hidden group">
                                    <div className="absolute top-0 right-0 p-8 opacity-10 group-hover:scale-110 transition-transform">
                                        <Sparkles className="h-12 w-12" />
                                    </div>
                                    <div className="relative z-10">
                                        <p className="text-[10px] font-black text-stone-400 uppercase tracking-[0.3em] mb-4 flex items-center gap-2">
                                            <Sparkles className="h-3 w-3" />
                                            About {contact.first_name}
                                        </p>
                                        <p className="text-lg font-bold leading-relaxed tracking-tight">
                                            {contact.bio}
                                        </p>
                                    </div>
                                </div>
                            )}

                            {/* Briefing Input Interface */}
                            {showNoteEditor && (
                                <div className="mb-10 border-b border-stone-50 pb-10">
                                    <InlineNoteEditor
                                        onSave={handleSaveNote}
                                        onCancel={() => setShowNoteEditor(false)}
                                        placeholder="Add a note about this contact..."
                                    />
                                </div>
                            )}

                            {showVoiceRecorder && (
                                <div className="mb-10 border-b border-stone-50 pb-10">
                                    <VoiceNoteRecorder
                                        onSave={handleSaveVoiceNote}
                                        onCancel={() => setShowVoiceRecorder(false)}
                                    />
                                </div>
                            )}

                            {/* Tactical Note Dispatch */}
                            {!showNoteEditor && !showVoiceRecorder && (
                                <div className="flex gap-4 mb-12 p-2 bg-stone-50 rounded-[2rem] border border-stone-100 shadow-inner">
                                    <Button
                                        variant="ghost"
                                        onClick={() => setShowNoteEditor(true)}
                                        className="flex-1 h-14 hover:bg-white hover:shadow-xl hover:shadow-stone-900/5 rounded-[1.5rem] transition-all font-black uppercase tracking-widest text-[10px] text-stone-600 hover:text-stone-900"
                                    >
                                        <FileText className="mr-3 h-4 w-4 text-stone-900" strokeWidth={2.5} />
                                        Add Note
                                    </Button>
                                    <div className="w-px h-8 bg-stone-200 self-center opacity-50"></div>
                                    <Button
                                        variant="ghost"
                                        onClick={() => setShowVoiceRecorder(true)}
                                        className="flex-1 h-14 hover:bg-white hover:shadow-xl hover:shadow-stone-900/5 rounded-[1.5rem] transition-all font-black uppercase tracking-widest text-[10px] text-stone-600 hover:text-stone-900"
                                    >
                                        <Mic className="mr-3 h-4 w-4 text-stone-900" strokeWidth={2.5} />
                                        Record Voice
                                    </Button>
                                </div>
                            )}

                            <ContactTimeline
                                timeline={timeline}
                                onAddNote={() => setShowNoteEditor(true)}
                                onRefresh={fetchTimeline}
                            />
                        </div>
                    </div>
                </div>

                {/* AI Research Modal */}
                <Modal
                    isOpen={showResearchModal}
                    onClose={() => {
                        if (!enriching) {
                            setShowResearchModal(false);
                            setEnrichmentSuggestions(null);
                        }
                    }}
                    title="AI Research"
                    size="xl"
                >
                    <EnrichmentPanel
                        loading={enriching}
                        suggestions={enrichmentSuggestions}
                        currentValues={{
                            bio: contact.bio,
                            website: contact.company?.website,
                            industry: contact.company?.industry,
                            description: contact.company?.description,
                            location: contact.company?.location,
                            products_services: contact.company?.products_services,
                            company_size: contact.company?.company_size,
                            linkedin_url: contact.linkedin_url
                        }}
                        onAccept={handleAcceptSuggestion}
                        onReject={(field) => {
                            const newSuggestions = { ...enrichmentSuggestions };
                            delete newSuggestions[field];
                            if (newSuggestions.confidence) delete newSuggestions.confidence[field];
                            if (Object.keys(newSuggestions).filter(k => k !== 'confidence' && k !== 'sources').length === 0) {
                                setEnrichmentSuggestions(null);
                                setShowResearchModal(false);
                            } else {
                                setEnrichmentSuggestions(newSuggestions);
                            }
                        }}
                        onEdit={handleAcceptSuggestion}
                        onCloseRequest={() => {
                            setEnrichmentSuggestions(null);
                            setShowResearchModal(false);
                        }}
                    />
                </Modal>

                {/* Edit Contact Modal */}
                <Modal
                    isOpen={showEditModal}
                    onClose={() => setShowEditModal(false)}
                    title="Edit Contact"
                    size="lg"
                >
                    <form onSubmit={handleUpdateContact} className="space-y-4">
                        <div className="grid grid-cols-2 gap-4">
                            <Input
                                label="First Name"
                                required
                                value={editForm.first_name}
                                onChange={(e: any) => setEditForm({ ...editForm, first_name: e.target.value })}
                            />
                            <Input
                                label="Last Name"
                                value={editForm.last_name}
                                onChange={(e: any) => setEditForm({ ...editForm, last_name: e.target.value })}
                            />
                        </div>
                        <Input
                            label="Email"
                            type="email"
                            value={editForm.email}
                            onChange={(e: any) => setEditForm({ ...editForm, email: e.target.value })}
                        />
                        <Input
                            label="Phone"
                            value={editForm.phone}
                            onChange={(e: any) => setEditForm({ ...editForm, phone: e.target.value })}
                        />
                        <Input
                            label="Job Title"
                            value={editForm.job_title}
                            onChange={(e: any) => setEditForm({ ...editForm, job_title: e.target.value })}
                        />
                        <Input
                            label="LinkedIn URL"
                            value={editForm.linkedin_url}
                            onChange={(e: any) => setEditForm({ ...editForm, linkedin_url: e.target.value })}
                        />
                        <div className="flex justify-end gap-3 mt-6">
                            <Button type="button" variant="outline" onClick={() => setShowEditModal(false)}>
                                Cancel
                            </Button>
                            <Button type="submit" variant="primary">
                                Save Changes
                            </Button>
                        </div>
                    </form>
                </Modal>
            </div>
        </AppShell>
    );
}
