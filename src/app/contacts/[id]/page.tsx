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
import { cn } from '@/lib/utils';
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
    Trash2,
    Loader2,
    Command
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
                        Intelligence Registry
                    </Button>

                    <div className="flex items-center gap-4">
                        <Button
                            variant="outline"
                            className="h-11 px-8 border-stone-200 text-stone-900 hover:bg-stone-50 rounded-xl font-black uppercase tracking-widest text-[10px] transition-all shadow-sm"
                        >
                            <Edit className="mr-2 h-4 w-4" strokeWidth={2.5} />
                            Modify Identity
                        </Button>
                        <Button
                            onClick={handleDeleteContact}
                            disabled={deleting}
                            className="h-11 px-8 bg-red-50 text-red-600 hover:bg-red-100 hover:text-red-700 rounded-xl font-black uppercase tracking-widest text-[10px] transition-all border-none"
                        >
                            <Trash2 className="mr-2 h-4 w-4" strokeWidth={2.5} />
                            {deleting ? 'Purging...' : 'Extract Identify'}
                        </Button>
                    </div>
                </div>

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

                            {/* Communication Registry */}
                            <div className="bg-white rounded-[2.5rem] border border-stone-100 shadow-sm p-8 space-y-6">
                                <h3 className="text-[10px] font-black text-stone-300 uppercase tracking-[0.3em] px-2">Access Protocols</h3>
                                <div className="space-y-4">
                                    {contact.email && (
                                        <div className="flex items-center gap-5 p-3 rounded-2xl hover:bg-stone-50 transition-colors group cursor-pointer border border-transparent hover:border-stone-100">
                                            <div className="h-11 w-11 rounded-xl bg-stone-900 text-white flex items-center justify-center shadow-lg group-hover:scale-110 transition-transform">
                                                <Mail className="h-5 w-5" strokeWidth={2.5} />
                                            </div>
                                            <div className="flex-1 min-w-0">
                                                <p className="text-[9px] font-black text-stone-400 uppercase tracking-widest mb-0.5">Primary Uplink</p>
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
                                                <p className="text-[9px] font-black text-stone-400 uppercase tracking-widest mb-0.5">Voice Proxy</p>
                                                <a href={`tel:${contact.phone}`} className="text-sm font-black text-stone-900 truncate block hover:text-stone-600 transition-colors">
                                                    {contact.phone}
                                                </a>
                                            </div>
                                        </div>
                                    )}

                                    {contact.linkedin_url && (
                                        <div className="flex items-center gap-5 p-3 rounded-2xl hover:bg-stone-50 transition-colors group cursor-pointer border border-transparent hover:border-stone-100">
                                            <div className="flex-1 min-w-0">
                                                <p className="text-[9px] font-black text-stone-400 uppercase tracking-widest mb-0.5">Network Identity</p>
                                                <a href={contact.linkedin_url} target="_blank" rel="noopener noreferrer" className="text-sm font-black text-stone-900 truncate block hover:text-stone-600 transition-colors">
                                                    Secure Link
                                                </a>
                                            </div>
                                        </div>
                                    )}
                                </div>
                            </div>

                            {/* Quick Action Hub */}
                            <div className="bg-white rounded-[2.5rem] border border-stone-100 shadow-sm p-8 hover:shadow-md transition-shadow">
                                <h3 className="text-[10px] font-black text-stone-300 uppercase tracking-[0.3em] px-2 mb-6">Strategic Actions</h3>
                                <ContactQuickActions
                                    email={contact.email}
                                    phone={contact.phone}
                                    onEmail={() => toast.info('Protocol deployment coming soon')}
                                    onAddNote={() => setShowNoteEditor(true)}
                                    onScheduleMeeting={() => router.push(`/meetings/new?contactId=${contactId}`)}
                                />
                            </div>

                            {/* AI Neural Enrichment */}
                            <div className="relative group overflow-hidden bg-stone-900 rounded-[2.5rem] p-10 shadow-2xl shadow-stone-900/20">
                                <div className="absolute top-0 right-0 p-8 opacity-[0.05] group-hover:scale-125 transition-transform duration-1000">
                                    <Sparkles size={160} strokeWidth={1} />
                                </div>
                                <div className="relative z-10">
                                    <h3 className="text-white font-black text-xl tracking-tight mb-3 flex items-center gap-3">
                                        <Sparkles className="h-5 w-5" strokeWidth={2.5} />
                                        Advanced Enrichment
                                    </h3>
                                    <p className="text-stone-400 text-xs font-medium leading-relaxed mb-8 italic">
                                        "Synthesize mutual strategic interests and company telemetry automatically."
                                    </p>
                                    <Button
                                        size="lg"
                                        className="w-full bg-white text-stone-900 hover:bg-stone-100 font-black text-[10px] uppercase tracking-widest h-14 rounded-xl shadow-xl border-none active:scale-95 transition-all"
                                        onClick={handleEnrichContact}
                                        disabled={enriching}
                                    >
                                        {enriching ? (
                                            <Loader2 className="h-4 w-4 animate-spin mr-3" strokeWidth={3} />
                                        ) : (
                                            <Command className="mr-3 h-4 w-4 text-stone-900" strokeWidth={3} />
                                        )}
                                        {enriching ? 'Enriching Registry...' : 'Initialize Enrichment'}
                                    </Button>
                                </div>
                            </div>
                        </div>
                    </div>

                    {/* Operational Timeline */}
                    <div className="lg:col-span-2">
                        <div className="bg-white rounded-[3rem] border border-stone-100 shadow-sm p-10 min-h-[800px] hover:shadow-md transition-shadow">
                            <div className="flex flex-col xl:flex-row xl:items-center justify-between gap-8 mb-12">
                                <h2 className="text-2xl font-black text-stone-900 tracking-tighter">
                                    Operational Timeline
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

                            {/* Briefing Input Interface */}
                            {showNoteEditor && (
                                <div className="mb-10 border-b border-stone-50 pb-10">
                                    <InlineNoteEditor
                                        onSave={handleSaveNote}
                                        onCancel={() => setShowNoteEditor(false)}
                                        placeholder="Capture intelligence about this profile..."
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
                                        Deploy Text Note
                                    </Button>
                                    <div className="w-px h-8 bg-stone-200 self-center opacity-50"></div>
                                    <Button
                                        variant="ghost"
                                        onClick={() => setShowVoiceRecorder(true)}
                                        className="flex-1 h-14 hover:bg-white hover:shadow-xl hover:shadow-stone-900/5 rounded-[1.5rem] transition-all font-black uppercase tracking-widest text-[10px] text-stone-600 hover:text-stone-900"
                                    >
                                        <Mic className="mr-3 h-4 w-4 text-stone-900" strokeWidth={2.5} />
                                        Initialize Voice Capture
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
            </div>
        </AppShell>
    );
}
