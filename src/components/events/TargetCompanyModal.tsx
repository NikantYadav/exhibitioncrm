'use client';

import { useState, useEffect } from 'react';
import { Modal } from '@/components/ui/Modal';
import { Input } from '@/components/ui/Input';
import { Textarea } from '@/components/ui/Textarea';
import { Select } from '@/components/ui/Select';
import { Button } from '@/components/ui/Button';
import { TargetCompany, Company } from '@/types';
import { Sparkles, Loader2 } from 'lucide-react';
import { generateTalkingPointsAction } from '@/app/actions/preparation';
import { toast } from 'sonner';

interface TargetCompanyModalProps {
    isOpen: boolean;
    onClose: () => void;
    onSave: (data: any) => void;
    target?: TargetCompany;
    company?: Company | null;
}

export function TargetCompanyModal({ isOpen, onClose, onSave, target, company }: TargetCompanyModalProps) {
    const [formData, setFormData] = useState({
        priority: (target?.priority || 'medium') as 'low' | 'medium' | 'high',
        booth_location: target?.booth_location || '',
        talking_points: target?.talking_points || '',
        notes: target?.notes || ''
    });
    const [isGenerating, setIsGenerating] = useState(false);

    // Reset/Sync form data when modal opens or target changes
    useEffect(() => {
        if (isOpen) {
            setFormData({
                priority: (target?.priority || 'medium') as 'low' | 'medium' | 'high',
                booth_location: target?.booth_location || '',
                talking_points: target?.talking_points || '',
                notes: target?.notes || ''
            });
        }
    }, [isOpen, target]);

    const handleSubmit = (e: React.FormEvent) => {
        e.preventDefault();
        onSave(formData);
    };

    const handleGenerateTalkingPoints = async () => {
        if (!company) return;

        setIsGenerating(true);
        try {
            const result = await generateTalkingPointsAction(company);
            if (result.error) {
                toast.error(result.error);
            } else if (result.points) {
                const pointsText = result.points.map((p: string) => `- ${p}`).join('\n');
                setFormData(prev => ({
                    ...prev,
                    talking_points: prev.talking_points
                        ? prev.talking_points + '\n\nAI Suggested:\n' + pointsText
                        : pointsText
                }));
                toast.success('Generated AI talking points');
            }
        } catch (error) {
            console.error('Points generation failed:', error);
            toast.error('Failed to generate talking points');
        } finally {
            setIsGenerating(false);
        }
    };

    const companyName = company?.name || target?.company?.name || 'Company';

    return (
        <Modal
            isOpen={isOpen}
            onClose={onClose}
            title={target ? 'Edit Target Company' : `Add ${companyName} as Target`}
            size="lg"
        >
            <form onSubmit={handleSubmit}>
                <div className="space-y-4">
                    <Select
                        label="Priority"
                        value={formData.priority}
                        onChange={(e) => setFormData({ ...formData, priority: e.target.value as 'low' | 'medium' | 'high' })}
                    >
                        <option value="low">Low</option>
                        <option value="medium">Medium</option>
                        <option value="high">High</option>
                    </Select>

                    <Input
                        label="Booth Location"
                        value={formData.booth_location}
                        onChange={(e) => setFormData({ ...formData, booth_location: e.target.value })}
                        placeholder="Hall A, Booth 123"
                    />

                    <div className="space-y-2">
                        <div className="flex items-center justify-between">
                            <label className="text-sm font-medium text-gray-700">Talking Points</label>
                            <Button
                                type="button"
                                variant="ghost"
                                size="sm"
                                className="text-indigo-600 hover:text-indigo-700 h-8 gap-1.5"
                                onClick={handleGenerateTalkingPoints}
                                disabled={isGenerating || !company}
                            >
                                {isGenerating ? (
                                    <Loader2 className="h-3.5 w-3.5 animate-spin" />
                                ) : (
                                    <Sparkles className="h-3.5 w-3.5" />
                                )}
                                Generate with AI
                            </Button>
                        </div>
                        <Textarea
                            value={formData.talking_points}
                            onChange={(e) => setFormData({ ...formData, talking_points: e.target.value })}
                            placeholder="Key topics to discuss, products to mention, etc. AI can help you with synergy points based on your profile and company research."
                            className="text-sm min-h-[120px]"
                        />
                    </div>

                    <Textarea
                        label="Notes"
                        rows={3}
                        value={formData.notes}
                        onChange={(e) => setFormData({ ...formData, notes: e.target.value })}
                        placeholder="Additional notes..."
                    />
                </div>

                <div className="flex gap-3 mt-6">
                    <Button type="button" variant="secondary" onClick={onClose}>
                        Cancel
                    </Button>
                    <Button type="submit" disabled={isGenerating}>
                        {target ? 'Update' : 'Add'} Target
                    </Button>
                </div>
            </form>
        </Modal>
    );
}
