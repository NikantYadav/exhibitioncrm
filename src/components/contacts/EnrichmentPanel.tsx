'use client';

import { useState } from 'react';
import { Button } from '@/components/ui/Button';
import { Input } from '@/components/ui/Input';
import { Sparkles, Check, X, Edit2, Loader2 } from 'lucide-react';

interface EnrichmentSuggestion {
    field: string;
    label: string;
    value: string;
    confidence: number;
    currentValue?: string;
}

interface EnrichmentPanelProps {
    suggestions: any;
    onAccept: (field: string, value: string) => void;
    onReject: (field: string) => void;
    onEdit: (field: string, value: string) => void;
}

export function EnrichmentPanel({ suggestions, onAccept, onReject, onEdit }: EnrichmentPanelProps) {
    const [editingField, setEditingField] = useState<string | null>(null);
    const [editValue, setEditValue] = useState('');

    if (!suggestions || Object.keys(suggestions).length === 0) {
        return null;
    }

    const fields: EnrichmentSuggestion[] = [
        { field: 'website', label: 'Website', value: suggestions.website, confidence: suggestions.confidence?.website || 0 },
        { field: 'industry', label: 'Industry', value: suggestions.industry, confidence: suggestions.confidence?.industry || 0 },
        { field: 'description', label: 'Description', value: suggestions.description, confidence: suggestions.confidence?.description || 0 },
        { field: 'location', label: 'Location', value: suggestions.location, confidence: suggestions.confidence?.location || 0 },
        { field: 'products_services', label: 'Products/Services', value: suggestions.products_services, confidence: suggestions.confidence?.products_services || 0 },
        { field: 'company_size', label: 'Company Size', value: suggestions.company_size, confidence: suggestions.confidence?.company_size || 0 },
        { field: 'linkedin_url', label: 'LinkedIn', value: suggestions.linkedin_url, confidence: suggestions.confidence?.linkedin_url || 0 },
    ].filter(f => f.value);

    const handleEdit = (field: string, currentValue: string) => {
        setEditingField(field);
        setEditValue(currentValue);
    };

    const handleSaveEdit = (field: string) => {
        onEdit(field, editValue);
        setEditingField(null);
        setEditValue('');
    };

    const getConfidenceBadge = (confidence: number) => {
        if (confidence >= 0.8) return <span className="text-xs px-2 py-0.5 rounded-full bg-green-100 text-green-700">High Confidence</span>;
        if (confidence >= 0.6) return <span className="text-xs px-2 py-0.5 rounded-full bg-yellow-100 text-yellow-700">Medium Confidence</span>;
        return <span className="text-xs px-2 py-0.5 rounded-full bg-orange-100 text-orange-700">Low Confidence</span>;
    };

    return (
        <div className="bg-gradient-to-r from-purple-50 to-indigo-50 rounded-lg p-6 border border-indigo-100">
            <div className="flex items-center gap-2 mb-4">
                <Sparkles className="h-5 w-5 text-purple-600" />
                <h3 className="font-semibold text-gray-900">AI Enrichment Suggestions</h3>
                <span className="text-xs text-gray-500 ml-auto">Estimated from public data</span>
            </div>

            <div className="space-y-3">
                {fields.map((suggestion) => (
                    <div key={suggestion.field} className="bg-white rounded-lg p-4 border border-gray-200">
                        <div className="flex items-start justify-between mb-2">
                            <div className="flex-1">
                                <div className="flex items-center gap-2 mb-1">
                                    <span className="text-sm font-medium text-gray-700">{suggestion.label}</span>
                                    {getConfidenceBadge(suggestion.confidence)}
                                </div>

                                {editingField === suggestion.field ? (
                                    <div className="flex gap-2 mt-2">
                                        <Input
                                            value={editValue}
                                            onChange={(e) => setEditValue(e.target.value)}
                                            className="flex-1"
                                            autoFocus
                                        />
                                        <Button
                                            size="sm"
                                            onClick={() => handleSaveEdit(suggestion.field)}
                                            className="bg-green-600 hover:bg-green-700"
                                        >
                                            <Check className="h-4 w-4" />
                                        </Button>
                                        <Button
                                            size="sm"
                                            variant="outline"
                                            onClick={() => setEditingField(null)}
                                        >
                                            <X className="h-4 w-4" />
                                        </Button>
                                    </div>
                                ) : (
                                    <p className="text-sm text-gray-900 mt-1">{suggestion.value}</p>
                                )}
                            </div>
                        </div>

                        {editingField !== suggestion.field && (
                            <div className="flex gap-2 mt-3">
                                <Button
                                    size="sm"
                                    onClick={() => onAccept(suggestion.field, suggestion.value)}
                                    className="bg-green-600 hover:bg-green-700 text-white"
                                >
                                    <Check className="h-3 w-3 mr-1" />
                                    Accept
                                </Button>
                                <Button
                                    size="sm"
                                    variant="outline"
                                    onClick={() => handleEdit(suggestion.field, suggestion.value)}
                                >
                                    <Edit2 className="h-3 w-3 mr-1" />
                                    Edit
                                </Button>
                                <Button
                                    size="sm"
                                    variant="ghost"
                                    onClick={() => onReject(suggestion.field)}
                                    className="text-gray-500 hover:text-red-600"
                                >
                                    <X className="h-3 w-3 mr-1" />
                                    Ignore
                                </Button>
                            </div>
                        )}
                    </div>
                ))}
            </div>

            <div className="mt-4 pt-4 border-t border-indigo-200">
                <p className="text-xs text-gray-500">
                    💡 These suggestions are AI-generated estimates based on public data. Please review and verify before accepting.
                </p>
            </div>
        </div>
    );
}
