'use client';

import { useState, useRef, useEffect } from 'react';
import { Button } from '@/components/ui/Button';
import { Modal } from '@/components/ui/Modal';
import { CaptureFlow, CaptureMode } from '@/components/events/CaptureFlow';
import {
    Camera,
    MoreVertical,
    IdCard,
    QrCode,
    Keyboard,
    Mic,
    Upload,
    ChevronDown,
    Zap
} from 'lucide-react';
import { cn, formatLabel } from '@/lib/utils';

interface CaptureDropdownProps {
    eventId?: string;
    className?: string;
    trigger?: React.ReactNode;
    align?: 'left' | 'right';
}

export function CaptureDropdown({ eventId, className, trigger, align = 'right' }: CaptureDropdownProps) {
    const [isOpen, setIsOpen] = useState(false);
    const [activeCaptureMode, setActiveCaptureMode] = useState<CaptureMode | null>(null);
    const [showModal, setShowModal] = useState(false);
    const dropdownRef = useRef<HTMLDivElement>(null);

    // Close dropdown when clicking outside
    useEffect(() => {
        function handleClickOutside(event: MouseEvent) {
            if (dropdownRef.current && !dropdownRef.current.contains(event.target as Node)) {
                setIsOpen(false);
            }
        }
        document.addEventListener('mousedown', handleClickOutside);
        return () => document.removeEventListener('mousedown', handleClickOutside);
    }, []);

    const handleOpenCapture = (mode: CaptureMode) => {
        setActiveCaptureMode(mode);
        setShowModal(true);
        setIsOpen(false);
    };

    const handleCaptureComplete = (data: any) => {
        setShowModal(false);
        setActiveCaptureMode(null);
        // Dispatch refresh event to update dashboard/timeline
        window.dispatchEvent(new CustomEvent('timeline:refresh'));
        window.dispatchEvent(new CustomEvent('sync:complete'));
    };

    const captureOptions = [
        { id: 'camera' as CaptureMode, label: 'Smart Scan', icon: Camera, color: 'text-blue-600', hover: 'hover:bg-blue-50' },
        { id: 'qr' as CaptureMode, label: 'Scan QR Code', icon: QrCode, color: 'text-amber-600', hover: 'hover:bg-amber-50' },
        { id: 'voice' as CaptureMode, label: 'Voice Note', icon: Mic, color: 'text-rose-600', hover: 'hover:bg-rose-50' },
        { id: 'manual' as CaptureMode, label: 'Manual Entry', icon: Keyboard, color: 'text-emerald-600', hover: 'hover:bg-emerald-50' },
        { id: 'upload' as CaptureMode, label: 'Import Photo', icon: Upload, color: 'text-purple-600', hover: 'hover:bg-purple-50', border: true },
    ];

    return (
        <div className={cn("relative", className)} ref={dropdownRef}>
            {trigger ? (
                <div onClick={() => setIsOpen(!isOpen)}>
                    {trigger}
                </div>
            ) : (
                <Button
                    onClick={() => setIsOpen(!isOpen)}
                    className="h-11 px-6 rounded-xl bg-stone-900 hover:bg-black text-white shadow-lg shadow-stone-200 transition-all hover:scale-[1.02] active:scale-[0.98] flex items-center gap-2"
                >
                    <Zap className="h-4 w-4 text-amber-400" />
                    New Capture
                    <ChevronDown className={cn("h-4 w-4 transition-transform", isOpen && "rotate-180")} />
                </Button>
            )}

            {isOpen && (
                <div className={cn(
                    "absolute mt-2 w-56 bg-white border border-stone-200 rounded-2xl shadow-2xl z-50 overflow-hidden animate-in fade-in slide-in-from-top-2 duration-200",
                    align === 'right' ? "right-0" : "left-0"
                )}>
                    <div className="p-1.5">
                        {captureOptions.map((option) => (
                            <button
                                key={option.id}
                                onClick={() => handleOpenCapture(option.id)}
                                className={cn(
                                    "w-full text-left px-4 py-2.5 text-sm font-semibold flex items-center gap-3 rounded-xl transition-colors",
                                    option.hover,
                                    option.border && "mt-1 pt-3 border-t border-stone-100 rounded-t-none"
                                )}
                            >
                                <option.icon className={cn("h-4 w-4", option.color)} />
                                <span className="text-stone-700">{option.label}</span>
                            </button>
                        ))}
                    </div>
                </div>
            )}

            <Modal
                isOpen={showModal}
                onClose={() => setShowModal(false)}
                size="lg"
                title={activeCaptureMode ? `${formatLabel(activeCaptureMode)} Capture` : 'Capture Lead'}
            >
                <div className="p-1">
                    <CaptureFlow
                        eventId={eventId || ""}
                        mode={activeCaptureMode}
                        onClose={() => setShowModal(false)}
                        onComplete={handleCaptureComplete}
                    />
                </div>
            </Modal>
        </div>
    );
}
