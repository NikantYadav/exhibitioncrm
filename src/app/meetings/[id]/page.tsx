'use client';

import { useEffect, useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import Link from 'next/link';
import { AppShell } from '@/components/layout/AppShell';
import { Button } from '@/components/ui/Button';
import { Textarea } from '@/components/ui/Textarea';
import { ArrowLeft, Calendar, MapPin, Lightbulb, History, FileText, CheckCircle, Edit, Save, X } from 'lucide-react';
import { cn, formatLabel } from '@/lib/utils';
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
    const [isEditingNotes, setIsEditingNotes] = useState(false);
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
            setPostNotes(data.meeting.status === 'completed'
                ? (data.meeting.post_meeting_notes || '')
                : (data.meeting.pre_meeting_notes || ''));

            // Default to notes for completed meetings
            if (data.meeting.status === 'completed') {
                setActiveTab('notes');
            }

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

    const handleSavePrep = async () => {
        try {
            const response = await fetch(`/api/meetings/${params.id}`, {
                method: 'PATCH',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ pre_meeting_notes: postNotes }),
            });

            if (response.ok) {
                toast.success('Prep notes updated');
                setIsEditingNotes(false);
                fetchMeetingData();
            } else {
                toast.error('Failed to update prep');
            }
        } catch (error) {
            toast.error('An error occurred');
        }
    };

    const handleSaveNotes = async () => {
        if (meeting?.status === 'scheduled') {
            return handleSavePrep();
        }
        try {
            const response = await fetch(`/api/meetings/${params.id}`, {
                method: 'PATCH',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ post_meeting_notes: postNotes }),
            });

            if (response.ok) {
                toast.success('Notes saved successfully');
                setIsEditingNotes(false);
                window.dispatchEvent(new CustomEvent('timeline:refresh'));
                fetchMeetingData();
            } else {
                toast.error('Failed to save notes');
            }
        } catch (error) {
            console.error('Save notes error:', error);
            toast.error('An error occurred while saving');
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
            <div className="max-w-5xl mx-auto py-8 px-4">
                {/* Refined Header */}
                <div className="mb-10">
                    <button
                        onClick={() => router.push('/meetings')}
                        className="group mb-8 flex items-center gap-2 text-[10px] font-bold uppercase tracking-[0.2em] text-stone-400 hover:text-stone-900 transition-colors"
                    >
                        <ArrowLeft className="h-3 w-3 transition-transform group-hover:-translate-x-1" />
                        Return to Dashboard
                    </button>

                    <div className="flex flex-col md:flex-row md:items-end md:justify-between gap-8">
                        <div className="space-y-4">
                            <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-stone-100 text-[10px] font-bold text-stone-600 uppercase tracking-widest border border-stone-200/50">
                                <Calendar className="w-3 h-3" />
                                {new Date(meeting.meeting_date).toLocaleDateString(undefined, { month: 'long', day: 'numeric', year: 'numeric' })}
                            </div>

                            <div>
                                <h1 className="text-4xl md:text-5xl font-bold tracking-tight text-stone-900 mb-3">
                                    {meeting.status === 'completed' ? 'Interaction Archive' : 'Meeting Briefing'}
                                </h1>
                                <div className="flex flex-wrap items-center gap-x-2 gap-y-1 text-xl text-stone-500">
                                    <span className="text-stone-400">Discussion with</span>
                                    <Link href={`/contacts/${meeting.contact.id}`} className="font-semibold text-stone-900 hover:text-indigo-600 border-b-2 border-stone-200 hover:border-indigo-200 transition-all">
                                        {contactName}
                                    </Link>
                                    <span className="text-stone-400">at</span>
                                    <span className="font-semibold text-stone-800">{companyName}</span>
                                </div>
                            </div>

                            <div className="flex flex-wrap items-center gap-6 text-sm text-stone-500">
                                <div className="flex items-center gap-2">
                                    <div className="w-2 h-2 rounded-full bg-stone-300" />
                                    <span className="font-medium">{formatLabel(meeting.meeting_type)} Engagement</span>
                                </div>
                                {meeting.meeting_location && (
                                    <div className="flex items-center gap-2">
                                        <MapPin className="w-4 h-4 text-stone-400" />
                                        <span>{meeting.meeting_location}</span>
                                    </div>
                                )}
                            </div>
                        </div>

                        {meeting.status === 'scheduled' && (
                            <Button
                                onClick={handleCompleteMeeting}
                                className="bg-stone-900 hover:bg-black text-white px-8 py-6 rounded-2xl shadow-xl shadow-stone-200 transition-all hover:scale-105 active:scale-95"
                            >
                                <CheckCircle className="mr-2 h-5 w-5" />
                                Mark as Completed
                            </Button>
                        )}
                    </div>
                </div>

                {/* High-End Tabs */}
                <div className="relative mb-12">
                    <div className="flex items-center gap-1 p-1 bg-stone-100/50 backdrop-blur-sm rounded-2xl border border-stone-200/50 w-fit">
                        {meeting.status !== 'completed' && (
                            <button
                                onClick={() => setActiveTab('briefing')}
                                className={`px-6 py-2.5 rounded-xl text-sm font-bold transition-all duration-300 ${activeTab === 'briefing'
                                    ? 'bg-white text-stone-900 shadow-sm border border-stone-200/50'
                                    : 'text-stone-500 hover:text-stone-700'
                                    }`}
                            >
                                Briefing
                            </button>
                        )}
                        <button
                            onClick={() => setActiveTab('notes')}
                            className={`px-6 py-2.5 rounded-xl text-sm font-bold transition-all duration-300 ${activeTab === 'notes'
                                ? 'bg-white text-stone-900 shadow-sm border border-stone-200/50'
                                : 'text-stone-500 hover:text-stone-700'
                                }`}
                        >
                            {meeting.status === 'completed' ? 'Archive Summary' : 'Session Prep'}
                        </button>
                        <button
                            onClick={() => setActiveTab('history')}
                            className={`px-6 py-2.5 rounded-xl text-sm font-bold transition-all duration-300 ${activeTab === 'history'
                                ? 'bg-white text-stone-900 shadow-sm border border-stone-200/50'
                                : 'text-stone-500 hover:text-stone-700'
                                }`}
                        >
                            Relationship Timeline
                        </button>
                    </div>
                </div>

                {/* Content */}
                {activeTab === 'briefing' && (
                    <div className="space-y-8">
                        {/* Top Section: Contact Info & Pre-meeting notes */}
                        <div className="grid grid-cols-1 lg:grid-cols-4 gap-8">
                            {/* Contact Info */}
                            <div className="premium-card p-8 lg:col-span-1">
                                <h2 className="text-[10px] font-bold text-stone-400 uppercase tracking-[0.2em] mb-6">Contact Profile</h2>
                                <div className="space-y-6">
                                    <div>
                                        <p className="text-[10px] font-bold text-stone-400 uppercase tracking-widest mb-1">Full Name</p>
                                        <Link
                                            href={`/contacts/${meeting.contact.id}`}
                                            className="text-lg font-bold text-stone-900 hover:text-indigo-600 transition-colors inline-block"
                                        >
                                            {contactName}
                                        </Link>
                                    </div>
                                    {meeting.contact.job_title && (
                                        <div>
                                            <p className="text-[10px] font-bold text-stone-400 uppercase tracking-widest mb-1">Designation</p>
                                            <p className="text-stone-700 font-medium">{meeting.contact.job_title}</p>
                                        </div>
                                    )}
                                    {meeting.contact.email && (
                                        <div>
                                            <p className="text-[10px] font-bold text-stone-400 uppercase tracking-widest mb-1">Email Address</p>
                                            <a href={`mailto:${meeting.contact.email}`} className="text-stone-700 hover:text-indigo-600 transition-colors">
                                                {meeting.contact.email}
                                            </a>
                                        </div>
                                    )}
                                    <div>
                                        <p className="text-[10px] font-bold text-stone-400 uppercase tracking-widest mb-1">Company</p>
                                        <p className="text-stone-700 font-medium">{companyName}</p>
                                    </div>
                                    {meeting.event && (
                                        <div className="pt-4 border-t border-stone-100">
                                            <p className="text-[10px] font-bold text-stone-400 uppercase tracking-widest mb-2">Acquisition Event</p>
                                            <Link
                                                href={`/events/${meeting.event.id}`}
                                                className="inline-flex items-center gap-2 px-3 py-1 rounded-lg bg-stone-50 text-xs font-bold text-stone-600 border border-stone-100 hover:bg-stone-100 transition-colors"
                                            >
                                                {meeting.event.name}
                                            </Link>
                                        </div>
                                    )}
                                </div>
                            </div>

                            {/* Briefing Intelligence Summary (Visible only when upcoming) */}
                            {meeting.status === 'scheduled' && (
                                <div className="lg:col-span-3 premium-card p-8 flex flex-col justify-center bg-stone-50/20">
                                    <h2 className="text-[10px] font-bold text-stone-400 uppercase tracking-[0.2em] mb-4">Briefing Status</h2>
                                    <p className="text-2xl font-bold text-stone-900 leading-snug">
                                        Preparing for {formatLabel(meeting.meeting_type)} Engagement
                                    </p>
                                    <p className="text-stone-500 mt-2 max-w-lg">
                                        Use the <span className="text-stone-900 font-bold">Session Prep</span> tab to define your meeting objectives and outcomes before commencing.
                                    </p>
                                </div>
                            )}
                        </div>

                        {/* Middle Section: AI Preparation */}
                        <section className="pt-2">
                            <div className="flex items-center gap-3 mb-6">
                                <div className="p-2 bg-stone-100 rounded-lg">
                                    <Lightbulb className="w-4 h-4 text-stone-600" />
                                </div>
                                <h2 className="text-sm font-bold text-stone-900 uppercase tracking-widest">Meeting Intelligence</h2>
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
                        <ContactTimeline
                            timeline={timeline}
                            onRefresh={fetchMeetingData}
                            hideBriefingLinks={true}
                        />
                    </div>
                )}

                {activeTab === 'notes' && (
                    <div className="space-y-8 max-w-4xl mx-auto">
                        {/* Premium Summary Header */}
                        {meeting.status === 'completed' && (
                            <div className="relative overflow-hidden rounded-3xl bg-stone-900 p-8 text-white shadow-2xl">
                                <div className="relative z-10 flex flex-col md:flex-row md:items-center justify-between gap-6">
                                    <div className="space-y-2">
                                        <h2 className="text-3xl font-bold tracking-tight">Meeting Outcome</h2>
                                        <p className="text-stone-400 text-sm max-w-md leading-relaxed">
                                            The discussion with {contactName} on {new Date(meeting.meeting_date).toLocaleDateString()} has been synthesized into your relationship timeline.
                                        </p>
                                    </div>
                                </div>
                                {/* Subtle decorative element */}
                                <div className="absolute top-0 right-0 -mr-16 -mt-16 h-64 w-64 rounded-full bg-indigo-500/10 blur-3xl" />
                            </div>
                        )}

                        <div className="premium-card overflow-hidden">
                            <div className="px-8 py-6 border-b border-stone-100 bg-stone-50/30 flex items-center justify-between">
                                <div className="flex items-center gap-3">
                                    <div className="p-2 bg-white rounded-lg shadow-sm border border-stone-100">
                                        <FileText className="w-5 h-5 text-stone-600" />
                                    </div>
                                    <h3 className="text-section-header">
                                        {meeting.status === 'completed' ? 'Synthesis & Outcomes' : 'Strategic Preparation'}
                                    </h3>
                                </div>
                                {!isEditingNotes && (
                                    <Button
                                        variant="outline"
                                        size="sm"
                                        onClick={() => setIsEditingNotes(true)}
                                        className="rounded-full px-4 border-stone-300 hover:bg-stone-900 hover:text-white transition-all duration-300"
                                    >
                                        <Edit className="h-4 w-4 mr-2" />
                                        {postNotes ? 'Refine' : (meeting.status === 'completed' ? 'Add Outcomes' : 'Set Objectives')}
                                    </Button>
                                )}
                            </div>

                            <div className="p-8">
                                {isEditingNotes ? (
                                    <div className="space-y-6">
                                        <div className="relative">
                                            <Textarea
                                                value={postNotes}
                                                onChange={(e) => setPostNotes(e.target.value)}
                                                className="min-h-[400px] text-lg leading-relaxed bg-stone-50/50 border-stone-200 focus:border-stone-400 focus:ring-0 rounded-2xl p-6 transition-all"
                                                placeholder={meeting.status === 'completed'
                                                    ? "What were the breakthroughs? What needs to happen next?"
                                                    : "What do you want to achieve in this session? What are the key objectives?"}
                                                autoFocus
                                            />
                                        </div>
                                        <div className="flex justify-end gap-3">
                                            <Button
                                                variant="ghost"
                                                onClick={() => {
                                                    setIsEditingNotes(false);
                                                    setPostNotes(meeting!.status === 'completed'
                                                        ? (meeting!.post_meeting_notes || '')
                                                        : (meeting!.pre_meeting_notes || ''));
                                                }}
                                                className="text-stone-500 hover:text-stone-900"
                                            >
                                                Discard
                                            </Button>
                                            <Button
                                                onClick={handleSaveNotes}
                                                className="bg-stone-900 hover:bg-black text-white px-8 rounded-full shadow-lg shadow-stone-200"
                                            >
                                                <Save className="h-4 w-4 mr-2" />
                                                Commit to Memory
                                            </Button>
                                        </div>
                                    </div>
                                ) : (
                                    <div
                                        className={`group relative min-h-[300px] rounded-2xl transition-all duration-500 ${postNotes
                                            ? 'bg-white'
                                            : 'bg-stone-50/50 border-2 border-dashed border-stone-200 flex items-center justify-center cursor-pointer hover:border-stone-400 hover:bg-stone-100/50'
                                            }`}
                                        onClick={() => !postNotes && setIsEditingNotes(true)}
                                    >
                                        {postNotes ? (
                                            <div className="relative">
                                                {/* Decorative Quote Mark */}
                                                <span className="absolute -top-6 -left-4 text-8xl text-stone-100 font-serif pointer-events-none select-none">“</span>
                                                <div className="relative z-10 space-y-4">
                                                    <p className="text-xl text-stone-800 leading-[1.8] font-medium italic">
                                                        {postNotes}
                                                    </p>
                                                </div>
                                            </div>
                                        ) : (
                                            <div className="text-center group-hover:scale-105 transition-transform duration-300">
                                                <div className="w-16 h-16 bg-white rounded-2xl shadow-sm border border-stone-100 flex items-center justify-center mx-auto mb-4">
                                                    <Edit className="h-6 w-6 text-stone-400" />
                                                </div>
                                                <p className="text-stone-500 font-medium">
                                                    {meeting.status === 'completed' ? 'No outcome recorded yet' : 'No prep recorded yet'}
                                                </p>
                                                <p className="text-stone-400 text-sm">
                                                    {meeting.status === 'completed' ? 'Click to begin the archive process' : 'Click to define your objectives'}
                                                </p>
                                            </div>
                                        )}
                                    </div>
                                )}
                            </div>
                        </div>
                    </div>
                )}
            </div>
        </AppShell>
    );
}
