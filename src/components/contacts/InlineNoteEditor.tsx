'use client';

import { useState } from 'react';
import { Button } from '@/components/ui/Button';
import { Input } from '@/components/ui/Input';
import { Textarea } from '@/components/ui/Textarea';
import { FileText, X } from 'lucide-react';

interface InlineNoteEditorProps {
    onSave: (content: string) => Promise<void>;
    onCancel?: () => void;
    placeholder?: string;
}

export function InlineNoteEditor({ onSave, onCancel, placeholder = 'Add a note...' }: InlineNoteEditorProps) {
    const [content, setContent] = useState('');
    const [saving, setSaving] = useState(false);

    const handleSave = async () => {
        if (!content.trim()) return;

        setSaving(true);
        try {
            await onSave(content);
            setContent('');
        } catch (error) {
            console.error('Failed to save note:', error);
        } finally {
            setSaving(false);
        }
    };

    const handleCancel = () => {
        setContent('');
        onCancel?.();
    };

    return (
        <div className="bg-white border-2 border-blue-200 rounded-lg p-4">
            <div className="flex items-start gap-3 mb-3">
                <div className="bg-blue-100 text-blue-600 p-2 rounded-lg">
                    <FileText className="h-4 w-4" />
                </div>
                <div className="flex-1">
                    <Textarea
                        rows={3}
                        value={content}
                        onChange={(e) => setContent(e.target.value)}
                        placeholder={placeholder}
                        autoFocus
                    />
                </div>
            </div>

            <div className="flex gap-2 justify-end">
                <Button
                    type="button"
                    variant="ghost"
                    size="sm"
                    onClick={handleCancel}
                    disabled={saving}
                >
                    <X className="mr-1 h-3 w-3" />
                    Cancel
                </Button>
                <Button
                    type="button"
                    size="sm"
                    onClick={handleSave}
                    disabled={!content.trim() || saving}
                >
                    {saving ? 'Saving...' : 'Save Note'}
                </Button>
            </div>
        </div>
    );
}
