'use client';

import { useEffect, useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import { AppShell } from '@/components/layout/AppShell';
import { Button } from '@/components/ui/Button';
import { Textarea } from '@/components/ui/Textarea';
import { ArrowLeft, Calendar, MapPin, Lightbulb, History, FileText } from 'lucide-react';
import { MeetingPrep } from '@/components/meetings/MeetingPrep';
import { DocumentSummarizer } from '@/components/meetings/DocumentSummarizer';
import { MeetingBrief, Interaction } from '@/types';
import { toast } from 'sonner';

export default function MeetingBriefPage() {
    const params = useParams();
    const router = useRouter();
    const [meeting, setMeeting] = useState<MeetingBrief | null>(null);
    const [interactions, setInteractions] = useState<Interaction[]>([]);
    const [loading, setLoading] = useState(true);
    const [activeTab, setActiveTab] = useState<'overview' | 'history' | 'notes' | 'prep'>('overview');
    const [postNotes, setPostNotes] = useState('');

    useEffect(() => {
        fetchMeetingData();
    }, [params.id]);

    const fetchMeetingData = async () => {
        try {
            const response = await fetch(`/api/meetings/${params.id}`);
            if (!response.ok) throw new Error('Failed to fetch meeting');

            const data = await response.json();
            setMeeting(data.meeting);
            setInteractions(data.interactions || []);
            setPostNotes(data.meeting.post_meeting_notes || '');
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
                                {contactName} at {companyName}
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
                        onClick={() => setActiveTab('overview')}
                        className={activeTab === 'overview' ? 'nav-pill nav-pill-active' : 'nav-pill nav-pill-inactive'}
                    >
                        Overview
                    </button>
                    <button
                        onClick={() => setActiveTab('prep')}
                        className={activeTab === 'prep' ? 'nav-pill nav-pill-active' : 'nav-pill nav-pill-inactive'}
                    >
                        Preparation
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
                {activeTab === 'overview' && (
                    <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
                        {/* Contact Info */}
                        <div className="premium-card p-6">
                            <h2 className="text-section-header mb-4">Contact Information</h2>
                            <div className="space-y-3">
                                <div>
                                    <p className="text-caption">Name</p>
                                    <p className="text-card-title">{contactName}</p>
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
                                {meeting.contact.company?.industry && (
                                    <div>
                                        <p className="text-caption">Industry</p>
                                        <p className="text-body">{meeting.contact.company.industry}</p>
                                    </div>
                                )}
                            </div>
                        </div>

                        {/* AI Talking Points */}
                        <div className="premium-card p-6">
                            <h2 className="text-section-header mb-4 flex items-center gap-2">
                                <Lightbulb className="w-5 h-5 text-amber-500" strokeWidth={2} />
                                AI-Generated Talking Points
                            </h2>
                            {meeting.ai_talking_points ? (
                                <ul className="space-y-2">
                                    {meeting.ai_talking_points.split('\n').filter(p => p.trim()).map((point, idx) => (
                                        <li key={idx} className="text-body flex items-start gap-2">
                                            <span className="text-indigo-600 mt-1">•</span>
                                            <span>{point.replace(/^[•-]\s*/, '')}</span>
                                        </li>
                                    ))}
                                </ul>
                            ) : (
                                <div className="text-center py-6">
                                    <p className="text-caption italic mb-4">No talking points generated</p>
                                    <Button size="sm" onClick={() => setActiveTab('prep')}>
                                        Go to Preparation
                                    </Button>
                                </div>
                            )}
                        </div>

                        {/* Pre-Meeting Notes */}
                        {meeting.pre_meeting_notes && (
                            <div className="premium-card p-6 lg:col-span-2">
                                <h2 className="text-section-header mb-4">Pre-Meeting Notes</h2>
                                <p className="text-body whitespace-pre-wrap">{meeting.pre_meeting_notes}</p>
                            </div>
                        )}

                        {/* Interaction Summary */}
                        {meeting.interaction_summary && (
                            <div className="premium-card p-6 lg:col-span-2">
                                <h2 className="text-section-header mb-4 flex items-center gap-2">
                                    <History className="w-5 h-5" strokeWidth={2} />
                                    Previous Interactions
                                </h2>
                                <p className="text-body whitespace-pre-wrap">{meeting.interaction_summary}</p>
                            </div>
                        )}
                    </div>
                )}

                {activeTab === 'prep' && (
                    <div className="space-y-6">
                        {/* Prep Component Placeholder - Will be properly imported and used below */}
                        <div className="premium-card p-6">
                            <h2 className="text-section-header mb-4">Meeting Intelligence</h2>
                            <p className="text-body text-gray-500">
                                Generate a comprehensive briefing including contact bio, relationship history, and suggested talking points.
                            </p>
                            {/* Client-side logic for the MeetingPrep component integration will be added in next step */}
                        </div>
                    </div>
                )}

                {activeTab === 'history' && (
                    <div className="premium-card p-6">
                        <h2 className="text-section-header mb-6">Interaction History</h2>
                        {interactions.length > 0 ? (
                            <div className="space-y-4">
                                {interactions.map((interaction) => (
                                    <div key={interaction.id} className="border-l-4 border-indigo-500 pl-4 py-2">
                                        <div className="flex justify-between items-start">
                                            <div>
                                                <p className="text-card-title capitalize">
                                                    {interaction.interaction_type.replace('_', ' ')}
                                                </p>
                                                {interaction.summary && (
                                                    <p className="text-body mt-1">{interaction.summary}</p>
                                                )}
                                            </div>
                                            <p className="text-caption">
                                                {new Date(interaction.interaction_date).toLocaleDateString()}
                                            </p>
                                        </div>
                                    </div>
                                ))}
                            </div>
                        ) : (
                            <p className="text-caption italic text-center py-8">No previous interactions</p>
                        )}
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
