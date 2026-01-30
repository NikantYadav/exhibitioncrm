'use client';

import { useState } from 'react';
import { Button } from '@/components/ui/Button';
import { Input } from '@/components/ui/Input';
import { FileText, Upload, Trash2, Link as LinkIcon, Download } from 'lucide-react';
import { createAsset, deleteAsset, MarketingAsset } from '@/app/actions/assets';
import { toast } from 'sonner';

interface MarketingAssetsProps {
    initialAssets: MarketingAsset[];
}

export function MarketingAssets({ initialAssets }: MarketingAssetsProps) {
    const [assets, setAssets] = useState<MarketingAsset[]>(initialAssets);
    const [isAdding, setIsAdding] = useState(false);
    const [newItem, setNewItem] = useState({ name: '', file_url: '', asset_type: 'brochure' as const });

    const handleAdd = async () => {
        if (!newItem.name || !newItem.file_url) return;

        const result = await createAsset(newItem);
        if (result.success) {
            toast.success('Asset added successfully');
            window.location.reload();
        } else {
            toast.error('Failed to add asset');
        }
    };

    const handleDelete = async (id: string) => {
        if (!confirm('Delete this asset?')) return;

        const result = await deleteAsset(id);
        if (result.success) {
            setAssets(assets.filter(a => a.id !== id));
            toast.success('Asset deleted successfully');
        } else {
            toast.error('Failed to delete asset');
        }
    };

    return (
        <div className="space-y-8 p-6">
            <div className="flex justify-between items-center">
                <div>
                    <h3 className="text-section-header">Asset Repository</h3>
                    <p className="text-[10px] font-bold text-stone-400 uppercase tracking-widest">Brochures, Catalogs & Whitepapers</p>
                </div>
                <Button
                    onClick={() => setIsAdding(!isAdding)}
                    size="sm"
                    className="rounded-full bg-stone-900 hover:bg-black text-white px-6 transition-all shadow-lg shadow-stone-200"
                >
                    <Upload className="h-4 w-4 mr-2" />
                    Ingest Asset
                </Button>
            </div>

            {isAdding && (
                <div className="bg-stone-50/50 p-6 rounded-2xl border border-stone-200 space-y-4 animate-in fade-in slide-in-from-top-4 duration-300">
                    <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                        <Input
                            placeholder="Identify Asset (e.g. Q1 2026 Portfolio)"
                            value={newItem.name}
                            onChange={e => setNewItem({ ...newItem, name: e.target.value })}
                            className="bg-white border-stone-200"
                        />
                        <select
                            className="flex h-10 w-full rounded-xl border border-stone-200 bg-white px-3 py-2 text-sm focus:ring-1 focus:ring-stone-900 transition-all font-medium"
                            value={newItem.asset_type}
                            onChange={e => setNewItem({ ...newItem, asset_type: e.target.value as any })}
                        >
                            <option value="brochure">Brochure</option>
                            <option value="catalog">Catalog</option>
                            <option value="whitepaper">Whitepaper</option>
                            <option value="other">Other Archive</option>
                        </select>
                    </div>
                    <Input
                        placeholder="Public Access URL (Secure PDF / Document Link)"
                        value={newItem.file_url}
                        onChange={e => setNewItem({ ...newItem, file_url: e.target.value })}
                        className="bg-white border-stone-200"
                    />
                    <div className="flex justify-end gap-3 pt-2">
                        <Button variant="ghost" size="sm" onClick={() => setIsAdding(false)} className="text-stone-500">Cancel</Button>
                        <Button
                            size="sm"
                            onClick={handleAdd}
                            className="bg-stone-900 text-white rounded-lg px-6"
                        >
                            Commit Asset
                        </Button>
                    </div>
                </div>
            )}

            <div className="grid gap-4">
                {assets.map(asset => (
                    <div key={asset.id} className="group flex items-center justify-between p-4 bg-white border border-stone-100 rounded-2xl hover:shadow-xl hover:shadow-stone-100 transition-all duration-300">
                        <div className="flex items-center gap-4">
                            <div className="w-12 h-12 bg-stone-50 rounded-xl flex items-center justify-center text-stone-400 group-hover:bg-stone-900 group-hover:text-white transition-all duration-500">
                                <FileText className="h-6 w-6" />
                            </div>
                            <div>
                                <h4 className="font-bold text-stone-900">{asset.name}</h4>
                                <div className="text-[10px] text-stone-400 font-bold uppercase tracking-widest">{asset.asset_type}</div>
                            </div>
                        </div>
                        <div className="flex items-center gap-2 opacity-0 group-hover:opacity-100 transition-opacity duration-300">
                            <a
                                href={asset.file_url}
                                target="_blank"
                                rel="noreferrer"
                                className="w-9 h-9 flex items-center justify-center rounded-full bg-stone-50 text-stone-400 hover:bg-stone-900 hover:text-white transition-all"
                                title="Download"
                            >
                                <Download className="h-4 w-4" />
                            </a>
                            <button
                                onClick={() => handleDelete(asset.id)}
                                className="w-9 h-9 flex items-center justify-center rounded-full bg-stone-50 text-stone-400 hover:bg-red-50 hover:text-red-600 transition-all"
                                title="Delete Archive"
                            >
                                <Trash2 className="h-4 w-4" />
                            </button>
                        </div>
                    </div>
                ))}
                {assets.length === 0 && !isAdding && (
                    <div className="text-center py-16 bg-stone-50/50 rounded-[2rem] border-2 border-dashed border-stone-100">
                        <div className="w-16 h-16 bg-white rounded-2xl flex items-center justify-center mx-auto mb-4 shadow-sm border border-stone-50">
                            <FileText className="h-6 w-6 text-stone-300" />
                        </div>
                        <p className="text-stone-400 font-medium italic">No assets committed to repository yet.</p>
                        <p className="text-[10px] text-stone-300 uppercase tracking-widest mt-1">Upload marketing decks for AI-generated follow-ups</p>
                    </div>
                )}
            </div>
        </div>
    );
}
