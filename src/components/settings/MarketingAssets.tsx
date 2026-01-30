'use client';

import { useState, useEffect } from 'react';
import { Button } from '@/components/ui/Button';
import { Input } from '@/components/ui/Input';
import { FileText, Upload, Trash2, Link as LinkIcon, Download, Database } from 'lucide-react';
import { createAsset, deleteAsset, MarketingAsset } from '@/app/actions/assets';
import { ConfirmDialog } from '@/components/ui/ConfirmDialog';
import { toast } from 'sonner';

interface MarketingAssetsProps {
    initialAssets: MarketingAsset[];
}

const ALLOWED_MIME_TYPES = [
    'application/pdf',
    'application/vnd.ms-powerpoint',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'text/markdown'
];

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
                    <h3 className="text-xs font-black text-stone-900 uppercase tracking-[0.2em]">Marketing Assets</h3>
                    <p className="text-[10px] font-bold text-stone-400 uppercase tracking-[0.1em] mt-1 italic">Collateral Nexus</p>
                </div>
                <Button
                    onClick={() => setIsAdding(!isAdding)}
                    size="sm"
                    className="h-9 px-5 rounded-xl bg-stone-900 hover:bg-stone-800 text-white font-black uppercase tracking-widest text-[10px] shadow-lg shadow-stone-900/10 transition-all active:scale-95"
                >
                    <Upload className="h-3.5 w-3.5 mr-2" strokeWidth={2.5} />
                    Deploy Asset
                </Button>
            </div>

            <div className="p-8 space-y-8">

                {isAdding && (
                    <div className="bg-stone-900 p-8 rounded-[2rem] border border-white/10 space-y-6 animate-in fade-in slide-in-from-top-4 duration-500 shadow-2xl relative overflow-hidden group">
                        <div className="absolute top-0 right-0 p-8 opacity-5 -rotate-12 translate-x-4 -translate-y-4 group-hover:scale-110 transition-transform duration-700">
                            <Database size={100} strokeWidth={2} />
                        </div>

                        <div className="relative z-10">
                            <input
                                type="file"
                                id="asset-upload"
                                className="hidden"
                                accept={ALLOWED_MIME_TYPES.join(',')}
                                onChange={(e) => {
                                    const file = e.target.files?.[0];
                                    if (file) {
                                        if (!ALLOWED_MIME_TYPES.includes(file.type)) {
                                            toast.error('Unsupported file type');
                                            return;
                                        }
                                        setSelectedFile(file);
                                    }
                                }}
                            />
                            <label
                                htmlFor="asset-upload"
                                className="flex items-center justify-center w-full h-40 border-2 border-dashed border-white/20 rounded-2xl cursor-pointer hover:border-white/40 hover:bg-white/5 transition-all group/upload"
                            >
                                <div className="flex flex-col items-center gap-3">
                                    {selectedFile ? (
                                        <>
                                            <div className="p-3 bg-white rounded-xl shadow-lg">
                                                <FileText className="w-6 h-6 text-stone-900" strokeWidth={2.5} />
                                            </div>
                                            <p className="text-sm font-black text-white">{selectedFile.name}</p>
                                            <p className="text-[10px] font-bold text-white/40 uppercase tracking-widest">{(selectedFile.size / 1024 / 1024).toFixed(2)} MB</p>
                                        </>
                                    ) : (
                                        <>
                                            <div className="p-3 bg-white/10 rounded-xl group-hover/upload:bg-white/20 transition-colors">
                                                <Upload className="w-6 h-6 text-white" strokeWidth={2.5} />
                                            </div>
                                            <p className="text-sm font-black text-white/80">Select strategic document</p>
                                            <p className="text-[10px] font-bold text-white/30 uppercase tracking-widest">PDF, Word, PPT (Max 10MB)</p>
                                        </>
                                    )}
                                </div>
                            </label>
                        </div>

                        <div className="flex justify-end items-center gap-6 relative z-10 pt-2">
                            <button
                                onClick={() => {
                                    setIsAdding(false);
                                    setSelectedFile(null);
                                    setNewItem({ file_url: '' });
                                }}
                                className="text-xs font-black uppercase tracking-widest text-white/40 hover:text-white transition-colors"
                            >
                                Cancel
                            </button>
                            <Button
                                size="lg"
                                onClick={handleAdd}
                                disabled={isUploading || !selectedFile}
                                className="bg-white hover:bg-stone-100 text-stone-900 rounded-xl px-8 font-black uppercase tracking-widest text-[10px] shadow-xl"
                            >
                                {isUploading ? (
                                    <>Processing...</>
                                ) : (
                                    <>Commit Asset</>
                                )}
                            </Button>
                        </div>
                    </div>
                )}

                <div className="grid gap-4">
                    {items.map(asset => (
                        <div key={asset.id} className="group flex items-center justify-between p-5 bg-white border border-stone-100 rounded-2xl hover:shadow-2xl hover:shadow-stone-900/5 transition-all duration-500">
                            <div className="flex items-center gap-5">
                                <div className="w-12 h-12 bg-stone-900 text-white rounded-xl shadow-lg flex items-center justify-center group-hover:scale-110 transition-transform duration-500">
                                    <FileText className="h-5 w-5" strokeWidth={2.5} />
                                </div>
                                <div className="min-w-0">
                                    <h4 className="font-black text-stone-900 text-sm truncate max-w-[200px]">{asset.name}</h4>
                                    <p className="text-[10px] font-black text-stone-400 uppercase tracking-widest mt-1">Available Asset</p>
                                </div>
                            </div>
                            <div className="flex items-center gap-3 opacity-0 group-hover:opacity-100 translate-x-4 group-hover:translate-x-0 transition-all duration-500">
                                <a
                                    href={asset.file_url}
                                    target="_blank"
                                    rel="noreferrer"
                                    className="w-10 h-10 flex items-center justify-center rounded-xl bg-stone-50 text-stone-400 hover:bg-stone-900 hover:text-white transition-all shadow-sm"
                                    title="Download"
                                >
                                    <Download className="h-4 w-4" strokeWidth={2.5} />
                                </a>
                                <button
                                    onClick={() => handleDelete(asset.id)}
                                    className="w-10 h-10 flex items-center justify-center rounded-xl bg-stone-50 text-stone-400 hover:bg-stone-900 hover:text-white transition-all shadow-sm"
                                    title="Delete"
                                >
                                    <Trash2 className="h-4 w-4" strokeWidth={2.5} />
                                </button>
                            </div>
                        </div>
                    ))}
                    {items.length === 0 && !isAdding && (
                        <div className="text-center py-16 bg-stone-50/50 rounded-[2.5rem] border-2 border-dashed border-stone-100">
                            <div className="h-16 w-16 bg-white border border-stone-100 rounded-2xl flex items-center justify-center mx-auto mb-4 text-stone-300 shadow-sm">
                                <Database className="w-8 h-8" strokeWidth={1.5} />
                            </div>
                            <p className="text-[10px] font-black text-stone-400 uppercase tracking-[0.2em]">Depository Empty</p>
                            <p className="text-sm font-medium text-stone-400 mt-2 italic">Upload collateral for relationship acceleration.</p>
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
