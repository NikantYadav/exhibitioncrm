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
                isSidebarCollapsed ? "pl-20" : "pl-72"
            )}>
                <TopBar />

                <main className="flex-1 p-10">
                    <div className="mx-auto max-w-7xl animate-in fade-in duration-500">
                        {children}
                    </div>
                </main>
            </div>

            {/* Premium FAB */}
            <div className="fixed bottom-10 right-10 z-40">
                <button
                    onClick={() => setIsNoteModalOpen(true)}
                    className={cn(
                        "group relative flex items-center justify-center p-4 rounded-2xl shadow-2xl transition-all duration-300 overflow-hidden",
                        "bg-stone-900 text-white hover:bg-stone-800"
                    )}
                    title="Quick Record"
                >
                    <div className="relative z-10 flex items-center gap-0 group-hover:gap-3 transition-all duration-300">
                        <Plus className="h-6 w-6 stroke-[3px]" />
                        <span className="max-w-0 overflow-hidden group-hover:max-w-xs transition-all duration-300 ease-in-out font-black text-xs uppercase tracking-widest whitespace-nowrap opacity-0 group-hover:opacity-100">
                            Fast Note
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
