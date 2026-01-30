'use client';

import { useState, useRef, useEffect } from 'react';
import { Camera, X, Check, Loader2, RefreshCw } from 'lucide-react';
import { Button } from '@/components/ui/Button';
import { Card, CardContent } from '@/components/ui/Card';
import { toast } from 'sonner';

interface BadgeScannerProps {
    onComplete: (extractedData: any) => void;
    onCancel: () => void;
}

export function BadgeScanner({ onComplete, onCancel }: BadgeScannerProps) {
    const [isActive, setIsActive] = useState(false);
    const [capturedImage, setCapturedImage] = useState<string | null>(null);
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
            }
        }
    };

    const processBadge = async () => {
        if (!capturedImage) return;

        setIsProcessing(true);
        try {
            // Run OCR client-side
            const { ClientOCRService } = await import('@/lib/services/ocr-client');
            const ocrResult = await ClientOCRService.extractTextFromImage(capturedImage, (progress) => {
                console.log(`OCR Progress: ${progress}%`);
            });

            // Parse badge-specific format (name, company, title typically on separate lines)
            const lines = ocrResult.text.split('\n').map(l => l.trim()).filter(l => l.length > 0);

            // Simple heuristic: first line is name, second is company, third is title
            const extractedData = {
                name: lines[0] || '',
                company: lines[1] || '',
                job_title: lines[2] || '',
                raw_text: ocrResult.text,
                confidence: 0.7 // Badge OCR confidence
            };

            onComplete(extractedData);
        } catch (error) {
            console.error('Badge processing error:', error);
            toast.error('Failed to process badge');
        } finally {
            setIsProcessing(false);
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
                                <h3 className="text-xl font-bold mb-2">Scan Event Badge</h3>
                                <p className="text-gray-400 mb-6">Position the badge in the frame</p>
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
                    <>
                        <div className="bg-gray-100 p-8 flex justify-center">
                            <img
                                src={capturedImage}
                                alt="Captured badge"
                                className="max-h-[500px] w-auto rounded-lg shadow-xl"
                            />
                        </div>
                        <div className="p-6 bg-white border-t flex justify-between items-center">
                            <Button
                                variant="ghost"
                                onClick={() => {
                                    setCapturedImage(null);
                                    startCamera();
                                }}
                                className="text-gray-500 hover:text-red-600"
                            >
                                <RefreshCw className="mr-2 h-4 w-4" />
                                Retake
                            </Button>
                            <Button
                                onClick={processBadge}
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
                                        Process Badge
                                    </>
                                )}
                            </Button>
                        </div>
                    </>
                )}
            </CardContent>
        </Card>
    );
}
