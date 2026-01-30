'use client';

import { useState } from 'react';
import { Card, CardContent } from '@/components/ui/Card';
import { Button } from '@/components/ui/Button';
import { User, History as HistoryIcon, FileText, MessageSquare, Sparkles, Loader2 } from 'lucide-react';

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
            <div className="text-center py-12 bg-white rounded-xl border border-gray-200">
                <Sparkles className="h-12 w-12 text-indigo-400 mx-auto mb-4" />
                <h3 className="text-lg font-medium text-gray-900 mb-2">Generate Meeting Brief</h3>
                <p className="text-gray-500 mb-6 max-w-sm mx-auto">
                    Use AI to analyze your history, documents, and contact profile to prepare a comprehensive briefing.
                </p>
                <Button onClick={onGenerate} className="bg-indigo-600 hover:bg-indigo-700">
                    <Sparkles className="h-4 w-4 mr-2" />
                    Generate Intelligence
                </Button>
            </div>
        );
    }

    if (isGenerating) {
        return (
            <div className="flex flex-col items-center justify-center py-20">
                <Loader2 className="h-10 w-10 text-indigo-600 animate-spin mb-4" />
                <p className="text-gray-600 font-medium">Analyzing contact history and documents...</p>
                <p className="text-gray-400 text-sm mt-2">This may take a moment</p>
            </div>
        );
    }

    return (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            {/* Who is this */}
            <Card className="md:col-span-2 bg-gradient-to-r from-indigo-50 to-purple-50 border-indigo-100">
                <CardContent className="p-6">
                    <div className="flex items-center gap-3 mb-3">
                        <div className="p-2 bg-white rounded-lg shadow-sm">
                            <User className="h-5 w-5 text-indigo-600" />
                        </div>
                        <h3 className="font-semibold text-indigo-900">Who is this?</h3>
                    </div>
                    <p className="text-indigo-800 leading-relaxed">
                        {prepData?.who_is_this}
                    </p>
                </CardContent>
            </Card>

            {/* Relationship */}
            <Card>
                <CardContent className="p-6">
                    <div className="flex items-center gap-3 mb-3">
                        <div className="p-2 bg-gray-100 rounded-lg">
                            <HistoryIcon className="h-5 w-5 text-gray-600" />
                        </div>
                        <h3 className="font-semibold text-gray-900">How you know them</h3>
                    </div>
                    <p className="text-gray-600 text-sm">
                        {prepData?.relationship_summary}
                    </p>
                    <div className="mt-4 pt-4 border-t border-gray-100">
                        <h4 className="text-xs font-semibold text-gray-500 uppercase tracking-wider mb-2">Highlights</h4>
                        <div className="text-sm text-gray-600">
                            {prepData?.interaction_highlights}
                        </div>
                    </div>
                </CardContent>
            </Card>

            {/* Talking Points */}
            <Card>
                <CardContent className="p-6">
                    <div className="flex items-center gap-3 mb-3">
                        <div className="p-2 bg-green-50 rounded-lg">
                            <MessageSquare className="h-5 w-5 text-green-600" />
                        </div>
                        <h3 className="font-semibold text-gray-900">Suggested Topics</h3>
                    </div>
                    <ul className="space-y-3">
                        {prepData?.key_talking_points?.map((point, i) => (
                            <li key={i} className="flex items-start gap-2 text-sm text-gray-700">
                                <span className="mt-1.5 h-1.5 w-1.5 rounded-full bg-green-500 flex-shrink-0" />
                                {point}
                            </li>
                        ))}
                    </ul>
                </CardContent>
            </Card>
        </div>
    );
}
