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
        <div className="space-y-6">
            <div className="flex justify-between items-center">
                <h3 className="text-lg font-semibold text-gray-900">Marketing Assets</h3>
                <Button onClick={() => setIsAdding(!isAdding)} size="sm">
                    <Upload className="h-4 w-4 mr-2" />
                    Add Asset
                </Button>
            </div>

            {isAdding && (
                <div className="bg-gray-50 p-4 rounded-lg border border-gray-200 space-y-3">
                    <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                        <Input
                            placeholder="Asset Name (e.g. 2025 Brochure)"
                            value={newItem.name}
                            onChange={e => setNewItem({ ...newItem, name: e.target.value })}
                        />
                        <select
                            className="flex h-10 w-full rounded-md border border-input bg-background px-3 py-2 text-sm ring-offset-background file:border-0 file:bg-transparent file:text-sm file:font-medium placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50"
                            value={newItem.asset_type}
                            onChange={e => setNewItem({ ...newItem, asset_type: e.target.value as any })}
                        >
                            <option value="brochure">Brochure</option>
                            <option value="catalog">Catalog</option>
                            <option value="whitepaper">Whitepaper</option>
                            <option value="other">Other</option>
                        </select>
                    </div>
                    <Input
                        placeholder="File URL (Public link to PDF/Doc)"
                        value={newItem.file_url}
                        onChange={e => setNewItem({ ...newItem, file_url: e.target.value })}
                    />
                    <div className="flex justify-end gap-2">
                        <Button variant="ghost" size="sm" onClick={() => setIsAdding(false)}>Cancel</Button>
                        <Button size="sm" onClick={handleAdd}>Save</Button>
                    </div>
                </div>
            )}

            <div className="grid gap-3">
                {assets.map(asset => (
                    <div key={asset.id} className="flex items-center justify-between p-3 bg-white border border-gray-100 rounded-lg shadow-sm">
                        <div className="flex items-center gap-3">
                            <div className="p-2 bg-blue-50 rounded-lg text-blue-600">
                                <FileText className="h-5 w-5" />
                            </div>
                            <div>
                                <h4 className="font-medium text-gray-900">{asset.name}</h4>
                                <div className="text-xs text-gray-500 capitalize">{asset.asset_type}</div>
                            </div>
                        </div>
                        <div className="flex items-center gap-2">
                            <a href={asset.file_url} target="_blank" rel="noreferrer" className="text-gray-400 hover:text-blue-600 p-2">
                                <LinkIcon className="h-4 w-4" />
                            </a>
                            <Button variant="ghost" size="sm" onClick={() => handleDelete(asset.id)} className="text-gray-400 hover:text-red-600">
                                <Trash2 className="h-4 w-4" />
                            </Button>
                        </div>
                    </div>
                ))}
                {assets.length === 0 && !isAdding && (
                    <div className="text-center py-8 text-gray-500 text-sm">
                        No assets uploaded yet. Add brochures or catalogs to share in emails.
                    </div>
                )}
            </div>
        </div>
    );
}
