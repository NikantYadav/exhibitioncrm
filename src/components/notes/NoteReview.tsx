'use client';

import { SuggestedNote } from '@/lib/services/note-service';
import { Button } from '@/components/ui/Button';
import { Card, CardContent } from '@/components/ui/Card';
import { Check, X, User, Calendar, Edit2 } from 'lucide-react';
import { useState } from 'react';

interface NoteReviewProps {
    note: SuggestedNote;
    onSave: (note: SuggestedNote) => Promise<void>;
    onCancel: () => void;
    isSaving: boolean;
}

export function NoteReview({ note, onSave, onCancel, isSaving }: NoteReviewProps) {
    const [editedNote, setEditedNote] = useState(note);
    const [isEditing, setIsEditing] = useState(false);

    return (
        <div className="space-y-4 animate-in fade-in slide-in-from-bottom-4 duration-300">
            <div className="bg-indigo-50 border border-indigo-100 rounded-lg p-4">
                <div className="flex items-start gap-3">
                    <div className="p-2 bg-white rounded-full shadow-sm">
                        <Check className="h-5 w-5 text-indigo-600" />
                    </div>
                    <div className="flex-1">
                        <h3 className="font-semibold text-indigo-900">Interpretation</h3>
                        <p className="text-sm text-indigo-700 mt-1">
                            I've analyzed your note. Please confirm the links below.
                        </p>
                    </div>
                </div>
            </div>

            <Card className="border-indigo-200 shadow-md">
                <CardContent className="p-0">
                    {/* Content Preview */}
                    <div className="p-4 border-b border-gray-100">
                        <div className="flex justify-between items-start mb-2">
                            <h4 className="text-xs font-semibold text-gray-500 uppercase tracking-wider">Note Content</h4>
                            <Button
                                variant="ghost"
                                size="sm"
                                onClick={() => setIsEditing(!isEditing)}
                                className="h-6 w-6 p-0 text-gray-400 hover:text-indigo-600"
                            >
                                <Edit2 className="h-3 w-3" />
                            </Button>
                        </div>
                        {isEditing ? (
                            <textarea
                                className="w-full text-sm p-2 border rounded-md focus:ring-indigo-500 focus:border-indigo-500"
                                value={editedNote.formatted_content}
                                onChange={(e) => setEditedNote({ ...editedNote, formatted_content: e.target.value })}
                                rows={3}
                            />
                        ) : (
                            <p className="text-gray-800 text-sm leading-relaxed">
                                {editedNote.formatted_content}
                            </p>
                        )}
                    </div>

                    {/* Links */}
                    <div className="p-4 bg-gray-50 space-y-3">
                        {/* Contact Link */}
                        <div className="flex items-center gap-3">
                            <div className={`p-1.5 rounded ${editedNote.contact_id ? 'bg-green-100' : 'bg-gray-200'}`}>
                                <User className={`h-4 w-4 ${editedNote.contact_id ? 'text-green-700' : 'text-gray-500'}`} />
                            </div>
                            <div className="flex-1">
                                <p className="text-xs text-gray-500 font-medium">Linked Contact</p>
                                <p className="text-sm font-semibold text-gray-900">
                                    {editedNote.contact_name || <span className="text-gray-400 italic">No contact detected</span>}
                                </p>
                            </div>
                        </div>

                        {/* Event Link */}
                        <div className="flex items-center gap-3">
                            <div className={`p-1.5 rounded ${editedNote.event_id ? 'bg-blue-100' : 'bg-gray-200'}`}>
                                <Calendar className={`h-4 w-4 ${editedNote.event_id ? 'text-blue-700' : 'text-gray-500'}`} />
                            </div>
                            <div className="flex-1">
                                <p className="text-xs text-gray-500 font-medium">Linked Event</p>
                                <p className="text-sm font-semibold text-gray-900">
                                    {editedNote.event_name || <span className="text-gray-400 italic">No event detected</span>}
                                </p>
                            </div>
                        </div>
                    </div>

                    {/* Actions */}
                    <div className="p-4 flex gap-3">
                        <Button
                            variant="secondary"
                            className="flex-1"
                            onClick={onCancel}
                            disabled={isSaving}
                        >
                            <X className="h-4 w-4 mr-2" />
                            Discard
                        </Button>
                        <Button
                            className="flex-1 bg-indigo-600 hover:bg-indigo-700 text-white"
                            onClick={() => onSave(editedNote)}
                            disabled={isSaving}
                        >
                            {isSaving ? "Saving..." : (
                                <>
                                    <Check className="h-4 w-4 mr-2" />
                                    Confirm & Save
                                </>
                            )}
                        </Button>
                    </div>
                </CardContent>
            </Card>
        </div>
    );
}
