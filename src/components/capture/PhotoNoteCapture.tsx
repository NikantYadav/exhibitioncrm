'use client';

import { useState, useRef, useEffect } from 'react';
import { Camera, X, Check, Loader2, RefreshCw, FileText } from 'lucide-react';
import { Button } from '@/components/ui/Button';
import { Textarea } from '@/components/ui/Textarea';
import { Card, CardContent } from '@/components/ui/Card';
import { toast } from 'sonner';

interface PhotoNoteCaptureProps {
    onComplete: (imageData: string, notes: string, extractedText: string) => void;
    onCancel: () => void;
}

export function PhotoNoteCapture({ onComplete, onCancel }: PhotoNoteCaptureProps) {
    const [isActive, setIsActive] = useState(false);
    const [capturedImage, setCapturedImage] = useState<string | null>(null);
    const [notes, setNotes] = useState('');
    const [extractedText, setExtractedText] = useState('');
    const [isProcessing, setIsProcessing] = useState(false);
    const videoRef = useRef<HTMLVideoElement>(null);
    const canvasRef = useRef<HTMLCanvasElement>(null);
    const streamRef = useRef<MediaStream | null>(null);

    useEffect(() => {
        return () => {
            stopCamera();
        };
    }, []);

    const startCamera = async () => {
        try {
            const stream = await navigator.mediaDevices.getUserMedia({
                video: { facingMode: 'environment' }
            });
            if (videoRef.current) {
                videoRef.current.srcObject = stream;
                streamRef.current = stream;
                setIsActive(true);
            }
        } catch (error) {
            console.error('Camera access error:', error);
            toast.error('Failed to access camera');
        }
    };

    const stopCamera = () => {
        if (streamRef.current) {
            streamRef.current.getTracks().forEach(track => track.stop());
            streamRef.current = null;
        }
        setIsActive(false);
    };

    const capturePhoto = () => {
        if (videoRef.current && canvasRef.current) {
            const video = videoRef.current;
            const canvas = canvasRef.current;
            canvas.width = video.videoWidth;
            canvas.height = video.videoHeight;
            const ctx = canvas.getContext('2d');
            if (ctx) {
                ctx.drawImage(video, 0, 0);
                const imageData = canvas.toDataURL('image/jpeg');
                setCapturedImage(imageData);
                stopCamera();
                // Run OCR on the image
                extractTextFromImage(imageData);
            }
        }
    };

    const extractTextFromImage = async (imageData: string) => {
        setIsProcessing(true);
        try {
            const { ClientOCRService } = await import('@/lib/services/ocr-client');
            const ocrResult = await ClientOCRService.extractTextFromImage(imageData, (progress) => {
                console.log(`OCR Progress: ${progress}%`);
            });
            setExtractedText(ocrResult.text);
        } catch (error) {
            console.error('OCR error:', error);
        } finally {
            setIsProcessing(false);
        }
    };

    const handleComplete = () => {
        if (capturedImage) {
            onComplete(capturedImage, notes, extractedText);
        }
    };

    return (
        <Card className="shadow-lg overflow-hidden">
            <CardContent className="p-0">
                {!capturedImage ? (
                    <div className="relative min-h-[400px] bg-black flex items-center justify-center">
                        {!isActive ? (
                            <div className="text-center p-8 text-white">
                                <Camera className="h-16 w-16 mx-auto mb-4 opacity-50" />
                                <h3 className="text-xl font-bold mb-2">Capture Card with Notes</h3>
                                <p className="text-gray-400 mb-6">Take a photo of the business card with your handwritten notes</p>
                                <Button onClick={startCamera} size="lg" className="bg-white text-black hover:bg-gray-200">
                                    Enable Camera
                                </Button>
                            </div>
                        ) : (
                            <>
                                <video
                                    ref={videoRef}
                                    autoPlay
                                    playsInline
                                    className="w-full h-full object-cover"
                                />
                                <canvas ref={canvasRef} className="hidden" />
                                <div className="absolute bottom-8 left-0 right-0 flex justify-center gap-4">
                                    <button
                                        onClick={onCancel}
                                        className="h-12 w-12 rounded-full border-2 border-white flex items-center justify-center bg-red-500/80 hover:bg-red-600/80 transition-colors"
                                    >
                                        <X className="h-6 w-6 text-white" />
                                    </button>
                                    <button
                                        onClick={capturePhoto}
                                        className="h-20 w-20 rounded-full border-4 border-white flex items-center justify-center bg-white/20 hover:bg-white/40 transition-colors"
                                    >
                                        <div className="h-16 w-16 bg-white rounded-full" />
                                    </button>
                                </div>
                            </>
                        )}
                    </div>
                ) : (
                    <div className="p-6 space-y-4">
                        <div className="bg-gray-100 p-4 rounded-lg">
                            <img
                                src={capturedImage}
                                alt="Captured card"
                                className="max-h-[300px] w-auto mx-auto rounded-lg shadow-md"
                            />
                        </div>

                        {isProcessing && (
                            <div className="flex items-center justify-center gap-2 text-gray-600">
                                <Loader2 className="h-4 w-4 animate-spin" />
                                <span className="text-sm">Extracting text from image...</span>
                            </div>
                        )}

                        {extractedText && (
                            <div className="bg-blue-50 p-3 rounded-lg border border-blue-200">
                                <div className="flex items-center gap-2 mb-2">
                                    <FileText className="h-4 w-4 text-blue-600" />
                                    <span className="text-sm font-medium text-blue-900">Extracted Text</span>
                                </div>
                                <p className="text-sm text-gray-700 whitespace-pre-wrap">{extractedText}</p>
                            </div>
                        )}

                        <div>
                            <label className="block text-sm font-medium text-gray-700 mb-2">
                                Your Notes
                            </label>
                            <Textarea
                                value={notes}
                                onChange={(e) => setNotes(e.target.value)}
                                placeholder="Add any additional notes from your conversation..."
                                rows={4}
                                className="w-full"
                            />
                        </div>

                        <div className="flex justify-between items-center pt-4 border-t">
                            <Button
                                variant="ghost"
                                onClick={() => {
                                    setCapturedImage(null);
                                    setExtractedText('');
                                    setNotes('');
                                    startCamera();
                                }}
                                className="text-gray-500 hover:text-red-600"
                            >
                                <RefreshCw className="mr-2 h-4 w-4" />
                                Retake
                            </Button>
                            <Button
                                onClick={handleComplete}
                                disabled={isProcessing}
                                size="lg"
                                className="min-w-[160px]"
                            >
                                <Check className="mr-2 h-4 w-4" />
                                Save Capture
                            </Button>
                        </div>
                    </div>
                )}
            </CardContent>
        </Card>
    );
}
