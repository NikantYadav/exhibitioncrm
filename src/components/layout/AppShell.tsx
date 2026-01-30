import { ReactNode, useState } from 'react';
import { Sidebar } from './Sidebar';
import { TopBar } from './TopBar';
import { OfflineIndicator } from '../ui/OfflineIndicator';
import { QuickNoteModal } from '../notes/QuickNoteModal';
import { PenTool } from 'lucide-react';

interface AppShellProps {
    children: ReactNode;
}

export function AppShell({ children }: AppShellProps) {
    const [isNoteModalOpen, setIsNoteModalOpen] = useState(false);

    return (
        <div className="min-h-screen">
            <Sidebar />

            <div className="pl-16">
                <TopBar />

                <main className="container mx-auto p-8 max-w-7xl">
                    {children}
                </main>
            </div>

            {/* Quick Note FAB */}
            <div className="fixed bottom-8 right-8 z-40">
                <button
                    onClick={() => setIsNoteModalOpen(true)}
                    className="bg-indigo-600 hover:bg-indigo-700 text-white rounded-full p-4 shadow-lg hover:shadow-xl transition-all hover:scale-105 group flex items-center gap-0 hover:gap-2"
                    title="Quick Note"
                >
                    <PenTool className="h-6 w-6" />
                    <span className="max-w-0 overflow-hidden group-hover:max-w-xs transition-all duration-300 ease-in-out font-medium whitespace-nowrap">
                        New Note
                    </span>
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
