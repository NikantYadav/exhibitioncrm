'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { Search, Target, Mail } from 'lucide-react';

import { AppShell } from '@/components/layout/AppShell';

export default function PreparationLayout({
    children,
    params
}: {
    children: React.ReactNode;
    params: { id: string };
}) {
    const pathname = usePathname();
    const eventId = params.id;
    const baseUrl = `/events/${eventId}/preparation`;

    const tabs = [
        { name: 'Research', href: `${baseUrl}/research`, icon: Search },
        { name: 'Target List', href: `${baseUrl}/targets`, icon: Target },
        { name: 'Emails', href: `${baseUrl}/emails`, icon: Mail },
    ];

    return (
        <AppShell>
            <div className="space-y-6">
                <div className="premium-card bg-white overflow-hidden">
                    <div className="px-8 py-6">
                        <div className="flex flex-col md:flex-row md:items-end justify-between gap-6">
                            <div>
                                <h1 className="text-2xl font-black text-stone-900 tracking-tight">Event Preparation</h1>
                                <p className="text-sm font-medium text-stone-400 mt-1 italic">Research attendees, build target lists, and draft outreach.</p>
                            </div>

                            <nav className="flex items-center gap-1 bg-stone-100/50 p-1 rounded-xl border border-stone-200/40">
                                {tabs.map((tab) => {
                                    const Icon = tab.icon;
                                    const isActive = pathname === tab.href;
                                    return (
                                        <Link
                                            key={tab.name}
                                            href={tab.href}
                                            className={`
                                                flex items-center px-5 py-2 text-sm font-bold rounded-lg transition-all
                                                ${isActive
                                                    ? 'bg-white text-stone-900 shadow-sm border border-stone-100'
                                                    : 'text-stone-400 hover:text-stone-600 hover:bg-white/50'}
                                            `}
                                        >
                                            <Icon className={`mr-2 h-4 w-4 ${isActive ? 'text-stone-900' : 'text-stone-300'}`} />
                                            {tab.name}
                                        </Link>
                                    );
                                })}
                            </nav>
                        </div>
                    </div>
                </div>

                <div className="animate-in fade-in slide-in-from-bottom-4 duration-500">
                    {children}
                </div>
            </div>
        </AppShell>
    );
}

