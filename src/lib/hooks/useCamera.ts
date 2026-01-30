'use client';

import { useState, useRef, useCallback, useEffect } from 'react';

export interface CameraOptions {
    facingMode?: 'user' | 'environment';
    width?: number;
    height?: number;
}

export function useCamera(options: CameraOptions = {}) {
    // We maintain internal state for facingMode to allow toggling
    const [facingMode, setFacingMode] = useState(options.facingMode || 'environment');
    const [stream, setStream] = useState<MediaStream | null>(null);
    const [error, setError] = useState<string | null>(null);
    const [isActive, setIsActive] = useState(false);
    const [isLoading, setIsLoading] = useState(false);
    const [isReady, setIsReady] = useState(false);
    const videoRef = useRef<HTMLVideoElement | null>(null);

    // Effect to bind stream to video element whenever stream changes
    useEffect(() => {
        if (!stream || !videoRef.current) return;

        const video = videoRef.current;
        video.srcObject = stream;
        video.muted = true;
        video.playsInline = true;

        const handleReady = () => {
            setIsReady(true);
        };

        const onLoadedMetadata = () => {
            video.play()
                .then(handleReady)
                .catch(err => {
                    console.error('Auto-play failed:', err);
                    // Retry once after a short delay
                    setTimeout(() => {
                        if (video.srcObject === stream) {
                            video.play().then(handleReady).catch(e => console.error('Retry play failed', e));
                        }
                    }, 100);
                });
        };

        video.addEventListener('loadedmetadata', onLoadedMetadata);

        // If metadata is already loaded by the time we attach
        if (video.readyState >= 1) { // HAVE_METADATA
            onLoadedMetadata();
        }

        return () => {
            video.removeEventListener('loadedmetadata', onLoadedMetadata);
        };
    }, [stream]);

    const stopCamera = useCallback(() => {
        if (stream) {
            stream.getTracks().forEach(track => track.stop());
            setStream(null);
        }
        setIsActive(false);
        setIsReady(false);
        if (videoRef.current) {
            videoRef.current.srcObject = null;
        }
    }, [stream]);

    const startCamera = useCallback(async () => {
        if (isLoading) return;

        setIsLoading(true);
        setError(null);
        setIsReady(false);

        if (stream) {
            stream.getTracks().forEach(track => track.stop());
        }

        // Constraints with fallbacks
        const constraints = [
            {
                video: {
                    facingMode: facingMode,
                    width: { ideal: options.width || 1280 },
                    height: { ideal: options.height || 720 },
                }
            },
            {
                video: {
                    facingMode: facingMode,
                    width: { ideal: 640 },
                    height: { ideal: 480 },
                }
            },
            { video: true }
        ];

        let success = false;
        let lastError: any = null;

        for (const constraint of constraints) {
            try {
                const mediaStream = await navigator.mediaDevices.getUserMedia(constraint);
                setStream(mediaStream);
                setIsActive(true);
                success = true;
                break;
            } catch (err) {
                lastError = err;
                continue;
            }
        }

        if (!success) {
            let message = 'Failed to access camera';
            if (lastError?.name === 'NotAllowedError') {
                message = 'Camera permission denied. Please allow camera access.';
            } else if (lastError?.name === 'NotFoundError') {
                message = 'No camera found on this device.';
            } else if (lastError?.name === 'NotReadableError') {
                message = 'Camera is in use by another app.';
            }
            setError(message);
            setIsActive(false);
        }

        setIsLoading(false);
    }, [facingMode, options.width, options.height, stream, isLoading]);

    const capturePhoto = useCallback((): string | null => {
        if (!videoRef.current || !isReady) return null;

        try {
            const canvas = document.createElement('canvas');
            canvas.width = videoRef.current.videoWidth;
            canvas.height = videoRef.current.videoHeight;
            const context = canvas.getContext('2d');
            if (!context) return null;

            context.drawImage(videoRef.current, 0, 0);
            return canvas.toDataURL('image/jpeg', 0.9);
        } catch (err) {
            console.error('Capture error:', err);
            return null;
        }
    }, [isReady]);

    const switchCamera = useCallback(async () => {
        const newMode = facingMode === 'user' ? 'environment' : 'user';
        setFacingMode(newMode);
    }, [facingMode]);

    // Automatically restart when facingMode changes if already active
    useEffect(() => {
        if (isActive) {
            startCamera();
        }
    }, [facingMode]);

    // Cleanup on unmount
    useEffect(() => {
        return () => {
            if (stream) {
                stream.getTracks().forEach(track => track.stop());
            }
        };
    }, [stream]);

    return {
        videoRef,
        stream,
        error,
        isActive,
        isLoading,
        isReady,
        startCamera,
        stopCamera,
        capturePhoto,
        switchCamera,
    };
}
