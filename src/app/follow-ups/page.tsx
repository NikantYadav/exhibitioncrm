
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
            <div className="max-w-7xl mx-auto space-y-8">
                <div>
                    <h1 className="text-display mb-2">Follow-Up Dashboard</h1>
                    <p className="text-body text-stone-500">Overview of your post-event engagement performance</p>
                </div>

                {/* Global Stats */}
                <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                    <Card className="bg-amber-50 border-amber-100">
                        <CardContent className="p-6 flex items-center justify-between">
                            <div>
                                <p className="text-sm font-medium text-amber-700 mb-1">Needs Attention</p>
                                <h3 className="text-3xl font-bold text-amber-900">{globalStats.needs_followup}</h3>
                            </div>
                            <div className="p-3 bg-amber-100 rounded-full text-amber-600">
                                <Clock className="h-6 w-6" />
                            </div>
                        </CardContent>
                    </Card>

                    <Card className="bg-stone-50 border-stone-100">
                        <CardContent className="p-6 flex items-center justify-between">
                            <div>
                                <p className="text-sm font-medium text-stone-600 mb-1">Not Contacted</p>
                                <h3 className="text-3xl font-bold text-stone-900">{globalStats.not_contacted}</h3>
                            </div>
                            <div className="p-3 bg-stone-200 rounded-full text-stone-600">
                                <XCircle className="h-6 w-6" />
                            </div>
                        </CardContent>
                    </Card>

                    <Card className="bg-emerald-50 border-emerald-100">
                        <CardContent className="p-6 flex items-center justify-between">
                            <div>
                                <p className="text-sm font-medium text-emerald-700 mb-1">Successfully Contacted</p>
                                <h3 className="text-3xl font-bold text-emerald-900">{globalStats.followed_up}</h3>
                            </div>
                            <div className="p-3 bg-emerald-100 rounded-full text-emerald-600">
                                <CheckCircle className="h-6 w-6" />
                            </div>
                        </CardContent>
                    </Card>
                </div>

                {/* Event Breakdown */}
                <div>
                    <h2 className="text-lg font-semibold text-stone-900 mb-4 flex items-center gap-2">
                        <BarChart3 className="h-5 w-5 text-indigo-600" />
                        Event Performance
                    </h2>

                    {eventStats.length === 0 ? (
                        <div className="bg-stone-50 border border-stone-200 rounded-lg p-12 text-center text-stone-500">
                            No active events with follow-up data found.
                        </div>
                    ) : (
                        <div className="grid grid-cols-1 gap-6">
                            {eventStats.map(event => (
                                <Card key={event.id} className="hover:shadow-md transition-shadow group">
                                    <div className="p-6">
                                        <div className="flex flex-col md:flex-row md:items-center justify-between gap-6">

                                            {/* Event Info */}
                                            <div className="flex-1 min-w-[200px]">
                                                <div className="flex items-center gap-2 mb-1">
                                                    <h3 className="text-lg font-semibold text-stone-900 group-hover:text-indigo-600 transition-colors">
                                                        {event.name}
                                                    </h3>
                                                    {event.status === 'ongoing' && (
                                                        <span className="bg-green-100 text-green-700 text-xs px-2 py-0.5 rounded-full font-medium">
                                                            Live
                                                        </span>
                                                    )}
                                                </div>
                                                <div className="flex items-center text-sm text-stone-500 gap-4">
                                                    <span className="flex items-center gap-1">
                                                        <Calendar className="h-3.5 w-3.5" />
                                                        {new Date(event.start_date).toLocaleDateString()}
                                                    </span>
                                                    <span className="flex items-center gap-1">
                                                        <Users className="h-3.5 w-3.5" />
                                                        {event.stats.total} leads
                                                    </span>
                                                </div>
                                            </div>

                                            {/* Progress Bars */}
                                            <div className="flex-1 min-w-[320px]">
                                                {event.stats.total > 0 ? (
                                                    <div className="bg-white rounded-lg border border-gray-100 p-4 shadow-sm">
                                                        <div className="flex items-center justify-between mb-3">
                                                            <span className="text-[11px] font-semibold text-stone-500 uppercase tracking-wider">Follow-up Progress</span>
                                                        </div>
                                                        <div className="w-full h-2 bg-stone-100 rounded-full overflow-hidden flex mb-4">
                                                            <div
                                                                style={{ width: `${(event.stats.followed_up / event.stats.total) * 100}%` }}
                                                                className="bg-emerald-500 h-full transition-all duration-500 shadow-sm"
                                                            />
                                                            <div
                                                                style={{ width: `${(event.stats.needs_followup / event.stats.total) * 100}%` }}
                                                                className="bg-amber-400 h-full transition-all duration-500 shadow-sm"
                                                            />
                                                            <div
                                                                style={{ width: `${(event.stats.not_contacted / event.stats.total) * 100}%` }}
                                                                className="bg-stone-200 h-full transition-all duration-500 shadow-sm"
                                                            />
                                                        </div>
                                                        <div className="flex justify-between items-center px-1">
                                                            <div className="flex items-center gap-1.5">
                                                                <div className="w-2 h-2 rounded-full bg-emerald-500" />
                                                                <span className="text-[10px] text-stone-500 font-medium">Followed Up ({event.stats.followed_up})</span>
                                                            </div>
                                                            <div className="flex items-center gap-1.5">
                                                                <div className="w-2 h-2 rounded-full bg-amber-400" />
                                                                <span className="text-[10px] text-stone-500 font-medium">Needs Attention ({event.stats.needs_followup})</span>
                                                            </div>
                                                            <div className="flex items-center gap-1.5">
                                                                <div className="w-2 h-2 rounded-full bg-stone-300" />
                                                                <span className="text-[10px] text-stone-500 font-medium">Not Contacted ({event.stats.not_contacted})</span>
                                                            </div>
                                                        </div>
                                                    </div>
                                                ) : (
                                                    <div className="h-full flex items-center justify-center border border-dashed border-stone-200 rounded-lg bg-stone-50/50 p-4">
                                                        <p className="text-xs text-stone-400 italic">No leads captured yet</p>
                                                    </div>
                                                )}
                                            </div>

                                            {/* Action */}
                                            <div>
                                                <Button
                                                    onClick={() => setExpandedEventId(expandedEventId === event.id ? null : event.id)}
                                                    variant={expandedEventId === event.id ? "primary" : "outline"}
                                                    className={`w-full md:w-auto transition-all ${expandedEventId === event.id ? '' : 'hover:border-indigo-600 hover:text-indigo-600'}`}
                                                >
                                                    {expandedEventId === event.id ? 'Close Board' : 'Manage Follow-ups'}
                                                    {expandedEventId === event.id ? <ChevronUp className="ml-2 h-4 w-4" /> : <ChevronDown className="ml-2 h-4 w-4" />}
                                                </Button>
                                            </div>
                                        </div>

                                        {/* Expanded Content */}
                                        {expandedEventId === event.id && (
                                            <div className="mt-8 pt-8 border-t border-gray-100 animate-in fade-in zoom-in-95 duration-300">
                                                <FollowUpsSection eventId={event.id} event={event} onRefresh={refreshDashboard} />
                                            </div>
                                        )}
                                    </div>
                                </Card>
                            ))}
                        </div>
                    )}
                </div>
            </div>
        </AppShell>
    );
}
