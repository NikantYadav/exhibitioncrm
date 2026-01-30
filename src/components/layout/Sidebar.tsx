'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import {
    Home,
    Calendar,
    Camera,
    Users,
    MessageSquare,
    Settings,
    Plug,
    Mail,
    User
} from 'lucide-react';
import { cn } from '@/lib/utils';
import * as Tooltip from '@radix-ui/react-tooltip';

const navItems = [
    { href: '/', icon: Home, label: 'Dashboard' },
    { href: '/events', icon: Calendar, label: 'Events' },
    { href: '/capture', icon: Camera, label: 'Capture' },
    { href: '/contacts', icon: Users, label: 'Contacts' },
    { href: '/follow-ups', icon: Mail, label: 'Follow-Ups' },
    { href: '/meetings', icon: MessageSquare, label: 'Meetings' },
    { href: '/integrations', icon: Plug, label: 'Integrations' },
];

export function Sidebar() {
    const pathname = usePathname();

    return (
        <Tooltip.Provider delayDuration={0}>
            <aside className="fixed left-0 top-0 z-40 h-screen w-16 border-r border-stone-200/60 bg-white">
                <div className="flex h-full flex-col items-center py-4">
                    {/* Logo - toned down */}
                    <Link
                        href="/"
                        className="mb-8 flex h-10 w-10 items-center justify-center rounded-xl bg-stone-900 text-white font-bold text-lg shadow-sm hover:shadow-md transition-smooth"
                    >
                        E
                    </Link>

                    {/* Navigation - softer active state */}
                    <nav className="flex flex-1 flex-col gap-1">
                        {navItems.map((item) => {
                            const isActive = pathname === item.href;
                            const Icon = item.icon;

                            return (
                                <Tooltip.Root key={item.href}>
                                    <Tooltip.Trigger asChild>
                                        <Link
                                            href={item.href}
                                            className={cn(
                                                "flex h-11 w-11 items-center justify-center rounded-xl transition-smooth",
                                                isActive
                                                    ? "sidebar-active"
                                                    : "sidebar-inactive"
                                            )}
                                        >
                                            <Icon className="h-5 w-5" strokeWidth={2} />
                                        </Link>
                                    </Tooltip.Trigger>
                                    <Tooltip.Portal>
                                        <Tooltip.Content
                                            side="right"
                                            className="rounded-lg bg-stone-900 px-3 py-2 text-sm text-white shadow-lg"
                                            sideOffset={8}
                                        >
                                            {item.label}
                                        </Tooltip.Content>
                                    </Tooltip.Portal>
                                </Tooltip.Root>
                            );
                        })}
                    </nav>

                    {/* Divider */}
                    <div className="w-8 h-px bg-stone-200 my-4" />

                    {/* Settings */}
                    <Tooltip.Root>
                        <Tooltip.Trigger asChild>
                            <Link
                                href="/settings"
                                className={cn(
                                    "flex h-11 w-11 items-center justify-center rounded-xl transition-smooth",
                                    pathname === '/settings'
                                        ? "sidebar-active"
                                        : "sidebar-inactive"
                                )}
                            >
                                <Settings className="h-5 w-5" strokeWidth={2} />
                            </Link>
                        </Tooltip.Trigger>
                        <Tooltip.Portal>
                            <Tooltip.Content side="right" className="rounded-lg bg-stone-900 px-3 py-2 text-sm text-white shadow-lg" sideOffset={8}>
                                Settings
                            </Tooltip.Content>
                        </Tooltip.Portal>
                    </Tooltip.Root>
                </div>
            </aside>
        </Tooltip.Provider>
    );
}
