'use client';

import React, { ReactNode, useEffect, useState } from 'react';
import { X } from 'lucide-react';
import { cn } from '@/lib/utils';
import { createPortal } from 'react-dom';

interface ModalProps {
    isOpen: boolean;
    onClose: () => void;
    title?: string;
    children: ReactNode;
    size?: 'sm' | 'md' | 'lg' | 'xl';
    headerActions?: React.ReactNode;
}

export function Modal({ isOpen, onClose, title, children, size = 'md', headerActions }: ModalProps) {
    // Handle hydration/portal
    const [mounted, setMounted] = useState(false);

    useEffect(() => {
        setMounted(true);
        if (isOpen) {
            document.body.style.overflow = 'hidden';
        }
        return () => {
            document.body.style.overflow = 'unset';
        };
    }, [isOpen]);

    if (!mounted || !isOpen) return null;

    const sizeClasses = {
        sm: 'max-w-md',
        md: 'max-w-lg',
        lg: 'max-w-2xl',
        xl: 'max-w-4xl',
    };

    return createPortal(
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
            {/* Backdrop */}
            <div
                className="absolute inset-0 bg-black/40 backdrop-blur-sm transition-opacity duration-200"
                onClick={onClose}
            />

            {/* Modal Content */}
            <div
                className={cn(
                    "relative w-full rounded-2xl bg-white shadow-2xl ring-1 ring-stone-900/5 transition-all animate-fade-in-up flex flex-col max-h-[90vh]",
                    sizeClasses[size]
                )}
                onClick={(e) => e.stopPropagation()}
            >
                {(title || headerActions) && (
                    <div className="flex items-center justify-between border-b border-stone-100 px-6 py-4 shrink-0">
                        <div className="flex items-center gap-4 flex-1">
                            {title && (
                                <h2 className="text-xl font-bold text-stone-900 leading-none tracking-tight truncate">
                                    {title}
                                </h2>
                            )}
                            {headerActions && (
                                <div className="flex items-center gap-2">
                                    {headerActions}
                                </div>
                            )}
                        </div>
                        <button
                            onClick={onClose}
                            className="rounded-full p-2 text-stone-400 hover:bg-stone-100 hover:text-stone-500 transition-colors ml-4"
                        >
                            <X className="h-5 w-5" />
                        </button>
                    </div>
                )}

                <div className="px-6 py-6 overflow-y-auto flex-1 custom-scrollbar">
                    {children}
                </div>
            </div>
        </div>,
        document.body
    );
}
