'use client';

import { useState } from 'react';
import { Button } from '@/components/ui/Button'; // Assuming Button exists
import { Textarea } from '@/components/ui/Textarea'; // Assuming Textarea exists
import { Mic, Send, Loader2, Sparkles } from 'lucide-react';

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
        // Mock voice recognition
        if (!isListening) {
            setIsListening(true);
            setTimeout(() => {
                setContent((prev) => prev + " Met with Sarah at the conference today. She's interested...");
                setIsListening(false);
            }, 2000);
        } else {
            setIsListening(false);
        }
    };

    return (
        <div className="space-y-4">
            <div className="relative">
                <Textarea
                    value={content}
                    onChange={(e) => setContent(e.target.value)}
                    placeholder="Type a quick note... (e.g., 'Lunch with John from Acme was great')"
                    className="min-h-[100px] p-4 pr-12 text-base resize-none"
                    disabled={isProcessing}
                />
                <Button
                    variant="ghost"
                    size="sm"
                    className={`absolute bottom-3 right-3 rounded-full h-8 w-8 p-0 ${isListening ? 'text-red-500 bg-red-50' : 'text-gray-400 hover:text-indigo-600'}`}
                    onClick={toggleListening}
                    disabled={isProcessing}
                >
                    <Mic className={`h-4 w-4 ${isListening ? 'animate-pulse' : ''}`} />
                </Button>
            </div>

            <div className="flex justify-end">
                <Button
                    onClick={handleSend}
                    disabled={!content.trim() || isProcessing}
                    className="bg-indigo-600 hover:bg-indigo-700 text-white shadow-md transition-all flex items-center gap-2"
                >
                    {isProcessing ? (
                        <>
                            <Loader2 className="h-4 w-4 animate-spin" />
                            Processing...
                        </>
                    ) : (
                        <>
                            <Sparkles className="h-4 w-4 text-indigo-200" />
                            Analyze & Link
                        </>
                    )}
                </Button>
            </div>
        </div>
    );
}
