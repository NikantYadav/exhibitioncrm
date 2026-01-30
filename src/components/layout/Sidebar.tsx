'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import {
    LayoutDashboard,
    CalendarDays,
    Camera,
    Users2,
    MessageSquareQuote,
    Plug2,
    MailCheck,
    Settings2,
    PlusCircle,
    PanelLeftClose,
    PanelLeftOpen
} from 'lucide-react';
import { cn } from '@/lib/utils';
import * as Tooltip from '@radix-ui/react-tooltip';
import { CaptureDropdown } from '@/components/capture/CaptureDropdown';
import { useSidebar } from './LayoutContext';

const navItems = [
    { href: '/', icon: LayoutDashboard, label: 'Overview' },
    { href: '/events', icon: CalendarDays, label: 'Major Events' },
    { href: '/capture', icon: Camera, label: 'Lead Capture' },
    { href: '/contacts', icon: Users2, label: 'All Contacts' },
    { href: '/follow-ups', icon: MailCheck, label: 'Follow-Ups' },
    { href: '/meetings', icon: MessageSquareQuote, label: 'Meetings' },
    { href: '/integrations', icon: Plug2, label: 'Integrations' },
];

export function Sidebar() {
    const pathname = usePathname();
    const { isSidebarCollapsed, toggleSidebar } = useSidebar();

    return (
        <Tooltip.Provider delayDuration={0}>
            <aside
                className={cn(
                    "fixed left-0 top-0 z-40 h-screen border-r border-stone-200/50 bg-white flex flex-col transition-all duration-300 ease-in-out shadow-[1px_0_0_rgba(0,0,0,0.02)]",
                    isSidebarCollapsed ? "w-16 items-center" : "w-64"
                )}
            >
                {/* Brand Identity */}
                <div className={cn("flex items-center w-full py-5", isSidebarCollapsed ? "justify-center" : "px-4")}>
                    <Link
                        href="/"
                        className="flex h-10 w-10 shrink-0 items-center justify-center rounded-[12px] bg-stone-900 text-white shadow-soft hover:shadow-glow transition-all active:scale-95 group"
                    >
                        <span className="font-black text-lg group-hover:scale-110 transition-transform">E</span>
                    </Link>
                    {!isSidebarCollapsed && (
                        <div className="ml-3 animate-in fade-in slide-in-from-left-2 duration-300">
                            <span className="font-black text-stone-900 tracking-tighter text-lg">Exhibition</span>
                            <span className="block text-[10px] font-black text-stone-400 uppercase tracking-widest leading-none">Intelligence</span>
                        </div>
                    )}
                </div>

                <div className={cn("bg-stone-100 mb-6 shrink-0", isSidebarCollapsed ? "w-8 h-px" : "w-[calc(100%-2rem)] h-px mx-4")} />

                {/* Navigation Ecosystem */}
                <nav className={cn("flex flex-1 flex-col gap-2 w-full", isSidebarCollapsed ? "px-2" : "px-3")}>
                    {navItems.map((item) => {
                        const isActive = pathname === item.href || (item.href !== '/' && pathname.startsWith(item.href));
                        const Icon = item.icon;

                        if (item.href === '/capture') {
                            return (
                                <Tooltip.Root key={item.href} delayDuration={isSidebarCollapsed ? 0 : 700}>
                                    <CaptureDropdown
                                        align="left"
                                        trigger={
                                            <Tooltip.Trigger asChild>
                                                <button
                                                    className={cn(
                                                        "flex h-11 items-center rounded-xl transition-all duration-200 w-full group",
                                                        isSidebarCollapsed ? "justify-center w-11" : "px-3",
                                                        isActive
                                                            ? "bg-stone-900 text-white shadow-md text-glow shadow-stone-200"
                                                            : "text-stone-400 hover:bg-stone-50 hover:text-stone-900"
                                                    )}
                                                >
                                                    <Icon className="h-5 w-5 shrink-0" />
                                                    {!isSidebarCollapsed && (
                                                        <span className="ml-3 text-sm font-bold truncate animate-in fade-in slide-in-from-left-1 duration-300">
                                                            {item.label}
                                                        </span>
                                                    )}
                                                </button>
                                            </Tooltip.Trigger>
                                        }
                                    />
                                    <Tooltip.Portal>
                                        <Tooltip.Content side="right" className="rounded-lg bg-stone-900 px-3 py-1.5 text-xs text-white shadow-lg z-[100]" sideOffset={12}>
                                            {item.label}
                                        </Tooltip.Content>
                                    </Tooltip.Portal>
                                </Tooltip.Root>
                            );
                        }

                        return (
                            <Tooltip.Root key={item.href} delayDuration={isSidebarCollapsed ? 0 : 700}>
                                <Tooltip.Trigger asChild>
                                    <Link
                                        href={item.href}
                                        className={cn(
                                            "flex h-11 items-center rounded-xl transition-all duration-200 w-full group",
                                            isSidebarCollapsed ? "justify-center w-11" : "px-3",
                                            isActive
                                                ? "bg-stone-900 text-white shadow-sm shadow-stone-200"
                                                : "text-stone-400 hover:bg-stone-50 hover:text-stone-900"
                                        )}
                                    >
                                        <Icon className="h-5 w-5 shrink-0" />
                                        {!isSidebarCollapsed && (
                                            <span className="ml-3 text-sm font-bold truncate animate-in fade-in slide-in-from-left-1 duration-300">
                                                {item.label}
                                            </span>
                                        )}
                                    </Link>
                                </Tooltip.Trigger>
                                <Tooltip.Portal>
                                    <Tooltip.Content side="right" className="rounded-lg bg-stone-900 px-3 py-1.5 text-xs text-white shadow-lg z-[100]" sideOffset={12}>
                                        {item.label}
                                    </Tooltip.Content>
                                </Tooltip.Portal>
                            </Tooltip.Root>
                        );
                    })}
                </nav>

                <div className="mt-auto w-full flex flex-col gap-2 pb-5">
                    <div className={cn("bg-stone-100 shrink-0", isSidebarCollapsed ? "w-8 h-px mx-auto" : "w-[calc(100%-2rem)] h-px mx-4")} />

                    <div className={cn("w-full pt-1", isSidebarCollapsed ? "px-2" : "px-3")}>
                        <Tooltip.Root delayDuration={isSidebarCollapsed ? 0 : 700}>
                            <Tooltip.Trigger asChild>
                                <Link
                                    href="/settings"
                                    className={cn(
                                        "flex h-11 items-center rounded-xl transition-all duration-200 w-full group",
                                        isSidebarCollapsed ? "justify-center w-11" : "px-3",
                                        pathname === '/settings'
                                            ? "bg-stone-900 text-white"
                                            : "text-stone-400 hover:bg-stone-50 hover:text-stone-900"
                                    )}
                                >
                                    <Settings2 className="h-5 w-5 shrink-0" />
                                    {!isSidebarCollapsed && (
                                        <span className="ml-3 text-sm font-bold truncate">Account Settings</span>
                                    )}
                                </Link>
                            </Tooltip.Trigger>
                            <Tooltip.Portal>
                                <Tooltip.Content side="right" className="rounded-lg bg-stone-900 px-3 py-1.5 text-xs text-white shadow-lg" sideOffset={12}>
                                    Account Settings
                                </Tooltip.Content>
                            </Tooltip.Portal>
                        </Tooltip.Root>

                        {/* Collapse Toggle Button */}
                        <button
                            onClick={toggleSidebar}
                            className={cn(
                                "flex h-11 items-center rounded-xl transition-all duration-200 w-full mt-1 group text-stone-400 hover:bg-stone-50 hover:text-stone-900",
                                isSidebarCollapsed ? "justify-center w-11" : "px-3"
                            )}
                        >
                            {isSidebarCollapsed ? (
                                <PanelLeftOpen className="h-5 w-5 shrink-0" />
                            ) : (
                                <>
                                    <PanelLeftClose className="h-5 w-5 shrink-0" />
                                    <span className="ml-3 text-sm font-bold truncate">Collapse Rails</span>
                                </>
                            )}
                        </button>
                    </div>
                </div>
            </aside>
        </Tooltip.Provider>
    );
}
