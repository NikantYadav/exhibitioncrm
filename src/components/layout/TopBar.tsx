'use client';

import { Mail, Bell, Settings, HelpCircle, ChevronRight } from 'lucide-react';
import { Avatar, AvatarFallback } from '@/components/ui/Avatar';
import { Button } from '@/components/ui/Button';
import { usePathname } from 'next/navigation';
import Link from 'next/link';

import { toast } from 'sonner';

import { NotificationsDropdown } from './NotificationsDropdown';

export function TopBar() {
    const pathname = usePathname();

    // Simple breadcrumb logic
    const segments = pathname.split('/').filter(Boolean);
    const currentPage = segments[0] || 'Dashboard';
    const isSubPage = segments.length > 1;

    return (
        <header className="sticky top-0 z-30 flex h-16 items-center justify-between border-b border-stone-200/60 bg-white/80 backdrop-blur-md px-8">
            <div className="flex items-center gap-4">
                <nav className="flex items-center gap-2 text-sm font-medium">
                    <Link
                        href="/"
                        className="text-stone-400 hover:text-stone-900 transition-colors"
                    >
                        CRM
                    </Link>
                    <ChevronRight className="h-4 w-4 text-stone-300" />
                    <span className="text-stone-900 capitalize font-bold tracking-tight">
                        {currentPage.replace('-', ' ')}
                    </span>
                    {isSubPage && (
                        <>
                            <ChevronRight className="h-4 w-4 text-stone-300" />
                            <span className="text-stone-500 font-medium">Details</span>
                        </>
                    )}
                </nav>
            </div>

            <div className="flex items-center gap-3">
                <div className="flex items-center gap-1 border-r border-stone-200 pr-4 mr-1">
                    <Button
                        variant="ghost"
                        size="icon"
                        className="h-9 w-9 rounded-xl text-stone-500 hover:text-stone-900 hover:bg-stone-50"
                        aria-label="Help"
                        onClick={() => toast.info('Help center is coming soon.')}
                    >
                        <HelpCircle className="h-4 w-4" />
                    </Button>
                    <Link href="/follow-ups">
                        <Button
                            variant="ghost"
                            size="icon"
                            className="h-9 w-9 rounded-xl text-stone-500 hover:text-stone-900 hover:bg-stone-50"
                            aria-label="Mail"
                        >
                            <Mail className="h-4 w-4" />
                        </Button>
                    </Link>
                    <NotificationsDropdown />
                </div>

                <div className="flex items-center gap-3 pl-1">
                    <div className="text-right hidden sm:block">
                        <p className="text-xs font-bold text-stone-900 leading-none mb-0.5">Jane Doe</p>
                        <p className="text-[10px] font-medium text-stone-400 uppercase tracking-wider">Account Manager</p>
                    </div>
                    <Link href="/profile">
                        <Avatar className="h-9 w-9 cursor-pointer transition-transform hover:scale-105 active:scale-95 border border-stone-100 ring-2 ring-white shadow-sm">
                            <AvatarFallback className="text-[10px] bg-stone-900 text-white font-bold">
                                JD
                            </AvatarFallback>
                        </Avatar>
                    </Link>
                </div>
            </div>
        </header>
    );
}
