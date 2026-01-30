'use client';

import { useOnlineStatus } from '@/lib/hooks/useOnlineStatus';
import { useSyncStatus } from '@/lib/hooks/useSyncStatus';
import { WifiOff, RefreshCw } from 'lucide-react';

export function OfflineIndicator() {
    const isOnline = useOnlineStatus();
    const { pending } = useSyncStatus();

    if (isOnline && pending === 0) return null;

    return (
        <div className="fixed top-4 right-4 z-50">
            {!isOnline ? (
                <div className="offline-badge flex items-center gap-2">
                    <WifiOff className="h-3.5 w-3.5" />
                    <span>Offline</span>
                </div>
            ) : pending > 0 ? (
                <div className="syncing-badge flex items-center gap-2">
                    <RefreshCw className="h-3.5 w-3.5 animate-spin" />
                    <span>Syncing {pending} items...</span>
                </div>
            ) : null}
        </div>
    );
}
