'use client';

import { useState, useEffect } from 'react';
import { Button } from '@/components/ui/Button';
import { Input } from '@/components/ui/Input';
import { FileText, Upload, Trash2, Link as LinkIcon, Download } from 'lucide-react';
import { createAsset, deleteAsset, MarketingAsset } from '@/app/actions/assets';
import { ConfirmDialog } from '@/components/ui/ConfirmDialog';
import { toast } from 'sonner';

interface MarketingAssetsProps {
    initialAssets: MarketingAsset[];
}

export function MarketingAssets({ initialAssets }: MarketingAssetsProps) {
    const [items, setItems] = useState<MarketingAsset[]>(initialAssets);
    const [isAdding, setIsAdding] = useState(false);
    const [isUploading, setIsUploading] = useState(false);
    const [newItem, setNewItem] = useState({ file_url: '' });
    const [selectedFile, setSelectedFile] = useState<File | null>(null);
    const [deleteConfirmOpen, setDeleteConfirmOpen] = useState(false);
    const [assetToDelete, setAssetToDelete] = useState<string | null>(null);
    const [isDeleting, setIsDeleting] = useState(false);

    // Sync state with props
    useEffect(() => {
        setItems(initialAssets);
    }, [initialAssets]);

    const handleAdd = async () => {
        if (!selectedFile) {
            toast.error('Please select a file');
            return;
        }

        setIsUploading(true);
        try {
            // 1. Upload file via Server Action/API
            const fileExt = selectedFile.name.split('.').pop();
            const fileName = `${Date.now()}-${Math.random().toString(36).substring(7)}.${fileExt}`;

            const formData = new FormData();
            formData.append('file', selectedFile);
            formData.append('fileName', fileName);

            const uploadResponse = await fetch('/api/upload', {
                method: 'POST',
                body: formData,
            });

            if (!uploadResponse.ok) {
                const errorData = await uploadResponse.json();
                throw new Error(errorData.error || 'Upload failed');
            }

            const { publicUrl } = await uploadResponse.json();

            // 2. Create Asset Record
            const assetData = {
                ...newItem,
                name: selectedFile.name, // Use original filename as name
                file_url: publicUrl,
                file_size: selectedFile.size
            };

            const result = await createAsset(assetData);
            if (result.success && result.asset) {
                toast.success('Asset uploaded successfully');
                setItems([result.asset, ...items]);
                setIsAdding(false);
                setSelectedFile(null);
                setNewItem({ file_url: '' });
            } else {
                throw new Error(result.error || 'Failed to create asset record');
            }
        } catch (error: any) {
            console.error('Upload failed:', error);
            toast.error(error.message || 'Failed to upload asset');
        } finally {
            setIsUploading(false);
        }
    };

    const handleDelete = (id: string) => {
        setAssetToDelete(id);
        setDeleteConfirmOpen(true);
    };

    const confirmDelete = async () => {
        if (!assetToDelete) return;

        setIsDeleting(true);
        const result = await deleteAsset(assetToDelete);
        if (result.success) {
            setItems(items.filter(a => a.id !== assetToDelete));
            toast.success('Asset deleted successfully');
        } else {
            toast.error('Failed to delete asset');
        }
        setIsDeleting(false);
        setDeleteConfirmOpen(false);
        setAssetToDelete(null);
    };

    return (
        <div className="space-y-0">
            <div className="px-8 py-6 border-b border-stone-100 bg-stone-50/30 flex items-center justify-between">
                <div>
                    <h3 className="text-sm font-black text-stone-900 uppercase tracking-widest">Marketing Assets</h3>
                    <p className="text-[9px] font-bold text-stone-400 uppercase tracking-[0.1em] mt-0.5">Resources & Collateral</p>
                </div>
                <Button
                    onClick={() => setIsAdding(!isAdding)}
                    size="sm"
                    className="h-8 rounded-lg bg-stone-900 hover:bg-black text-[10px] font-bold text-white px-4 transition-all shadow-sm"
                >
                    <Upload className="h-3 w-3 mr-2" />
                    Add
                </Button>
            </div>

            <div className="p-8 space-y-6">

                {isAdding && (
                    <div className="bg-stone-50/50 p-6 rounded-2xl border border-stone-200 space-y-4 animate-in fade-in slide-in-from-top-4 duration-300">
                        <div className="grid grid-cols-1 gap-4">
                        </div>

                        <div className="relative">
                            <input
                                type="file"
                                id="asset-upload"
                                className="hidden"
                                onChange={(e) => {
                                    if (e.target.files?.[0]) {
                                        setSelectedFile(e.target.files[0]);
                                    }
                                }}
                            />
                            <label
                                htmlFor="asset-upload"
                                className="flex items-center justify-center w-full h-32 border-2 border-dashed border-stone-200 rounded-xl cursor-pointer hover:border-stone-400 hover:bg-stone-50 transition-colors"
                            >
                                <div className="flex flex-col items-center gap-2">
                                    {selectedFile ? (
                                        <>
                                            <FileText className="w-8 h-8 text-stone-900" />
                                            <p className="text-sm font-bold text-stone-900">{selectedFile.name}</p>
                                            <p className="text-xs text-stone-500">{(selectedFile.size / 1024 / 1024).toFixed(2)} MB</p>
                                            <p className="text-xs text-stone-400 mt-2">Click to replace</p>
                                        </>
                                    ) : (
                                        <>
                                            <Upload className="w-8 h-8 text-stone-300" />
                                            <p className="text-sm font-bold text-stone-400">Click to upload document</p>
                                            <p className="text-xs text-stone-300">PDF, DOC, DOCX up to 10MB</p>
                                        </>
                                    )}
                                </div>
                            </label>
                        </div>

                        <div className="flex justify-end gap-3 pt-2">
                            <Button
                                variant="ghost"
                                size="sm"
                                onClick={() => {
                                    setIsAdding(false);
                                    setSelectedFile(null);
                                    setNewItem({ file_url: '' });
                                }}
                                className="text-stone-500"
                            >
                                Cancel
                            </Button>
                            <Button
                                size="sm"
                                onClick={handleAdd}
                                disabled={isUploading || !selectedFile}
                                className="bg-stone-900 text-white rounded-lg px-6"
                            >
                                {isUploading ? (
                                    <>Uploading...</>
                                ) : (
                                    <>Save Asset</>
                                )}
                            </Button>
                        </div>
                    </div>
                )}

                <div className="grid gap-3">
                    {items.map(asset => (
                        <div key={asset.id} className="group flex items-center justify-between p-4 bg-white border border-stone-100 rounded-2xl hover:shadow-xl hover:shadow-stone-100 transition-all duration-300">
                            <div className="flex items-center gap-4">
                                <div className="w-10 h-10 bg-stone-50 rounded-xl flex items-center justify-center text-stone-400 group-hover:bg-stone-900 group-hover:text-white transition-all duration-500">
                                    <FileText className="h-5 w-5" />
                                </div>
                                <div>
                                    <h4 className="font-bold text-stone-900 text-sm">{asset.name}</h4>
                                </div>
                            </div>
                            <div className="flex items-center gap-2 opacity-0 group-hover:opacity-100 transition-opacity duration-300">
                                <a
                                    href={asset.file_url}
                                    target="_blank"
                                    rel="noreferrer"
                                    className="w-8 h-8 flex items-center justify-center rounded-full bg-stone-50 text-stone-400 hover:bg-stone-900 hover:text-white transition-all"
                                    title="Download"
                                >
                                    <Download className="h-4 w-4" />
                                </a>
                                <button
                                    onClick={() => handleDelete(asset.id)}
                                    className="w-8 h-8 flex items-center justify-center rounded-full bg-stone-50 text-stone-400 hover:bg-red-50 hover:text-red-600 transition-all"
                                    title="Delete"
                                >
                                    <Trash2 className="h-4 w-4" />
                                </button>
                            </div>
                        </div>
                    ))}
                    {items.length === 0 && !isAdding && (
                        <div className="text-center py-12 bg-stone-50/50 rounded-3xl border-2 border-dashed border-stone-100">
                            <p className="text-stone-400 text-xs italic">No assets added yet.</p>
                        </div>
                    )}
                </div>
            </div>

            <ConfirmDialog
                isOpen={deleteConfirmOpen}
                onClose={() => setDeleteConfirmOpen(false)}
                onConfirm={confirmDelete}
                title="Delete Asset"
                description="Are you sure you want to delete this marketing asset? This action cannot be undone."
                confirmText="Delete"
                variant="danger"
                isLoading={isDeleting}
            />
        </div>
    );
}
