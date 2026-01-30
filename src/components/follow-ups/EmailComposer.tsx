'use client';

import { useState } from 'react';
import { Modal } from '@/components/ui/Modal';
import { Button } from '@/components/ui/Button';
import { Input } from '@/components/ui/Input';
import { Textarea } from '@/components/ui/Textarea';
import { ConfidenceScore } from '@/components/ui/ConfidenceScore';
import { Sparkles, Copy, Send, Loader2 } from 'lucide-react';

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

import { toast } from 'sonner';

export function EmailComposer({ isOpen, onClose, contact, event }: EmailComposerProps) {
    const [subject, setSubject] = useState('');
    const [body, setBody] = useState('');
    const [generating, setGenerating] = useState(false);
    const [confidence, setConfidence] = useState<number | null>(null);

    const handleGenerateDraft = async () => {
        setGenerating(true);
        const draftToast = toast.loading('Generating AI draft...');
        try {
            const response = await fetch('/api/emails/draft', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    contact_id: contact.id,
                    event_id: event?.id,
                    email_type: 'follow_up'
                })
            });

            const data = await response.json();
            if (data.data) {
                setSubject(data.data.subject);
                setBody(data.data.body);
                setConfidence(data.data.confidence || 0.85);
                toast.success('Draft generated!', { id: draftToast });
            } else {
                toast.error('Failed to generate draft', { id: draftToast });
            }
        } catch (error) {
            console.error('Failed to generate draft:', error);
            toast.error('Failed to generate draft', { id: draftToast });
        } finally {
            setGenerating(false);
        }
    };

    const handleCopyToClipboard = () => {
        const emailText = `Subject: ${subject}\n\n${body}`;
        navigator.clipboard.writeText(emailText);
        toast.success('Email copied to clipboard!');
    };

    const handleSend = async () => {
        // In production, implement actual email sending
        toast.info('Email sending not implemented. Use "Copy to Clipboard" instead.');
    };

    return (
        <Modal isOpen={isOpen} onClose={onClose} title="Compose Email" size="lg">
            <div className="space-y-4">
                {/* Recipient */}
                <div>
                    <label className="text-sm font-medium text-gray-700 mb-1 block">
                        To
                    </label>
                    <Input
                        value={`${contact.first_name} ${contact.last_name || ''} <${contact.email}>`}
                        disabled
                    />
                </div>

                {/* Subject */}
                <div>
                    <label className="text-sm font-medium text-gray-700 mb-1 block">
                        Subject
                    </label>
                    <Input
                        value={subject}
                        onChange={(e) => setSubject(e.target.value)}
                        placeholder="Email subject..."
                    />
                </div>

                {/* Body */}
                <div>
                    <label className="text-sm font-medium text-gray-700 mb-1 block">
                        Message
                    </label>
                    <Textarea
                        className="min-h-[200px]"
                        value={body}
                        onChange={(e) => setBody(e.target.value)}
                        placeholder="Email body..."
                    />
                </div>

                {/* AI Confidence */}
                {confidence !== null && (
                    <div className="bg-purple-50 rounded-lg p-3">
                        <p className="text-sm font-medium text-gray-700 mb-2">
                            AI Draft Quality
                        </p>
                        <ConfidenceScore confidence={confidence} />
                    </div>
                )}

                {/* Actions */}
                <div className="flex gap-3">
                    <Button
                        onClick={handleGenerateDraft}
                        disabled={generating}
                        variant="outline"
                        className="flex-1"
                    >
                        {generating ? (
                            <>
                                <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                                Generating...
                            </>
                        ) : (
                            <>
                                <Sparkles className="mr-2 h-4 w-4" />
                                Generate Draft
                            </>
                        )}
                    </Button>
                </div>

                <div className="flex gap-3 pt-2 border-t">
                    <Button
                        onClick={handleCopyToClipboard}
                        variant="outline"
                        disabled={!subject || !body}
                    >
                        <Copy className="mr-2 h-4 w-4" />
                        Copy to Clipboard
                    </Button>
                    <Button
                        onClick={handleSend}
                        disabled={!subject || !body}
                        className="flex-1"
                    >
                        <Send className="mr-2 h-4 w-4" />
                        Send Email
                    </Button>
                </div>
            </div>
        </Modal>
    );
}
