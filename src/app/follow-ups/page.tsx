
'use client';

import { useState, useEffect } from 'react';
import { AppShell } from '@/components/layout/AppShell';
import { Button } from '@/components/ui/Button';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/Card';
import { ArrowRight, Calendar, Users, Mail, CheckCircle, Clock, XCircle, BarChart3, ChevronDown, ChevronUp } from 'lucide-react';
import { Skeleton } from '@/components/ui/Skeleton';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { FollowUpsSection } from '@/components/events/detail/FollowUpsSection';
import { syncChannel, SyncEventType } from '@/lib/events';

export default function FollowUpDashboard() {
    const router = useRouter();
    const [events, setEvents] = useState<any[]>([]);
    const [followUpData, setFollowUpData] = useState<any>(null);
    const [loading, setLoading] = useState(true);
    const [expandedEventId, setExpandedEventId] = useState<string | null>(null);

    const refreshDashboard = async () => {
        try {
            // Fetch events and follow-ups in parallel
            const [eventsRes, followUpsRes] = await Promise.all([
                fetch('/api/events'),
                fetch('/api/follow-ups')
            ]);

            const eventsData = await eventsRes.json();
            const followUpsData = await followUpsRes.json();

            setEvents(eventsData.data || []);
            setFollowUpData(followUpsData.data);
        } catch (error) {
            console.error('Failed to load dashboard data:', error);
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        refreshDashboard();

        // Listen for sync events from other tabs/pages
        if (syncChannel) {
            const handleMessage = (event: MessageEvent) => {
                if (event.data.type === SyncEventType.CONTACT_UPDATED) {
                    refreshDashboard();
                }
            };
            syncChannel.addEventListener('message', handleMessage);
            return () => {
                syncChannel?.removeEventListener('message', handleMessage);
            };
        }
    }, []);

    // Calculate aggregated stats
    const globalStats = {
        needs_followup: followUpData?.needs_followup?.length || 0,
        not_contacted: followUpData?.not_contacted?.length || 0,
        followed_up: followUpData?.followed_up?.length || 0,
    };

    // Calculate per-event stats
    const eventStats = events.map(event => {
        const stats = {
            total: 0,
            needs_followup: 0,
            not_contacted: 0,
            followed_up: 0
        };

        if (followUpData) {
            // Helper to check if contact belongs to event
            const isInEvent = (contact: any) => {
                return contact.interactions?.some((i: any) => i.event_id === event.id);
            };

            // Count from each category
            ['needs_followup', 'not_contacted', 'followed_up'].forEach(status => {
                const count = (followUpData[status] || []).filter(isInEvent).length;
                stats[status as keyof typeof stats] += count;
                stats.total += count;
            });
        }

        return { ...event, stats };
    }).filter(e => e.stats.total > 0 || e.status === 'ongoing'); // Show active events or those with data

    if (loading) {
        return (
            <AppShell>
                <div className="max-w-7xl mx-auto space-y-8">
                    <div>
                        <Skeleton className="h-10 w-64 mb-2" />
                        <Skeleton className="h-4 w-96" />
                    </div>
                    <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                        {[1, 2, 3].map(i => <Skeleton key={i} className="h-24 rounded-2xl" />)}
                    </div>
                    <div className="space-y-4 pt-4">
                        <Skeleton className="h-6 w-48 mb-4" />
                        {[1, 2, 3].map(i => <Skeleton key={i} className="h-32 rounded-2xl w-full" />)}
                    </div>
                </div>
            </AppShell>
        );
    }

    return (
        <AppShell>
            <div className="max-w-7xl mx-auto px-4 py-8 space-y-12">
                {/* Dashboard Header */}
                <div className="flex flex-col md:flex-row md:items-end justify-between gap-8">
                    <div>
                        <h1 className="text-4xl font-black text-stone-900 tracking-tight leading-tight mb-2">Follow-ups</h1>
                        <p className="text-sm font-medium text-stone-500">Track and manage your connections after the events.</p>
                    </div>
                </div>

                {/* Status Overview */}
                <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
                    <div className="bg-white border border-stone-100 rounded-[2.5rem] p-8 shadow-sm transition-all duration-300">
                        <div className="flex items-center justify-between mb-6">
                            <div className="p-3 bg-stone-900 text-white rounded-2xl shadow-xl shadow-stone-900/10">
                                <Clock className="h-5 w-5" strokeWidth={3} />
                            </div>
                            <span className="text-4xl font-black text-stone-900 tracking-tighter">{globalStats.needs_followup}</span>
                        </div>
                        <p className="text-[10px] font-black text-stone-400 uppercase tracking-widest">Needs Follow-up</p>
                    </div>

                    <div className="bg-white border border-stone-100 rounded-[2.5rem] p-8 shadow-sm transition-all duration-300">
                        <div className="flex items-center justify-between mb-6">
                            <div className="p-3 bg-stone-900 text-white rounded-2xl shadow-xl shadow-stone-900/10">
                                <Users className="h-5 w-5" strokeWidth={3} />
                            </div>
                            <span className="text-4xl font-black text-stone-900 tracking-tighter">{globalStats.not_contacted}</span>
                        </div>
                        <p className="text-[10px] font-black text-stone-400 uppercase tracking-widest">Not Contacted</p>
                    </div>

                    <div className="bg-white border border-stone-100 rounded-[2.5rem] p-8 shadow-sm transition-all duration-300">
                        <div className="flex items-center justify-between mb-6">
                            <div className="p-3 bg-stone-900 text-white rounded-2xl shadow-xl shadow-stone-900/10">
                                <CheckCircle className="h-5 w-5" strokeWidth={3} />
                            </div>
                            <span className="text-4xl font-black text-stone-900 tracking-tighter">{globalStats.followed_up}</span>
                        </div>
                        <p className="text-[10px] font-black text-stone-400 uppercase tracking-widest">Completed</p>
                    </div>
                </div>

                {/* Event Breakdown */}
                <div className="space-y-8">
                    <h2 className="text-[10px] font-black text-stone-900 uppercase tracking-[0.3em] flex items-center gap-3">
                        <BarChart3 className="h-4 w-4 text-stone-900" strokeWidth={3} />
                        Status by Event
                    </h2>

                    {eventStats.length === 0 ? (
                        <div className="bg-stone-50/50 rounded-[2.5rem] p-20 text-center border border-dashed border-stone-200 flex flex-col items-center">
                            <div className="mb-6 flex h-16 w-16 items-center justify-center rounded-2xl bg-white border border-stone-100 text-stone-300 shadow-sm">
                                <BarChart3 className="h-8 w-8" strokeWidth={2} />
                            </div>
                            <p className="text-[10px] font-black uppercase tracking-[0.2em] text-stone-400">No contacts yet</p>
                        </div>
                    ) : (
                        <div className="grid grid-cols-1 gap-6">
                            {eventStats.map(event => (
                                <div key={event.id} className="group bg-white border border-stone-100 rounded-[2.5rem] overflow-hidden shadow-sm hover:border-stone-200 transition-all duration-300">
                                    <div className="p-8">
                                        <div className="grid grid-cols-1 xl:grid-cols-4 items-center gap-8 xl:gap-12">

                                            {/* Event Info */}
                                            <div className="xl:col-span-1">
                                                <div className="flex items-center gap-4 mb-3">
                                                    <h3 className="text-xl font-black text-stone-900 tracking-tight truncate">
                                                        {event.name}
                                                    </h3>
                                                    {event.status === 'ongoing' && (
                                                        <span className="bg-stone-900 text-white text-[8px] font-black uppercase tracking-widest px-2.5 py-1 rounded-lg">
                                                            Live
                                                        </span>
                                                    )}
                                                </div>
                                                <div className="flex flex-wrap items-center gap-3">
                                                    <div className="flex items-center gap-1.5 text-[9px] font-black text-stone-400 uppercase tracking-widest">
                                                        <Calendar className="h-3 w-3 text-stone-900" strokeWidth={3} />
                                                        {new Date(event.start_date).toLocaleDateString(undefined, { month: 'short', day: 'numeric' })}
                                                    </div>
                                                    <div className="flex items-center gap-1.5 text-[9px] font-black text-stone-400 uppercase tracking-widest">
                                                        <Users className="h-3 w-3 text-stone-900" strokeWidth={3} />
                                                        {event.stats.total} contacts
                                                    </div>
                                                </div>
                                            </div>

                                            {/* Progress */}
                                            <div className="xl:col-span-2">
                                                {event.stats.total > 0 ? (
                                                    <div className="bg-stone-50/80 rounded-2xl border border-stone-100 p-5">
                                                        <div className="flex items-center justify-between mb-3">
                                                            <span className="text-[9px] font-black text-stone-400 uppercase tracking-widest">Completion</span>
                                                            <span className="text-[9px] font-black text-stone-900 tracking-tighter">
                                                                {Math.round((event.stats.followed_up / event.stats.total) * 100)}%
                                                            </span>
                                                        </div>
                                                        <div className="w-full h-2.5 bg-stone-200/50 rounded-full overflow-hidden flex mb-4">
                                                            <div
                                                                style={{ width: `${(event.stats.followed_up / event.stats.total) * 100}%` }}
                                                                className="bg-stone-900 h-full transition-all duration-1000"
                                                            />
                                                            <div
                                                                style={{ width: `${(event.stats.needs_followup / event.stats.total) * 100}%` }}
                                                                className="bg-stone-400 h-full -ml-px transition-all duration-1000"
                                                            />
                                                        </div>
                                                        <div className="flex gap-4">
                                                            <div className="flex items-center gap-1.5">
                                                                <div className="w-1.5 h-1.5 rounded-full bg-stone-900" />
                                                                <span className="text-[8px] font-black text-stone-500 uppercase tracking-widest">Sent ({event.stats.followed_up})</span>
                                                            </div>
                                                            <div className="flex items-center gap-1.5">
                                                                <div className="w-1.5 h-1.5 rounded-full bg-stone-400" />
                                                                <span className="text-[8px] font-black text-stone-500 uppercase tracking-widest">Pending ({event.stats.needs_followup})</span>
                                                            </div>
                                                        </div>
                                                    </div>
                                                ) : (
                                                    <div className="h-full flex items-center justify-center border border-dashed border-stone-200 rounded-2xl bg-stone-50/50 p-5">
                                                        <p className="text-[9px] font-black text-stone-300 uppercase tracking-widest italic">No connections yet</p>
                                                    </div>
                                                )}
                                            </div>

                                            {/* Action */}
                                            <div className="xl:col-span-1 flex justify-end">
                                                <Button
                                                    onClick={() => setExpandedEventId(expandedEventId === event.id ? null : event.id)}
                                                    className={`h-11 px-6 rounded-xl font-black uppercase tracking-widest text-[10px] transition-all shadow-lg active:scale-95 flex items-center gap-3 ${expandedEventId === event.id
                                                        ? 'bg-stone-900 text-white shadow-stone-900/10'
                                                        : 'bg-white border border-stone-200 text-stone-900 hover:bg-stone-50 hover:border-stone-300'}`}
                                                >
                                                    {expandedEventId === event.id ? 'Close' : 'View Contacts'}
                                                    {expandedEventId === event.id ? <ChevronUp className="h-4 w-4" strokeWidth={3} /> : <ChevronDown className="h-4 w-4" strokeWidth={3} />}
                                                </Button>
                                            </div>
                                        </div>

                                        {/* Leads List */}
                                        {expandedEventId === event.id && (
                                            <div className="mt-10 pt-10 border-t border-stone-50 animate-in fade-in duration-500">
                                                <FollowUpsSection eventId={event.id} event={event} onRefresh={refreshDashboard} />
                                            </div>
                                        )}
                                    </div>
                                </div>
                            ))}
                        </div>
                    )}
                </div>
            </div>
        </AppShell>
    );
}
