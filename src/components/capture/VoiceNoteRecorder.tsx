'use client';

import { useState } from 'react';
import { useVoiceRecorder } from '@/lib/hooks/useVoiceRecorder';
import { Button } from '@/components/ui/Button';
import { Mic, Square, Pause, Play, Trash2, Check, Loader2 } from 'lucide-react';
import { VoiceNotePlayer } from '@/components/ui/VoiceNotePlayer';

interface VoiceNoteRecorderProps {
    onSave: (audioBlob: Blob, duration: number) => Promise<void>;
    onCancel?: () => void;
}

export function VoiceNoteRecorder({ onSave, onCancel }: VoiceNoteRecorderProps) {
    const [saving, setSaving] = useState(false);
    const {
        isRecording,
        isPaused,
        duration,
        audioURL,
        audioBlob,
        startRecording,
        stopRecording,
        pauseRecording,
        resumeRecording,
        clearRecording
    } = useVoiceRecorder();

    const formatDuration = (seconds: number) => {
        const mins = Math.floor(seconds / 60);
        const secs = seconds % 60;
        return `${mins}:${secs.toString().padStart(2, '0')}`;
    };

    const handleSave = async () => {
        if (audioBlob) {
            setSaving(true);
            try {
                await onSave(audioBlob, duration);
                clearRecording();
            } finally {
                setSaving(false);
            }
        }
    };

    return (
        <div className="bg-white border-2 border-purple-200 rounded-lg p-6">
            <div className="flex items-center gap-3 mb-4">
                <div className="bg-purple-100 text-purple-600 p-3 rounded-full">
                    {saving ? <Loader2 className="h-6 w-6 animate-spin" /> : <Mic className="h-6 w-6" />}
                </div>
                <div>
                    <h3 className="font-semibold text-gray-900">Voice Note</h3>
                    <p className="text-sm text-gray-600">
                        {saving ? 'Saving recording...' : (isRecording ? 'Recording...' : audioURL ? 'Recording complete' : 'Ready to record')}
                    </p>
                </div>
            </div>

            {/* Timer */}
            <div className="text-center mb-6">
                <div className="text-4xl font-mono font-bold text-gray-900">
                    {formatDuration(duration)}
                </div>
            </div>

            {/* Playback Review */}
            {audioURL && !isRecording && (
                <div className="mb-6">
                    <div className="text-[10px] font-bold text-stone-400 uppercase tracking-widest mb-2 flex items-center gap-1.5">
                        <Play className="h-3 w-3" />
                        Preview Recording
                    </div>
                    <VoiceNotePlayer audioURL={audioURL} />
                </div>
            )}

            {/* Controls */}
            <div className="flex gap-2">
                {!isRecording && !audioURL && (
                    <Button onClick={startRecording} className="flex-1" disabled={saving}>
                        <Mic className="mr-2 h-4 w-4" />
                        Start Recording
                    </Button>
                )}

                {isRecording && (
                    <>
                        {!isPaused ? (
                            <Button onClick={pauseRecording} variant="outline" className="flex-1" disabled={saving}>
                                <Pause className="mr-2 h-4 w-4" />
                                Pause
                            </Button>
                        ) : (
                            <Button onClick={resumeRecording} variant="outline" className="flex-1" disabled={saving}>
                                <Play className="mr-2 h-4 w-4" />
                                Resume
                            </Button>
                        )}
                        <Button onClick={stopRecording} variant="destructive" disabled={saving}>
                            <Square className="h-4 w-4" />
                        </Button>
                    </>
                )}

                {audioURL && !isRecording && (
                    <>
                        <Button onClick={handleSave} className="flex-1" disabled={saving}>
                            {saving ? (
                                <>
                                    <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                                    Transcribing...
                                </>
                            ) : (
                                <>
                                    <Check className="mr-2 h-4 w-4" />
                                    Save Note
                                </>
                            )}
                        </Button>
                        <Button onClick={clearRecording} variant="outline" disabled={saving}>
                            <Trash2 className="h-4 w-4" />
                        </Button>
                    </>
                )}

                {onCancel && (
                    <Button onClick={onCancel} variant="ghost" disabled={saving}>
                        Cancel
                    </Button>
                )}
            </div>
        </div>
    );
}
