'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { AppShell } from '@/components/layout/AppShell';
import { Button } from '@/components/ui/Button';
import { Calendar, Clock, ChevronRight } from 'lucide-react';
import { Skeleton } from '@/components/ui/Skeleton';
import { cn, formatLabel } from '@/lib/utils';

interface MeetingBrief {
    id: string;
    meeting_date: string;
    meeting_type: string;
    status: string;
    contact: {
        first_name: string;
        last_name?: string;
        company?: {
            name: string;
        };
    };
}

export default function MeetingsPage() {
    const router = useRouter();
    const [meetings, setMeetings] = useState<MeetingBrief[]>([]);
    const [loading, setLoading] = useState(true);
    const [activeTab, setActiveTab] = useState<'scheduled' | 'completed'>('scheduled');

    useEffect(() => {
        fetchMeetings();
    }, [activeTab]);

    const fetchMeetings = async () => {
        try {
            setLoading(true);
            const response = await fetch(`/api/meetings?status=${activeTab}`);
            if (!response.ok) throw new Error('Failed to fetch meetings');

            const data = await response.json();
            setMeetings(data.meetings || []);
        } catch (error) {
            console.error('Error fetching meetings:', error);
        } finally {
            setLoading(false);
        }
    };

    const handleCreateMeeting = () => {
        router.push('/meetings/new');
    };

    return (
        <AppShell>
            <div className="max-w-7xl mx-auto">
                {/* Header */}
                <div className="mb-8">
                    <div className="flex items-center justify-between mb-6">
                        <div>
                            <h1 className="text-display mb-1">Meeting Briefs</h1>
                            <p className="text-body">
                                Prepare for meetings with AI-powered insights
                            </p>
                        </div>
                        <Button onClick={handleCreateMeeting}>
                            + New Meeting
                        </Button>
                    </div>

                    {/* Tabs */}
                    <div className="flex items-center gap-2">
                        <button
                            onClick={() => setActiveTab('scheduled')}
                            className={activeTab === 'scheduled' ? 'nav-pill nav-pill-active' : 'nav-pill nav-pill-inactive'}
                        >
                            Upcoming
                        </button>
                        <button
                            onClick={() => setActiveTab('completed')}
                            className={activeTab === 'completed' ? 'nav-pill nav-pill-active' : 'nav-pill nav-pill-inactive'}
                        >
                            Completed
                        </button>
                    </div>
                </div>

                {/* Meetings List */}
                <div>
                    {loading ? (
                        <div className="grid gap-4">
                            {[1, 2, 3].map((i) => (
                                <div key={i} className="premium-card p-6 flex flex-col gap-4">
                                    <div className="flex justify-between items-start">
                                        <div className="space-y-2 flex-1">
                                            <div className="flex items-center gap-3">
                                                <Skeleton className="h-6 w-1/4" />
                                                <Skeleton className="h-5 w-20 rounded-full" />
                                            </div>
                                            <Skeleton className="h-4 w-1/3" />
                                        </div>
                                        <Skeleton className="h-5 w-5 rounded-md" />
                                    </div>
                                    <div className="flex gap-4">
                                        <Skeleton className="h-4 w-24" />
                                        <Skeleton className="h-4 w-24" />
                                        <Skeleton className="h-4 w-20" />
                                    </div>
                                </div>
                            ))}
                        </div>
                    ) : meetings.length === 0 ? (
                        <div className="premium-card p-12 text-center">
                            <div className="mb-4 flex h-12 w-12 items-center justify-center rounded-full bg-stone-100 text-stone-400 mx-auto">
                                <Calendar className="h-6 w-6" strokeWidth={2} />
                            </div>
                            <h3 className="text-card-title mb-2">No meetings</h3>
                            <p className="text-body mb-6">
                                Get started by creating a new meeting brief.
                            </p>
                            <Button onClick={handleCreateMeeting}>
                                + New Meeting
                            </Button>
                        </div>
                    ) : (
                        <div className="grid gap-4">
                            {meetings.map((meeting) => {
                                const contactName = `${meeting.contact.first_name} ${meeting.contact.last_name || ''}`.trim();
                                const companyName = meeting.contact.company?.name || 'Unknown Company';
                                const meetingDate = new Date(meeting.meeting_date);

                                return (
                                    <Link
                                        key={meeting.id}
                                        href={`/meetings/${meeting.id}`}
                                        className="premium-card p-6 hover:shadow-lg transition-smooth cursor-pointer group"
                                    >
                                        <div className="flex items-center justify-between">
                                            <div className="flex-1">
                                                <div className="flex items-center gap-3 mb-2">
                                                    <h3 className="text-card-title group-hover:text-indigo-600 transition-colors">
                                                        {contactName}
                                                    </h3>
                                                    <span className={`px-2 py-1 text-xs font-medium rounded-full ${meeting.status === 'scheduled'
                                                        ? 'bg-blue-100 text-blue-800'
                                                        : 'bg-green-100 text-green-800'
                                                        }`}>
                                                        {formatLabel(meeting.status)}
                                                    </span>
                                                </div>
                                                <p className="text-body mb-3">{companyName}</p>
                                                <div className="flex items-center gap-4 text-caption">
                                                    <span className="flex items-center gap-1.5">
                                                        <Calendar className="w-4 h-4" strokeWidth={2} />
                                                        {meetingDate.toLocaleDateString()}
                                                    </span>
                                                    <span className="flex items-center gap-1.5">
                                                        <Clock className="w-4 h-4" strokeWidth={2} />
                                                        {meetingDate.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                                                    </span>
                                                    <span>{formatLabel(meeting.meeting_type)}</span>
                                                </div>
                                            </div>
                                            <ChevronRight className="w-5 h-5 text-stone-400 group-hover:text-indigo-600 transition-colors" strokeWidth={2} />
                                        </div>
                                    </Link>
                                );
                            })}
                        </div>
                    )}
                </div>
            </div>
        </AppShell >
    );
}
