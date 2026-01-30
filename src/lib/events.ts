
/**
 * Global broadcast channel for cross-tab/page communication
 */
export const syncChannel = typeof window !== 'undefined' ? new BroadcastChannel('crm_sync') : null;

export const emitSyncEvent = (type: string, data?: any) => {
    if (syncChannel) {
        syncChannel.postMessage({ type, data, source: window.location.pathname });
    }
};

export const enum SyncEventType {
    CONTACT_UPDATED = 'CONTACT_UPDATED',
    EVENT_UPDATED = 'EVENT_UPDATED',
    STATS_UPDATED = 'STATS_UPDATED'
}
