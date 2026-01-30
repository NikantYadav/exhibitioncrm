'use client';

import { useState } from 'react';
import { Button } from '@/components/ui/Button';
import { ConfidenceScore } from '@/components/ui/ConfidenceScore';
import { Upload, X, Check, Loader2 } from 'lucide-react';

interface BatchItem {
    id: string;
    file: File;
    preview: string;
    status: 'pending' | 'processing' | 'completed' | 'failed';
    extractedData?: any;
    error?: string;
}

interface BatchCaptureProps {
    onComplete: (items: BatchItem[]) => void;
    onCancel: () => void;
}

export function BatchCapture({ onComplete, onCancel }: BatchCaptureProps) {
    const [items, setItems] = useState<BatchItem[]>([]);
    const [processing, setProcessing] = useState(false);

    const handleFileSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
        const files = Array.from(e.target.files || []);
        const newItems: BatchItem[] = files.map((file, index) => ({
            id: `${Date.now()}-${index}`,
            file,
            preview: URL.createObjectURL(file),
            status: 'pending'
        }));

        setItems(prev => [...prev, ...newItems]);
    };

    const removeItem = (id: string) => {
        setItems(prev => prev.filter(item => item.id !== id));
    };

    const processAll = async () => {
        setProcessing(true);

        for (const item of items) {
            if (item.status !== 'pending') continue;

            // Update status to processing
            setItems(prev => prev.map(i =>
                i.id === item.id ? { ...i, status: 'processing' as const } : i
            ));

            try {
                // Simulate OCR processing (replace with actual OCR call)
                await new Promise(resolve => setTimeout(resolve, 2000));

                // Mock extracted data
                const extractedData = {
                    name: { value: 'John Doe', confidence: 0.85 },
                    email: { value: 'john@example.com', confidence: 0.9 },
                    company: { value: 'Acme Corp', confidence: 0.75 }
                };

                setItems(prev => prev.map(i =>
                    i.id === item.id
                        ? { ...i, status: 'completed' as const, extractedData }
                        : i
                ));
            } catch (error) {
                setItems(prev => prev.map(i =>
                    i.id === item.id
                        ? { ...i, status: 'failed' as const, error: 'Processing failed' }
                        : i
                ));
            }
        }

        setProcessing(false);
    };

    const completedItems = items.filter(i => i.status === 'completed');
    const canComplete = completedItems.length > 0;

    return (
        <div className="space-y-4">
            {/* Header */}
            <div className="flex items-center justify-between">
                <div>
                    <h3 className="text-lg font-semibold">Batch Card Processing</h3>
                    <p className="text-sm text-gray-600">
                        {items.length} cards • {completedItems.length} processed
                    </p>
                </div>
                <Button variant="ghost" size="sm" onClick={onCancel}>
                    <X className="h-4 w-4" />
                </Button>
            </div>

            {/* Upload Area */}
            {!processing && (
                <label className="block">
                    <input
                        type="file"
                        multiple
                        accept="image/*"
                        onChange={handleFileSelect}
                        className="hidden"
                    />
                    <div className="border-2 border-dashed border-gray-300 rounded-lg p-8 text-center hover:border-blue-500 cursor-pointer transition-colors">
                        <Upload className="h-12 w-12 text-gray-400 mx-auto mb-3" />
                        <p className="text-sm text-gray-600">
                            Click to upload or drag and drop
                        </p>
                        <p className="text-xs text-gray-500 mt-1">
                            Upload multiple business card images
                        </p>
                    </div>
                </label>
            )}

            {/* Items Grid */}
            {items.length > 0 && (
                <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
                    {items.map((item) => (
                        <div
                            key={item.id}
                            className="relative border border-gray-200 rounded-lg overflow-hidden"
                        >
                            {/* Image */}
                            <img
                                src={item.preview}
                                alt="Card"
                                className="w-full h-32 object-cover"
                            />

                            {/* Status Overlay */}
                            <div className="absolute inset-0 bg-black bg-opacity-50 flex items-center justify-center">
                                {item.status === 'pending' && (
                                    <span className="text-white text-xs">Pending</span>
                                )}
                                {item.status === 'processing' && (
                                    <Loader2 className="h-6 w-6 text-white animate-spin" />
                                )}
                                {item.status === 'completed' && (
                                    <Check className="h-6 w-6 text-green-500" />
                                )}
                                {item.status === 'failed' && (
                                    <X className="h-6 w-6 text-red-500" />
                                )}
                            </div>

                            {/* Remove Button */}
                            {!processing && (
                                <button
                                    onClick={() => removeItem(item.id)}
                                    className="absolute top-1 right-1 bg-white rounded-full p-1 shadow-md hover:bg-gray-100"
                                >
                                    <X className="h-3 w-3" />
                                </button>
                            )}
                        </div>
                    ))}
                </div>
            )}

            {/* Progress Bar */}
            {processing && (
                <div className="bg-blue-50 rounded-lg p-4">
                    <div className="flex items-center justify-between mb-2">
                        <span className="text-sm font-medium text-blue-900">
                            Processing cards...
                        </span>
                        <span className="text-sm text-blue-700">
                            {completedItems.length} / {items.length}
                        </span>
                    </div>
                    <div className="bg-blue-200 rounded-full h-2 overflow-hidden">
                        <div
                            className="bg-blue-600 h-full transition-all duration-300"
                            style={{ width: `${(completedItems.length / items.length) * 100}%` }}
                        />
                    </div>
                </div>
            )}

            {/* Actions */}
            <div className="flex gap-3">
                {!processing && items.length > 0 && (
                    <Button onClick={processAll} className="flex-1">
                        Process All Cards
                    </Button>
                )}
                {!processing && canComplete && (
                    <Button onClick={() => onComplete(completedItems)} variant="outline">
                        <Check className="mr-2 h-4 w-4" />
                        Accept {completedItems.length} Cards
                    </Button>
                )}
            </div>
        </div>
    );
}
