'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { AppShell } from '@/components/layout/AppShell';
import { Button } from '@/components/ui/Button';
import { Calendar, Plus } from 'lucide-react';
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
            <div className="max-w-7xl mx-auto px-4 py-8 min-h-[calc(100vh-4rem)] flex flex-col">
                {/* Tactical Header */}
                <div className="mb-10 shrink-0">
                    <div className="flex flex-col md:flex-row md:items-end justify-between gap-8">
                        <div>
                            <h1 className="text-4xl font-black text-stone-900 tracking-tight leading-tight mb-2">Meetings</h1>
                            <p className="text-sm font-medium text-stone-500 italic">
                                Schedule and track your meetings with contacts.
                            </p>
                        </div>
                        <Button
                            onClick={handleCreateMeeting}
                            className="bg-stone-900 hover:bg-stone-800 text-white rounded-xl px-8 h-12 shadow-xl shadow-stone-900/10 font-black uppercase tracking-widest text-[10px] active:scale-95 transition-all"
                        >
                            <Plus className="mr-2 h-4 w-4" strokeWidth={3} />
                            Schedule Meeting
                        </Button>
                    </div>
                </div>

                {/* Main Calendar Interface */}
                <div className="flex-1 min-h-0 bg-white rounded-[3rem] border border-stone-100 shadow-sm overflow-hidden flex flex-col hover:shadow-md transition-shadow">
                    {loading ? (
                        <div className="flex-1 p-10">
                            <Skeleton className="w-full h-full rounded-[2rem]" />
                        </div>
                    ) : meetings.length === 0 ? (
                        <div className="flex-1 flex flex-col items-center justify-center p-20 text-center">
                            <div className="mb-8 flex h-20 w-20 items-center justify-center rounded-[2rem] bg-stone-900 text-white shadow-2xl shadow-stone-900/20 group hover:scale-110 transition-transform">
                                <Calendar className="h-10 w-10" strokeWidth={2.5} />
                            </div>
                            <h3 className="text-2xl font-black text-stone-900 mb-3 tracking-tight">No meetings scheduled</h3>
                            <p className="text-sm text-stone-500 mb-10 max-w-sm mx-auto font-medium italic leading-relaxed">
                                You haven't scheduled any meetings yet. Add your first meeting to get started.
                            </p>
                            <Button
                                onClick={handleCreateMeeting}
                                className="h-12 px-8 bg-stone-900 hover:bg-stone-800 text-white rounded-xl font-black uppercase tracking-widest text-[10px] shadow-xl shadow-stone-900/10 active:scale-95 transition-all"
                            >
                                <Plus className="mr-2 h-4 w-4" strokeWidth={3} />
                                Schedule First Meeting
                            </Button>
                        </div>
                    ) : (
                        <div className="flex-1 flex flex-col min-h-0 p-4">
                            <MeetingsCalendar
                                meetings={meetings as any}
                                initialView="month"
                                showToolbar={true}
                            />
                        </div>
                    )}
                </div>
            </div>
        </AppShell>
    );
}
