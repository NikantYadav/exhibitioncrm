'use client';

import React, { useEffect, useRef, useState } from 'react';
import WaveSurfer from 'wavesurfer.js';
import { Play, Pause, Download, Volume2, VolumeX } from 'lucide-react';

interface VoiceNotePlayerProps {
    audioURL: string;
    duration?: number;
}

export function VoiceNotePlayer({ audioURL, duration }: VoiceNotePlayerProps) {
    const containerRef = useRef<HTMLDivElement>(null);
    const wavesurferRef = useRef<WaveSurfer | null>(null);
    const [isPlaying, setIsPlaying] = useState(false);
    const [currentTime, setCurrentTime] = useState(0);
    const [totalDuration, setTotalDuration] = useState(0);
    const [isMuted, setIsMuted] = useState(false);

    useEffect(() => {
        if (!containerRef.current) return;

        const ws = WaveSurfer.create({
            container: containerRef.current,
            waveColor: '#d1d5db', // gray-300
            progressColor: '#8b5cf6', // violet-500
            height: 40,
            barWidth: 2,
            barGap: 1,
            barRadius: 2,
            cursorColor: '#8b5cf6',
            cursorWidth: 2,
        });

        ws.load(audioURL).catch((err) => {
            if (err.name !== 'AbortError') {
                console.warn('WaveSurfer load error:', err);
            }
        });

        ws.on('ready', () => {
            setTotalDuration(ws.getDuration());
        });

        ws.on('play', () => setIsPlaying(true));
        ws.on('pause', () => setIsPlaying(false));
        ws.on('timeupdate', (time: number) => setCurrentTime(time));
        ws.on('finish', () => setIsPlaying(false));

        wavesurferRef.current = ws;

        return () => {
            try {
                ws.destroy();
            } catch (e) {
                // Ignore destruction errors
            }
        };
    }, [audioURL]);

    const togglePlay = () => {
        if (wavesurferRef.current) {
            wavesurferRef.current.playPause();
        }
    };

    const toggleMute = () => {
        if (wavesurferRef.current) {
            wavesurferRef.current.setMuted(!isMuted);
            setIsMuted(!isMuted);
        }
    };

    const formatTime = (seconds: number) => {
        const mins = Math.floor(seconds / 60);
        const secs = Math.floor(seconds % 60);
        return `${mins}:${secs.toString().padStart(2, '0')}`;
    };

    return (
        <div className="bg-white rounded-xl p-4 border border-stone-200 shadow-sm hover:border-purple-200 transition-colors">
            <div className="flex items-center gap-4">
                <button
                    onClick={togglePlay}
                    className="flex-shrink-0 w-10 h-10 flex items-center justify-center bg-purple-600 hover:bg-purple-700 text-white rounded-full transition-all active:scale-95 shadow-md"
                >
                    {isPlaying ? (
                        <Pause className="h-5 w-5 fill-current" />
                    ) : (
                        <Play className="h-5 w-5 ml-0.5 fill-current" />
                    )}
                </button>

                <div className="flex-1 min-w-0">
                    <div ref={containerRef} className="w-full" />
                    <div className="flex justify-between mt-2 px-1">
                        <span className="text-[10px] font-mono text-stone-500 tabular-nums">
                            {formatTime(currentTime)}
                        </span>
                        <span className="text-[10px] font-mono text-stone-500 tabular-nums">
                            {formatTime(totalDuration)}
                        </span>
                    </div>
                </div>

                <div className="flex items-center gap-2">
                    <button
                        onClick={toggleMute}
                        className="p-1.5 text-stone-400 hover:text-stone-600 hover:bg-stone-100 rounded-md transition-colors"
                    >
                        {isMuted ? <VolumeX className="h-4 w-4" /> : <Volume2 className="h-4 w-4" />}
                    </button>
                    <a
                        href={audioURL}
                        download="voice-note.webm"
                        className="p-1.5 text-stone-400 hover:text-stone-600 hover:bg-stone-100 rounded-md transition-colors"
                    >
                        <Download className="h-4 w-4" />
                    </a>
                </div>
            </div>
        </div>
    );
}
