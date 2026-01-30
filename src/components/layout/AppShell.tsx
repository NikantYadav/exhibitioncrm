import { ReactNode, useState } from 'react';
import { Sidebar } from './Sidebar';
import { TopBar } from './TopBar';
import { OfflineIndicator } from '../ui/OfflineIndicator';
import { QuickNoteModal } from '../notes/QuickNoteModal';
import { Plus, PenLine } from 'lucide-react';
import { cn } from '@/lib/utils';

interface AppShellProps {
    children: ReactNode;
}

import { useSidebar } from './LayoutContext';

export function AppShell({ children }: AppShellProps) {
    const [isNoteModalOpen, setIsNoteModalOpen] = useState(false);
    const { isSidebarCollapsed } = useSidebar();

    return (
        <div className="min-h-screen bg-stone-50/50">
            <Sidebar />

            <div className={cn(
                "flex flex-col min-h-screen transition-all duration-300 ease-in-out",
                isSidebarCollapsed ? "pl-16" : "pl-64"
            )}>
                <TopBar />

                <main className="flex-1 p-8">
                    <div className="mx-auto max-w-7xl animate-in fade-in slide-in-from-bottom-2 duration-500">
                        {children}
                    </div>
                </main>
            </div>

            {/* Premium FAB */}
            <div className="fixed bottom-10 right-10 z-40">
                <button
                    onClick={() => setIsNoteModalOpen(true)}
                    className={cn(
                        "group relative flex items-center justify-center p-4 rounded-2xl shadow-xl transition-all duration-300",
                        "bg-stone-900 text-white hover:bg-indigo-600 hover:scale-110 active:scale-95",
                        "before:absolute before:inset-0 before:rounded-2xl before:bg-indigo-600 before:scale-x-0 before:origin-right before:transition-transform group-hover:before:scale-x-100 group-hover:before:origin-left"
                    )}
                    title="Quick Record"
                >
                    <div className="relative z-10 flex items-center gap-0 group-hover:gap-2 transition-all duration-300">
                        <Plus className="h-6 w-6 transition-transform group-hover:rotate-90" />
                        <span className="max-w-0 overflow-hidden group-hover:max-w-xs transition-all duration-300 ease-in-out font-bold text-sm whitespace-nowrap opacity-0 group-hover:opacity-100">
                            Quick Note
                        </span>
                    </div>
                </button>
            </div>

            <QuickNoteModal
                isOpen={isNoteModalOpen}
                onClose={() => setIsNoteModalOpen(false)}
            />

            <OfflineIndicator />
        </div>
    );
}
