'use client';

import { useState, useEffect } from 'react';
import { generateEmailDraftAction, saveEmailDraftAction } from '@/app/actions/preparation';
import { Loader2, Send, Save, Wand2, Paperclip, FileText } from 'lucide-react';
import { getAssets, MarketingAsset } from '@/app/actions/assets';

import { toast } from 'sonner';

export default function EmailDrafter({ targets, eventId }: { targets: any[], eventId: string }) {
    const [selectedTargetId, setSelectedTargetId] = useState<string>('');
    const [contactName, setContactName] = useState('');
    const [emailType, setEmailType] = useState('pre_event');
    const [generatedDraft, setGeneratedDraft] = useState<{ subject: string, body: string } | null>(null);
    const [isGenerating, setIsGenerating] = useState(false);
    const [isSaving, setIsSaving] = useState(false);

    // Assets state
    const [availableAssets, setAvailableAssets] = useState<MarketingAsset[]>([]);
    const [selectedAssetIds, setSelectedAssetIds] = useState<string[]>([]);

    useEffect(() => {
        // Fetch assets
        getAssets().then(setAvailableAssets);
    }, []);

    const selectedTarget = targets.find(t => t.id === selectedTargetId);

    const toggleAsset = (id: string) => {
        if (selectedAssetIds.includes(id)) {
            setSelectedAssetIds(selectedAssetIds.filter(a => a !== id));
        } else {
            setSelectedAssetIds([...selectedAssetIds, id]);
        }
    };

    const handleGenerate = async () => {
        if (!selectedTarget) return;
        setIsGenerating(true);
        const genToast = toast.loading('Drafting email with AI...');

        const selectedAssetNames = availableAssets
            .filter(a => selectedAssetIds.includes(a.id))
            .map(a => a.name);

        const data = {
            type: emailType,
            contact: {
                first_name: contactName.split(' ')[0],
                last_name: contactName.split(' ').slice(1).join(' '),
                company: { name: selectedTarget.company.name }
            },
            event: { name: 'the Exhibition' }, // Ideally fetch real event name
            context: `Background: ${selectedTarget.company.description}. \nTalking Points: ${selectedTarget.talking_points || 'None'}`,
            attachments: selectedAssetNames
        };

        const response = await generateEmailDraftAction(data);
        if (response.result) {
            setGeneratedDraft(response.result);
            toast.success('Draft generated!', { id: genToast });
        } else {
            toast.error('Failed to generate draft', { id: genToast });
        }
        setIsGenerating(false);
    };

    const handleSave = async () => {
        if (!generatedDraft || !selectedTarget) return;
        setIsSaving(true);
        const savingToast = toast.loading('Saving draft...');

        const response = await saveEmailDraftAction({
            companyId: selectedTarget.company.id,
            eventId: eventId,
            contactName, // Will create contact if needed
            type: emailType,
            subject: generatedDraft.subject,
            body: generatedDraft.body
        });

        if (response.success) {
            toast.success('Draft saved successfully!', { id: savingToast });
            setGeneratedDraft(null);
            setContactName('');
            setSelectedTargetId('');
            setSelectedAssetIds([]);
        } else {
            toast.error('Failed to save draft', { id: savingToast });
        }
        setIsSaving(false);
    };

    return (
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
            <div className="lg:col-span-1 space-y-6">
                <div className="bg-white p-6 rounded-xl shadow-sm border border-gray-200">
                    <h3 className="font-semibold mb-4">1. Select Recipient</h3>
                    <div className="space-y-4">
                        <div>
                            <label className="block text-sm font-medium text-gray-700 mb-1">Target Company</label>
                            <select
                                className="w-full border-gray-300 rounded-lg shadow-sm focus:ring-blue-500 focus:border-blue-500"
                                value={selectedTargetId}
                                onChange={(e) => setSelectedTargetId(e.target.value)}
                            >
                                <option value="">Select a company...</option>
                                {targets.map(t => (
                                    <option key={t.id} value={t.id}>{t.company.name}</option>
                                ))}
                            </select>
                        </div>

                        <div>
                            <label className="block text-sm font-medium text-gray-700 mb-1">Contact Name</label>
                            <input
                                type="text"
                                className="w-full border-gray-300 rounded-lg shadow-sm focus:ring-blue-500 focus:border-blue-500"
                                placeholder="e.g. John Doe"
                                value={contactName}
                                onChange={(e) => setContactName(e.target.value)}
                            />
                        </div>

                        <div>
                            <label className="block text-sm font-medium text-gray-700 mb-1">Email Type</label>
                            <select
                                className="w-full border-gray-300 rounded-lg shadow-sm focus:ring-blue-500 focus:border-blue-500"
                                value={emailType}
                                onChange={(e) => setEmailType(e.target.value)}
                            >
                                <option value="pre_event">Pre-Event Intro</option>
                                <option value="follow_up">Post-Event Follow-up</option>
                                <option value="pre_meeting">Meeting Confirmation</option>
                            </select>
                        </div>

                        {/* Attachments Section */}
                        {availableAssets.length > 0 && (
                            <div>
                                <label className="block text-sm font-medium text-gray-700 mb-2 flex items-center gap-2">
                                    <Paperclip className="h-4 w-4" />
                                    Attachments
                                </label>
                                <div className="space-y-2 max-h-40 overflow-y-auto border border-gray-200 rounded-lg p-2 bg-gray-50">
                                    {availableAssets.map(asset => (
                                        <div
                                            key={asset.id}
                                            className={`
                                                flex items-center gap-2 p-2 rounded cursor-pointer border transition-colors
                                                ${selectedAssetIds.includes(asset.id)
                                                    ? 'bg-blue-50 border-blue-200'
                                                    : 'bg-white border-transparent hover:bg-gray-100'}
                                            `}
                                            onClick={() => toggleAsset(asset.id)}
                                        >
                                            <div className={`
                                                w-4 h-4 rounded border flex items-center justify-center
                                                ${selectedAssetIds.includes(asset.id) ? 'bg-blue-600 border-blue-600' : 'border-gray-400'}
                                            `}>
                                                {selectedAssetIds.includes(asset.id) && <FileText className="h-3 w-3 text-white" />}
                                            </div>
                                            <span className="text-sm truncate">{asset.name}</span>
                                        </div>
                                    ))}
                                </div>
                            </div>
                        )}

                        <button
                            onClick={handleGenerate}
                            disabled={!selectedTargetId || !contactName || isGenerating}
                            className="w-full bg-blue-600 text-white py-2 px-4 rounded-lg font-medium hover:bg-blue-700 disabled:opacity-50 flex justify-center items-center gap-2"
                        >
                            {isGenerating ? <Loader2 className="h-4 w-4 animate-spin" /> : <Wand2 className="h-4 w-4" />}
                            Generate Draft
                        </button>
                    </div>
                </div>
            </div>

            <div className="lg:col-span-2">
                {generatedDraft ? (
                    <div className="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden h-full flex flex-col">
                        <div className="p-4 border-b border-gray-200 bg-gray-50 flex justify-between items-center">
                            <h3 className="font-semibold text-gray-700">Draft Preview</h3>
                            <button
                                onClick={handleSave}
                                disabled={isSaving}
                                className="text-sm bg-green-600 text-white px-3 py-1.5 rounded-lg hover:bg-green-700 flex items-center gap-2 disabled:opacity-50"
                            >
                                {isSaving ? <Loader2 className="h-3 w-3 animate-spin" /> : <Save className="h-3 w-3" />}
                                Save Draft
                            </button>
                        </div>
                        <div className="p-6 space-y-4 flex-1">
                            <div>
                                <label className="block text-xs font-semibold text-gray-500 uppercase tracking-wider mb-1">Subject</label>
                                <input
                                    type="text"
                                    className="w-full border-gray-300 rounded-lg bg-gray-50"
                                    value={generatedDraft.subject}
                                    onChange={(e) => setGeneratedDraft({ ...generatedDraft, subject: e.target.value })}
                                />
                            </div>
                            <div className="h-full">
                                <label className="block text-xs font-semibold text-gray-500 uppercase tracking-wider mb-1">Body</label>
                                <textarea
                                    className="w-full h-[400px] border-gray-300 rounded-lg bg-gray-50 font-mono text-sm p-4"
                                    value={generatedDraft.body}
                                    onChange={(e) => setGeneratedDraft({ ...generatedDraft, body: e.target.value })}
                                />
                            </div>

                            {/* Selected Attachments Preview */}
                            {selectedAssetIds.length > 0 && (
                                <div className="mt-4 pt-4 border-t border-gray-100">
                                    <span className="text-xs font-semibold text-gray-500 uppercase tracking-wider block mb-2">Attachments</span>
                                    <div className="flex gap-2 flex-wrap">
                                        {availableAssets.filter(a => selectedAssetIds.includes(a.id)).map(asset => (
                                            <div key={asset.id} className="inline-flex items-center gap-1 px-2 py-1 bg-gray-100 rounded text-xs text-gray-700">
                                                <Paperclip className="h-3 w-3" />
                                                {asset.name}
                                            </div>
                                        ))}
                                    </div>
                                </div>
                            )}
                        </div>
                    </div>
                ) : (
                    <div className="h-full flex flex-col items-center justify-center text-gray-400 border-2 border-dashed border-gray-200 rounded-xl p-12">
                        <Wand2 className="h-12 w-12 mb-4 opacity-50" />
                        <p>Select a target and click "Generate Draft" to start.</p>
                    </div>
                )}
            </div>
        </div>
    );
}
