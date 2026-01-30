'use client';

import { useState, useEffect } from 'react';
import Link from 'next/link';
import { AppShell } from '@/components/layout/AppShell';
import { Avatar, AvatarFallback } from '@/components/ui/Avatar';
import { Button } from '@/components/ui/Button';
import { Skeleton } from '@/components/ui/Skeleton';
import {
    Plus,
    Calendar,
    Camera,
    ArrowRight,
    Users,
    CheckCircle2,
    Clock,
    Target,
    Zap,
    TrendingUp,
    MessageSquare,
    ChevronRight,
    Search
} from 'lucide-react';
import { CaptureDropdown } from '@/components/capture/CaptureDropdown';
import { cn, formatLabel } from '@/lib/utils';
import { MeetingsCalendar } from '@/components/meetings/MeetingsCalendar';

export default function HomePage() {
    const [loading, setLoading] = useState(true);
    const [dashboardData, setDashboardData] = useState<any>(null);

    useEffect(() => {
        fetchDashboardData();

        const handleRefresh = () => fetchDashboardData();
        const handleFocus = () => {
            // Optional: debounce or check time since last fetch
            fetchDashboardData();
        };

        window.addEventListener('meeting:refresh', handleRefresh);
        window.addEventListener('focus', handleFocus);

        return () => {
            window.removeEventListener('meeting:refresh', handleRefresh);
            window.removeEventListener('focus', handleFocus);
        };
    }, []);

    const fetchDashboardData = async () => {
        try {
            const response = await fetch('/api/dashboard/summary');
            if (response.ok) {
                const data = await response.json();
                setDashboardData(data);
            }
        } catch (error) {
            console.error('Failed to fetch dashboard data:', error);
        } finally {
            setLoading(false);
        }
    };

    if (loading) {
        return (
            <AppShell>
                <div className="max-w-7xl mx-auto space-y-12">
                    <div className="space-y-4">
                        <Skeleton className="h-10 w-48" />
                        <Skeleton className="h-4 w-72" />
                    </div>
                    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
                        {[1, 2, 3, 4].map(i => <Skeleton key={i} className="h-32 rounded-2xl" />)}
                    </div>
                    <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
                        <Skeleton className="lg:col-span-2 h-[500px] rounded-2xl" />
                        <Skeleton className="h-[500px] rounded-2xl" />
                    </div>
                </div>
            </AppShell>
        );
    }

    const summary = dashboardData?.summary || { targets: 0, captured: 0, enriched: 0, drafts: 0, sent: 0 };

    const stats = [
        { label: 'Target Companies', value: summary.targets, icon: Target },
        { label: 'Total Scans', value: summary.captured, icon: Camera },
        { label: 'Enriched Profiles', value: summary.enriched, icon: CheckCircle2 },
        { label: 'Follow-ups Due', value: summary.drafts, icon: Clock },
    ];

    const upcomingMeetings = dashboardData?.upcomingMeetings || [];
    const recentActivity = dashboardData?.recentActivity || [];
    const activeContacts = dashboardData?.activeContacts || [];

    return (
        <AppShell>
            <div className="max-w-7xl mx-auto px-4 py-6 h-[calc(100vh-6rem)] flex flex-col">
                {/* Header Section */}
                <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 pb-4 shrink-0">
                    <div>
                        <h1 className="text-3xl font-black text-stone-900 tracking-tight leading-tight">Dashboard</h1>
                        <p className="text-[10px] font-bold text-stone-400 uppercase tracking-widest">Your network summary</p>
                    </div>

                    <div className="flex items-center gap-3">
                        <CaptureDropdown />
                        <Link href="/meetings/new">
                            <Button className="h-10 px-6 bg-stone-900 hover:bg-stone-800 text-white rounded-xl shadow-lg shadow-stone-900/10 font-black uppercase tracking-widest text-[9px] transition-all active:scale-95">
                                <Plus className="mr-2 h-3.5 w-3.5" strokeWidth={3} />
                                New Meeting
                            </Button>
                        </Link>
                    </div>
                </div>

                {/* Performance Metrics */}
                <div className="grid grid-cols-2 lg:grid-cols-4 gap-3 mb-4 shrink-0">
                    {stats.map((stat, i) => (
                        <div key={i} className="group relative bg-white border border-stone-100 rounded-2xl p-3 shadow-sm transition-all duration-300 hover:border-stone-200 cursor-default flex items-center gap-3">
                            <div className="p-2 rounded-lg bg-stone-900 text-white shadow-md shadow-stone-900/10 shrink-0">
                                <stat.icon className="h-3.5 w-3.5" strokeWidth={3} />
                            </div>
                            <div className="min-w-0">
                                <p className="text-[9px] font-black text-stone-400 uppercase tracking-widest leading-none mb-1">{stat.label}</p>
                                <span className="text-lg font-black text-stone-900 tracking-tighter leading-none">{stat.value}</span>
                            </div>
                        </div>
                    ))}
                </div>

                <div className="flex-1 grid grid-cols-1 lg:grid-cols-3 gap-10 min-h-0">

                    {/* Left Panel: Schedule */}
                    <div className="lg:col-span-2 flex flex-col min-h-0">
                        <section className="bg-white border border-stone-100 rounded-[2.5rem] overflow-hidden flex flex-col h-full shadow-sm hover:border-stone-200 transition-all">
                            <div className="px-8 py-6 border-b border-stone-100 flex items-center justify-between shrink-0 bg-stone-50/50">
                                <h2 className="text-[10px] font-black text-stone-900 uppercase tracking-[0.2em] flex items-center gap-3">
                                    <Calendar className="h-4 w-4 text-stone-900" strokeWidth={3} />
                                    Timeline
                                </h2>
                                <Link href="/meetings" className="text-[10px] font-black text-stone-900 hover:text-stone-600 uppercase tracking-widest flex items-center gap-2 transition-colors">
                                    View All
                                    <ChevronRight className="h-3.5 w-3.5" strokeWidth={3} />
                                </Link>
                            </div>

                            <div className="flex-1 overflow-y-auto custom-scrollbar p-6">
                                {upcomingMeetings.length === 0 ? (
                                    <div className="h-full flex flex-col items-center justify-center">
                                        <div className="w-16 h-16 bg-stone-50 rounded-[1.2rem] flex items-center justify-center mb-6 border border-stone-100 shadow-inner">
                                            <Calendar className="h-7 w-7 text-stone-200" strokeWidth={1.5} />
                                        </div>
                                        <p className="text-[10px] font-black uppercase tracking-widest text-stone-300">No upcoming meetings</p>
                                    </div>
                                ) : (
                                    <div className="h-full">
                                        <MeetingsCalendar
                                            meetings={upcomingMeetings}
                                            initialView="day"
                                            showToolbar={true}
                                            availableViews={['day', 'week']}
                                        />
                                    </div>
                                )}
                            </div>
                        </section>
                    </div>

                    {/* Right Panel: Activity Feed */}
                    <div className="lg:col-span-1 flex flex-col min-h-0">
                        <section className="bg-white border border-stone-100 rounded-[2.5rem] overflow-hidden flex flex-col h-full shadow-sm hover:border-stone-200 transition-all">
                            <div className="px-8 py-6 border-b border-stone-100 shrink-0 bg-stone-50/50">
                                <h2 className="text-[10px] font-black text-stone-900 uppercase tracking-[0.2em] flex items-center gap-3">
                                    <Zap className="h-4 w-4 text-stone-900" strokeWidth={3} />
                                    Daily Feed
                                </h2>
                            </div>

                            <div className="flex-1 overflow-y-auto custom-scrollbar p-5">
                                {recentActivity.length === 0 ? (
                                    <div className="h-full flex flex-col items-center justify-center opacity-40">
                                        <Search className="h-8 w-8 mb-6 text-stone-200" strokeWidth={1.5} />
                                        <p className="text-[10px] font-black uppercase tracking-widest text-stone-300">No recent activity</p>
                                    </div>
                                ) : (
                                    <div className="space-y-3">
                                        {recentActivity.map((activity: any) => (
                                            <div key={activity.id} className="p-5 rounded-[1.8rem] bg-stone-50/50 hover:bg-white transition-all duration-300 flex gap-4 group cursor-default border border-transparent hover:border-stone-100">
                                                <div className="relative shrink-0">
                                                    <div className="h-10 w-10 rounded-xl bg-stone-900 flex items-center justify-center text-[10px] font-black text-white uppercase tracking-tighter shadow-sm transition-transform">
                                                        {activity.contact?.first_name?.[0] || '?'}{activity.contact?.last_name?.[0] || ''}
                                                    </div>
                                                    <div className="absolute -bottom-1 -right-1 h-5 w-5 rounded-lg bg-white border border-stone-100 text-stone-900 flex items-center justify-center shadow-md">
                                                        {activity.interaction_type === 'capture' && <Camera className="h-2.5 w-2.5" strokeWidth={3} />}
                                                        {activity.interaction_type === 'note' && <MessageSquare className="h-2.5 w-2.5" strokeWidth={3} />}
                                                        {activity.interaction_type === 'meeting' && <Calendar className="h-2.5 w-2.5" strokeWidth={3} />}
                                                    </div>
                                                </div>
                                                <div className="flex-1 min-w-0">
                                                    <p className="text-[11px] font-black text-stone-900 leading-snug tracking-tight mb-1.5">
                                                        {activity.summary ? activity.summary : `${activity.interaction_type} recorded`}
                                                    </p>
                                                    <div className="flex items-center gap-2">
                                                        <Link href={`/contacts/${activity.contact?.id}`} className="text-[9px] font-black text-stone-400 hover:text-stone-900 transition-colors uppercase tracking-widest">
                                                            {activity.contact?.first_name} {activity.contact?.last_name}
                                                        </Link>
                                                        <span className="text-stone-200 text-xs">•</span>
                                                        <span className="text-[9px] font-black text-stone-300 uppercase tracking-widest font-mono">
                                                            {new Date(activity.interaction_date).toLocaleDateString([], { month: 'short', day: 'numeric' })}
                                                        </span>
                                                    </div>
                                                </div>
                                            </div>
                                        ))}
                                    </div>
                                )}
                            </div>
                        </section>
                    </div>
                </div>
            </div>
        </AppShell>
    );
}
