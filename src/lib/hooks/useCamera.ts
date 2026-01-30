'use client';

import { useState, useRef, useCallback } from 'react';

export interface CameraOptions {
    facingMode?: 'user' | 'environment';
    width?: number;
    height?: number;
}

export function useCamera(options: CameraOptions = {}) {
    const [stream, setStream] = useState<MediaStream | null>(null);
    const [error, setError] = useState<string | null>(null);
    const [isActive, setIsActive] = useState(false);
    const videoRef = useRef<HTMLVideoElement | null>(null);

    const startCamera = useCallback(async () => {
        try {
            setError(null);

            const mediaStream = await navigator.mediaDevices.getUserMedia({
                video: {
                    facingMode: options.facingMode || 'environment',
                    width: options.width || 1280,
                    height: options.height || 720,
                },
            });

            setStream(mediaStream);
            setIsActive(true);

            if (videoRef.current) {
                videoRef.current.srcObject = mediaStream;
            }
        } catch (err) {
            const errorMessage = err instanceof Error ? err.message : 'Failed to access camera';
            setError(errorMessage);
            console.error('Camera error:', err);
        }
    }, [options.facingMode, options.width, options.height]);

    const stopCamera = useCallback(() => {
        if (stream) {
            stream.getTracks().forEach(track => track.stop());
            setStream(null);
            setIsActive(false);

            if (videoRef.current) {
                videoRef.current.srcObject = null;
            }
        }
    }, [stream]);

    const capturePhoto = useCallback((): string | null => {
        if (!videoRef.current || !isActive) return null;

        const canvas = document.createElement('canvas');
        canvas.width = videoRef.current.videoWidth;
        canvas.height = videoRef.current.videoHeight;

        const context = canvas.getContext('2d');
        if (!context) return null;

        context.drawImage(videoRef.current, 0, 0);
        return canvas.toDataURL('image/jpeg', 0.9);
    }, [isActive]);

    const switchCamera = useCallback(async () => {
        stopCamera();
        const newFacingMode = options.facingMode === 'user' ? 'environment' : 'user';
        await startCamera();
    }, [options.facingMode, startCamera, stopCamera]);

    return {
        videoRef,
        stream,
        error,
        isActive,
        startCamera,
        stopCamera,
        capturePhoto,
        switchCamera,
    };
}
