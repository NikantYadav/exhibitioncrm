'use client';

import { useState } from 'react';
import { Button } from '@/components/ui/Button';
import { Card, CardContent } from '@/components/ui/Card';
import { FileText, Upload, Trash2, Loader2, Sparkles, Paperclip } from 'lucide-react';

interface ContactDocument {
    id: string;
    name: string;
    file_url: string;
    summary?: string;
    created_at: string;
}

interface DocumentUploadProps {
    contactId: string;
    documents: ContactDocument[];
    onUploadSuccess: () => void;
}

import { toast } from 'sonner';

export function DocumentUpload({ contactId, documents, onUploadSuccess }: DocumentUploadProps) {
    const [isUploading, setIsUploading] = useState(false);
    const [fileUrl, setFileUrl] = useState('');
    const [description, setDescription] = useState('');

    const handleUpload = async () => {
        if (!fileUrl) return;
        setIsUploading(true);
        const uploadToast = toast.loading('Uploading document...');

        try {
            // 1. Save document
            const response = await fetch('/api/documents', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    contact_id: contactId,
                    name: description || 'Uploaded Document',
                    file_url: fileUrl,
                    file_type: 'pdf' // Mocking for now
                })
            });

            if (!response.ok) throw new Error('Failed to upload');

            // 2. Trigger summarization (happens in background or API)

            onUploadSuccess();
            setFileUrl('');
            setDescription('');
            toast.success('Document uploaded successfully!', { id: uploadToast });
        } catch (error) {
            console.error('Upload failed', error);
            toast.error('Failed to upload document', { id: uploadToast });
        } finally {
            setIsUploading(false);
        }
    };

    return (
        <div className="space-y-6">
            <div className="flex items-center justify-between">
                <div>
                    <h3 className="text-lg font-semibold text-gray-900">Shared Documents</h3>
                    <p className="text-sm text-gray-500">Contracts, proposals, and other files shared with this contact</p>
                </div>
            </div>

            {/* Upload Area */}
            <div className="bg-white border border-gray-200 rounded-lg p-4 shadow-sm">
                <div className="space-y-3">
                    <input
                        type="text"
                        value={description}
                        onChange={(e) => setDescription(e.target.value)}
                        placeholder="Document Name (e.g. Q1 Proposal)"
                        className="w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm p-2"
                    />
                    <div className="flex gap-2">
                        <input
                            type="text"
                            value={fileUrl}
                            onChange={(e) => setFileUrl(e.target.value)}
                            placeholder="File URL..."
                            className="flex-1 rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm p-2"
                        />
                        <Button onClick={handleUpload} disabled={!fileUrl || isUploading}>
                            {isUploading ? (
                                <>
                                    <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                                    Saving...
                                </>
                            ) : (
                                <>
                                    <Upload className="h-4 w-4 mr-2" />
                                    Add Document
                                </>
                            )}
                        </Button>
                    </div>
                </div>
            </div>

            {/* Documents List */}
            <div className="grid gap-3">
                {documents.map((doc) => (
                    <Card key={doc.id}>
                        <CardContent className="p-4 flex items-start gap-3">
                            <div className="p-2 bg-blue-50 rounded-lg shrink-0">
                                <FileText className="h-5 w-5 text-blue-600" />
                            </div>
                            <div className="flex-1 min-w-0">
                                <h4 className="font-medium text-gray-900 truncate">{doc.name}</h4>
                                <div className="flex items-center gap-2 text-xs text-gray-500 mt-1">
                                    <span>{new Date(doc.created_at).toLocaleDateString()}</span>
                                    <span>•</span>
                                    <a href={doc.file_url} target="_blank" rel="noopener noreferrer" className="text-indigo-600 hover:text-indigo-800">
                                        View File
                                    </a>
                                </div>
                                {doc.summary && (
                                    <div className="mt-2 text-sm text-gray-600 bg-gray-50 p-2 rounded">
                                        <Sparkles className="h-3 w-3 inline mr-1 text-indigo-400" />
                                        {doc.summary}
                                    </div>
                                )}
                            </div>
                        </CardContent>
                    </Card>
                ))}

                {documents.length === 0 && (
                    <div className="text-center py-8 text-gray-400 border-2 border-dashed border-gray-200 rounded-lg">
                        <Paperclip className="h-8 w-8 mx-auto mb-2 opacity-50" />
                        <p className="text-sm">No documents uploaded</p>
                    </div>
                )}
            </div>
        </div>
    );
}
