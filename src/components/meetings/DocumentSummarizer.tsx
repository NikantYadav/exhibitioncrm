'use client';

import { useState } from 'react';
import { Button } from '@/components/ui/Button';
import { Card, CardContent } from '@/components/ui/Card';
import { FileText, Upload, Trash2, Loader2, Sparkles } from 'lucide-react';

interface DocumentSummary {
    id: string;
    name: string;
    url: string;
    summary: string;
    key_points: string[];
}

interface DocumentSummarizerProps {
    meetingId: string;
    documents?: DocumentSummary[];
    onUpload: (url: string) => Promise<void>;
}

import { toast } from 'sonner';

export function DocumentSummarizer({ meetingId, documents = [], onUpload }: DocumentSummarizerProps) {
    const [fileUrl, setFileUrl] = useState('');
    const [isAnalyzing, setIsAnalyzing] = useState(false);

    const handleAnalyze = async () => {
        if (!fileUrl) return;
        setIsAnalyzing(true);
        const analysisToast = toast.loading('Analyzing document with AI...');
        try {
            await onUpload(fileUrl);
            setFileUrl('');
            toast.success('Document analyzed successfully!', { id: analysisToast });
        } catch (error) {
            console.error('Analysis failed', error);
            toast.error('Failed to analyze document', { id: analysisToast });
        } finally {
            setIsAnalyzing(false);
        }
    };

    return (
        <div className="space-y-6">
            <div className="flex items-center justify-between">
                <div>
                    <h3 className="text-lg font-semibold text-gray-900">Shared Documents</h3>
                    <p className="text-sm text-gray-500">Upload documents to generate AI summaries and key points</p>
                </div>
            </div>

            {/* Upload Area */}
            <div className="bg-gray-50 border border-gray-200 rounded-lg p-4">
                <div className="flex gap-4">
                    <input
                        type="text"
                        value={fileUrl}
                        onChange={(e) => setFileUrl(e.target.value)}
                        placeholder="Paste document URL (PDF/Doc)..."
                        className="flex-1 rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm p-2"
                    />
                    <Button onClick={handleAnalyze} disabled={!fileUrl || isAnalyzing}>
                        {isAnalyzing ? (
                            <>
                                <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                                Analyzing...
                            </>
                        ) : (
                            <>
                                <Sparkles className="h-4 w-4 mr-2" />
                                Analyze
                            </>
                        )}
                    </Button>
                </div>
            </div>

            {/* Documents List */}
            <div className="grid gap-4">
                {documents.map((doc) => (
                    <Card key={doc.id}>
                        <CardContent className="p-4">
                            <div className="flex items-start justify-between mb-4">
                                <div className="flex items-center gap-3">
                                    <div className="p-2 bg-red-50 rounded-lg">
                                        <FileText className="h-5 w-5 text-red-600" />
                                    </div>
                                    <div>
                                        <h4 className="font-medium text-gray-900">{doc.name}</h4>
                                        <a href={doc.url} target="_blank" rel="noopener noreferrer" className="text-xs text-indigo-600 hover:text-indigo-800">
                                            View Original
                                        </a>
                                    </div>
                                </div>
                                <Button variant="ghost" size="sm" className="text-gray-400 hover:text-red-600">
                                    <Trash2 className="h-4 w-4" />
                                </Button>
                            </div>

                            <div className="bg-gray-50 rounded-lg p-3 text-sm text-gray-700 mb-3">
                                <p className="leading-relaxed">{doc.summary}</p>
                            </div>

                            <div>
                                <h5 className="text-xs font-semibold text-gray-500 uppercase tracking-wider mb-2">Key Points</h5>
                                <ul className="list-disc list-inside space-y-1">
                                    {doc.key_points.map((point, i) => (
                                        <li key={i} className="text-sm text-gray-600">{point}</li>
                                    ))}
                                </ul>
                            </div>
                        </CardContent>
                    </Card>
                ))}

                {documents.length === 0 && (
                    <div className="text-center py-8 text-gray-400 border-2 border-dashed border-gray-200 rounded-lg">
                        <FileText className="h-8 w-8 mx-auto mb-2 opacity-50" />
                        <p className="text-sm">No documents analyzed yet</p>
                    </div>
                )}
            </div>
        </div>
    );
}
