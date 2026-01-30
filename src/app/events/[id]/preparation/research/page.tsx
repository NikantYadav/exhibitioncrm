'use client';

import { useState } from 'react';
import { Search, Loader2, Globe, Building2, MapPin, Plus, Check } from 'lucide-react';
import { searchCompanyAction, addTargetCompany } from '@/app/actions/preparation';
import { CompanyResearchResult } from '@/lib/services/company-research';

export default function ResearchPage({ params }: { params: { id: string } }) {
    const [query, setQuery] = useState('');
    const [isLoading, setIsLoading] = useState(false);
    const [result, setResult] = useState<CompanyResearchResult | null>(null);
    const [error, setError] = useState('');
    const [isAdding, setIsAdding] = useState(false);
    const [isAdded, setIsAdded] = useState(false);

    const handleSearch = async (e: React.FormEvent) => {
        e.preventDefault();
        if (!query.trim()) return;

        setIsLoading(true);
        setError('');
        setResult(null);
        setIsAdded(false);

        const formData = new FormData();
        formData.append('query', query);

        const response = await searchCompanyAction(formData);

        if (response.error) {
            setError(response.error);
        } else if (response.result) {
            setResult(response.result);
        }

        setIsLoading(false);
    };

    const handleAdd = async () => {
        if (!result) return;
        setIsAdding(true);
        const response = await addTargetCompany(params.id, { name: query }, result); // Name derived from query is imperfect but works for search
        if (response.success) {
            setIsAdded(true);
        } else {
            setError('Failed to add to targets');
        }
        setIsAdding(false);
    };

    return (
        <div className="max-w-4xl mx-auto space-y-6">
            <div className="bg-white p-6 rounded-xl shadow-sm border border-gray-200">
                <h2 className="text-lg font-semibold mb-4">AI Company Research</h2>
                <form onSubmit={handleSearch} className="flex gap-2">
                    <div className="relative flex-1">
                        <Search className="absolute left-3 top-2.5 h-5 w-5 text-gray-400" />
                        <input
                            type="text"
                            placeholder="Enter Company Name or specific URL (e.g. google.com)"
                            className="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                            value={query}
                            onChange={(e) => setQuery(e.target.value)}
                        />
                    </div>
                    <button
                        type="submit"
                        disabled={isLoading || !query}
                        className="bg-blue-600 text-white px-6 py-2 rounded-lg font-medium hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed flex items-center"
                    >
                        {isLoading ? <Loader2 className="h-4 w-4 animate-spin mr-2" /> : null}
                        Analyze
                    </button>
                </form>
            </div>

            {error && (
                <div className="bg-red-50 text-red-700 p-4 rounded-lg border border-red-200">
                    {error}
                </div>
            )}

            {result && (
                <div className="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden animate-in fade-in slide-in-from-bottom-4">
                    <div className="p-6 border-b border-gray-100 flex justify-between items-start">
                        <div>
                            <div className="flex items-center gap-2 mb-1">
                                <h3 className="text-2xl font-bold text-gray-900">{query}</h3>
                                <span className={`px-2 py-0.5 rounded-full text-xs font-medium ${result.confidence > 0.8 ? 'bg-green-100 text-green-800' : 'bg-yellow-100 text-yellow-800'}`}>
                                    {Math.round(result.confidence * 100)}% Confidence
                                </span>
                            </div>
                            <div className="flex flex-wrap gap-4 text-sm text-gray-500">
                                <span className="flex items-center gap-1">
                                    <Globe className="h-4 w-4" />
                                    <a href={result.website} target="_blank" rel="noreferrer" className="hover:underline text-blue-600">
                                        {result.website || 'No website found'}
                                    </a>
                                </span>
                                {(result.location || result.industry) && (
                                    <span className="flex items-center gap-1">
                                        <Building2 className="h-4 w-4" />
                                        {result.industry} {result.location ? `• ${result.location}` : ''}
                                    </span>
                                )}
                            </div>
                        </div>
                        <button
                            onClick={handleAdd}
                            disabled={isAdding || isAdded}
                            className={`flex items-center px-4 py-2 rounded-lg text-sm font-medium transition-colors ${isAdded
                                    ? 'bg-green-50 text-green-700 border border-green-200'
                                    : 'bg-gray-900 text-white hover:bg-gray-800'
                                }`}
                        >
                            {isAdded ? (
                                <>
                                    <Check className="h-4 w-4 mr-2" />
                                    Added to Targets
                                </>
                            ) : (
                                <>
                                    {isAdding ? <Loader2 className="h-4 w-4 animate-spin mr-2" /> : <Plus className="h-4 w-4 mr-2" />}
                                    Add to Targets
                                </>
                            )}
                        </button>
                    </div>

                    <div className="p-6 grid grid-cols-1 md:grid-cols-2 gap-8">
                        <div className="space-y-6">
                            <section>
                                <h4 className="text-sm font-semibold text-gray-500 uppercase tracking-wider mb-2">Overview</h4>
                                <p className="text-gray-700 leading-relaxed">{result.overview}</p>
                            </section>

                            <section>
                                <h4 className="text-sm font-semibold text-gray-500 uppercase tracking-wider mb-2">Key Products & Services</h4>
                                <p className="text-gray-700">{result.products_services || 'No specific products identified.'}</p>
                            </section>

                            <section>
                                <h4 className="text-sm font-semibold text-gray-500 uppercase tracking-wider mb-2">Key Insights</h4>
                                <ul className="space-y-2">
                                    {result.keyInsights.map((insight, i) => (
                                        <li key={i} className="flex items-start gap-2 text-gray-700 bg-blue-50/50 p-2 rounded">
                                            <span className="text-blue-500 mt-1">•</span>
                                            <span>{insight}</span>
                                        </li>
                                    ))}
                                </ul>
                            </section>
                        </div>

                        <div className="space-y-6">
                            <section>
                                <h4 className="text-sm font-semibold text-gray-500 uppercase tracking-wider mb-2">Competitors</h4>
                                <div className="flex flex-wrap gap-2">
                                    {result.competitors.length > 0 ? result.competitors.map((comp, i) => (
                                        <span key={i} className="px-3 py-1 bg-gray-100 text-gray-700 rounded-full text-sm">
                                            {comp}
                                        </span>
                                    )) : <span className="text-gray-400 italic">None identified</span>}
                                </div>
                            </section>

                            <section>
                                <h4 className="text-sm font-semibold text-gray-500 uppercase tracking-wider mb-2">Recent News</h4>
                                <div className="space-y-3">
                                    {result.recentNews.length > 0 ? result.recentNews.map((news, i) => (
                                        <a key={i} href={news.url} target="_blank" className="block group p-3 rounded-lg hover:bg-gray-50 border border-transparent hover:border-gray-200 transition-all">
                                            <h5 className="font-medium text-gray-900 group-hover:text-blue-600 line-clamp-1">{news.title}</h5>
                                            <p className="text-sm text-gray-500 mt-1 line-clamp-2">{news.summary}</p>
                                            <div className="flex items-center gap-2 mt-2 text-xs text-gray-400">
                                                <span>{news.source}</span>
                                                <span>•</span>
                                                <span>{news.date}</span>
                                            </div>
                                        </a>
                                    )) : <span className="text-gray-400 italic">No recent news found</span>}
                                </div>
                            </section>
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
}
