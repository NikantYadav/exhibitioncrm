'use client';

import { useState, useEffect } from 'react';
import { useSearchParams } from 'next/navigation';
import dynamic from 'next/dynamic';
import { AppShell } from '@/components/layout/AppShell';
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
    IdCard
} from 'lucide-react';

// Dynamic imports to prevent SSR issues with browser-only libraries (Workers, Media APIs)
const QrScanner = dynamic(() => import('@/components/capture/QrScanner'), {
    ssr: false,
    loading: () => <div className="h-[400px] flex items-center justify-center text-white bg-black">Loading Scanner...</div>
});

const VoiceRecorder = dynamic(() => import('@/components/capture/VoiceRecorder'), {
    ssr: false,
    loading: () => <div className="p-12 text-center text-gray-500">Loading Recorder...</div>
});

const BadgeScanner = dynamic(() => import('@/components/capture/BadgeScanner').then(mod => ({ default: mod.BadgeScanner })), {
    ssr: false,
    loading: () => <div className="h-[400px] flex items-center justify-center text-white bg-black">Loading Badge Scanner...</div>
});

const PhotoNoteCapture = dynamic(() => import('@/components/capture/PhotoNoteCapture').then(mod => ({ default: mod.PhotoNoteCapture })), {
    ssr: false,
    loading: () => <div className="h-[400px] flex items-center justify-center text-white bg-black">Loading Photo Capture...</div>
});

export default function CapturePage() {
    const searchParams = useSearchParams();
    const eventIdParam = searchParams.get('event_id');
    const modeParam = searchParams.get('mode') as 'camera' | 'upload' | 'manual' | 'qr' | 'voice' | 'badge' | 'photo_note' | null;

    // Mode state
    const [captureMode, setCaptureMode] = useState<'camera' | 'upload' | 'manual' | 'qr' | 'voice' | 'badge' | 'photo_note' | null>(modeParam || null);
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
        event_id: eventIdParam || ''
    });

    useEffect(() => {
        if (modeParam) {
            setCaptureMode(modeParam);
        }
    }, [modeParam]);

    // Hooks
    const camera = useCamera({ facingMode: 'environment' });

    // Constants for unified design
    const captureModes = [
        {
            id: 'camera' as const,
            label: 'Scan Card',
            description: 'Use device camera',
            icon: Camera,
            gradient: 'from-blue-500 to-indigo-600',
            bg: 'bg-blue-50',
            border: 'border-blue-100',
            text: 'text-blue-700'
        },
        {
            id: 'upload' as const,
            label: 'Upload Photo',
            description: 'Choose from gallery',
            icon: Upload,
            gradient: 'from-purple-500 to-pink-600',
            bg: 'bg-purple-50',
            border: 'border-purple-100',
            text: 'text-purple-700'
        },
        {
            id: 'manual' as const,
            label: 'Manual Entry',
            description: 'Type details',
            icon: Keyboard,
            gradient: 'from-emerald-500 to-teal-600',
            bg: 'bg-emerald-50',
            border: 'border-emerald-100',
            text: 'text-emerald-700'
        },
        {
            id: 'qr' as const,
            label: 'QR Code',
            description: 'Scan QR code',
            icon: QrCode,
            gradient: 'from-amber-500 to-orange-600',
            bg: 'bg-amber-50',
            border: 'border-amber-100',
            text: 'text-amber-700'
        },
        {
            id: 'voice' as const,
            label: 'Voice Note',
            description: 'Record audio',
            icon: Mic,
            gradient: 'from-rose-500 to-red-600',
            bg: 'bg-rose-50',
            border: 'border-rose-100',
            text: 'text-rose-700'
        },
        {
            id: 'badge' as const,
            label: 'Event Badge',
            description: 'Scan badge',
            icon: IdCard,
            gradient: 'from-cyan-500 to-blue-600',
            bg: 'bg-cyan-50',
            border: 'border-cyan-100',
            text: 'text-cyan-700'
        },
        {
            id: 'photo_note' as const,
            label: 'Photo + Notes',
            description: 'Card with notes',
            icon: Camera,
            gradient: 'from-teal-500 to-emerald-600',
            bg: 'bg-teal-50',
            border: 'border-teal-100',
            text: 'text-teal-700'
        }
    ];

    // --- Handlers ---

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
        setCaptureMode(null);
    };

    // Generic processing function for card/image
    const processCard = async () => {
        if (!capturedImage) return;

        setIsProcessing(true);
        const processingToast = toast.loading('Processing business card...');
        try {
            // Run OCR client-side
            const { ClientOCRService } = await import('@/lib/services/ocr-client');
            const ocrResult = await ClientOCRService.extractTextFromImage(capturedImage, (progress) => {
                console.log(`OCR Progress: ${progress}%`);
            });

            // Send to API to save
            const response = await fetch('/api/captures', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    image: capturedImage,
                    capture_type: captureMode === 'camera' ? 'card_scan' : 'photo_upload',
                    event_id: eventIdParam || null,
                    extracted_data: ocrResult.extractedData,
                    raw_text: ocrResult.text
                }),
            });

            const result = await response.json();

            if (response.ok) {
                if (result.contactId) {
                    toast.success('Contact created successfully! Redirecting...', { id: processingToast });
                    window.location.href = `/contacts/${result.contactId}`;
                } else {
                    toast.success('Card processed successfully!', { id: processingToast });
                    resetAll();
                }
            } else {
                toast.error(result.error || 'Failed to process card', { id: processingToast });
            }
        } catch (error) {
            console.error('Processing error:', error);
            toast.error('Failed to process card', { id: processingToast });
        } finally {
            setIsProcessing(false);
        }
    };

    const resetAll = () => {
        setCaptureMode(null);
        setCapturedImage(null);
        setManualData({
            first_name: '',
            last_name: '',
            email: '',
            phone: '',
            company_name: '',
            job_title: '',
            notes: '',
            event_id: eventIdParam || ''
        });
        camera.stopCamera();
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
                window.location.href = `/contacts/${result.data.id}`;
            } else {
                toast.error(result.error || 'Failed to create contact', { id: loadingToast });
            }
        } catch (error) {
            console.error('Manual save error:', error);
            toast.error('Failed to create contact', { id: loadingToast });
        }
    };

    // --- Main Render ---

    // 1. Selection Screen (Main Menu)
    if (!captureMode) {
        return (
            <AppShell>
                <div className="max-w-5xl mx-auto py-8 px-4">
                    <div className="mb-10 text-center">
                        <h1 className="text-4xl font-extrabold tracking-tight text-gray-900 sm:text-5xl mb-4">
                            Capture Lead
                        </h1>
                        <p className="text-lg text-gray-600 max-w-2xl mx-auto">
                            Choose the best way to capture your lead's information.
                        </p>
                    </div>

                    <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
                        {captureModes.map((mode) => {
                            const Icon = mode.icon;
                            return (
                                <button
                                    key={mode.id}
                                    onClick={() => setCaptureMode(mode.id)}
                                    className={`
                                        group relative flex flex-col items-center p-8 rounded-2xl 
                                        bg-white border transition-all duration-300
                                        hover:shadow-xl hover:-translate-y-1 hover:border-transparent
                                        ${mode.border}
                                    `}
                                >
                                    {/* Icon Circle */}
                                    <div className={`
                                        h-16 w-16 rounded-full flex items-center justify-center mb-6
                                        transition-all duration-300 shadow-sm group-hover:shadow-md
                                        bg-gradient-to-br ${mode.gradient}
                                    `}>
                                        <Icon className="h-8 w-8 text-white" />
                                    </div>

                                    {/* Text */}
                                    <div className="text-center space-y-2">
                                        <h3 className="font-bold text-xl text-gray-900 group-hover:text-primary transition-colors">
                                            {mode.label}
                                        </h3>
                                        <p className="text-sm text-gray-500">
                                            {mode.description}
                                        </p>
                                    </div>

                                    {/* BG Tint on Hover */}
                                    <div className={`
                                        absolute inset-0 rounded-2xl opacity-0 
                                        group-hover:opacity-10 transition-opacity duration-300 
                                        bg-gradient-to-br ${mode.gradient}
                                    `} />
                                </button>
                            );
                        })}
                    </div>
                </div>
            </AppShell>
        );
    }

    // 2. Capture Interface (Modal-like overlay or full page)
    return (
        <AppShell>
            <div className="max-w-3xl mx-auto py-6 px-4">
                {/* Header / Nav */}
                <div className="flex items-center justify-between mb-8">
                    <Button
                        variant="ghost"
                        onClick={resetAll}
                        className="text-gray-500 hover:text-gray-900 -ml-2"
                    >
                        <X className="mr-2 h-5 w-5" />
                        Back to Options
                    </Button>
                    <span className="font-semibold text-lg text-gray-900 capitalize">
                        {captureModes.find(m => m.id === captureMode)?.label}
                    </span>
                    <div className="w-10" /> {/* Spacer for balance */}
                </div>

                {/* --- Camera Mode --- */}
                {captureMode === 'camera' && !capturedImage && (
                    <Card className="overflow-hidden shadow-lg border-0 bg-black">
                        <CardContent className="p-0 relative min-h-[400px] flex items-center justify-center">
                            {!camera.isActive ? (
                                <div className="text-center p-8 text-white">
                                    <Camera className="h-16 w-16 mx-auto mb-4 opacity-50" />
                                    <h3 className="text-xl font-bold mb-2">Camera Access Needed</h3>
                                    <p className="text-gray-400 mb-6">Allow access to scan business cards</p>
                                    <Button onClick={camera.startCamera} size="lg" className="bg-white text-black hover:bg-gray-200">
                                        Enable Camera
                                    </Button>
                                </div>
                            ) : (
                                <>
                                    <video
                                        ref={camera.videoRef}
                                        autoPlay
                                        playsInline
                                        className="w-full h-full object-cover"
                                    />
                                    <div className="absolute bottom-8 left-0 right-0 flex justify-center">
                                        <button
                                            onClick={handleCameraCapture}
                                            className="h-20 w-20 rounded-full border-4 border-white flex items-center justify-center bg-white/20 hover:bg-white/40 transition-colors"
                                        >
                                            <div className="h-16 w-16 bg-white rounded-full" />
                                        </button>
                                    </div>
                                </>
                            )}
                        </CardContent>
                    </Card>
                )}

                {/* --- Upload Mode --- */}
                {captureMode === 'upload' && !capturedImage && (
                    <Card className="border-dashed border-2 border-gray-200 shadow-sm">
                        <CardContent className="p-16 text-center">
                            <div className="h-24 w-24 bg-purple-50 rounded-full flex items-center justify-center mx-auto mb-6">
                                <Upload className="h-10 w-10 text-purple-600" />
                            </div>
                            <h3 className="text-2xl font-bold text-gray-900 mb-2">Upload File</h3>
                            <p className="text-gray-500 mb-8 max-w-sm mx-auto">
                                Select an image from your device. We support JPG, PNG and HEIC.
                            </p>
                            <label className="inline-flex">
                                <input
                                    type="file"
                                    accept="image/*"
                                    onChange={handleFileUpload}
                                    className="hidden"
                                />
                                <Button size="lg" asChild className="cursor-pointer bg-purple-600 hover:bg-purple-700">
                                    <span>Select Image</span>
                                </Button>
                            </label>
                        </CardContent>
                    </Card>
                )}

                {/* --- QR Code Mode --- */}
                {captureMode === 'qr' && (
                    <QrScanner onScan={handleQrScan} />
                )}

                {/* --- Voice Note Mode --- */}
                {captureMode === 'voice' && (
                    <VoiceRecorder onComplete={() => setCaptureMode(null)} onCancel={() => setCaptureMode(null)} />
                )}

                {/* --- Badge Scanner Mode --- */}
                {captureMode === 'badge' && (
                    <BadgeScanner
                        onComplete={async (data: any) => {
                            const loadingToast = toast.loading('Saving badge data...');
                            try {
                                const response = await fetch('/api/captures', {
                                    method: 'POST',
                                    headers: { 'Content-Type': 'application/json' },
                                    body: JSON.stringify({
                                        image: '', // Badge scanner doesn't save image
                                        capture_type: 'badge_scan',
                                        event_id: eventIdParam || null,
                                        extracted_data: data,
                                        raw_text: data.raw_text
                                    }),
                                });

                                const result = await response.json();

                                if (response.ok && result.contactId) {
                                    toast.success('Contact created from badge! Redirecting...', { id: loadingToast });
                                    window.location.href = `/contacts/${result.contactId}`;
                                } else {
                                    toast.error('Badge scanned but failed to create contact', { id: loadingToast });
                                    resetAll();
                                }
                            } catch (error) {
                                console.error('Badge save error:', error);
                                toast.error('Failed to save badge data', { id: loadingToast });
                                resetAll();
                            }
                        }}
                        onCancel={resetAll}
                    />
                )}

                {/* --- Photo + Notes Mode --- */}
                {captureMode === 'photo_note' && (
                    <PhotoNoteCapture
                        onComplete={async (imageData: string, notes: string, extractedText: string) => {
                            const loadingToast = toast.loading('Processing photo and notes...');
                            try {
                                // Run OCR to extract structured data
                                const { ClientOCRService } = await import('@/lib/services/ocr-client');
                                const ocrResult = await ClientOCRService.extractTextFromImage(imageData, () => { });

                                const response = await fetch('/api/captures', {
                                    method: 'POST',
                                    headers: { 'Content-Type': 'application/json' },
                                    body: JSON.stringify({
                                        image: imageData,
                                        capture_type: 'photo_upload',
                                        event_id: eventIdParam || null,
                                        extracted_data: ocrResult.extractedData,
                                        raw_text: `${extractedText}\n\nNotes: ${notes}`
                                    }),
                                });

                                const result = await response.json();

                                if (response.ok && result.contactId) {
                                    toast.success('Contact created from photo! Redirecting...', { id: loadingToast });
                                    window.location.href = `/contacts/${result.contactId}`;
                                } else {
                                    toast.error('Photo saved but failed to create contact', { id: loadingToast });
                                    resetAll();
                                }
                            } catch (error) {
                                console.error('Photo save error:', error);
                                toast.error('Failed to save photo', { id: loadingToast });
                                resetAll();
                            }
                        }}
                        onCancel={resetAll}
                    />
                )}


                {/* --- Manual Entry Mode --- */}
                {captureMode === 'manual' && (
                    <Card className="shadow-lg">
                        <CardContent className="p-8">
                            <div className="grid gap-6 md:grid-cols-2 mb-6">
                                <Input
                                    label="First Name"
                                    placeholder="John"
                                    required
                                    value={manualData.first_name}
                                    onChange={(e) => setManualData({ ...manualData, first_name: e.target.value })}
                                />
                                <Input
                                    label="Last Name"
                                    placeholder="Doe"
                                    value={manualData.last_name}
                                    onChange={(e) => setManualData({ ...manualData, last_name: e.target.value })}
                                />
                                <Input
                                    label="Email"
                                    type="email"
                                    placeholder="john@example.com"
                                    value={manualData.email}
                                    onChange={(e) => setManualData({ ...manualData, email: e.target.value })}
                                />
                                <Input
                                    label="Phone"
                                    type="tel"
                                    placeholder="+1-555-0100"
                                    value={manualData.phone}
                                    onChange={(e) => setManualData({ ...manualData, phone: e.target.value })}
                                />
                                <Input
                                    label="Company"
                                    placeholder="Acme Corp"
                                    value={manualData.company_name}
                                    onChange={(e) => setManualData({ ...manualData, company_name: e.target.value })}
                                />
                                <Input
                                    label="Job Title"
                                    placeholder="CEO"
                                    value={manualData.job_title}
                                    onChange={(e) => setManualData({ ...manualData, job_title: e.target.value })}
                                />
                            </div>
                            <div className="mb-8">
                                <label className="text-sm font-medium mb-2 block text-gray-700">Notes</label>
                                <Textarea
                                    className="min-h-[120px]"
                                    placeholder="Add conversation notes or context..."
                                    value={manualData.notes}
                                    onChange={(e) => setManualData({ ...manualData, notes: e.target.value })}
                                />
                            </div>
                            <div className="flex justify-end gap-3">
                                <Button variant="outline" onClick={() => setCaptureMode(null)}>
                                    Cancel
                                </Button>
                                <Button
                                    onClick={handleManualSave}
                                    className="bg-emerald-600 hover:bg-emerald-700"
                                >
                                    <Check className="mr-2 h-4 w-4" />
                                    Save Contact
                                </Button>
                            </div>
                        </CardContent>
                    </Card>
                )}

                {/* --- Image Preview & Processing (Common for Camera & Upload) --- */}
                {capturedImage && (
                    <Card className="shadow-lg overflow-hidden">
                        <CardContent className="p-0">
                            <div className="bg-gray-100 p-8 flex justify-center">
                                <img
                                    src={capturedImage}
                                    alt="Captured"
                                    className="max-h-[500px] w-auto rounded-lg shadow-xl"
                                />
                            </div>
                            <div className="p-6 bg-white border-t flex justify-between items-center">
                                <Button
                                    variant="ghost"
                                    onClick={() => setCapturedImage(null)}
                                    className="text-gray-500 hover:text-red-600"
                                >
                                    <RefreshCw className="mr-2 h-4 w-4" />
                                    Retake
                                </Button>
                                <Button
                                    onClick={processCard}
                                    disabled={isProcessing}
                                    size="lg"
                                    className="min-w-[160px]"
                                >
                                    {isProcessing ? (
                                        <>
                                            <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                                            Processing...
                                        </>
                                    ) : (
                                        <>
                                            <Check className="mr-2 h-4 w-4" />
                                            Process Card
                                        </>
                                    )}
                                </Button>
                            </div>
                        </CardContent>
                    </Card>
                )}
            </div>
        </AppShell>
    );
}
