'use server';

import { NoteService, SuggestedNote } from '@/lib/services/note-service';

export async function processSmartNoteAction(content: string) {
    try {
        const result = await NoteService.processSmartNote(content);
        return { success: true, note: result };
    } catch (error) {
        console.error('Action error:', error);
        return { success: false, error: 'Failed to process note' };
    }
}

export async function saveSmartNoteAction(note: SuggestedNote) {
    try {
        await NoteService.saveNote(note);
        return { success: true };
    } catch (error) {
        console.error('Action error:', error);
        return { success: false, error: 'Failed to save note' };
    }
}
