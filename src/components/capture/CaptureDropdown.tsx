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
        { id: 'camera' as CaptureMode, label: 'Business Card', icon: Camera, desc: 'AI card extraction' },
        { id: 'qr' as CaptureMode, label: 'QR Scan', icon: QrCode, desc: 'Digital profile sync' },
        { id: 'voice' as CaptureMode, label: 'Voice Note', icon: Mic, desc: 'Quick voice capture' },
        { id: 'manual' as CaptureMode, label: 'Manual Entry', icon: Keyboard, desc: 'Direct input' },
        { id: 'upload' as CaptureMode, label: 'From Gallery', icon: Upload, desc: 'Upload photo', border: true },
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
                    className="h-11 px-6 rounded-xl bg-stone-900 hover:bg-stone-800 text-white shadow-lg shadow-stone-900/20 transition-all flex items-center gap-2 font-black uppercase tracking-widest text-[10px]"
                >
                    <Zap className="h-4 w-4 text-white" fill="currentColor" />
                    Add Contact
                    <ChevronDown className={cn("h-4 w-4 transition-transform opacity-50", isOpen && "rotate-180")} />
                </Button>
            )}

            {isOpen && (
                <div className={cn(
                    "absolute mt-2 w-52 bg-white border border-stone-100 rounded-[1.8rem] shadow-[0_20px_50px_rgba(0,0,0,0.12)] z-50 overflow-hidden animate-in fade-in slide-in-from-top-2 duration-300",
                    align === 'right' ? "right-0" : "left-0"
                )}>
                    <div className="p-2 space-y-0.5">
                        {captureOptions.map((option) => (
                            <button
                                key={option.id}
                                onClick={() => handleOpenCapture(option.id)}
                                className={cn(
                                    "w-full text-left p-2 rounded-xl transition-all flex items-center gap-3 group hover:bg-stone-50",
                                    option.border && "mt-1 pt-2 border-t border-stone-100 rounded-t-none"
                                )}
                            >
                                <div className="h-8 w-8 bg-stone-900 text-white rounded-[0.6rem] shadow-lg flex items-center justify-center shrink-0 transition-all">
                                    <option.icon className="h-4 w-4" strokeWidth={3} />
                                </div>
                                <div className="min-w-0">
                                    <p className="text-[10px] font-black text-stone-900 leading-none uppercase tracking-widest">{option.label}</p>
                                </div>
                            </button>
                        ))}
                    </div>
                </div>
            )}

            <Modal
                isOpen={showModal}
                onClose={() => setShowModal(false)}
                size="lg"
                title={activeCaptureMode ? `${formatLabel(activeCaptureMode)}` : 'Add Contact'}
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
