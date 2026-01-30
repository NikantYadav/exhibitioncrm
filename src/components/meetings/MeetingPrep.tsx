'use client';

import { useState } from 'react';
import { Card, CardContent } from '@/components/ui/Card';
import { Button } from '@/components/ui/Button';
import { User, History as HistoryIcon, FileText, MessageSquare, Sparkles, Loader2, RefreshCw } from 'lucide-react';

interface PrepData {
    who_is_this?: string;
    relationship_summary?: string;
    key_talking_points?: string[];
    interaction_highlights?: string;
}

interface MeetingPrepProps {
    contactId: string;
    prepData?: PrepData;
    onGenerate: () => Promise<void>;
    isGenerating: boolean;
}

export function MeetingPrep({ contactId, prepData, onGenerate, isGenerating }: MeetingPrepProps) {
    if (!prepData && !isGenerating) {
        return (
            <div className="text-center py-20 bg-stone-50/50 rounded-[2rem] border-2 border-dashed border-stone-200 group hover:border-stone-400 transition-all duration-500">
                <div className="w-20 h-20 bg-white rounded-3xl shadow-sm border border-stone-100 flex items-center justify-center mx-auto mb-6 group-hover:scale-110 transition-transform duration-500">
                    <Sparkles className="h-8 w-8 text-stone-400" />
                </div>
                <h3 className="text-xl font-bold text-stone-900 mb-2">AI Insights</h3>
                <p className="text-stone-500 mb-8 max-w-sm mx-auto text-sm leading-relaxed">
                    Let AI analyze your interaction history and documents to prepare for your meeting.
                </p>
                <Button
                    onClick={onGenerate}
                    className="bg-stone-900 hover:bg-black text-white px-8 rounded-full shadow-lg shadow-stone-200"
                >
                    <Sparkles className="h-4 w-4 mr-2" />
                    Generate Insights
                </Button>
            </div>
        );
    }

    if (isGenerating) {
        return (
            <div className="flex flex-col items-center justify-center py-32 space-y-6">
                <div className="relative">
                    <div className="h-16 w-16 rounded-full border-4 border-stone-100 border-t-stone-900 animate-spin" />
                    <Sparkles className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 h-6 w-6 text-stone-400" />
                </div>
                <div className="text-center space-y-1">
                    <p className="text-stone-900 font-bold tracking-tight">Generating AI Insights</p>
                    <p className="text-stone-400 text-xs uppercase tracking-[0.2em]">Analyzing history and documents</p>
                </div>
            </div>
        );
    }

    return (
        <div className="relative">
            {prepData && (
                <div className="absolute -top-12 right-0">
                    <Button
                        variant="ghost"
                        size="sm"
                        onClick={onGenerate}
                        className="text-stone-400 hover:text-indigo-600 transition-colors"
                        disabled={isGenerating}
                    >
                        <RefreshCw className={`h-4 w-4 mr-2 ${isGenerating ? 'animate-spin' : ''}`} />
                        Refresh Insights
                    </Button>
                </div>
            )}

            <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
                {/* Executive Profile Section */}
                <div className="md:col-span-2 premium-card p-10 overflow-hidden relative group">
                    <div className="relative z-10 space-y-6">
                        <div className="flex items-center gap-3">
                            <div className="w-10 h-10 rounded-xl bg-stone-900 text-white flex items-center justify-center shadow-lg shadow-stone-200">
                                <User className="h-5 w-5" />
                            </div>
                            <div>
                                <h3 className="text-[10px] font-bold text-stone-400 uppercase tracking-[0.2em]">AI Summary</h3>
                                <p className="text-xl font-bold text-stone-900">Contact Overview</p>
                            </div>
                        </div>
                        <p className="text-2xl font-medium text-stone-800 leading-[1.6] italic pr-12">
                            {prepData?.who_is_this}
                        </p>
                    </div>
                    {/* Architectural Accent */}
                    <div className="absolute top-0 right-0 w-32 h-full bg-stone-50/50 skew-x-[-15deg] translate-x-16 pointer-events-none" />
                </div>

                {/* Contextual History */}
                <div className="premium-card p-8 space-y-6">
                    <div className="flex items-center gap-3">
                        <div className="w-8 h-8 rounded-lg bg-stone-100 text-stone-600 flex items-center justify-center">
                            <HistoryIcon className="h-4 w-4" />
                        </div>
                        <h3 className="text-sm font-bold text-stone-900 uppercase tracking-widest">Meeting Context</h3>
                    </div>

                    <div className="space-y-6">
                        <div className="space-y-2">
                            <span className="text-[10px] font-bold text-stone-400 uppercase tracking-widest">The Connection</span>
                            <p className="text-stone-700 leading-relaxed">
                                {prepData?.relationship_summary}
                            </p>
                        </div>

                        <div className="pt-6 border-t border-stone-100">
                            <div className="flex items-center gap-2 text-[10px] font-bold text-stone-900 uppercase tracking-widest mb-3">
                                <Sparkles className="h-3 w-3" />
                                Key Highlights
                            </div>
                            <p className="text-stone-600 text-sm leading-relaxed italic">
                                "{prepData?.interaction_highlights}"
                            </p>
                        </div>
                    </div>
                </div>

                {/* High-Value Topics */}
                <div className="premium-card p-8 space-y-6">
                    <div className="flex items-center gap-3">
                        <div className="w-8 h-8 rounded-lg bg-stone-100 text-stone-600 flex items-center justify-center">
                            <MessageSquare className="h-4 w-4" />
                        </div>
                        <h3 className="text-sm font-bold text-stone-900 uppercase tracking-widest">Talking Points</h3>
                    </div>

                    <ul className="space-y-4">
                        {prepData?.key_talking_points?.map((point, i) => (
                            <li key={i} className="flex items-start gap-4 group">
                                <div className="mt-1.5 h-1.5 w-1.5 rounded-full bg-stone-300 group-hover:scale-150 group-hover:bg-stone-900 transition-all duration-300" />
                                <span className="text-stone-700 text-sm leading-relaxed font-medium">
                                    {point}
                                </span>
                            </li>
                        ))}
                    </ul>
                </div>
            </div>
        </div>
    );
}
