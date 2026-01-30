'use client';

import { useState } from 'react';
import { Input } from '@/components/ui/Input';
import { Button } from '@/components/ui/Button';
import { ConfidenceScore } from '@/components/ui/ConfidenceScore';
import { Check, X, RefreshCw, Sparkles } from 'lucide-react';

interface ExtractedField {
    value: string;
    confidence: number;
}

interface OCRPreviewProps {
    imageUrl: string;
    extractedData: {
        name?: ExtractedField;
        email?: ExtractedField;
        phone?: ExtractedField;
        company?: ExtractedField;
        jobTitle?: ExtractedField;
    };
    onAccept: (data: any) => void;
    onRetry: () => void;
    onCancel: () => void;
    isEnriching?: boolean;
}

export function OCRPreview({
    imageUrl,
    extractedData,
    onAccept,
    onRetry,
    onCancel,
    isEnriching = false
}: OCRPreviewProps) {
    const [formData, setFormData] = useState({
        name: extractedData.name?.value || '',
        email: extractedData.email?.value || '',
        phone: extractedData.phone?.value || '',
        company: extractedData.company?.value || '',
        jobTitle: extractedData.jobTitle?.value || ''
    });

    const handleSubmit = (e: React.FormEvent) => {
        e.preventDefault();
        onAccept(formData);
    };

    return (
        <div className="bg-white rounded-lg border border-gray-200 overflow-hidden">
            {/* Header */}
            <div className="bg-gradient-to-r from-blue-50 to-purple-50 p-4 border-b border-gray-200">
                <div className="flex items-center justify-between">
                    <div className="flex items-center gap-2">
                        <Sparkles className="h-5 w-5 text-blue-600" />
                        <h3 className="font-semibold text-gray-900">OCR Extraction Results</h3>
                    </div>
                    {isEnriching && (
                        <span className="text-sm text-blue-600 animate-pulse">
                            Enriching...
                        </span>
                    )}
                </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-6 p-6">
                {/* Left: Image Preview */}
                <div>
                    <h4 className="text-sm font-semibold text-gray-700 mb-3">Captured Image</h4>
                    <img
                        src={imageUrl}
                        alt="Business card"
                        className="w-full rounded-lg border border-gray-300 shadow-sm"
                    />
                </div>

                {/* Right: Extracted Fields */}
                <div>
                    <h4 className="text-sm font-semibold text-gray-700 mb-3">Extracted Information</h4>
                    <form onSubmit={handleSubmit} className="space-y-4">
                        {/* Name */}
                        <div>
                            <label className="text-xs font-medium text-gray-700 mb-1 block">
                                Name
                            </label>
                            <Input
                                value={formData.name}
                                onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                                placeholder="Full name"
                            />
                            {extractedData.name && (
                                <div className="mt-1">
                                    <ConfidenceScore
                                        confidence={extractedData.name.confidence}
                                        size="sm"
                                    />
                                </div>
                            )}
                        </div>

                        {/* Email */}
                        <div>
                            <label className="text-xs font-medium text-gray-700 mb-1 block">
                                Email
                            </label>
                            <Input
                                type="email"
                                value={formData.email}
                                onChange={(e) => setFormData({ ...formData, email: e.target.value })}
                                placeholder="email@example.com"
                            />
                            {extractedData.email && (
                                <div className="mt-1">
                                    <ConfidenceScore
                                        confidence={extractedData.email.confidence}
                                        size="sm"
                                    />
                                </div>
                            )}
                        </div>

                        {/* Phone */}
                        <div>
                            <label className="text-xs font-medium text-gray-700 mb-1 block">
                                Phone
                            </label>
                            <Input
                                type="tel"
                                value={formData.phone}
                                onChange={(e) => setFormData({ ...formData, phone: e.target.value })}
                                placeholder="+1-555-0100"
                            />
                            {extractedData.phone && (
                                <div className="mt-1">
                                    <ConfidenceScore
                                        confidence={extractedData.phone.confidence}
                                        size="sm"
                                    />
                                </div>
                            )}
                        </div>

                        {/* Company */}
                        <div>
                            <label className="text-xs font-medium text-gray-700 mb-1 block">
                                Company
                            </label>
                            <Input
                                value={formData.company}
                                onChange={(e) => setFormData({ ...formData, company: e.target.value })}
                                placeholder="Company name"
                            />
                            {extractedData.company && (
                                <div className="mt-1">
                                    <ConfidenceScore
                                        confidence={extractedData.company.confidence}
                                        size="sm"
                                    />
                                </div>
                            )}
                        </div>

                        {/* Job Title */}
                        <div>
                            <label className="text-xs font-medium text-gray-700 mb-1 block">
                                Job Title
                            </label>
                            <Input
                                value={formData.jobTitle}
                                onChange={(e) => setFormData({ ...formData, jobTitle: e.target.value })}
                                placeholder="Position"
                            />
                            {extractedData.jobTitle && (
                                <div className="mt-1">
                                    <ConfidenceScore
                                        confidence={extractedData.jobTitle.confidence}
                                        size="sm"
                                    />
                                </div>
                            )}
                        </div>

                        {/* Actions */}
                        <div className="flex gap-2 pt-4">
                            <Button type="submit" className="flex-1">
                                <Check className="mr-2 h-4 w-4" />
                                Accept
                            </Button>
                            <Button type="button" variant="outline" onClick={onRetry}>
                                <RefreshCw className="h-4 w-4" />
                            </Button>
                            <Button type="button" variant="ghost" onClick={onCancel}>
                                <X className="h-4 w-4" />
                            </Button>
                        </div>
                    </form>
                </div>
            </div>
        </div>
    );
}
