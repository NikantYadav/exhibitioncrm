'use client';

import { useState, useEffect } from 'react';
import Link from 'next/link';
import { AppShell } from '@/components/layout/AppShell';
import { Avatar, AvatarFallback } from '@/components/ui/Avatar';
import { Button } from '@/components/ui/Button';
import { SyncService } from '@/lib/services/sync';
import {
    Plus,
    Calendar,
    Camera,
    ArrowRight,
    MoreHorizontal
} from 'lucide-react';

export default function HomePage() {
    const [loading, setLoading] = useState(true);
    const [dashboardData, setDashboardData] = useState<any>(null);

    useEffect(() => {
        SyncService.setupSyncListeners();
        fetchDashboardData();
    }, []);

    const fetchDashboardData = async () => {
        try {
            const response = await fetch('/api/dashboard/summary');
            const data = await response.json();
            setDashboardData(data);
        } catch (error) {
            console.error('Failed to fetch dashboard data:', error);
        } finally {
            setLoading(false);
        }
    };

    if (loading) {
        return (
            <AppShell>
                <div className="flex items-center justify-center min-h-[60vh]">
                    <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-indigo-600"></div>
                </div>
            </AppShell>
        );
    }

    const summary = dashboardData?.summary || {
        targets: 0,
        captured: 0,
        enriched: 0,
        drafts: 0,
        sent: 0,
    };

    const activeConversations = dashboardData?.activeContacts?.map((c: any) => ({
        id: c.id,
        name: `${c.first_name} ${c.last_name || ''}`,
        initials: `${c.first_name[0]}${c.last_name?.[0] || ''}`,
        status: 'online' // Hardcoded for now as we don't have real-time status
    })) || [];

    // Journey stages data
    const journeyStages = [
        {
            id: 'targets',
            title: 'Targets',
            count: summary.targets,
            leads: dashboardData?.stages?.targets || []
        },
        {
            id: 'captured',
            title: 'Captured',
            count: summary.captured,
            leads: dashboardData?.stages?.captured || []
        },
        {
            id: 'enriched',
            title: 'Enriched',
            count: summary.enriched,
            leads: dashboardData?.stages?.enriched || []
        },
        {
            id: 'draft',
            title: 'Follow-up Draft',
            count: summary.drafts,
            leads: dashboardData?.stages?.drafts || []
        },
        {
            id: 'sent',
            title: 'Sent',
            count: summary.sent,
            leads: dashboardData?.stages?.sent || []
        },
    ];

    const upcomingMeetings = dashboardData?.upcomingMeetings?.map((m: any) => ({
        id: m.id,
        title: `Meeting with ${m.contact?.first_name} ${m.contact?.last_name || ''}`,
        time: new Date(m.meeting_date).toLocaleString([], { dateStyle: 'short', timeStyle: 'short' }),
        initials: `${m.contact?.first_name[0]}${m.contact?.last_name?.[0] || ''}`
    })) || [];

    const recentActivity = dashboardData?.recentActivity?.map((a: any) => ({
        id: a.id,
        description: a.summary || `${a.interaction_type} with ${a.contact?.first_name} ${a.contact?.last_name || ''}`,
        time: new Date(a.interaction_date).toLocaleDateString(),
        initials: `${a.contact?.first_name[0]}${a.contact?.last_name?.[0] || ''}`
    })) || [];

    return (
        <AppShell>
            <div className="max-w-7xl mx-auto">
                {/* Header with pill tabs + avatar strip + CTAs */}
                <div className="mb-12">
                    <div className="flex items-center justify-between mb-6">
                        <div>
                            <h1 className="text-display mb-1">Dashboard</h1>
                            <p className="text-body">Track your exhibition journey and relationships</p>
                        </div>

                        {/* Primary CTAs */}
                        <div className="flex items-center gap-3">
                            <Link href="/events">
                                <Button variant="secondary" size="sm">
                                    <Calendar className="mr-1.5 h-4 w-4" strokeWidth={2} />
                                    New Event
                                </Button>
                            </Link>
                            <Link href="/capture">
                                <Button size="sm">
                                    <Camera className="mr-1.5 h-4 w-4" strokeWidth={2} />
                                    Capture Lead
                                </Button>
                            </Link>
                        </div>
                    </div>

                    {/* Pill-style navigation tabs */}
                    <div className="flex items-center justify-between">
                        <div className="flex items-center gap-2">
                            <div className="nav-pill nav-pill-active">Dashboard</div>
                            <Link href="/events"><div className="nav-pill nav-pill-inactive">Events</div></Link>
                            <Link href="/capture"><div className="nav-pill nav-pill-inactive">Capture</div></Link>
                            <Link href="/contacts"><div className="nav-pill nav-pill-inactive">Contacts</div></Link>
                            <Link href="/follow-ups"><div className="nav-pill nav-pill-inactive">Follow-ups</div></Link>
                        </div>

                        {/* Active Conversations avatar strip */}
                        <div className="flex items-center gap-3">
                            <span className="text-caption">Active conversations</span>
                            <div className="flex items-center">
                                {activeConversations.map((person: any, index: number) => (
                                    <div key={person.id} className={`relative ${index > 0 ? 'avatar-overlap' : ''}`}>
                                        <Link href={`/contacts/${person.id}`}>
                                            <Avatar className="h-8 w-8 border-2 border-white cursor-pointer hover:z-10 transition-transform hover:scale-110">
                                                <AvatarFallback className="text-xs bg-gradient-to-br from-stone-400 to-stone-500 text-white font-medium">
                                                    {person.initials}
                                                </AvatarFallback>
                                            </Avatar>
                                        </Link>
                                        <span className={`avatar-status-dot ${person.status === 'online' ? 'bg-emerald-500' : 'bg-stone-300'}`} />
                                    </div>
                                ))}
                                <Link href="/contacts">
                                    <button className="ml-2 flex h-8 w-8 items-center justify-center rounded-full border border-stone-300 bg-white text-stone-600 hover:bg-stone-50 transition-smooth">
                                        <Plus className="h-4 w-4" strokeWidth={2} />
                                    </button>
                                </Link>
                            </div>
                        </div>
                    </div>
                </div>

                {/* Signature: Today's Journey Canvas */}
                <div className="section-gap">
                    <div className="flex items-center justify-between mb-6">
                        <h2 className="text-section-header">Today's Journey</h2>
                        <Link href="/contacts" className="text-caption hover:text-stone-900 transition-colors">
                            View all stages <ArrowRight className="inline h-3 w-3 ml-1" strokeWidth={2} />
                        </Link>
                    </div>

                    {/* Horizontal journey stages */}
                    <div className="relative">
                        <div className="flex gap-4 overflow-x-auto pb-4">
                            {journeyStages.map((stage, index) => (
                                <div key={stage.id} className="journey-stage">
                                    <div className="journey-stage-header">
                                        <div>
                                            <h3 className="text-card-title">{stage.title}</h3>
                                            <p className="text-caption">{stage.count} leads</p>
                                        </div>
                                        <Link href="/capture">
                                            <button className="flex h-6 w-6 items-center justify-center rounded-full bg-white border border-stone-300 text-stone-600 hover:bg-stone-50 transition-smooth">
                                                <Plus className="h-3.5 w-3.5" strokeWidth={2} />
                                            </button>
                                        </Link>
                                    </div>

                                    {/* Empty state for each stage */}
                                    {stage.leads.length === 0 && (
                                        <div className="py-8 text-center">
                                            <p className="text-caption">No leads yet</p>
                                        </div>
                                    )}

                                    {/* Lead cards */}
                                    {stage.leads.map((lead: any) => (
                                        <Link key={lead.id} href={`/contacts/${lead.id}`}>
                                            <div className="lead-card hover:bg-stone-50 transition-colors cursor-pointer">
                                                <div className="flex items-start gap-2">
                                                    <Avatar className="h-8 w-8">
                                                        <AvatarFallback className="text-xs bg-gradient-to-br from-indigo-400 to-indigo-600 text-white">
                                                            {lead.initials}
                                                        </AvatarFallback>
                                                    </Avatar>
                                                    <div className="flex-1 min-w-0">
                                                        <p className="text-sm font-medium text-stone-900 truncate">{lead.name}</p>
                                                        <p className="text-xs text-stone-500 truncate">{lead.company}</p>
                                                    </div>
                                                </div>
                                            </div>
                                        </Link>
                                    ))}
                                </div>
                            ))}
                        </div>

                        {/* Curved connector lines (SVG overlay) */}
                        <svg className="absolute top-0 left-0 w-full h-full pointer-events-none" style={{ zIndex: -1 }}>
                            {journeyStages.slice(0, -1).map((_, index) => (
                                <path
                                    key={index}
                                    className="journey-connector"
                                    d={`M ${(index + 1) * 300 - 20} 40 Q ${(index + 1) * 300 + 10} 40 ${(index + 1) * 300 + 20} 40`}
                                />
                            ))}
                        </svg>
                    </div>
                </div>

                {/* Two-column lower section */}
                <div className="grid gap-6 lg:grid-cols-2">
                    {/* Upcoming Meetings with avatars */}
                    <div className="premium-card p-6 transition-smooth">
                        <div className="flex items-center justify-between mb-6">
                            <h2 className="text-section-header">Upcoming Meetings</h2>
                            <Link href="/meetings" className="text-caption hover:text-stone-900 transition-colors flex items-center gap-1">
                                View all
                                <ArrowRight className="h-3 w-3" strokeWidth={2} />
                            </Link>
                        </div>

                        {upcomingMeetings.length === 0 ? (
                            <div className="py-12 text-center">
                                <div className="mb-4 flex h-12 w-12 items-center justify-center rounded-full bg-stone-100 text-stone-400 mx-auto">
                                    <Calendar className="h-6 w-6" strokeWidth={2} />
                                </div>
                                <p className="text-sm font-medium text-stone-900 mb-1">No upcoming meetings</p>
                                <p className="text-caption mb-4">Schedule a meeting to see it here</p>
                                <Link href="/meetings/new">
                                    <Button variant="secondary" size="sm">
                                        <Plus className="mr-1.5 h-4 w-4" strokeWidth={2} />
                                        Schedule Meeting
                                    </Button>
                                </Link>
                            </div>
                        ) : (
                            <div className="space-y-2">
                                {upcomingMeetings.map((meeting: any) => (
                                    <Link key={meeting.id} href={`/meetings/${meeting.id}`}>
                                        <div className="meeting-card hover:bg-stone-50 transition-colors cursor-pointer">
                                            <Avatar className="h-10 w-10">
                                                <AvatarFallback className="text-xs bg-gradient-to-br from-indigo-400 to-indigo-600 text-white">
                                                    {meeting.initials}
                                                </AvatarFallback>
                                            </Avatar>
                                            <div className="flex-1">
                                                <p className="text-sm font-medium text-stone-900">{meeting.title}</p>
                                                <p className="text-caption">{meeting.time}</p>
                                            </div>
                                            <button className="text-stone-400 hover:text-stone-600">
                                                <MoreHorizontal className="h-4 w-4" strokeWidth={2} />
                                            </button>
                                        </div>
                                    </Link>
                                ))}
                            </div>
                        )}
                    </div>

                    {/* Recent Activity timeline with avatars */}
                    <div className="premium-card p-6 transition-smooth">
                        <div className="flex items-center justify-between mb-6">
                            <h2 className="text-section-header">Recent Activity</h2>
                            <button className="text-caption hover:text-stone-900 transition-colors flex items-center gap-1">
                                View all
                                <ArrowRight className="h-3 w-3" strokeWidth={2} />
                            </button>
                        </div>

                        {recentActivity.length === 0 ? (
                            <div className="py-12 text-center">
                                <div className="mb-4 flex h-12 w-12 items-center justify-center rounded-full bg-stone-100 text-stone-400 mx-auto">
                                    <Camera className="h-6 w-6" strokeWidth={2} />
                                </div>
                                <p className="text-sm font-medium text-stone-900 mb-1">No recent activity</p>
                                <p className="text-caption mb-4">Your captures and interactions will appear here</p>
                                <Link href="/capture">
                                    <Button size="sm">
                                        <Plus className="mr-1.5 h-4 w-4" strokeWidth={2} />
                                        Capture First Lead
                                    </Button>
                                </Link>
                            </div>
                        ) : (
                            <div className="space-y-1">
                                {recentActivity.map((activity: any) => (
                                    <div key={activity.id} className="timeline-item">
                                        <div className="relative">
                                            <Avatar className="h-8 w-8">
                                                <AvatarFallback className="text-xs bg-gradient-to-br from-stone-400 to-stone-500 text-white">
                                                    {activity.initials}
                                                </AvatarFallback>
                                            </Avatar>
                                            <span className="timeline-dot absolute -right-1" />
                                        </div>
                                        <div className="flex-1">
                                            <p className="text-sm text-stone-900">{activity.description}</p>
                                            <p className="text-caption">{activity.time}</p>
                                        </div>
                                    </div>
                                ))}
                            </div>
                        )}
                    </div>
                </div>
            </div>
        </AppShell>
    );
}
