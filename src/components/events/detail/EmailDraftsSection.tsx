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
import { cn, formatLabel } from '@/lib/utils';

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
            toast.error('Internal Server Error');
        }
    };

    const handleCopyToClipboard = (subject: string, body: string) => {
        const text = `Subject: ${subject}\n\n${body}`;
        navigator.clipboard.writeText(text);
        toast.success('Copied to clipboard');
    };

    return (
        <div className="space-y-10">
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-10">
                {/* Drafts List */}
                <div className="order-2 lg:order-1">
                    <h3 className="text-[11px] font-black text-stone-900 uppercase tracking-widest mb-6 px-1">Recent Drafts</h3>
                    {loadingDrafts ? (
                        <div className="text-center py-20">
                            <Loader2 className="h-10 w-10 animate-spin text-stone-200 mx-auto" strokeWidth={1} />
                        </div>
                    ) : drafts.length === 0 ? (
                        <div className="text-center py-20 border border-dashed border-stone-100 rounded-[2.5rem] bg-stone-50/30">
                            <Mail className="h-10 w-10 text-stone-200 mx-auto mb-4" strokeWidth={1.5} />
                            <p className="text-[10px] font-black text-stone-400 uppercase tracking-widest leading-none">Nothing Drafted</p>
                        </div>
                    ) : (
                        <div className="space-y-5">
                            {drafts.map((draft) => (
                                <div key={draft.id} className="bg-white rounded-[2.5rem] p-6 border border-stone-100 shadow-sm group hover:border-stone-200 transition-all">
                                    <div className="flex items-start justify-between mb-6">
                                        <div className="flex items-center gap-4">
                                            <div className="h-11 w-11 rounded-xl bg-stone-900 flex items-center justify-center shadow-lg shadow-stone-900/10">
                                                <Mail className="h-5 w-5 text-white" strokeWidth={3} />
                                            </div>
                                            <div>
                                                <h4 className="text-sm font-black text-stone-900 tracking-tight">
                                                    {draft.company_name ||
                                                        draft.contact?.company?.name ||
                                                        draft.contacts?.companies?.name ||
                                                        'Company'}
                                                </h4>
                                                <p className="text-[9px] text-stone-400 font-black uppercase tracking-widest mt-1">
                                                    {formatLabel(draft.email_type || '')}
                                                </p>
                                            </div>
                                        </div>
                                        <div className="flex items-center gap-2">
                                            <Button
                                                variant="ghost"
                                                size="sm"
                                                className="h-9 w-9 p-0 text-stone-300 hover:text-stone-900 rounded-xl"
                                                onClick={() => handleDelete(draft.id)}
                                            >
                                                <Trash2 className="h-4 w-4" />
                                            </Button>
                                        </div>
                                    </div>

                                    <div className="bg-stone-50/50 rounded-2xl p-5 border border-stone-100 space-y-3 mb-6">
                                        <p className="text-[10px] font-black text-stone-400 uppercase tracking-widest">Subject: {draft.subject}</p>
                                        <p className="text-sm font-bold text-stone-600 leading-relaxed whitespace-pre-wrap">{draft.body}</p>
                                    </div>

                                    <div className="flex items-center justify-between">
                                        <p className="text-[10px] font-black text-stone-300 uppercase tracking-widest">
                                            {new Date(draft.created_at).toLocaleDateString([], { month: 'short', day: 'numeric' })}
                                        </p>
                                        <div className="flex items-center gap-2">
                                            <Button
                                                variant="outline"
                                                size="sm"
                                                className="h-9 px-4 text-[9px] font-black uppercase tracking-widest border-stone-200 text-stone-600 hover:text-stone-900 hover:bg-stone-50 rounded-xl transition-all"
                                                onClick={() => handleCopyToClipboard(draft.subject, draft.body)}
                                            >
                                                <Copy className="h-3.5 w-3.5 mr-2" strokeWidth={3} />
                                                Copy
                                            </Button>
                                            <Button
                                                size="sm"
                                                className="h-9 px-4 text-[9px] font-black uppercase tracking-widest bg-stone-900 text-white rounded-[2rem] shadow-xl shadow-stone-900/10 hover:bg-stone-800 transition-all"
                                                onClick={() => {
                                                    toast.info('Gmail integration coming soon!');
                                                }}
                                            >
                                                <ExternalLink className="h-3.5 w-3.5 mr-2" strokeWidth={3} />
                                                Open
                                            </Button>
                                        </div>
                                    </div>
                                </div>
                            ))}
                        </div>
                    )}
                </div>

                {/* Generator Card */}
                <div className="order-1 lg:order-2 bg-stone-50/50 rounded-[2.5rem] p-8 border border-stone-100 shadow-sm h-fit sticky top-0">
                    <div className="flex items-center gap-4 mb-8">
                        <div className="p-3 bg-stone-900 rounded-[2rem] shadow-xl shadow-stone-900/10">
                            <Sparkles className="h-5 w-5 text-white" strokeWidth={3} />
                        </div>
                        <div>
                            <h3 className="text-[11px] font-black text-stone-900 uppercase tracking-widest">AI Draft Assistant</h3>
                            <p className="text-[10px] font-bold text-stone-400 uppercase tracking-widest mt-1">Generate personalized outreach.</p>
                        </div>
                    </div>

                    <div className="space-y-6">
                        <div className="space-y-2">
                            <label className="text-[9px] font-black text-stone-400 uppercase tracking-widest ml-1">Target Company</label>
                            <select
                                value={selectedTargetId}
                                onChange={(e) => setSelectedTargetId(e.target.value)}
                                className="w-full h-12 px-4 rounded-xl border border-stone-200 bg-white text-sm font-bold focus:ring-0 focus:border-stone-900 transition-all outline-none"
                            >
                                <option value="">Select Target...</option>
                                {targets.map(t => (
                                    <option key={t.id} value={t.id}>{t.company?.name}</option>
                                ))}
                            </select>
                        </div>

                        <div className="space-y-2">
                            <label className="text-[9px] font-black text-stone-400 uppercase tracking-widest ml-1">Context Type</label>
                            <select
                                value={emailType}
                                onChange={(e) => setEmailType(e.target.value)}
                                className="w-full h-12 px-4 rounded-xl border border-stone-200 bg-white text-sm font-bold focus:ring-0 focus:border-stone-900 transition-all outline-none"
                            >
                                <option value="pre_event">Pre-Event Outreach</option>
                                <option value="follow_up">Post-Event Follow-up</option>
                                <option value="pre_meeting">Meeting Request</option>
                            </select>
                        </div>

                        <div className="space-y-2">
                            <label className="text-[9px] font-black text-stone-400 uppercase tracking-widest ml-1">Instructions (Optional)</label>
                            <Textarea
                                placeholder="e.g. Focus on cloud migration..."
                                value={customContext}
                                onChange={(e) => setCustomContext(e.target.value)}
                                className="min-h-[120px] p-4 text-sm font-bold rounded-xl border-stone-200 focus:border-stone-900 transition-all resize-none bg-white"
                            />
                        </div>

                        <Button
                            className="w-full h-12 bg-stone-900 hover:bg-stone-800 text-white font-black uppercase tracking-widest text-[10px] rounded-xl shadow-xl shadow-stone-900/10 active:scale-95 transition-all"
                            onClick={handleGenerate}
                            disabled={isGenerating || !selectedTargetId}
                        >
                            {isGenerating ? (
                                <Loader2 className="h-4 w-4 animate-spin mr-3" />
                            ) : (
                                <Sparkles className="h-4 w-4 mr-3" strokeWidth={3} />
                            )}
                            Generate Draft
                        </Button>
                    </div>
                </div>
            </div>
        </div>
    );
}
