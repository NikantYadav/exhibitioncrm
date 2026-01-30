'use server';

import { MemoryService } from '@/lib/services/memory-service';

export async function getRelationshipMemoryAction(contactId: string) {
    try {
        const memory = await MemoryService.getRelationshipMemory(contactId);
        return { success: true, memory };
    } catch (error) {
        console.error('Failed to get relationship memory:', error);
        return { success: false, error: 'Failed to generate memory' };
    }
}
