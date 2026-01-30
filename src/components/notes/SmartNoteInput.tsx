'use client';

import { useState } from 'react';
import { Button } from '@/components/ui/Button'; // Assuming Button exists
import { Textarea } from '@/components/ui/Textarea'; // Assuming Textarea exists
import { Mic, Send, Loader2, Sparkles } from 'lucide-react';
import { toast } from 'sonner';

interface SmartNoteInputProps {
    onProcess: (content: string) => Promise<void>;
    isProcessing: boolean;
}

export function SmartNoteInput({ onProcess, isProcessing }: SmartNoteInputProps) {
    const [content, setContent] = useState('');
    const [isListening, setIsListening] = useState(false);

    const handleSend = async () => {
        if (!content.trim()) return;
        await onProcess(content);
        setContent(''); // Clear after processing starts (or wait for success depending on preference)
    };

    const toggleListening = () => {
        if (isListening) {
            setIsListening(false);
            return;
        }

        const SpeechRecognition = (window as any).SpeechRecognition || (window as any).webkitSpeechRecognition;

        if (!SpeechRecognition) {
            toast.error('Speech recognition is not supported in this browser.');
            return;
        }

        const recognition = new SpeechRecognition();
        recognition.lang = 'en-US';
        recognition.interimResults = false;
        recognition.maxAlternatives = 1;

        recognition.onstart = () => {
            setIsListening(true);
            toast.info('Listening...', { duration: 1000 });
        };

        recognition.onresult = (event: any) => {
            const transcript = event.results[0][0].transcript;
            setContent((prev) => prev + (prev.trim() ? ' ' : '') + transcript);
        };

        recognition.onerror = (event: any) => {
            console.error('Speech recognition error:', event.error);
            setIsListening(false);
            if (event.error !== 'no-speech') {
                toast.error(`Speech recognition error: ${event.error}`);
            }
        };

        recognition.onend = () => {
            setIsListening(false);
        };

        recognition.start();
    };

    return (
        <div className="space-y-4">
            <div className="relative">
                <Textarea
                    value={content}
                    onChange={(e) => setContent(e.target.value)}
                    placeholder="Type a note... (e.g., 'Lunch with John from Acme was great')"
                    className="min-h-[140px] p-5 pr-12 text-sm font-medium resize-none rounded-2xl border-stone-100 bg-stone-50/50 focus:bg-white focus:ring-stone-200 transition-all placeholder:text-stone-300"
                    disabled={isProcessing}
                />
                <Button
                    variant="ghost"
                    size="sm"
                    className={`absolute bottom-4 right-4 rounded-full h-10 w-10 p-0 shadow-sm transition-all ${isListening ? 'text-red-500 bg-red-50' : 'text-stone-400 hover:text-stone-900 hover:bg-stone-100'}`}
                    onClick={toggleListening}
                    disabled={isProcessing}
                >
                    <Mic className={`h-5 w-5 ${isListening ? 'animate-pulse' : ''}`} />
                </Button>
            </div>

            <div className="flex justify-end pt-2">
                <Button
                    onClick={handleSend}
                    disabled={!content.trim() || isProcessing}
                    className="bg-stone-900 hover:bg-stone-800 text-white shadow-xl shadow-stone-900/10 h-12 px-8 rounded-xl font-black uppercase tracking-widest text-[10px] flex items-center gap-3 transition-all active:scale-95"
                >
                    {isProcessing ? (
                        <>
                            <Loader2 className="h-4 w-4 animate-spin" />
                            Processing...
                        </>
                    ) : (
                        <>
                            <Sparkles className="h-4 w-4 text-white" strokeWidth={2.5} />
                            Save Note
                        </>
                    )}
                </Button>
            </div>
        </div>
    );
}
