'use client';

import { Card, CardContent } from '@/components/ui/Card';
import { Button } from '@/components/ui/Button';
import { Brain, Sparkles, Loader2, ArrowRight } from 'lucide-react';

export interface MemoryContext {
    narrative_summary: string;
    key_facts: string[];
    last_interaction_context: string;
}

interface RelationshipMemoryProps {
    memory?: MemoryContext;
    isLoading: boolean;
    onGenerate: () => void;
}

export function RelationshipMemory({ memory, isLoading, onGenerate }: RelationshipMemoryProps) {
    if (!memory && !isLoading) {
        return (
            <div className="premium-card p-6 bg-gradient-to-br from-indigo-50 to-purple-50 border-indigo-100">
                <div className="flex items-center gap-3 mb-4">
                    <div className="p-2 bg-white rounded-lg shadow-sm">
                        <Brain className="h-5 w-5 text-indigo-600" />
                    </div>
                    <h3 className="font-semibold text-indigo-900">Relationship Memory</h3>
                </div>
                <p className="text-sm text-indigo-700 mb-4">
                    Generate an AI summary of your entire relationship history, including key facts and context.
                </p>
                <Button onClick={onGenerate} size="sm" className="bg-indigo-600 hover:bg-indigo-700 w-full sm:w-auto">
                    <Sparkles className="h-4 w-4 mr-2" />
                    Generate Memory
                </Button>
            </div>
        );
    }

    if (isLoading) {
        return (
            <div className="premium-card p-8 flex flex-col items-center justify-center min-h-[200px]">
                <Loader2 className="h-8 w-8 text-indigo-600 animate-spin mb-3" />
                <p className="text-sm text-gray-500 font-medium">Synthesizing relationship history...</p>
            </div>
        );
    }

    return (
        <div className="premium-card p-0 overflow-hidden border-indigo-100">
            <div className="bg-gradient-to-r from-indigo-50 to-purple-50 p-4 border-b border-indigo-50">
                <div className="flex items-center gap-2">
                    <Brain className="h-5 w-5 text-indigo-600" />
                    <h3 className="font-semibold text-indigo-900">Relationship Memory</h3>
                </div>
            </div>

            <div className="p-6 space-y-6">
                {/* Narrative */}
                <div>
                    <p className="text-gray-700 leading-relaxed text-sm">
                        {memory?.narrative_summary}
                    </p>
                </div>

                {/* Last Interaction */}
                <div className="bg-gray-50 rounded-lg p-3 border border-gray-100">
                    <div className="flex items-center gap-2 mb-1">
                        <ArrowRight className="h-4 w-4 text-gray-400" />
                        <span className="text-xs font-semibold text-gray-500 uppercase tracking-wider">Last Interaction</span>
                    </div>
                    <p className="text-sm text-gray-600 italic">
                        "{memory?.last_interaction_context}"
                    </p>
                </div>

                {/* Key Facts */}
                {memory?.key_facts && memory.key_facts.length > 0 && (
                    <div>
                        <h4 className="text-xs font-semibold text-gray-500 uppercase tracking-wider mb-3">Key Facts</h4>
                        <div className="flex flex-wrap gap-2">
                            {memory.key_facts.map((fact, i) => (
                                <span key={i} className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-indigo-50 text-indigo-700 border border-indigo-100">
                                    {fact}
                                </span>
                            ))}
                        </div>
                    </div>
                )}
            </div>
        </div>
    );
}
