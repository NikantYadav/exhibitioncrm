'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { Search, Target, Mail } from 'lucide-react';

import { Header } from '@/components/layout/Header';

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
        <div className="min-h-screen bg-stone-50">
            <Header />

            <div className="bg-white border-b border-stone-200">
                <div className="px-8 py-6 max-w-[1600px] mx-auto">
                    <div className="flex flex-col md:flex-row md:items-end justify-between gap-6">
                        <div>
                            <h1 className="text-2xl font-bold text-stone-900 tracking-tight">Event Preparation</h1>
                            <p className="text-sm text-stone-500 mt-1">Research attendees, build target lists, and draft outreach.</p>
                        </div>

                        <nav className="flex items-center gap-1 bg-stone-50 p-1 rounded-xl border border-stone-200/60">
                            {tabs.map((tab) => {
                                const Icon = tab.icon;
                                const isActive = pathname === tab.href;
                                return (
                                    <Link
                                        key={tab.name}
                                        href={tab.href}
                                        className={`
                                            flex items-center px-4 py-2 text-sm font-medium rounded-lg transition-all
                                            ${isActive
                                                ? 'bg-white text-indigo-600 shadow-sm border border-stone-200/60'
                                                : 'text-stone-600 hover:text-stone-900 hover:bg-stone-100/50'}
                                        `}
                                    >
                                        <Icon className={`mr-2 h-4 w-4 ${isActive ? 'text-indigo-600' : 'text-stone-400'}`} />
                                        {tab.name}
                                    </Link>
                                );
                            })}
                        </nav>
                    </div>
                </div>
            </div>

            <main className="max-w-[1600px] mx-auto p-8">
                {children}
            </main>
        </div>
    );
}

