'use client';

import { useState, useEffect } from 'react';
import { OfflineManager } from '../supabase/offline';

export function useSyncStatus() {
    const [stats, setStats] = useState({
        total: 0,
        pending: 0,
        syncing: 0,
        completed: 0,
        failed: 0,
    });

    useEffect(() => {
        // Update stats initially
        updateStats();

        // Poll for updates every 2 seconds
        const interval = setInterval(updateStats, 2000);

        return () => clearInterval(interval);
    }, []);

    const updateStats = () => {
        setStats(OfflineManager.getQueueStats());
    };

    return {
        ...stats,
        hasPending: stats.pending > 0,
        refresh: updateStats,
    };
}
