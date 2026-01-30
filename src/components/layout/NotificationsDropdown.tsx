'use client';

import { useState, useRef, useEffect } from 'react';
import { Bell, CheckCircle2, Zap, Clock, UserCheck, Calendar } from 'lucide-react';
import { cn } from '@/lib/utils';
import Link from 'next/link';

interface Notification {
    id: string;
    title: string;
    description: string;
    time: string;
    type: 'lead' | 'insight' | 'follow-up' | 'event';
    isRead: boolean;
}

const MOCK_NOTIFICATIONS: Notification[] = [
    {
        id: '1',
        title: 'New Lead Captured',
        description: 'Alex Carter from Google added to contacts.',
        time: '2m ago',
        type: 'lead',
        isRead: false
    },
    {
        id: '2',
        title: 'AI Insight Ready',
        description: 'Prep brief for TechConf 2024 is now completed.',
        time: '15m ago',
        type: 'insight',
        isRead: false
    },
    {
        id: '3',
        title: 'Follow-up Reminder',
        description: 'Don\'t forget to send a draft to Sarah Jenkins.',
        time: '1h ago',
        type: 'follow-up',
        isRead: true
    },
    {
        id: '4',
        title: 'Event Starting Tomorrow',
        description: 'Global Green Expo exhibition starts at 9:00 AM.',
        time: '3h ago',
        type: 'event',
        isRead: true
    }
];

export function NotificationsDropdown() {
    const [isOpen, setIsOpen] = useState(false);
    const dropdownRef = useRef<HTMLDivElement>(null);

    useEffect(() => {
        function handleClickOutside(event: MouseEvent) {
            if (dropdownRef.current && !dropdownRef.current.contains(event.target as Node)) {
                setIsOpen(false);
            }
        }
        document.addEventListener('mousedown', handleClickOutside);
        return () => document.removeEventListener('mousedown', handleClickOutside);
    }, []);

    return (
        <div className="relative" ref={dropdownRef}>
            <button
                onClick={() => setIsOpen(!isOpen)}
                className={cn(
                    "h-9 w-9 rounded-xl flex items-center justify-center transition-all relative group",
                    isOpen ? "bg-stone-100 text-stone-900" : "text-stone-500 hover:text-stone-900 hover:bg-stone-50"
                )}
                aria-label="Notifications"
            >
                <Bell className="h-4 w-4" />
            </button>

            {isOpen && (
                <div className="absolute right-0 mt-3 w-80 bg-white border border-stone-200 rounded-2xl shadow-2xl z-50 overflow-hidden animate-in fade-in slide-in-from-top-2 duration-200">
                    {/* Header */}
                    <div className="px-5 py-4 border-b border-stone-100 flex items-center justify-between bg-white">
                        <h3 className="text-sm font-black text-stone-900 uppercase tracking-widest">Notifications</h3>
                    </div>

                    {/* Placeholder Content */}
                    <div className="py-16 px-8 text-center bg-white">
                        <div className="h-14 w-14 bg-stone-50 rounded-2xl flex items-center justify-center mx-auto mb-6 border border-stone-100/50 shadow-inner">
                            <Bell className="h-7 w-7 text-stone-200" />
                        </div>
                        <h4 className="text-xs font-black text-stone-900 uppercase tracking-[0.15em] mb-2 px-2">
                            System Offline
                        </h4>
                        <p className="text-[11px] text-stone-400 font-medium italic leading-relaxed">
                            The notification engine is currently under development. Real-time alerts will appear here once connected.
                        </p>
                    </div>

                    {/* Footer */}
                    <div className="p-3 bg-stone-50/50 border-t border-stone-100">
                        <div className="flex items-center justify-center gap-2 py-2 w-full text-[10px] font-black text-stone-300 uppercase tracking-widest cursor-not-allowed">
                            Settings Restricted
                            <Zap className="h-3 w-3" />
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
}
