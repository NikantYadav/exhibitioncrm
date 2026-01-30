'use client';

import { useState, useEffect } from 'react';
import { Button } from '@/components/ui/Button';
import { Input } from '@/components/ui/Input';
import { Sparkles, Check, X, Info, ArrowUpRight, Loader2 } from 'lucide-react';
import { cn } from '@/lib/utils';
import { Skeleton } from '@/components/ui/Skeleton';

interface EnrichmentSuggestion {
    field: string;
    label: string;
    value: string;
    confidence: number;
    currentValue?: string;
}

interface EnrichmentPanelProps {
    suggestions: any;
    loading?: boolean;
    onAccept: (field: string, value: string) => void;
    onReject: (field: string) => void;
    onEdit: (field: string, value: string) => void;
    currentValues?: Record<string, any>;
    onCloseRequest?: () => void;
}

const ResearchLoading = () => {
    const [step, setStep] = useState(0);
    const steps = [
        "Scanning social profiles...",
        "Searching company website...",
        "Identifying industry trends...",
        "Synthesizing public data...",
        "Computing match confidence..."
    ];

    useEffect(() => {
        const interval = setInterval(() => {
            setStep((s) => (s + 1) % steps.length);
        }, 2000);
        return () => clearInterval(interval);
    }, [steps.length]);

    return (
        <div className="py-20 flex flex-col items-center justify-center">
            <div className="relative mb-12">
                {/* Search Pulse Circles */}
                <div className="absolute inset-0 rounded-full bg-stone-900/5 animate-ping duration-[3000ms]" />
                <div className="absolute inset-0 rounded-full bg-stone-900/10 animate-pulse" />

                {/* Central Kinetic Icon */}
                <div className="relative h-24 w-24 bg-stone-900 rounded-[2rem] flex items-center justify-center shadow-2xl shadow-stone-900/20 ring-8 ring-stone-100 overflow-hidden">
                    <Sparkles className="h-10 w-10 text-white animate-bounce" strokeWidth={2.5} />

                    {/* Scanning Beam */}
                    <div className="absolute inset-0 bg-gradient-to-b from-transparent via-white/50 to-transparent h-[200%] w-full" style={{
                        animation: 'scan-active 2s linear infinite'
                    }} />
                </div>
            </div>

            <div className="text-center space-y-3">
                <div className="flex items-center justify-center gap-3">
                    <div className="h-1 w-1 rounded-full bg-stone-900 animate-bounce [animation-delay:-0.3s]" />
                    <div className="h-1 w-1 rounded-full bg-stone-900 animate-bounce [animation-delay:-0.15s]" />
                    <div className="h-1 w-1 rounded-full bg-stone-900 animate-bounce" />
                </div>
                <h3 className="text-[12px] font-black text-stone-900 uppercase tracking-[0.3em] h-4">
                    {steps[step]}
                </h3>
                <p className="text-[10px] font-bold text-stone-400 uppercase tracking-widest">
                    Research Active
                </p>
            </div>

            <style jsx global>{`
                @keyframes scan-active {
                    0% { transform: translateY(-100%); }
                    100% { transform: translateY(100%); }
                }
            `}</style>
        </div>
    );
};

export function EnrichmentPanel({ suggestions, loading, onAccept, onReject, onEdit, currentValues, onCloseRequest }: EnrichmentPanelProps) {
    const [editingField, setEditingField] = useState<string | null>(null);
    const [editValue, setEditValue] = useState('');

    const fields: EnrichmentSuggestion[] = suggestions ? [
        { field: 'bio', label: 'Biography', value: suggestions.bio, confidence: suggestions.confidence?.bio || 0 },
        { field: 'website', label: 'Company Website', value: suggestions.website, confidence: suggestions.confidence?.website || 0 },
        { field: 'industry', label: 'Industry', value: suggestions.industry, confidence: suggestions.confidence?.industry || 0 },
        { field: 'description', label: 'About Company', value: suggestions.description, confidence: suggestions.confidence?.description || 0 },
        { field: 'location', label: 'Office Location', value: suggestions.location, confidence: suggestions.confidence?.location || 0 },
        { field: 'products_services', label: 'What they do', value: suggestions.products_services, confidence: suggestions.confidence?.products_services || 0 },
        { field: 'company_size', label: 'Company Size', value: suggestions.company_size, confidence: suggestions.confidence?.company_size || 0 },
        { field: 'linkedin_url', label: 'LinkedIn Profile', value: suggestions.linkedin_url, confidence: suggestions.confidence?.linkedin_url || 0 },
    ].filter(f => {
        // Filter out if no value
        if (!f.value) return false;

        // Filter out if matches existing value exactly
        if (currentValues && currentValues[f.field] === f.value) return false;

        return true;
    }) : [];

    useEffect(() => {
        if (!loading && suggestions && Object.keys(suggestions).length > 0 && fields.length === 0 && onCloseRequest) {
            onCloseRequest();
        }
    }, [fields.length, loading, suggestions, onCloseRequest]);

    const handleEdit = (field: string, currentValue: string) => {
        setEditingField(field);
        setEditValue(currentValue || '');
    };

    const handleSaveEdit = (field: string) => {
        onEdit(field, editValue);
        setEditingField(null);
        setEditValue('');
    };

    const getConfidenceLabel = (confidence: number) => {
        if (confidence >= 0.8) return 'High Match';
        if (confidence >= 0.6) return 'Likely';
        return 'Estimate';
    };

    if (loading) {
        return <ResearchLoading />;
    }

    if (!suggestions || Object.keys(suggestions).length === 0) {
        return (
            <div className="p-12 text-center">
                <p className="text-stone-400 font-bold uppercase tracking-widest text-[10px]">No research data found</p>
            </div>
        );
    }

    return (
        <div className="bg-white rounded-[2.5rem] overflow-hidden">
            {/* Simple Header */}
            <div className="px-10 py-6 border-b border-stone-50 bg-stone-50/30 flex items-center justify-between">
                <div className="flex items-center gap-4">
                    <div className="p-2.5 bg-stone-900 text-white rounded-xl shadow-lg ring-4 ring-white">
                        <Sparkles className="h-4 w-4" strokeWidth={2.5} />
                    </div>
                    <div>
                        <h3 className="text-xs font-black text-stone-900 uppercase tracking-[0.2em] mb-0.5">Research Results</h3>
                        <p className="text-[10px] font-bold text-stone-400 uppercase tracking-widest">Found from public info</p>
                    </div>
                </div>
                <div className="flex items-center gap-2 px-3 py-1.5 bg-white border border-stone-100 rounded-full">
                    <div className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse" />
                    <span className="text-[9px] font-black text-stone-600 uppercase tracking-widest">Live Search</span>
                </div>
            </div>

            <div className="p-10 text-left">
                <div className="grid grid-cols-1 md:grid-cols-2 gap-x-10 gap-y-8">
                    {fields.map((suggestion) => (
                        <div key={suggestion.field} className="group relative">
                            <div className="flex items-center justify-between mb-2.5">
                                <div className="flex items-center gap-2">
                                    <span className="text-[9px] font-black text-stone-400 uppercase tracking-[0.2em]">{suggestion.label}</span>
                                    {suggestion.value.toLowerCase() !== 'unknown' && (
                                        <span className={cn(
                                            "text-[8px] font-black px-2 py-0.5 rounded-full uppercase tracking-widest",
                                            suggestion.confidence >= 0.8 ? "bg-emerald-50 text-emerald-600" :
                                                suggestion.confidence >= 0.6 ? "bg-stone-100 text-stone-600" :
                                                    "bg-stone-50 text-stone-400"
                                        )}>
                                            {getConfidenceLabel(suggestion.confidence)}
                                        </span>
                                    )}
                                </div>
                            </div>

                            <div className="relative">
                                {editingField === suggestion.field ? (
                                    <div className="flex items-center gap-2">
                                        <Input
                                            value={editValue}
                                            onChange={(e) => setEditValue(e.target.value)}
                                            className="h-11 bg-stone-50 border-none rounded-xl font-medium focus:ring-2 focus:ring-stone-900/5 transition-all"
                                            autoFocus
                                        />
                                        <button
                                            onClick={() => handleSaveEdit(suggestion.field)}
                                            className="h-11 w-11 shrink-0 bg-stone-900 text-white rounded-xl flex items-center justify-center hover:scale-105 active:scale-95 transition-all shadow-lg shadow-stone-900/10"
                                        >
                                            <Check className="h-4 w-4" strokeWidth={3} />
                                        </button>
                                        <button
                                            onClick={() => setEditingField(null)}
                                            className="h-11 w-11 shrink-0 bg-stone-100 text-stone-400 rounded-xl flex items-center justify-center hover:text-stone-900 transition-colors"
                                        >
                                            <X className="h-4 w-4" strokeWidth={3} />
                                        </button>
                                    </div>
                                ) : (
                                    <div className="flex flex-col gap-3">
                                        <div className="p-4 bg-stone-50/50 border border-stone-100/50 rounded-2xl group-hover:bg-white group-hover:border-stone-200 group-hover:shadow-xl group-hover:shadow-stone-900/5 transition-all duration-500">
                                            {suggestion.field === 'website' || suggestion.field === 'linkedin_url' ? (
                                                <div className="flex flex-col gap-1">
                                                    {suggestion.value === 'Not found' ? (
                                                        <div className="flex items-center gap-2 text-stone-400 italic text-sm font-medium h-6">
                                                            <span className="h-1.5 w-1.5 rounded-full bg-stone-300" />
                                                            Not found during research
                                                        </div>
                                                    ) : (
                                                        <>
                                                            <a
                                                                href={suggestion.field === 'website'
                                                                    ? (suggestion.value.startsWith('http') ? suggestion.value : `https://www.${suggestion.value.replace(/^www\./, '')}`)
                                                                    : (suggestion.value.startsWith('http') ? suggestion.value : `https://${suggestion.value}`)}
                                                                target="_blank"
                                                                rel="noopener noreferrer"
                                                                className="text-stone-900 font-bold text-sm flex items-center gap-2 hover:text-stone-600 transition-colors truncate block"
                                                            >
                                                                {suggestion.field === 'website'
                                                                    ? `www.${suggestion.value.replace(/^https?:\/\/(www\.)?/, '').replace(/\/$/, '')}`
                                                                    : suggestion.value.replace(/^https?:\/\/(www\.)?/, '').replace(/\/$/, '')}
                                                                <ArrowUpRight className="h-3 w-3 opacity-30 shrink-0" />
                                                            </a>
                                                            {suggestion.field === 'linkedin_url' && (
                                                                <span className="text-[9px] text-emerald-600 font-bold uppercase tracking-widest flex items-center gap-1">
                                                                    <Check className="h-2.5 w-2.5" /> Verified Profile
                                                                </span>
                                                            )}
                                                        </>
                                                    )}
                                                </div>
                                            ) : (
                                                <p className="text-stone-900 font-bold text-sm leading-relaxed line-clamp-2">{suggestion.value}</p>
                                            )}
                                        </div>

                                        <div className="flex items-center gap-2 opacity-0 group-hover:opacity-100 transition-all transform translate-y-1 group-hover:translate-y-0 duration-300">
                                            <button
                                                onClick={() => onAccept(suggestion.field, suggestion.value)}
                                                disabled={suggestion.value === 'Not found'}
                                                className={cn(
                                                    "h-8 px-4 bg-stone-900 text-white rounded-lg text-[9px] font-black uppercase tracking-widest hover:scale-105 active:scale-95 transition-all",
                                                    suggestion.value === 'Not found' && "opacity-50 cursor-not-allowed hover:scale-100 bg-stone-200 text-stone-400"
                                                )}
                                            >
                                                Apply
                                            </button>
                                            <button
                                                onClick={() => handleEdit(suggestion.field, suggestion.value)}
                                                className="h-8 px-4 bg-white border border-stone-100 text-stone-600 rounded-lg text-[9px] font-black uppercase tracking-widest hover:bg-stone-50 active:scale-95 transition-all shadow-sm"
                                            >
                                                Edit
                                            </button>
                                            <button
                                                onClick={() => onReject(suggestion.field)}
                                                className="h-8 px-4 text-stone-400 hover:text-red-500 rounded-lg text-[9px] font-black uppercase tracking-widest transition-colors"
                                            >
                                                Ignore
                                            </button>
                                        </div>
                                    </div>
                                )}
                            </div>
                        </div>
                    ))}
                </div>

                <div className="mt-12 pt-8 border-t border-stone-100 flex items-start gap-3">
                    <div className="p-1.5 bg-stone-100 rounded-lg text-stone-400">
                        <Info className="h-3.5 w-3.5" />
                    </div>
                    <p className="text-[10px] text-stone-400 font-bold leading-relaxed italic max-w-2xl">
                        These results were found by searching public info online. Please check them before adding to the profile.
                    </p>
                </div>
            </div>
        </div>
    );
}
