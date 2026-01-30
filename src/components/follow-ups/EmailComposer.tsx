'use client';

import { useState, useRef, useEffect, useMemo } from 'react';
import { Modal } from '@/components/ui/Modal';
import { Button } from '@/components/ui/Button';
import { Input } from '@/components/ui/Input';
import { RichTextEditor } from '@/components/ui/RichTextEditor';
import { Sparkles, Copy, Send, Loader2, Mail, Edit3, Wand2, RotateCcw } from 'lucide-react';
import { cn } from '@/lib/utils';
import { toast } from 'sonner';

interface EmailComposerProps {
    isOpen: boolean;
    onClose: () => void;
    contact: {
        id: string;
        first_name: string;
        last_name?: string;
        email?: string;
        company?: { name: string };
    };
    event?: {
        id: string;
        name: string;
    };
}

export function EmailComposer({ isOpen, onClose, contact, event }: EmailComposerProps) {
    const [mode, setMode] = useState<'ai' | 'manual'>('ai');
    const [subject, setSubject] = useState('');
    const [body, setBody] = useState('');
    const [instructions, setInstructions] = useState('');
    const [refineInstructions, setRefineInstructions] = useState('');
    const [generating, setGenerating] = useState(false);
    const [improving, setImproving] = useState(false);
    const [aiShowResult, setAiShowResult] = useState(false);

    const handleGenerateDraft = async () => {
        if (!instructions.trim()) {
            toast.error('Please provide context for the AI');
            return;
        }

        setGenerating(true);
        const draftToast = toast.loading('AI is crafting your email...');
        try {
            const response = await fetch('/api/emails/draft', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    contact_id: contact.id,
                    event_id: event?.id,
                    email_type: 'follow_up',
                    custom_context: instructions
                })
            });

            const data = await response.json();
            if (data.data) {
                setSubject(data.data.subject);
                setBody(data.data.body);
                setAiShowResult(true);
                toast.success('Draft generated!', { id: draftToast });
            } else {
                toast.error('Internal Server Error', { id: draftToast });
            }
        } catch (error) {
            console.error('Failed to generate draft:', error);
            toast.error('Internal Server Error', { id: draftToast });
        } finally {
            setGenerating(false);
        }
    };

    const handleImproveDraft = async () => {
        if (!body || !refineInstructions.trim()) return;
        setImproving(true);
        const improveToast = toast.loading('Refining draft...');
        try {
            const response = await fetch('/api/emails/improve', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    text: body,
                    instructions: refineInstructions
                })
            });

            const data = await response.json();
            if (data.data) {
                setSubject(data.data.subject);
                setBody(data.data.body);
                setRefineInstructions('');
                toast.success('Email improved!', { id: improveToast });
            } else {
                toast.error('Internal Server Error', { id: improveToast });
            }
        } catch (error) {
            console.error('Failed to improve email:', error);
            toast.error('Internal Server Error', { id: improveToast });
        } finally {
            setImproving(false);
        }
    };

    const handleStartOver = () => {
        setBody('');
        setSubject('');
        setInstructions('');
        setRefineInstructions('');
        setAiShowResult(false);
        setMode('ai');
    };

    const handleCopyToClipboard = () => {
        const plainBody = body.replace(/<[^>]*>?/gm, '');
        const emailText = `Subject: ${subject}\n\n${plainBody}`;
        navigator.clipboard.writeText(emailText);
        toast.success('Email copied to clipboard!');
    };

    const handleSend = async () => {
        toast.info('Email sending not implemented. Use "Copy Draft" instead.');
    };

    const isWorkspaceActive = body.length > 0 || aiShowResult;

    return (
        <Modal isOpen={isOpen} onClose={onClose} title="Compose Email" size="xl">
            <div className="grid grid-cols-1 lg:grid-cols-5 gap-8 h-[600px]">
                {/* Left Column: Side Controls */}
                <div className="lg:col-span-2 flex flex-col space-y-6 border-r border-gray-100 pr-8">
                    {/* Mode Selector */}
                    <div className="flex p-1 bg-gray-100 rounded-xl shrink-0">
                        <button
                            onClick={() => setMode('ai')}
                            className={cn(
                                "flex-1 flex items-center justify-center gap-2 py-2 text-xs font-bold rounded-lg transition-all",
                                mode === 'ai' ? "bg-white shadow-sm text-indigo-600" : "text-gray-500 hover:text-gray-700"
                            )}
                        >
                            <Sparkles className="h-3.5 w-3.5" />
                            AI Assistant
                        </button>
                        <button
                            onClick={() => setMode('manual')}
                            className={cn(
                                "flex-1 flex items-center justify-center gap-2 py-2 text-xs font-bold rounded-lg transition-all",
                                mode === 'manual' ? "bg-white shadow-sm text-indigo-600" : "text-gray-500 hover:text-gray-700"
                            )}
                        >
                            <Edit3 className="h-3.5 w-3.5" />
                            Manual Draft
                        </button>
                    </div>

                    <div className="space-y-4 shrink-0 px-1">
                        <h4 className="text-[10px] font-bold text-gray-400 uppercase tracking-widest">Recipient</h4>
                        <div className="bg-gray-50 p-3 rounded-xl border border-gray-100 italic text-[11px] text-gray-500 truncate">
                            {contact.first_name} {contact.last_name || ''} &lt;{contact.email}&gt;
                        </div>
                    </div>

                    {/* AI Refinement Tool - Only shown when there's content */}
                    {isWorkspaceActive && (
                        <div className="flex-1 flex flex-col justify-end gap-6 overflow-hidden animate-in fade-in slide-in-from-top-2 duration-300">
                            <div className="bg-indigo-50/50 p-5 rounded-2xl border border-indigo-100/50 space-y-3 shadow-sm">
                                <label className="text-[10px] font-bold text-indigo-900/40 uppercase tracking-widest block font-sans">
                                    Refine with AI
                                </label>
                                <textarea
                                    className="w-full min-h-[80px] text-xs bg-white border border-indigo-100 focus:border-indigo-400 focus:ring-4 focus:ring-indigo-400/5 rounded-xl shadow-sm p-3 outline-none transition-all leading-relaxed resize-none"
                                    value={refineInstructions}
                                    onChange={(e) => setRefineInstructions(e.target.value)}
                                    placeholder="e.g. 'Make it more professional'..."
                                />
                                <Button
                                    onClick={handleImproveDraft}
                                    disabled={improving || !refineInstructions.trim()}
                                    className="w-full bg-indigo-600 hover:bg-indigo-700 text-white shadow-lg h-10 font-bold"
                                >
                                    {improving ? (
                                        <Loader2 className="h-4 w-4 animate-spin" />
                                    ) : (
                                        <>
                                            <Wand2 className="mr-2 h-4 w-4" />
                                            Update Message
                                        </>
                                    )}
                                </Button>
                            </div>

                            <Button
                                onClick={handleStartOver}
                                variant="outline"
                                className="w-full text-[10px] text-gray-400 border-gray-100 hover:bg-red-50 hover:text-red-500 hover:border-red-100 transition-all uppercase tracking-[0.2em] font-bold h-10"
                            >
                                <RotateCcw className="mr-2 h-3 w-3" />
                                Clear Workspace
                            </Button>
                        </div>
                    )}
                </div>

                {/* Right Column: Main Editor Workspace */}
                <div className="lg:col-span-3 flex flex-col h-full bg-stone-50/30 rounded-2xl border border-stone-100 overflow-hidden relative">

                    {mode === 'ai' && !aiShowResult ? (
                        /* AI PROMPTING VIEW */
                        <div className="flex flex-col h-full animate-in fade-in duration-300">
                            <div className="px-6 py-4 border-b border-stone-100 bg-white shrink-0">
                                <h3 className="text-[10px] font-bold text-stone-400 uppercase tracking-widest leading-none">
                                    Drafting Instructions
                                </h3>
                            </div>

                            <textarea
                                className="flex-1 resize-none font-sans text-sm text-stone-800 leading-relaxed p-8 border-none bg-transparent outline-none focus:ring-0"
                                value={instructions}
                                onChange={(e) => setInstructions(e.target.value)}
                                placeholder="What should the email say? e.g. 'Met at the exhibit, discussed security, invite for a demo...'"
                                autoFocus
                            />

                            <div className="p-6 bg-white border-t border-stone-100 shrink-0">
                                <Button
                                    onClick={handleGenerateDraft}
                                    disabled={generating || !instructions.trim()}
                                    className="w-full h-12 bg-indigo-600 hover:bg-indigo-700 text-white font-bold text-base shadow-lg rounded-xl transition-all active:scale-[0.98]"
                                >
                                    {generating ? (
                                        <>
                                            <Loader2 className="mr-2 h-5 w-5 animate-spin" />
                                            AI is Drafting...
                                        </>
                                    ) : (
                                        <>
                                            <Sparkles className="mr-2 h-5 w-5" />
                                            Generate Email
                                        </>
                                    )}
                                </Button>
                            </div>
                        </div>
                    ) : (
                        /* EMAIL EDITOR VIEW (Manual or AI Result) */
                        <div className="flex flex-col h-full animate-in fade-in duration-300">
                            {/* Embedded Subject Line */}
                            <div className="px-8 py-5 border-b border-stone-100 flex items-center gap-4 bg-white shrink-0">
                                <span className="text-[10px] font-black text-stone-300 uppercase tracking-widest w-14 shrink-0">Subject</span>
                                <input
                                    className="flex-1 text-sm font-bold text-stone-800 placeholder-stone-200 border-none bg-transparent focus:outline-none focus:ring-0 p-0"
                                    value={subject}
                                    onChange={(e) => setSubject(e.target.value)}
                                    placeholder="Enter subject..."
                                />
                            </div>

                            {/* Full Email Body - Rich Text */}
                            <div className="flex-1 overflow-hidden flex flex-col pt-2">
                                <RichTextEditor
                                    value={body}
                                    onChange={setBody}
                                    placeholder="Start writing your email..."
                                    className="flex-1 border-none rounded-none"
                                />
                            </div>

                            {/* Footer Actions */}
                            <div className="flex gap-4 p-5 border-t border-stone-100 bg-white shrink-0">
                                <Button
                                    onClick={handleCopyToClipboard}
                                    variant="outline"
                                    className="flex-1 h-11 border-stone-200 hover:bg-stone-50 text-stone-500 font-bold text-xs"
                                >
                                    <Copy className="mr-2 h-4 w-4 text-stone-300" />
                                    Copy Draft
                                </Button>
                                <Button
                                    onClick={handleSend}
                                    className="flex-[2] h-11 bg-indigo-600 hover:bg-indigo-700 shadow-lg font-bold"
                                >
                                    <Send className="mr-2 h-4 w-4" />
                                    Send Email
                                </Button>
                            </div>
                        </div>
                    )}
                </div>
            </div>
        </Modal>
    );
}
