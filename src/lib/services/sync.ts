import { supabase } from '../supabase/client';
import { OfflineManager } from '../supabase/offline';
import { SyncQueueItem } from '@/types';

export class SyncService {
    /**
     * Process sync queue - sync all pending items to Supabase
     */
    static async processSyncQueue(): Promise<{
        synced: number;
        failed: number;
        errors: string[];
    }> {
        if (!OfflineManager.isOnline()) {
            return { synced: 0, failed: 0, errors: ['Device is offline'] };
        }

        const pendingItems = OfflineManager.getPendingItems();
        let synced = 0;
        let failed = 0;
        const errors: string[] = [];

        for (const item of pendingItems) {
            try {
                OfflineManager.updateQueueItem(item.id, { status: 'syncing' });

                await this.syncItem(item);

                OfflineManager.updateQueueItem(item.id, { status: 'completed' });
                synced++;
            } catch (error) {
                const errorMessage = error instanceof Error ? error.message : 'Unknown error';
                errors.push(`${item.table} ${item.operation}: ${errorMessage}`);

                // Retry logic
                const retries = item.retries + 1;
                if (retries < 3) {
                    OfflineManager.updateQueueItem(item.id, {
                        status: 'pending',
                        retries,
                    });
                } else {
                    OfflineManager.updateQueueItem(item.id, { status: 'failed' });
                    failed++;
                }
            }
        }

        // Clean up completed items
        OfflineManager.clearCompleted();

        return { synced, failed, errors };
    }

    /**
     * Sync a single queue item
     */
    private static async syncItem(item: SyncQueueItem): Promise<void> {
        const { operation, table, data } = item;

        switch (operation) {
            case 'create':
                await supabase.from(table).insert(data);
                break;

            case 'update':
                if (!data.id) throw new Error('Update requires id');
                await supabase.from(table).update(data).eq('id', data.id);
                break;

            case 'delete':
                if (!data.id) throw new Error('Delete requires id');
                await supabase.from(table).delete().eq('id', data.id);
                break;

            default:
                throw new Error(`Unknown operation: ${operation}`);
        }
    }

    /**
     * Start background sync (call this when app comes online)
     */
    static async startBackgroundSync(): Promise<void> {
        if (!OfflineManager.isOnline()) return;

        const stats = OfflineManager.getQueueStats();
        if (stats.pending === 0) return;

        console.log(`Starting background sync: ${stats.pending} items pending`);

        const result = await this.processSyncQueue();

        console.log(`Sync complete: ${result.synced} synced, ${result.failed} failed`);

        if (result.errors.length > 0) {
            console.error('Sync errors:', result.errors);
        }
    }

    /**
     * Setup online/offline listeners
     */
    static setupSyncListeners(): void {
        if (typeof window === 'undefined') return;

        window.addEventListener('online', () => {
            console.log('Device is online, starting sync...');
            this.startBackgroundSync();
        });

        window.addEventListener('offline', () => {
            console.log('Device is offline, queuing operations...');
        });
    }
}
