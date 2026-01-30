'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { AppShell } from '@/components/layout/AppShell';
import { Button } from '@/components/ui/Button';
import { Calendar } from 'lucide-react';
import { Skeleton } from '@/components/ui/Skeleton';
import { MeetingsCalendar } from '@/components/meetings/MeetingsCalendar';

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

    useEffect(() => {
        fetchMeetings();

        const handleRefresh = () => fetchMeetings();
        const handleFocus = () => fetchMeetings();

        window.addEventListener('meeting:refresh', handleRefresh);
        window.addEventListener('focus', handleFocus);

        return () => {
            window.removeEventListener('meeting:refresh', handleRefresh);
            window.removeEventListener('focus', handleFocus);
        };
    }, []);

    const fetchMeetings = async () => {
        try {
            setLoading(true);
            // Fetch all meetings without status filter
            const response = await fetch(`/api/meetings`);
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
            <div className="max-w-7xl mx-auto h-[calc(100vh-80px)] flex flex-col">
                {/* Header */}
                <div className="mb-6 shrink-0">
                    <div className="flex items-center justify-between">
                        <div>
                            <h1 className="text-display mb-1">Meetings</h1>
                            <p className="text-body">
                                Manage your schedule and meeting briefs
                            </p>
                        </div>
                        <Button onClick={handleCreateMeeting}>
                            + New Meeting
                        </Button>
                    </div>
                </div>

                {/* Main Content */}
                <div className="flex-1 min-h-0 bg-white rounded-3xl border border-stone-200 shadow-sm overflow-hidden flex flex-col">
                    {loading ? (
                        <div className="flex-1 p-6">
                            <Skeleton className="w-full h-full rounded-2xl" />
                        </div>
                    ) : meetings.length === 0 ? (
                        <div className="flex-1 flex flex-col items-center justify-center p-12 text-center">
                            <div className="mb-4 flex h-12 w-12 items-center justify-center rounded-full bg-stone-100 text-stone-400 mx-auto">
                                <Calendar className="h-6 w-6" strokeWidth={2} />
                            </div>
                            <h3 className="text-card-title mb-2">No meetings found</h3>
                            <p className="text-body mb-6">
                                Get started by creating a new meeting brief.
                            </p>
                            <Button onClick={handleCreateMeeting}>
                                + New Meeting
                            </Button>
                        </div>
                    ) : (
                        <div className="flex-1 flex flex-col min-h-0">
                            <MeetingsCalendar
                                meetings={meetings as any}
                                initialView="month"
                                showToolbar={true}
                            />
                        </div>
                    )}
                </div>
            </div>
        </AppShell >
    );
}
