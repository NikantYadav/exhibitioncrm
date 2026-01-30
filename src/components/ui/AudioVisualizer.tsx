'use client';

import { useEffect, useRef } from 'react';

interface AudioVisualizerProps {
    analyser: AnalyserNode | null;
    isPaused?: boolean;
}

export function AudioVisualizer({ analyser, isPaused }: AudioVisualizerProps) {
    const canvasRef = useRef<HTMLCanvasElement>(null);

    useEffect(() => {
        if (!analyser || isPaused) return;

        const canvas = canvasRef.current;
        if (!canvas) return;

        const ctx = canvas.getContext('2d');
        if (!ctx) return;

        const bufferLength = analyser.frequencyBinCount;
        const dataArray = new Uint8Array(bufferLength);

        let animationId: number;

        const renderFrame = () => {
            animationId = requestAnimationFrame(renderFrame);
            analyser.getByteFrequencyData(dataArray);

            ctx.clearRect(0, 0, canvas.width, canvas.height);

            const barWidth = (canvas.width / bufferLength) * 2.5;
            let barHeight;
            let x = 0;

            for (let i = 0; i < bufferLength; i++) {
                barHeight = (dataArray[i] / 255) * canvas.height;

                // Create a gradient for a more premium look
                const gradient = ctx.createLinearGradient(0, canvas.height, 0, 0);
                gradient.addColorStop(0, '#6366f1'); // indigo-500
                gradient.addColorStop(1, '#a855f7'); // purple-500

                ctx.fillStyle = gradient;

                // Rounded bars
                const radius = 2;
                ctx.beginPath();
                ctx.roundRect(x, canvas.height - barHeight, barWidth - 1, barHeight, [radius, radius, 0, 0]);
                ctx.fill();

                x += barWidth + 1;
            }
        };

        renderFrame();

        return () => {
            cancelAnimationFrame(animationId);
        };
    }, [analyser, isPaused]);

    return (
        <canvas
            ref={canvasRef}
            width={300}
            height={40}
            className="w-full h-10 rounded-lg bg-stone-50"
        />
    );
}
