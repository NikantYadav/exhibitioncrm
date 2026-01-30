'use client';

import { useState } from 'react';
import { Modal } from '@/components/ui/Modal';
import { Input } from '@/components/ui/Input';
import { Textarea } from '@/components/ui/Textarea';
import { Button } from '@/components/ui/Button';
import { Company } from '@/types';
import { Search, Building2, Plus, Sparkles, Loader2, ArrowLeft, Keyboard } from 'lucide-react';
import { searchCompanyAction } from '@/app/actions/preparation';
import { toast } from 'sonner';

interface CompanySearchModalProps {
    isOpen: boolean;
    onClose: () => void;
    onSelect: (company: Company) => void;
    eventId: string;
}

export function CompanySearchModal({ isOpen, onClose, onSelect, eventId }: CompanySearchModalProps) {
    const [searchQuery, setSearchQuery] = useState('');
    const [companies, setCompanies] = useState<Company[]>([]);
    const [loading, setLoading] = useState(false);
    const [hasSearched, setHasSearched] = useState(false);
    const [isResearching, setIsResearching] = useState(false);
    const [showForm, setShowForm] = useState(false);
    const [formMode, setFormMode] = useState<'create' | 'ai'>('create');

    const [formData, setFormData] = useState({
        name: '',
        website: '',
        industry: '',
        description: '',
        location: '',
        products_services: ''
    });

    const searchCompanies = async (query: string) => {
        if (!query.trim()) {
            setCompanies([]);
            setHasSearched(false);
            return;
        }

        setLoading(true);
        setHasSearched(true);
        try {
            const response = await fetch(`/api/companies?search=${encodeURIComponent(query)}`);
            const data = await response.json();
            setCompanies(data.data || []);
        } catch (error) {
            console.error('Failed to search companies:', error);
            toast.error('Failed to search companies');
        } finally {
            setLoading(false);
        }
    };

    const handleSearch = (e: React.FormEvent) => {
        e.preventDefault();
        searchCompanies(searchQuery);
    };

    const handleAIResearch = async () => {
        const query = searchQuery.trim();
        if (!query) {
            toast.error('Please enter a company name or website to research');
            return;
        }

        setIsResearching(true);
        try {
            const data = await searchCompanyAction(query);
            if (data.error) {
                toast.error('Internal Server Error');
            } else if (data.result) {
                setFormData({
                    name: data.result.companyName || query,
                    website: data.result.website || '',
                    industry: data.result.industry || '',
                    description: data.result.overview || '',
                    location: data.result.location || '',
                    products_services: data.result.products_services || (data.result.products?.join(', ') || '')
                });
                setFormMode('ai');
                setShowForm(true);
            }
        } catch (error) {
            console.error('AI Research failed:', error);
            toast.error('AI Research failed');
        } finally {
            setIsResearching(false);
        }
    };

    const handleManualEntry = () => {
        setFormData({
            ...formData,
            name: searchQuery || ''
        });
        setFormMode('create');
        setShowForm(true);
    };

    const handleSaveCompany = async (e: React.FormEvent) => {
        e.preventDefault();
        setLoading(true);
        try {
            const response = await fetch('/api/companies', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(formData)
            });
            const data = await response.json();
            if (data.data) {
                onSelect(data.data);
                resetAll();
                onClose();
            } else {
                toast.error('Internal Server Error');
            }
        } catch (error) {
            console.error('Failed to save company:', error);
            toast.error('Failed to save company');
        } finally {
            setLoading(false);
        }
    };

    const resetAll = () => {
        setSearchQuery('');
        setCompanies([]);
        setHasSearched(false);
        setShowForm(false);
        setFormMode('create');
        setFormData({
            name: '',
            website: '',
            industry: '',
            description: '',
            location: '',
            products_services: ''
        });
    };

    return (
        <Modal
            isOpen={isOpen}
            onClose={() => { resetAll(); onClose(); }}
            title={showForm ? (formMode === 'ai' ? 'Review AI Research' : 'Create New Company') : 'Add Target Company'}
            size="lg"
        >
            {!showForm ? (
                <div className="space-y-6">
                    {/* Top Action Bar */}
                    <div className="flex items-center gap-2">
                        <Button
                            variant="outline"
                            size="sm"
                            className="flex-1 h-9 gap-2 border-stone-200 hover:bg-stone-50"
                            onClick={handleManualEntry}
                        >
                            <Keyboard className="h-4 w-4 text-stone-500" />
                            Manual Entry
                        </Button>
                        <Button
                            variant="outline"
                            size="sm"
                            className="flex-1 h-9 gap-2 border-blue-100 hover:bg-blue-50 hover:text-blue-600"
                            onClick={handleAIResearch}
                            disabled={isResearching}
                        >
                            {isResearching ? (
                                <Loader2 className="h-4 w-4 animate-spin" />
                            ) : (
                                <Sparkles className="h-4 w-4" />
                            )}
                            AI Auto-Research
                        </Button>
                    </div>

                    <div className="relative">
                        <div className="absolute inset-0 flex items-center" aria-hidden="true">
                            <div className="w-full border-t border-stone-100"></div>
                        </div>
                        <div className="relative flex justify-center text-xs uppercase">
                            <span className="bg-white px-3 text-stone-400 font-medium">or search database</span>
                        </div>
                    </div>

                    <div>
                        <form onSubmit={handleSearch} className="flex gap-2">
                            <div className="relative flex-1">
                                <Search className="absolute left-3 top-2.5 h-4 w-4 text-stone-400" />
                                <Input
                                    className="pl-10"
                                    placeholder="Company name or website..."
                                    value={searchQuery}
                                    onChange={(e) => setSearchQuery(e.target.value)}
                                    autoFocus
                                />
                            </div>
                            <Button type="submit" disabled={loading || isResearching} className="bg-blue-600 hover:bg-blue-700">
                                {loading ? <Loader2 className="h-4 w-4 animate-spin" /> : 'Search'}
                            </Button>
                        </form>
                    </div>

                    {hasSearched ? (
                        companies.length > 0 ? (
                            <div className="space-y-2 max-h-80 overflow-y-auto pr-1">
                                <p className="text-xs font-semibold text-stone-400 uppercase tracking-wider mb-2">Found in your database</p>
                                {companies.map((company) => (
                                    <button
                                        key={company.id}
                                        onClick={() => {
                                            onSelect(company);
                                            resetAll();
                                            onClose();
                                        }}
                                        className="w-full text-left p-4 border border-gray-100 rounded-xl hover:bg-blue-50/50 hover:border-blue-200 transition-all group"
                                    >
                                        <div className="flex items-center justify-between">
                                            <div className="flex items-start gap-3">
                                                <div className="p-2 bg-gray-100 rounded-lg group-hover:bg-blue-100 transition-colors">
                                                    <Building2 className="h-5 w-5 text-gray-500 group-hover:text-blue-600" />
                                                </div>
                                                <div>
                                                    <p className="font-semibold text-gray-900">{company.name}</p>
                                                    {company.industry && (
                                                        <p className="text-sm text-gray-600 font-medium">{company.industry}</p>
                                                    )}
                                                    {company.website && (
                                                        <p className="text-xs text-blue-600 mt-0.5">
                                                            www.{company.website.replace(/^https?:\/\/(www\.)?/, '').replace(/\/$/, '')}
                                                        </p>
                                                    )}
                                                </div>
                                            </div>
                                            <Plus className="h-5 w-5 text-gray-400 group-hover:text-blue-600" />
                                        </div>
                                    </button>
                                ))}
                            </div>
                        ) : !loading && (
                            <div className="bg-stone-50 rounded-2xl p-8 border border-stone-100 text-center">
                                <div className="max-w-xs mx-auto">
                                    <Search className="h-10 w-10 text-stone-300 mx-auto mb-4" />
                                    <h4 className="font-semibold text-gray-900 mb-2">No Results Found</h4>
                                    <p className="text-sm text-gray-500 mb-6">
                                        We couldn't find "{searchQuery}" in your records. Would you like to use AI research or enter it manually?
                                    </p>
                                    <div className="flex flex-col gap-2">
                                        <Button
                                            onClick={handleAIResearch}
                                            disabled={isResearching}
                                            className="w-full bg-blue-600 hover:bg-blue-700 h-10 gap-2"
                                        >
                                            {isResearching ? <Loader2 className="h-4 w-4 animate-spin" /> : <Sparkles className="h-4 w-4" />}
                                            Research with AI
                                        </Button>
                                        <Button
                                            variant="ghost"
                                            onClick={handleManualEntry}
                                            className="h-10"
                                        >
                                            Enter Manually
                                        </Button>
                                    </div>
                                </div>
                            </div>
                        )
                    ) : (
                        <div className="text-center py-12 border-2 border-dashed border-gray-100 rounded-2xl">
                            <Building2 className="h-12 w-12 text-gray-300 mx-auto mb-3" />
                            <p className="text-gray-500 text-sm">Type a name above to search or use AI</p>
                        </div>
                    )}
                </div>
            ) : (
                <form onSubmit={handleSaveCompany} className="space-y-4">
                    {formMode === 'ai' && (
                        <div className="bg-blue-50 border border-blue-100 rounded-xl p-4 mb-4 flex items-start gap-3">
                            <Sparkles className="h-5 w-5 text-blue-600 mt-0.5 shrink-0" />
                            <p className="text-sm text-blue-800">
                                <strong>AI Research Complete!</strong> Review and edit the details below before saving.
                            </p>
                        </div>
                    )}

                    <div className="grid grid-cols-2 gap-4">
                        <div className="col-span-2">
                            <Input
                                label="Company Name"
                                required
                                value={formData.name}
                                onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                                placeholder="Acme Corp"
                            />
                        </div>
                        <Input
                            label="Website"
                            value={formData.website}
                            onChange={(e) => setFormData({ ...formData, website: e.target.value })}
                            placeholder="https://acme.com"
                        />
                        <Input
                            label="Industry"
                            value={formData.industry}
                            onChange={(e) => setFormData({ ...formData, industry: e.target.value })}
                            placeholder="Technology"
                        />
                        <div className="col-span-2">
                            <Input
                                label="Location"
                                value={formData.location}
                                onChange={(e) => setFormData({ ...formData, location: e.target.value })}
                                placeholder="San Francisco, CA"
                            />
                        </div>
                        <div className="col-span-2">
                            <Textarea
                                label="Description"
                                rows={3}
                                value={formData.description}
                                onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                                placeholder="Brief description..."
                            />
                        </div>
                        <div className="col-span-2">
                            <Textarea
                                label="Products & Services"
                                rows={2}
                                value={formData.products_services}
                                onChange={(e) => setFormData({ ...formData, products_services: e.target.value })}
                                placeholder="List key products or services..."
                            />
                        </div>
                    </div>

                    <div className="flex gap-3 pt-4">
                        <Button type="button" variant="secondary" onClick={() => setShowForm(false)}>
                            <ArrowLeft className="mr-2 h-4 w-4" />
                            Back
                        </Button>
                        <Button type="submit" disabled={loading} className="flex-1 bg-blue-600 hover:bg-blue-700">
                            {loading ? <Loader2 className="h-4 w-4 animate-spin" /> : `Save & Continue`}
                        </Button>
                    </div>
                </form>
            )}
        </Modal>
    );
}
