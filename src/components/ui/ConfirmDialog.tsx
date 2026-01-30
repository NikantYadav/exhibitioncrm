'use client';

import React from 'react';
import { Modal } from './Modal';
import { Button } from './Button';
import { AlertTriangle } from 'lucide-react';

interface ConfirmDialogProps {
    isOpen: boolean;
    onClose: () => void;
    onConfirm: () => void;
    title: string;
    description: string;
    confirmText?: string;
    cancelText?: string;
    variant?: 'danger' | 'warning' | 'info';
    isLoading?: boolean;
}

export function ConfirmDialog({
    isOpen,
    onClose,
    onConfirm,
    title,
    description,
    confirmText = 'Confirm',
    cancelText = 'Cancel',
    variant = 'danger',
    isLoading = false
}: ConfirmDialogProps) {
    const variantColors = {
        danger: 'bg-red-50 text-red-600',
        warning: 'bg-yellow-50 text-yellow-600',
        info: 'bg-blue-50 text-blue-600'
    };

    const confirmButtonVariants = {
        danger: 'bg-red-600 hover:bg-red-700 text-white border-red-600',
        warning: 'bg-yellow-600 hover:bg-yellow-700 text-white border-yellow-600',
        info: 'bg-blue-600 hover:bg-blue-700 text-white border-blue-600'
    };

    return (
        <Modal isOpen={isOpen} onClose={onClose} size="sm">
            <div className="flex flex-col items-center text-center">
                <div className={`h-12 w-12 rounded-full flex items-center justify-center mb-4 ${variantColors[variant]}`}>
                    <AlertTriangle className="h-6 w-6" />
                </div>

                <h3 className="text-xl font-bold text-gray-900 mb-2">{title}</h3>
                <p className="text-gray-500 mb-8">{description}</p>

                <div className="flex flex-col-reverse sm:flex-row gap-3 w-full">
                    <Button
                        variant="ghost"
                        className="flex-1"
                        onClick={onClose}
                    >
                        {cancelText}
                    </Button>
                    <Button
                        className={`flex-1 ${confirmButtonVariants[variant]}`}
                        onClick={onConfirm}
                        loading={isLoading}
                    >
                        {confirmText}
                    </Button>
                </div>
            </div>
        </Modal>
    );
}
