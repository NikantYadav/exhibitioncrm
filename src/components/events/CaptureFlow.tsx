'use client';

import { useState, useEffect } from 'react';
import dynamic from 'next/dynamic';
import { Card, CardContent } from '@/components/ui/Card';
import { Button } from '@/components/ui/Button';
import { Input } from '@/components/ui/Input';
import { Textarea } from '@/components/ui/Textarea';
import { useCamera } from '@/lib/hooks/useCamera';
import { toast } from 'sonner';
import {
    Camera,
    Upload,
    Keyboard,
    QrCode,
    Mic,
    X,
    Check,
    Loader2,
    RefreshCw,
    IdCard,
    Download
} from 'lucide-react';

// Dynamic imports to prevent SSR issues
const QrScanner = dynamic(() => import('@/components/capture/QrScanner'), {
    ssr: false,
    loading: () => <div className="h-[400px] flex items-center justify-center text-white bg-black rounded-lg">Loading Scanner...</div>
});

const VoiceRecorder = dynamic(() => import('@/components/capture/VoiceRecorder'), {
    ssr: false,
    loading: () => <div className="p-12 text-center text-gray-500">Loading Recorder...</div>
});

const BadgeScanner = dynamic(() => import('@/components/capture/BadgeScanner').then(mod => ({ default: mod.BadgeScanner })), {
    ssr: false,
    loading: () => <div className="h-[400px] flex items-center justify-center text-white bg-black rounded-lg">Loading Badge Scanner...</div>
});

const PhotoNoteCapture = dynamic(() => import('@/components/capture/PhotoNoteCapture').then(mod => ({ default: mod.PhotoNoteCapture })), {
    ssr: false,
    loading: () => <div className="h-[400px] flex items-center justify-center text-white bg-black rounded-lg">Loading Photo Capture...</div>
});

export type CaptureMode = 'camera' | 'upload' | 'manual' | 'qr' | 'voice' | 'badge' | 'photo_note';

interface CaptureFlowProps {
    eventId: string;
    mode: CaptureMode | null;
    onClose: () => void;
    onComplete: (data: any) => void;
}

export function CaptureFlow({ eventId, mode, onClose, onComplete }: CaptureFlowProps) {
    const [captureMode, setCaptureMode] = useState<CaptureMode | null>(mode);
    const [capturedImage, setCapturedImage] = useState<string | null>(null);
    const [isProcessing, setIsProcessing] = useState(false);
    const [manualData, setManualData] = useState({
        first_name: '',
        last_name: '',
        email: '',
        phone: '',
        company_name: '',
        job_title: '',
        notes: '',
        event_id: eventId
    });

    const camera = useCamera({ facingMode: 'environment' });

    useEffect(() => {
        setCaptureMode(mode);
        if (!mode) {
            setCapturedImage(null);
        }
    }, [mode]);

    const handleCameraCapture = () => {
        const photo = camera.capturePhoto();
        if (photo) {
            setCapturedImage(photo);
            camera.stopCamera();
        }
    };

    const handleFileUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
        const file = e.target.files?.[0];
        if (file) {
            const reader = new FileReader();
            reader.onload = (event) => {
                setCapturedImage(event.target?.result as string);
            };
            reader.readAsDataURL(file);
        }
    };

    const handleQrScan = (rawValue: string) => {
        toast.success(`QR Code Scanned: ${rawValue}`);
        // In a real app, we'd process this. For now just close.
        onComplete({ qr_data: rawValue });
    };

    const processCard = async () => {
        if (!capturedImage) return;

        setIsProcessing(true);
        const processingToast = toast.loading('AI is analyzing business card...');
        try {
            // Step 1: Analyze image with advanced AI (multimodal)
            const analyzeResponse = await fetch('/api/ai/analyze-card', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ image: capturedImage }),
            });

            if (!analyzeResponse.ok) {
                const errorData = await analyzeResponse.json();
                throw new Error(errorData.error || 'AI analysis failed');
            }

            const { data: aiResult } = await analyzeResponse.json();
            console.log('Advanced AI Results:', aiResult);

            // Step 2: Create the capture record with the AI data
            const response = await fetch('/api/captures', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    image: capturedImage,
                    capture_type: captureMode === 'camera' ? 'card_scan' : 'photo_upload',
                    event_id: eventId,
                    extracted_data: {
                        name: aiResult.name || `${aiResult.first_name} ${aiResult.last_name}`.trim(),
                        first_name: aiResult.first_name,
                        last_name: aiResult.last_name,
                        email: aiResult.email,
                        phone: aiResult.phone,
                        company: aiResult.company,
                        jobTitle: aiResult.job_title,
                        website: aiResult.website,
                        address: aiResult.address
                    },
                    raw_text: JSON.stringify(aiResult, null, 2)
                }),
            });

            const result = await response.json();

            if (response.ok) {
                toast.success('Lead captured with AI!', { id: processingToast });
                onComplete(result);
            } else if (response.status === 422) {
                toast.error(result.error || 'Failed to find contact info', { id: processingToast, duration: 5000 });
            } else {
                toast.error(result.error || 'Failed to process card', { id: processingToast });
            }
        } catch (error: any) {
            console.error('Processing error:', error);
            toast.error(error.message || 'Failed to process card', { id: processingToast });
        } finally {
            setIsProcessing(false);
        }
    };

    const handleManualSave = async () => {
        if (!manualData.first_name) {
            toast.error('First name is required');
            return;
        }

        const loadingToast = toast.loading('Creating contact...');
        try {
            const response = await fetch('/api/contacts', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(manualData),
            });

            const result = await response.json();

            if (response.ok) {
                toast.success('Contact created successfully!', { id: loadingToast });
                onComplete(result);
            } else {
                toast.error(result.error || 'Failed to create contact', { id: loadingToast });
            }
        } catch (error) {
            console.error('Manual save error:', error);
            toast.error('Failed to create contact', { id: loadingToast });
        }
    };

    if (!captureMode) return null;

    return (
        <div className="w-full">
            {/* Header */}
            <div className="flex items-center justify-between mb-6">
                <Button
                    variant="ghost"
                    size="sm"
                    onClick={onClose}
                    className="text-gray-500 hover:text-gray-900"
                >
                    <X className="mr-2 h-4 w-4" />
                    Cancel
                </Button>
                <h3 className="font-bold text-lg capitalize">
                    {captureMode.replace('_', ' ')}
                </h3>
                <div className="w-20" />
            </div>

            {/* Content areas based on mode */}
            {captureMode === 'camera' && !capturedImage && (
                <div className="bg-black rounded-xl overflow-hidden relative min-h-[400px] flex items-center justify-center">
                    {!camera.isActive ? (
                        <div className="text-center p-8 text-white">
                            <Camera className="h-12 w-12 mx-auto mb-4 opacity-50" />
                            <h3 className="text-lg font-bold mb-2">Camera Access Needed</h3>
                            <Button onClick={camera.startCamera} size="sm" className="bg-white text-black hover:bg-gray-200">
                                Enable Camera
                            </Button>
                        </div>
                    ) : (
                        <>
                            <video
                                ref={camera.videoRef}
                                autoPlay
                                playsInline
                                className="w-full max-h-[500px] object-cover"
                            />
                            <div className="absolute bottom-6 left-0 right-0 flex justify-center">
                                <button
                                    onClick={handleCameraCapture}
                                    className="h-16 w-16 rounded-full border-4 border-white flex items-center justify-center bg-white/20 hover:bg-white/40 transition-colors"
                                >
                                    <div className="h-12 w-12 bg-white rounded-full" />
                                </button>
                            </div>
                        </>
                    )}
                </div>
            )}

            {captureMode === 'upload' && !capturedImage && (
                <div className="border-dashed border-2 border-gray-200 rounded-xl p-12 text-center">
                    <div className="h-16 w-16 bg-purple-50 rounded-full flex items-center justify-center mx-auto mb-4">
                        <Upload className="h-8 w-8 text-purple-600" />
                    </div>
                    <p className="text-gray-500 mb-6">Select an image from your device</p>
                    <label className="inline-flex">
                        <input type="file" accept="image/*" onChange={handleFileUpload} className="hidden" />
                        <Button asChild className="cursor-pointer bg-purple-600 hover:bg-purple-700">
                            <span>Select Image</span>
                        </Button>
                    </label>
                </div>
            )}

            {captureMode === 'qr' && (
                <QrScanner onScan={handleQrScan} />
            )}

            {captureMode === 'voice' && (
                <VoiceRecorder
                    onComplete={(data) => onComplete({ type: 'voice', ...data })}
                    onCancel={onClose}
                />
            )}

            {captureMode === 'badge' && (
                <BadgeScanner
                    onComplete={async (data: any) => {
                        const loadingToast = toast.loading('Saving badge data...');
                        try {
                            const response = await fetch('/api/captures', {
                                method: 'POST',
                                headers: { 'Content-Type': 'application/json' },
                                body: JSON.stringify({
                                    image: '',
                                    capture_type: 'badge_scan',
                                    event_id: eventId,
                                    extracted_data: data,
                                    raw_text: data.raw_text
                                }),
                            });
                            const result = await response.json();
                            if (response.ok) {
                                toast.success('Lead captured from badge!', { id: loadingToast });
                                onComplete(result);
                            } else if (response.status === 422) {
                                toast.error(result.error || 'Failed to find contact info', { id: loadingToast, duration: 5000 });
                            } else {
                                toast.error('Failed to save badge data', { id: loadingToast });
                            }
                        } catch (error) {
                            toast.error('Error saving badge data', { id: loadingToast });
                        }
                    }}
                    onCancel={onClose}
                />
            )}

            {captureMode === 'photo_note' && (
                <PhotoNoteCapture
                    onComplete={async (imageData: string, notes: string, extractedText: string) => {
                        const loadingToast = toast.loading('AI is processing photo...');
                        try {
                            // Step 1: AI analysis
                            const analyzeResponse = await fetch('/api/ai/analyze-card', {
                                method: 'POST',
                                headers: { 'Content-Type': 'application/json' },
                                body: JSON.stringify({ image: imageData }),
                            });

                            const { data: aiResult } = await analyzeResponse.json();
                            console.log('Advanced AI Results (Photo + Note):', aiResult);

                            // Step 2: Create capture
                            const response = await fetch('/api/captures', {
                                method: 'POST',
                                headers: { 'Content-Type': 'application/json' },
                                body: JSON.stringify({
                                    image: imageData,
                                    capture_type: 'photo_upload',
                                    event_id: eventId,
                                    extracted_data: {
                                        name: aiResult.name || `${aiResult.first_name} ${aiResult.last_name}`.trim(),
                                        first_name: aiResult.first_name,
                                        last_name: aiResult.last_name,
                                        email: aiResult.email,
                                        phone: aiResult.phone,
                                        company: aiResult.company,
                                        jobTitle: aiResult.job_title
                                    },
                                    raw_text: `Notes: ${notes}\n\nAI Extracted: ${JSON.stringify(aiResult, null, 2)}`
                                }),
                            });
                            const result = await response.json();
                            if (response.ok) {
                                toast.success('Lead captured with AI!', { id: loadingToast });
                                onComplete(result);
                            } else if (response.status === 422) {
                                toast.error(result.error || 'Failed to find contact info', { id: loadingToast, duration: 5000 });
                            } else {
                                toast.error('Failed to save photo', { id: loadingToast });
                            }
                        } catch (error) {
                            console.error('AI Catch error:', error);
                            toast.error('Error saving photo', { id: loadingToast });
                        }
                    }}
                    onCancel={onClose}
                />
            )}

            {captureMode === 'manual' && (
                <div className="space-y-4">
                    <div className="grid grid-cols-2 gap-4">
                        <Input
                            label="First Name"
                            placeholder="John"
                            value={manualData.first_name}
                            onChange={(e) => setManualData({ ...manualData, first_name: e.target.value })}
                        />
                        <Input
                            label="Last Name"
                            placeholder="Doe"
                            value={manualData.last_name}
                            onChange={(e) => setManualData({ ...manualData, last_name: e.target.value })}
                        />
                    </div>
                    <Input
                        label="Email"
                        type="email"
                        placeholder="john@example.com"
                        value={manualData.email}
                        onChange={(e) => setManualData({ ...manualData, email: e.target.value })}
                    />
                    <Input
                        label="Company"
                        placeholder="Acme Corp"
                        value={manualData.company_name}
                        onChange={(e) => setManualData({ ...manualData, company_name: e.target.value })}
                    />
                    <Textarea
                        label="Notes"
                        placeholder="Add details..."
                        value={manualData.notes}
                        onChange={(e) => setManualData({ ...manualData, notes: e.target.value })}
                    />
                    <div className="flex justify-end pt-4">
                        <Button onClick={handleManualSave} className="bg-emerald-600 hover:bg-emerald-700">
                            <Check className="mr-2 h-4 w-4" />
                            Save Lead
                        </Button>
                    </div>
                </div>
            )}

            {/* Preview and Process for Card/Upload */}
            {capturedImage && (
                <div className="space-y-4">
                    <div className="bg-gray-100 rounded-lg p-4 flex justify-center">
                        <img src={capturedImage} alt="Captured" className="max-h-[400px] rounded shadow-lg" />
                    </div>
                    <div className="flex justify-between items-center">
                        <Button variant="ghost" size="sm" onClick={() => setCapturedImage(null)}>
                            <RefreshCw className="mr-2 h-4 w-4" />
                            Retake
                        </Button>
                        <Button onClick={processCard} disabled={isProcessing}>
                            {isProcessing ? <Loader2 className="mr-2 h-4 w-4 animate-spin" /> : <Check className="mr-2 h-4 w-4" />}
                            Process Card
                        </Button>
                    </div>
                </div>
            )}
        </div>
    );
}
