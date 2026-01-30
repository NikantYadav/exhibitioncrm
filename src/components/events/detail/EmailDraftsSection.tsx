'use client';

import { useState, useEffect } from 'react';
import { Button } from '@/components/ui/Button';
import { Input } from '@/components/ui/Input';
import { Select } from '@/components/ui/Select';
import { Textarea } from '@/components/ui/Textarea';
import { Sparkles, Mail, Send, Copy, Loader2, Trash2, ExternalLink } from 'lucide-react';
import { toast } from 'sonner';
import { supabase } from '@/lib/supabase/client';
import { TargetCompany } from '@/types';

interface EmailDraftsSectionProps {
    eventId: string;
    targets: TargetCompany[];
}

export function EmailDraftsSection({ eventId, targets }: EmailDraftsSectionProps) {
    const [drafts, setDrafts] = useState<any[]>([]);
    const [loadingDrafts, setLoadingDrafts] = useState(true);
    const [isGenerating, setIsGenerating] = useState(false);

    // Form state
    const [selectedTargetId, setSelectedTargetId] = useState('');
    const [emailType, setEmailType] = useState('pre_event');
    const [customContext, setCustomContext] = useState('');

    useEffect(() => {
        fetchDrafts();
    }, [eventId]);

    const fetchDrafts = async () => {
        try {
            const res = await fetch(`/api/events/${eventId}/emails`);
            const data = await res.json();
            console.log('Fetched drafts:', data.data);
            setDrafts(data.data || []);
        } catch (error) {
            console.error('Failed to fetch drafts:', error);
        } finally {
            setLoadingDrafts(false);
        }
    };

    const handleGenerate = async () => {
        if (!selectedTargetId) {
            toast.error('Please select a target company');
            return;
        }

        const target = targets.find(t => t.id === selectedTargetId);
        if (!target || !target.company_id) {
            toast.error('Invalid target selection');
            return;
        }

        setIsGenerating(true);
        const genToast = toast.loading('AI is drafting your email...');

        try {
            // 1. Need a contact for the email draft endpoint
            // For MVP/Event Dashboard, we'll try to find an existing contact or use a placeholder
            const contactRes = await fetch(`/api/contacts?company_id=${target.company_id}`);

            if (!contactRes.ok) {
                const text = await contactRes.text();
                console.error('Contact fetch failed:', text);
                throw new Error('Failed to fetch contact for company');
            }

            const contactsData = await contactRes.json();
            const contacts = contactsData.data || [];

            let contactId = contacts[0]?.id;

            if (!contactId) {
                // Create a placeholder contact if none exists
                const createContactRes = await fetch(`/api/contacts`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        first_name: 'Contact',
                        last_name: 'Person',
                        company_id: target.company_id,
                        email: `hello@${target.company?.website || 'company.com'}`
                    })
                });

                if (!createContactRes.ok) throw new Error('Failed to create placeholder contact');

                const newContact = await createContactRes.json();
                contactId = newContact.data.id;
            }

            // 2. Clear current draft state if needed
            const response = await fetch('/api/emails/draft', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    contact_id: contactId,
                    event_id: eventId,
                    email_type: emailType,
                    custom_context: customContext
                })
            });

            if (!response.ok) throw new Error('Failed to generate draft');

            toast.success('AI Draft Generated!', { id: genToast });
            fetchDrafts(); // Refresh list
            setCustomContext('');
        } catch (error) {
            console.error('Generation error:', error);
            toast.error('Failed to generate draft', { id: genToast });
        } finally {
            setIsGenerating(true); // Wait, should be false
            setIsGenerating(false);
        }
    };

    const handleDelete = async (draftId: string) => {
        try {
            console.log('Deleting draft via API:', draftId);
            const res = await fetch(`/api/emails/drafts/${draftId}`, {
                method: 'DELETE',
                headers: { 'Content-Type': 'application/json' }
            });

            const result = await res.json();
            console.log('Delete API response:', result);

            if (!res.ok) {
                throw new Error(result.error || 'Failed to delete');
            }

            // Update UI
            setDrafts(drafts.filter(d => d.id !== draftId));
            toast.success('Draft deleted');
        } catch (error: any) {
            console.error('Delete error:', error);
            toast.error('Failed to delete draft: ' + (error.message || 'Unknown error'));
        }
    };

    const handleCopyToClipboard = (subject: string, body: string) => {
        const text = `Subject: ${subject}\n\n${body}`;
        navigator.clipboard.writeText(text);
        toast.success('Copied to clipboard');
    };

    return (
        <div className="space-y-8">
            {/* Generator Card */}
            <div className="premium-card p-6 border-blue-100 bg-blue-50/30">
                <div className="flex items-center gap-2 mb-4">
                    <div className="p-2 bg-blue-600 rounded-lg">
                        <Sparkles className="h-4 w-4 text-white" />
                    </div>
                    <div>
                        <h3 className="text-sm font-bold text-stone-900">AI Outreach Assistant</h3>
                        <p className="text-xs text-stone-500">Draft personalized emails using company research and talking points.</p>
                    </div>
                </div>

                <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
                    <div className="space-y-1.5">
                        <label className="text-xs font-bold text-stone-500 uppercase tracking-wider">Target Company</label>
                        <select
                            value={selectedTargetId}
                            onChange={(e) => setSelectedTargetId(e.target.value)}
                            className="w-full h-10 px-3 rounded-xl border border-stone-200 bg-white text-sm focus:ring-2 focus:ring-blue-500/20 outline-none transition-all"
                        >
                            <option value="">Select a company...</option>
                            {targets.map(t => (
                                <option key={t.id} value={t.id}>{t.company?.name}</option>
                            ))}
                        </select>
                    </div>
                    <div className="space-y-1.5">
                        <label className="text-xs font-bold text-stone-500 uppercase tracking-wider">Email Type</label>
                        <select
                            value={emailType}
                            onChange={(e) => setEmailType(e.target.value)}
                            className="w-full h-10 px-3 rounded-xl border border-stone-200 bg-white text-sm focus:ring-2 focus:ring-blue-500/20 outline-none transition-all"
                        >
                            <option value="pre_event">Pre-Event Outreach</option>
                            <option value="follow_up">Post-Event Follow-up</option>
                            <option value="pre_meeting">Meeting Request</option>
                        </select>
                    </div>
                </div>

                <div className="space-y-1.5 mb-6">
                    <label className="text-xs font-bold text-stone-500 uppercase tracking-wider">Custom Context (Optional)</label>
                    <Textarea
                        placeholder="e.g. Mention we met at the coffee stand, or focus on their recent AI product launch..."
                        value={customContext}
                        onChange={(e) => setCustomContext(e.target.value)}
                        className="min-h-[80px] text-sm"
                    />
                </div>

                <Button
                    className="w-full bg-blue-600 hover:bg-blue-700 shadow-lg shadow-blue-200"
                    onClick={handleGenerate}
                    disabled={isGenerating || !selectedTargetId}
                >
                    {isGenerating ? (
                        <Loader2 className="h-4 w-4 animate-spin mr-2" />
                    ) : (
                        <Sparkles className="h-4 w-4 mr-2" />
                    )}
                    Generate personalized draft
                </Button>
            </div>

            {/* Drafts List */}
            <div className="space-y-4">
                <h3 className="text-xs font-bold text-stone-400 uppercase tracking-widest flex items-center gap-2 px-1">
                    <Mail className="h-3.5 w-3.5" />
                    Generated Drafts
                </h3>

                {loadingDrafts ? (
                    <div className="text-center py-12">
                        <Loader2 className="h-8 w-8 animate-spin text-stone-200 mx-auto" />
                    </div>
                ) : drafts.length === 0 ? (
                    <div className="text-center py-12 border-2 border-dashed border-stone-100 rounded-2xl">
                        <p className="text-sm text-stone-400">No drafts generated for this event yet.</p>
                    </div>
                ) : (
                    <div className="space-y-4">
                        {drafts.map((draft) => (
                            <div key={draft.id} className="premium-card p-5 group transition-all hover:border-blue-200">
                                <div className="flex items-start justify-between mb-3">
                                    <div className="flex items-center gap-3">
                                        <div className="h-8 w-8 rounded-lg bg-stone-100 flex items-center justify-center">
                                            <Mail className="h-4 w-4 text-stone-500" />
                                        </div>
                                        <div>
                                            <h4 className="text-sm font-bold text-stone-900">
                                                {draft.company_name ||
                                                    draft.contact?.company?.name ||
                                                    draft.contacts?.companies?.name ||
                                                    'Company'}
                                            </h4>
                                            <p className="text-[10px] text-stone-400 font-medium uppercase tracking-wider">
                                                {draft.email_type?.replace('_', ' ')}
                                            </p>
                                        </div>
                                    </div>
                                    <div className="flex items-center gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                                        <Button
                                            variant="ghost"
                                            size="sm"
                                            className="h-8 w-8 p-0 text-stone-400 hover:text-red-600"
                                            onClick={() => handleDelete(draft.id)}
                                        >
                                            <Trash2 className="h-4 w-4" />
                                        </Button>
                                    </div>
                                </div>

                                <div className="bg-stone-50 rounded-xl p-4 border border-stone-100 space-y-2 mb-4">
                                    <p className="text-sm font-bold text-stone-700">Subject: {draft.subject}</p>
                                    <p className="text-sm text-stone-600 leading-relaxed whitespace-pre-wrap">{draft.body}</p>
                                </div>

                                <div className="flex items-center justify-between">
                                    <p className="text-[10px] text-stone-400">Created {new Date(draft.created_at).toLocaleDateString()}</p>
                                    <div className="flex items-center gap-2">
                                        <Button
                                            variant="outline"
                                            size="sm"
                                            className="h-8 text-xs font-medium border-stone-200"
                                            onClick={() => handleCopyToClipboard(draft.subject, draft.body)}
                                        >
                                            <Copy className="h-3.5 w-3.5 mr-1.5" />
                                            Copy
                                        </Button>
                                        <Button
                                            size="sm"
                                            className="h-8 text-xs font-medium bg-stone-900 border-stone-200"
                                            onClick={() => {
                                                toast.info('Gmail integration coming soon!');
                                            }}
                                        >
                                            <Send className="h-3.5 w-3.5 mr-1.5" />
                                            Open in Gmail
                                        </Button>
                                    </div>
                                </div>
                            </div>
                        ))}
                    </div>
                )}
            </div>
        </div>
    );
}
