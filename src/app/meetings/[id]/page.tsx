'use client';

import { useEffect, useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import Link from 'next/link';
import { AppShell } from '@/components/layout/AppShell';
import { Button } from '@/components/ui/Button';
import { Textarea } from '@/components/ui/Textarea';
import { ArrowLeft, Calendar, MapPin, Lightbulb, History, FileText } from 'lucide-react';
import { MeetingPrep } from '@/components/meetings/MeetingPrep';
import { ContactTimeline } from '@/components/contacts/ContactTimeline';
import { MeetingBrief } from '@/types';
import { toast } from 'sonner';

export default function MeetingBriefPage() {
    const params = useParams();
    const router = useRouter();
    const [meeting, setMeeting] = useState<MeetingBrief | null>(null);
    const [timeline, setTimeline] = useState<any[]>([]);
    const [loading, setLoading] = useState(true);
    const [activeTab, setActiveTab] = useState<'briefing' | 'history' | 'notes'>('briefing');
    const [postNotes, setPostNotes] = useState('');
    const [isGenerating, setIsGenerating] = useState(false);

    useEffect(() => {
        fetchMeetingData();
    }, [params.id]);

    const fetchMeetingData = async () => {
        try {
            const response = await fetch(`/api/meetings/${params.id}`);
            if (!response.ok) throw new Error('Failed to fetch meeting');

            const data = await response.json();
            setMeeting(data.meeting);
            setPostNotes(data.meeting.post_meeting_notes || '');

            // Fetch interaction timeline for the contact
            if (data.meeting.contact.id) {
                const timelineRes = await fetch(`/api/contacts/${data.meeting.contact.id}/timeline?type=all`);
                if (timelineRes.ok) {
                    const timelineData = await timelineRes.json();
                    setTimeline(timelineData.data || []);
                }
            }
        } catch (error) {
            console.error('Error fetching meeting:', error);
            toast.error('Failed to load meeting details');
        } finally {
            setLoading(false);
        }
    };

    const handleSaveNotes = async () => {
        try {
            const response = await fetch(`/api/meetings/${params.id}`, {
                method: 'PATCH',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ post_meeting_notes: postNotes }),
            });

            if (!response.ok) throw new Error('Failed to save notes');
            toast.success('Notes saved successfully!');
        } catch (error) {
            console.error('Error saving notes:', error);
            toast.error('Failed to save notes');
        }
    };

    const handleCompleteMeeting = async () => {
        try {
            const response = await fetch(`/api/meetings/${params.id}`, {
                method: 'PATCH',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ status: 'completed' }),
            });

            if (!response.ok) throw new Error('Failed to complete meeting');

            // Log interaction
            await fetch('/api/interactions', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    contact_id: meeting?.contact.id,
                    interaction_type: 'meeting',
                    summary: `Completed meeting: ${meeting?.meeting_type}`,
                    details: {
                        meeting_id: meeting?.id,
                        notes: postNotes
                    }
                }),
            });

            toast.success('Meeting marked as completed!');
            router.push('/meetings');
        } catch (error) {
            console.error('Error completing meeting:', error);
            toast.error('Failed to complete meeting');
        }
    };

    const handleGeneratePrep = async () => {
        setIsGenerating(true);
        try {
            const response = await fetch(`/api/meetings/${params.id}/prep`, {
                method: 'POST',
            });

            if (!response.ok) throw new Error('Failed to generate prep');

            const data = await response.json();
            if (meeting) {
                setMeeting({
                    ...meeting,
                    prep_data: data.prep_data,
                    ai_talking_points: data.prep_data.key_talking_points.join('\n'),
                    interaction_summary: data.prep_data.relationship_summary
                });
            }
            toast.success('Meeting intelligence generated!');
        } catch (error) {
            console.error('Error generating prep:', error);
            toast.error('Failed to generate meeting intelligence');
        } finally {
            setIsGenerating(false);
        }
    };

    const handleAnalyzeDocument = async (url: string) => {
        // Implementation for document analysis
        toast.info('Document analysis coming soon!');
    };

    if (loading) {
        return (
            <AppShell>
                <div className="max-w-7xl mx-auto text-center py-12">
                    <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-indigo-600 mx-auto mb-4"></div>
                    <p className="text-body">Loading meeting brief...</p>
                </div>
            </AppShell>
        );
    }

    if (!meeting) {
        return (
            <AppShell>
                <div className="max-w-7xl mx-auto text-center py-12">
                    <h2 className="text-section-header mb-4">Meeting not found</h2>
                    <Button variant="secondary" onClick={() => router.push('/meetings')}>
                        <ArrowLeft className="mr-2 h-4 w-4" strokeWidth={2} />
                        Back to meetings
                    </Button>
                </div>
            </AppShell>
        );
    }

    const companyName = meeting.contact.company?.name || meeting.company?.name || 'Unknown Company';
    const contactName = `${meeting.contact.first_name} ${meeting.contact.last_name || ''}`.trim();

    return (
        <AppShell>
            <div className="max-w-7xl mx-auto">
                {/* Header */}
                <div className="mb-8">
                    <button
                        onClick={() => router.push('/meetings')}
                        className="text-caption hover:text-stone-900 transition-colors mb-4 flex items-center gap-1"
                    >
                        <ArrowLeft className="h-4 w-4" strokeWidth={2} />
                        Back to meetings
                    </button>
                    <div className="flex items-start justify-between">
                        <div>
                            <h1 className="text-display mb-1">Meeting Brief</h1>
                            <p className="text-section-header mb-2">
                                <Link href={`/contacts/${meeting.contact.id}`} className="hover:text-indigo-600 transition-colors">
                                    {contactName}
                                </Link>
                                <span className="text-stone-400 mx-2">at</span>
                                <span className="text-stone-600">{companyName}</span>
                            </p>
                            <div className="flex items-center gap-4 text-caption">
                                <span className="flex items-center gap-1.5">
                                    <Calendar className="w-4 h-4" strokeWidth={2} />
                                    {new Date(meeting.meeting_date).toLocaleString()}
                                </span>
                                <span className="capitalize">{meeting.meeting_type.replace('_', ' ')}</span>
                                {meeting.meeting_location && (
                                    <span className="flex items-center gap-1.5">
                                        <MapPin className="w-4 h-4" strokeWidth={2} />
                                        {meeting.meeting_location}
                                    </span>
                                )}
                            </div>
                        </div>
                        {meeting.status === 'scheduled' && (
                            <Button onClick={handleCompleteMeeting} variant="secondary">
                                Mark as Completed
                            </Button>
                        )}
                    </div>
                </div>

                {/* Tabs */}
                <div className="flex items-center gap-2 mb-8">
                    <button
                        onClick={() => setActiveTab('briefing')}
                        className={activeTab === 'briefing' ? 'nav-pill nav-pill-active' : 'nav-pill nav-pill-inactive'}
                    >
                        Briefing
                    </button>
                    <button
                        onClick={() => setActiveTab('history')}
                        className={activeTab === 'history' ? 'nav-pill nav-pill-active' : 'nav-pill nav-pill-inactive'}
                    >
                        History
                    </button>
                    <button
                        onClick={() => setActiveTab('notes')}
                        className={activeTab === 'notes' ? 'nav-pill nav-pill-active' : 'nav-pill nav-pill-inactive'}
                    >
                        Notes
                    </button>
                </div>

                {/* Content */}
                {activeTab === 'briefing' && (
                    <div className="space-y-8">
                        {/* Top Section: Contact Info & Pre-meeting notes */}
                        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
                            {/* Contact Info */}
                            <div className="premium-card p-6">
                                <h2 className="text-section-header mb-4">Contact Information</h2>
                                <div className="space-y-3">
                                    <div>
                                        <p className="text-caption">Name</p>
                                        <Link
                                            href={`/contacts/${meeting.contact.id}`}
                                            className="text-card-title text-indigo-600 hover:text-indigo-800 transition-colors inline-block"
                                        >
                                            {contactName}
                                        </Link>
                                    </div>
                                    {meeting.contact.job_title && (
                                        <div>
                                            <p className="text-caption">Title</p>
                                            <p className="text-body">{meeting.contact.job_title}</p>
                                        </div>
                                    )}
                                    {meeting.contact.email && (
                                        <div>
                                            <p className="text-caption">Email</p>
                                            <a href={`mailto:${meeting.contact.email}`} className="text-body text-indigo-600 hover:text-indigo-800">
                                                {meeting.contact.email}
                                            </a>
                                        </div>
                                    )}
                                    <div>
                                        <p className="text-caption">Company</p>
                                        <p className="text-body">{companyName}</p>
                                    </div>
                                    {meeting.event && (
                                        <div>
                                            <p className="text-caption">Captured At</p>
                                            <Link
                                                href={`/events/${meeting.event.id}`}
                                                className="text-body text-indigo-600 hover:text-indigo-800 transition-colors font-medium flex items-center gap-1"
                                            >
                                                {meeting.event.name}
                                            </Link>
                                        </div>
                                    )}
                                </div>
                            </div>

                            {/* Pre-Meeting Notes */}
                            <div className="premium-card p-6 lg:col-span-2">
                                <h2 className="text-section-header mb-4">Pre-Meeting Notes</h2>
                                {meeting.pre_meeting_notes ? (
                                    <p className="text-body whitespace-pre-wrap">{meeting.pre_meeting_notes}</p>
                                ) : (
                                    <p className="text-caption italic opacity-50">No pre-meeting notes provided.</p>
                                )}
                            </div>
                        </div>

                        {/* Middle Section: AI Preparation */}
                        <section className="pt-4">
                            <div className="flex items-center gap-2 mb-4">
                                <Lightbulb className="w-5 h-5 text-amber-500" strokeWidth={2} />
                                <h2 className="text-section-header">Meeting Intelligence</h2>
                            </div>
                            <MeetingPrep
                                contactId={meeting.contact.id}
                                prepData={meeting.prep_data}
                                isGenerating={isGenerating}
                                onGenerate={handleGeneratePrep}
                            />
                        </section>

                    </div>
                )}

                {activeTab === 'history' && (
                    <div className="premium-card p-6">
                        <h2 className="text-section-header mb-6">Interaction Timeline</h2>
                        <ContactTimeline timeline={timeline} />
                    </div>
                )}

                {activeTab === 'notes' && (
                    <div className="premium-card p-6">
                        <h2 className="text-section-header mb-4 flex items-center gap-2">
                            <FileText className="w-5 h-5" strokeWidth={2} />
                            Post-Meeting Notes
                        </h2>
                        <Textarea
                            value={postNotes}
                            onChange={(e) => setPostNotes(e.target.value)}
                            className="h-64 text-body"
                            placeholder="Add your notes from the meeting..."
                        />
                        <div className="mt-4 flex justify-end">
                            <Button onClick={handleSaveNotes}>
                                Save Notes
                            </Button>
                        </div>
                    </div>
                )}
            </div>
        </AppShell>
    );
}
