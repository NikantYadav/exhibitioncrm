'use client';

import { Search, Mail, Bell } from 'lucide-react';
import { Avatar, AvatarFallback } from '@/components/ui/Avatar';
import { Input } from '@/components/ui/Input';
import { Button } from '@/components/ui/Button';

export function TopBar() {
    return (
        <header className="sticky top-0 z-30 flex h-16 items-center gap-6 border-b border-stone-200 bg-white px-8">
            {/* Logo + Brand */}
            <div className="flex items-center gap-3">
                <div className="h-8 w-8 rounded-lg bg-gradient-to-br from-indigo-600 to-indigo-700 flex items-center justify-center text-white font-bold text-sm shadow-md">
                    E
                </div>
                <span className="font-semibold text-stone-900 hidden sm:inline">Exhibition CRM</span>
            </div>

            {/* Search */}
            <div className="flex-1 max-w-96">
                <div className="relative">
                    <Search className="absolute left-3 top-1/2 h-5 w-5 -translate-y-1/2 text-stone-400 transition-colors peer-focus:text-stone-600" strokeWidth={2} />
                    <Input
                        placeholder="Search..."
                        className="peer pl-10 h-10 bg-white border-stone-200 rounded-xl focus-visible:ring-2 focus-visible:ring-indigo-400/20 focus-visible:border-indigo-400"
                    />
                </div>
            </div>

            {/* Right actions */}
            <div className="flex items-center gap-2">
                <Button
                    variant="ghost"
                    size="icon"
                    className="rounded-full text-stone-600 hover:text-stone-900"
                    aria-label="Search"
                >
                    <Search className="h-5 w-5" strokeWidth={2} />
                </Button>

                <Button
                    variant="ghost"
                    size="icon"
                    className="rounded-full text-stone-600 hover:text-stone-900"
                    aria-label="Mail"
                >
                    <Mail className="h-5 w-5" strokeWidth={2} />
                </Button>

                <Button
                    variant="ghost"
                    size="icon"
                    className="rounded-full text-stone-600 hover:text-stone-900 relative"
                    aria-label="Notifications"
                >
                    <Bell className="h-5 w-5" strokeWidth={2} />
                    <span className="absolute right-2 top-2 h-2 w-2 rounded-full bg-red-500 border border-white" />
                </Button>

                <Avatar className="h-10 w-10 cursor-pointer avatar-ring">
                    <AvatarFallback className="text-xs bg-gradient-to-br from-indigo-500 to-indigo-600 text-white font-semibold">
                        JD
                    </AvatarFallback>
                </Avatar>
            </div>
        </header>
    );
}
