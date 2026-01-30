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

export default function HomePage() {
    const [loading, setLoading] = useState(true);
    const [dashboardData, setDashboardData] = useState<any>(null);

    useEffect(() => {
        fetchDashboardData();
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
        { label: 'Target Companies', value: summary.targets, icon: Target, color: 'text-blue-600', bg: 'bg-blue-50' },
        { label: 'Total Scans', value: summary.captured, icon: Camera, color: 'text-amber-600', bg: 'bg-amber-50' },
        { label: 'Enriched Profiles', value: summary.enriched, icon: CheckCircle2, color: 'text-purple-600', bg: 'bg-purple-50' },
        { label: 'Follow-ups Due', value: summary.drafts, icon: Clock, color: 'text-stone-600', bg: 'bg-stone-100' },
    ];

    const upcomingMeetings = dashboardData?.upcomingMeetings || [];
    const recentActivity = dashboardData?.recentActivity || [];
    const activeContacts = dashboardData?.activeContacts || [];

    return (
        <AppShell>
            <div className="max-w-7xl mx-auto h-[calc(100vh-8rem)] flex flex-col">
                {/* Header */}
                <div className="flex flex-col md:flex-row md:items-end justify-between gap-6 pb-6 shrink-0">
                    <div>
                        <h1 className="text-3xl font-bold tracking-tight text-stone-900 mb-1">Overview</h1>
                        <p className="text-sm text-stone-500">You have {upcomingMeetings.length} meetings scheduled for today.</p>
                    </div>

                    <div className="flex items-center gap-3">
                        <CaptureDropdown />
                        <Link href="/meetings/new">
                            <Button variant="outline" className="h-10 px-5 rounded-xl border-stone-200 hover:bg-stone-50 transition-all text-sm">
                                <Plus className="mr-2 h-4 w-4" />
                                Schedule Meeting
                            </Button>
                        </Link>
                    </div>
                </div>

                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8 shrink-0">
                    {stats.map((stat, i) => (
                        <div key={i} className="bg-white border border-stone-100 rounded-2xl p-5 shadow-sm hover:shadow-md transition-shadow group cursor-default">
                            <div className="flex items-start justify-between">
                                <div className={`p-2 rounded-xl ${stat.bg} ${stat.color} border border-current border-opacity-10`}>
                                    <stat.icon className="h-4 w-4" />
                                </div>
                                <span className="text-2xl font-bold text-stone-900 leading-none">{stat.value}</span>
                            </div>
                            <p className="mt-4 text-[10px] font-bold text-stone-400 uppercase tracking-widest">{stat.label}</p>
                        </div>
                    ))}
                </div>

                <div className="flex-1 grid grid-cols-1 lg:grid-cols-3 gap-8 min-h-0">

                    {/* Left Column: Schedule */}
                    <div className="lg:col-span-2 flex flex-col min-h-0">
                        <section className="bg-white border border-stone-100 rounded-3xl overflow-hidden flex flex-col h-full shadow-sm">
                            <div className="px-6 py-4 border-b border-stone-50 flex items-center justify-between shrink-0 bg-stone-50/30">
                                <h2 className="text-[10px] font-bold text-stone-900 uppercase tracking-[0.2em] flex items-center gap-2">
                                    <Calendar className="h-3.5 w-3.5 text-stone-400" />
                                    Today&apos;s Schedule
                                </h2>
                                <Link href="/meetings" className="text-[10px] font-bold text-indigo-600 hover:text-indigo-800 uppercase tracking-wider flex items-center gap-1 group">
                                    Full Calendar
                                    <ChevronRight className="h-3 w-3 transition-transform group-hover:translate-x-0.5" />
                                </Link>
                            </div>

                            <div className="flex-1 overflow-y-auto custom-scrollbar p-2">
                                {upcomingMeetings.length === 0 ? (
                                    <div className="h-full flex flex-col items-center justify-center opacity-40">
                                        <div className="w-12 h-12 bg-stone-50 rounded-2xl flex items-center justify-center mb-4 border border-stone-100">
                                            <Calendar className="h-6 w-6 text-stone-200" />
                                        </div>
                                        <p className="text-xs font-bold uppercase tracking-widest">No meetings today</p>
                                    </div>
                                ) : (
                                    <div className="space-y-1">
                                        {upcomingMeetings.map((meeting: any) => (
                                            <Link key={meeting.id} href={`/meetings/${meeting.id}`} className="flex items-center gap-4 p-4 hover:bg-stone-50 rounded-xl transition-all group">
                                                <div className="h-10 w-10 rounded-full bg-stone-100 text-stone-600 border border-stone-200 flex items-center justify-center text-[10px] font-bold shrink-0">
                                                    {meeting.contact?.first_name?.[0]}{meeting.contact?.last_name?.[0]}
                                                </div>
                                                <div className="flex-1 min-w-0">
                                                    <h3 className="text-sm font-bold text-stone-900 truncate group-hover:text-indigo-600 transition-colors">
                                                        {meeting.contact?.first_name} {meeting.contact?.last_name || ''}
                                                    </h3>
                                                    <p className="text-[10px] font-bold text-stone-400 uppercase tracking-tight">
                                                        {meeting.contact?.company?.name || 'Visitor'} • {meeting.meeting_location || formatLabel(meeting.meeting_type)}
                                                    </p>
                                                </div>
                                                <div className="text-right shrink-0">
                                                    <p className="text-sm font-bold text-stone-900 tracking-tighter">
                                                        {new Date(meeting.meeting_date).toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' })}
                                                    </p>
                                                    <p className="text-[9px] font-bold text-stone-400 uppercase tracking-widest">
                                                        {new Date(meeting.meeting_date).toLocaleDateString([], { month: 'short', day: 'numeric' })}
                                                    </p>
                                                </div>
                                            </Link>
                                        ))}
                                    </div>
                                )}
                            </div>
                        </section>
                    </div>

                    {/* Right Column: Activity Feed */}
                    <div className="lg:col-span-1 flex flex-col min-h-0">
                        <section className="bg-white border border-stone-100 rounded-3xl overflow-hidden flex flex-col h-full shadow-sm">
                            <div className="px-6 py-4 border-b border-stone-50 shrink-0 bg-stone-50/30">
                                <h2 className="text-[10px] font-bold text-stone-900 uppercase tracking-[0.2em] flex items-center gap-2">
                                    <MessageSquare className="h-3.5 w-3.5 text-stone-400" />
                                    Activity Feed
                                </h2>
                            </div>

                            <div className="flex-1 overflow-y-auto custom-scrollbar p-2">
                                {recentActivity.length === 0 ? (
                                    <div className="h-full flex flex-col items-center justify-center opacity-40">
                                        <Search className="h-8 w-8 mb-3 text-stone-200" />
                                        <p className="text-[10px] font-bold uppercase tracking-widest">No recent activity</p>
                                    </div>
                                ) : (
                                    <div className="space-y-1">
                                        {recentActivity.map((activity: any) => (
                                            <div key={activity.id} className="p-4 rounded-xl hover:bg-stone-50 transition-colors flex gap-4 group cursor-default">
                                                <div className="relative shrink-0">
                                                    <div className="h-10 w-10 rounded-full bg-white border border-stone-100 flex items-center justify-center text-[10px] font-bold text-stone-400 uppercase">
                                                        {activity.contact?.first_name?.[0] || '?'}{activity.contact?.last_name?.[0] || ''}
                                                    </div>
                                                    <div className="absolute -bottom-1 -right-1 h-5 w-5 rounded-full bg-white border border-stone-100 flex items-center justify-center shadow-sm">
                                                        {activity.interaction_type === 'capture' && <Camera className="h-2.5 w-2.5 text-blue-600" />}
                                                        {activity.interaction_type === 'note' && <MessageSquare className="h-2.5 w-2.5 text-emerald-600" />}
                                                        {activity.interaction_type === 'meeting' && <Calendar className="h-2.5 w-2.5 text-amber-600" />}
                                                    </div>
                                                </div>
                                                <div className="flex-1 min-w-0 pt-0.5">
                                                    <p className="text-xs font-bold text-stone-800 leading-snug">
                                                        {activity.summary ? formatLabel(activity.summary) : `${formatLabel(activity.interaction_type)} logged`}
                                                    </p>
                                                    <div className="flex items-center gap-2 mt-2">
                                                        <Link href={`/contacts/${activity.contact?.id}`} className="text-[10px] font-bold text-stone-400 hover:text-indigo-600 transition-colors uppercase tracking-widest">
                                                            {activity.contact?.first_name} {activity.contact?.last_name}
                                                        </Link>
                                                        <span className="text-stone-200 text-xs">•</span>
                                                        <span className="text-[10px] font-bold text-stone-300 uppercase tracking-widest font-mono">
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
