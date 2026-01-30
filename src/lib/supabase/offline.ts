import { SyncQueueItem } from '@/types';

const SYNC_QUEUE_KEY = 'crm_sync_queue';
const OFFLINE_CACHE_KEY = 'crm_offline_cache';

export class OfflineManager {
    // Add item to sync queue
    static addToQueue(item: Omit<SyncQueueItem, 'id' | 'timestamp' | 'status' | 'retries'>): void {
        const queue = this.getQueue();
        const newItem: SyncQueueItem = {
            ...item,
            id: crypto.randomUUID(),
            timestamp: Date.now(),
            status: 'pending',
            retries: 0,
        };
        queue.push(newItem);
        localStorage.setItem(SYNC_QUEUE_KEY, JSON.stringify(queue));
    }

    // Get all pending items in queue
    static getQueue(): SyncQueueItem[] {
        if (typeof window === 'undefined') return [];
        const queue = localStorage.getItem(SYNC_QUEUE_KEY);
        return queue ? JSON.parse(queue) : [];
    }

    // Get pending items only
    static getPendingItems(): SyncQueueItem[] {
        return this.getQueue().filter(item => item.status === 'pending');
    }

    // Update queue item status
    static updateQueueItem(id: string, updates: Partial<SyncQueueItem>): void {
        const queue = this.getQueue();
        const index = queue.findIndex(item => item.id === id);
        if (index !== -1) {
            queue[index] = { ...queue[index], ...updates };
            localStorage.setItem(SYNC_QUEUE_KEY, JSON.stringify(queue));
        }
    }

    // Remove item from queue
    static removeFromQueue(id: string): void {
        const queue = this.getQueue().filter(item => item.id !== id);
        localStorage.setItem(SYNC_QUEUE_KEY, JSON.stringify(queue));
    }

    // Clear completed items
    static clearCompleted(): void {
        const queue = this.getQueue().filter(item => item.status !== 'completed');
        localStorage.setItem(SYNC_QUEUE_KEY, JSON.stringify(queue));
    }

    // Cache data for offline access
    static cacheData(key: string, data: any): void {
        if (typeof window === 'undefined') return;
        const cache = this.getCache();
        cache[key] = {
            data,
            timestamp: Date.now(),
        };
        localStorage.setItem(OFFLINE_CACHE_KEY, JSON.stringify(cache));
    }

    // Get cached data
    static getCachedData(key: string): any {
        if (typeof window === 'undefined') return null;
        const cache = this.getCache();
        return cache[key]?.data || null;
    }

    // Get all cache
    static getCache(): Record<string, { data: any; timestamp: number }> {
        if (typeof window === 'undefined') return {};
        const cache = localStorage.getItem(OFFLINE_CACHE_KEY);
        return cache ? JSON.parse(cache) : {};
    }

    // Clear old cache (older than 7 days)
    static clearOldCache(): void {
        const cache = this.getCache();
        const sevenDaysAgo = Date.now() - 7 * 24 * 60 * 60 * 1000;

        Object.keys(cache).forEach(key => {
            if (cache[key].timestamp < sevenDaysAgo) {
                delete cache[key];
            }
        });

        localStorage.setItem(OFFLINE_CACHE_KEY, JSON.stringify(cache));
    }

    // Check if online
    static isOnline(): boolean {
        return typeof window !== 'undefined' && navigator.onLine;
    }

    // Get queue stats
    static getQueueStats() {
        const queue = this.getQueue();
        return {
            total: queue.length,
            pending: queue.filter(item => item.status === 'pending').length,
            syncing: queue.filter(item => item.status === 'syncing').length,
            completed: queue.filter(item => item.status === 'completed').length,
            failed: queue.filter(item => item.status === 'failed').length,
        };
    }
}
