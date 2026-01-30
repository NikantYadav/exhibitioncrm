import { useState } from 'react';
import { Button } from '@/components/ui/Button';
import { CompanyResearchResult } from '@/lib/services/company-research';
import { Search, Loader2, Globe, Building2, MapPin, Check, Plus } from 'lucide-react';

interface AIResearchSectionProps {
    researchQuery: string;
    setResearchQuery: (query: string) => void;
    isResearching: boolean;
    researchResult: CompanyResearchResult | null;
    researchError: string;
    isAddingResearch: boolean;
    isAddedResearch: boolean;
    onSearch: (e: React.FormEvent) => void;
    onAddToTargets: () => void;
}

export function AIResearchSection({
    researchQuery,
    setResearchQuery,
    isResearching,
    researchResult,
    researchError,
    isAddingResearch,
    isAddedResearch,
    onSearch,
    onAddToTargets
}: AIResearchSectionProps) {
    return (
        <div className="space-y-6">
            <div className="bg-stone-50/50 p-6 rounded-2xl border border-stone-200">
                <h3 className="font-semibold mb-3">AI Deep Research</h3>
                <p className="text-sm text-stone-500 mb-4">Analyze any company profile based on their website or name.</p>
                <form onSubmit={onSearch} className="flex gap-2">
                    <div className="relative flex-1">
                        <Search className="absolute left-3 top-2.5 h-4 w-4 text-stone-400" />
                        <input
                            type="text"
                            value={researchQuery}
                            onChange={(e) => setResearchQuery(e.target.value)}
                            placeholder="Enter company name or website..."
                            className="w-full pl-9 pr-3 py-2 border border-stone-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 text-sm"
                            disabled={isResearching}
                        />
                    </div>
                    <Button type="submit" disabled={isResearching || !researchQuery.trim()}>
                        {isResearching ? (
                            <>
                                <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                                Researching...
                            </>
                        ) : (
                            'Research'
                        )}
                    </Button>
                </form>
            </div>

            {researchError && (
                <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-lg text-sm">
                    {researchError}
                </div>
            )}

            {researchResult && (
                <div className="bg-white border border-stone-200 rounded-2xl p-6 space-y-6">
                    <div className="flex items-start justify-between">
                        <div>
                            <h3 className="text-xl font-bold text-stone-900 mb-1">
                                {researchResult.companyName}
                            </h3>
                            {researchResult.website && (
                                <a
                                    href={researchResult.website.startsWith('http')
                                        ? researchResult.website
                                        : `https://www.${researchResult.website.replace(/^www\./, '')}`}
                                    target="_blank"
                                    rel="noopener noreferrer"
                                    className="text-sm text-blue-600 hover:underline flex items-center gap-1"
                                >
                                    <Globe className="h-3 w-3" />
                                    www.{researchResult.website.replace(/^https?:\/\/(www\.)?/, '').replace(/\/$/, '')}
                                </a>
                            )}
                        </div>
                        <Button
                            onClick={onAddToTargets}
                            disabled={isAddingResearch || isAddedResearch}
                            size="sm"
                        >
                            {isAddingResearch ? (
                                <>
                                    <Loader2 className="mr-2 h-3 w-3 animate-spin" />
                                    Adding...
                                </>
                            ) : isAddedResearch ? (
                                <>
                                    <Check className="mr-2 h-3 w-3" />
                                    Added
                                </>
                            ) : (
                                <>
                                    <Plus className="mr-2 h-3 w-3" />
                                    Add to Targets
                                </>
                            )}
                        </Button>
                    </div>

                    <div className="grid grid-cols-2 gap-4">
                        {researchResult.industry && (
                            <div>
                                <div className="text-xs text-stone-500 mb-1 flex items-center gap-1">
                                    <Building2 className="h-3 w-3" />
                                    Industry
                                </div>
                                <div className="text-sm font-medium text-stone-900">{researchResult.industry}</div>
                            </div>
                        )}
                        {researchResult.location && (
                            <div>
                                <div className="text-xs text-stone-500 mb-1 flex items-center gap-1">
                                    <MapPin className="h-3 w-3" />
                                    Location
                                </div>
                                <div className="text-sm font-medium text-stone-900">{researchResult.location}</div>
                            </div>
                        )}
                    </div>

                    {researchResult.overview && (
                        <div>
                            <h4 className="text-sm font-semibold text-stone-900 mb-2">Company Overview</h4>
                            <p className="text-sm text-stone-600 leading-relaxed">{researchResult.overview}</p>
                        </div>
                    )}

                    {researchResult.products && researchResult.products.length > 0 && (
                        <div>
                            <h4 className="text-sm font-semibold text-stone-900 mb-2">Products & Services</h4>
                            <ul className="space-y-1">
                                {researchResult.products.map((product, idx) => (
                                    <li key={idx} className="text-sm text-stone-600 flex items-start gap-2">
                                        <span className="text-blue-600 mt-1">•</span>
                                        <span>{product}</span>
                                    </li>
                                ))}
                            </ul>
                        </div>
                    )}

                    {researchResult.talkingPoints && researchResult.talkingPoints.length > 0 && (
                        <div>
                            <h4 className="text-sm font-semibold text-stone-900 mb-2">Suggested Talking Points</h4>
                            <ul className="space-y-1">
                                {researchResult.talkingPoints.map((point, idx) => (
                                    <li key={idx} className="text-sm text-stone-600 flex items-start gap-2">
                                        <span className="text-green-600 mt-1">→</span>
                                        <span>{point}</span>
                                    </li>
                                ))}
                            </ul>
                        </div>
                    )}
                </div>
            )}
        </div>
    );
}
