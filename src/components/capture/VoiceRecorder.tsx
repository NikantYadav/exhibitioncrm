'use client';

import { useReactMediaRecorder } from 'react-media-recorder';
import { Mic, Check, StopCircle } from 'lucide-react';
import { Button } from '@/components/ui/Button';
import { Card, CardContent } from '@/components/ui/Card';
import { toast } from 'sonner';

interface VoiceRecorderProps {
    onComplete: (data: any) => void;
    onCancel: () => void;
}

export default function VoiceRecorder({ onComplete, onCancel }: VoiceRecorderProps) {
    const { status, startRecording, stopRecording, mediaBlobUrl, clearBlobUrl } = useReactMediaRecorder({ audio: true });

    return (
        <Card className="shadow-lg">
            <CardContent className="p-12 text-center">
                <div className="mb-8">
                    <div className={`
                        h-32 w-32 mx-auto rounded-full flex items-center justify-center transition-all duration-500
                        ${status === 'recording' ? 'bg-red-500 animate-pulse' : 'bg-rose-100'}
                    `}>
                        <Mic className={`h-12 w-12 ${status === 'recording' ? 'text-white' : 'text-rose-600'}`} />
                    </div>
                </div>

                <h3 className="text-2xl font-bold text-gray-900 mb-2">
                    {status === 'recording' ? 'Listening...' : 'Voice Note'}
                </h3>
                <p className="text-gray-500 mb-8">
                    {status === 'recording'
                        ? 'Speak clearly to record your notes'
                        : 'Tap microphone to start recording'}
                </p>

                <div className="flex justify-center gap-4">
                    {status !== 'recording' ? (
                        <Button size="lg" onClick={startRecording} className="w-40 bg-rose-600 hover:bg-rose-700">
                            <Mic className="mr-2 h-5 w-5" /> Start
                        </Button>
                    ) : (
                        <Button size="lg" variant="destructive" onClick={stopRecording} className="w-40">
                            <StopCircle className="mr-2 h-5 w-5" /> Stop
                        </Button>
                    )}
                </div>

                {mediaBlobUrl && (
                    <div className="mt-8 p-6 bg-gray-50 rounded-xl border animate-in fade-in slide-in-from-bottom-4">
                        <div className="flex items-center justify-center gap-4 mb-4">
                            <audio src={mediaBlobUrl} controls className="w-full max-w-sm" />
                        </div>
                        <div className="flex justify-center gap-3">
                            <Button onClick={() => toast.info('Feature coming soon: Save recording')}>
                                <Check className="mr-2 h-4 w-4" /> Save Recording
                            </Button>
                            <Button variant="outline" onClick={clearBlobUrl} className="text-red-600 hover:text-red-700 hover:bg-red-50">
                                Delete
                            </Button>
                        </div>
                    </div>
                )}
            </CardContent>
        </Card>
    );
}
