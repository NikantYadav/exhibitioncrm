'use client';

import { useState } from 'react';
import { SmartNoteInput } from './SmartNoteInput';
import { NoteReview } from './NoteReview';
import { processSmartNoteAction, saveSmartNoteAction } from '@/app/actions/notes';
import { SuggestedNote } from '@/lib/services/note-service';
import { X, Sparkles } from 'lucide-react';

interface QuickNoteModalProps {
    isOpen: boolean;
    onClose: () => void;
}

import { toast } from 'sonner';

export function QuickNoteModal({ isOpen, onClose }: QuickNoteModalProps) {
    const [step, setStep] = useState<'input' | 'review'>('input');
    const [suggestedNote, setSuggestedNote] = useState<SuggestedNote | null>(null);
    const [isProcessing, setIsProcessing] = useState(false);
    const [isSaving, setIsSaving] = useState(false);

    if (!isOpen) return null;

    const handleProcess = async (content: string) => {
        setIsProcessing(true);
        const processingToast = toast.loading('Processing note with AI...');
        const result = await processSmartNoteAction(content);
        if (result.success && result.note) {
            setSuggestedNote(result.note);
            setStep('review');
            toast.success('Note structured!', { id: processingToast });
        } else {
            toast.error('Failed to process note', { id: processingToast });
        }
        setIsProcessing(false);
    };

    const handleSave = async (note: SuggestedNote) => {
        setIsSaving(true);
        const savingToast = toast.loading('Saving note...');
        const result = await saveSmartNoteAction(note);
        if (result.success) {
            toast.success('Note saved!', { id: savingToast });
            window.dispatchEvent(new CustomEvent('timeline:refresh'));
            handleClose();
        } else {
            toast.error('Failed to save note', { id: savingToast });
        }
        setIsSaving(false);
    };

    const handleClose = () => {
        setStep('input');
        setSuggestedNote(null);
        onClose();
    };

    return (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-stone-900/40 backdrop-blur-sm animate-in fade-in duration-300">
            <div className="bg-white rounded-3xl shadow-2xl w-full max-w-lg overflow-hidden border border-stone-100">
                {/* Header */}
                <div className="bg-stone-900 p-6 flex justify-between items-center text-white">
                    <div className="flex items-center gap-3">
                        <div className="p-2 bg-white/10 rounded-xl">
                            <Sparkles className="h-5 w-5 text-white" />
                        </div>
                        <h3 className="font-black text-lg tracking-tight uppercase">Fast Note</h3>
                    </div>
                    <button
                        onClick={handleClose}
                        className="p-2 hover:bg-white/10 rounded-full transition-colors active:scale-95"
                    >
                        <X className="h-5 w-5" />
                    </button>
                </div>

                {/* Body */}
                <div className="p-8">
                    {step === 'input' ? (
                        <SmartNoteInput
                            onProcess={handleProcess}
                            isProcessing={isProcessing}
                        />
                    ) : (
                        suggestedNote && (
                            <NoteReview
                                note={suggestedNote}
                                onSave={handleSave}
                                onCancel={() => setStep('input')}
                                isSaving={isSaving}
                            />
                        )
                    )}
                </div>
            </div>
        </div>
    );
}
