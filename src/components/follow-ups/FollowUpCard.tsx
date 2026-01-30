'use client';

import { useRouter } from 'next/navigation';
import { Mail, Phone, Eye } from 'lucide-react';
import { Button } from '@/components/ui/Button';
import { Avatar, AvatarFallback } from '@/components/ui/Avatar';

interface FollowUpCardProps {
    contact: {
        id: string;
        first_name: string;
        last_name?: string;
        email?: string;
        phone?: string;
        company?: {
            name: string;
        };
        last_interaction?: string;
    };
    currentStatus?: string;
    onEmail?: () => void;
    onMove?: (status: string) => void;
    isDragging?: boolean;
}

export function FollowUpCard({ contact, onEmail, onMove, currentStatus, isDragging }: FollowUpCardProps) {
    const router = useRouter();

    const getInitials = () => {
        return `${contact.first_name[0]}${contact.last_name?.[0] || ''}`.toUpperCase();
    };

    const formatDate = (dateString?: string) => {
        if (!dateString) return 'No interactions';
        const date = new Date(dateString);
        const now = new Date();
        const diffDays = Math.floor((now.getTime() - date.getTime()) / (1000 * 60 * 60 * 24));

        if (diffDays === 0) return 'Today';
        if (diffDays === 1) return 'Yesterday';
        if (diffDays < 7) return `${diffDays} days ago`;
        return date.toLocaleDateString();
    };

    return (
        <div
            className={`premium-card p-4 transition-all ${isDragging ? 'opacity-50 rotate-2 shadow-xl ring-2 ring-indigo-500/20' : ''
                }`}
        >
            <div className="flex items-start gap-3">
                {/* Avatar */}
                <Avatar className="w-10 h-10 border border-stone-100">
                    <AvatarFallback className="text-sm bg-gradient-to-br from-indigo-500 to-indigo-600 text-white font-medium">
                        {getInitials()}
                    </AvatarFallback>
                </Avatar>

                {/* Info */}
                <div className="flex-1 min-w-0">
                    <h4 className="font-semibold text-stone-900 truncate">
                        {contact.first_name} {contact.last_name || ''}
                    </h4>
                    {contact.company && (
                        <p className="text-sm text-stone-500 truncate">{contact.company.name}</p>
                    )}
                    <p className="text-xs text-stone-400 mt-1">
                        Last: {formatDate(contact.last_interaction)}
                    </p>
                </div>
            </div>

            {/* Actions */}
            <div className="flex gap-2 mt-3">
                <Button
                    size="sm"
                    variant="outline"
                    onClick={onEmail}
                    className="flex-1"
                >
                    <Mail className="h-3 w-3 mr-1" />
                    Email
                </Button>
                {contact.phone && (
                    <Button
                        size="sm"
                        variant="ghost"
                        asChild
                    >
                        <a href={`tel:${contact.phone}`}>
                            <Phone className="h-3 w-3" />
                        </a>
                    </Button>
                )}
                <Button
                    size="sm"
                    variant="ghost"
                    onClick={() => router.push(`/contacts/${contact.id}`)}
                >
                    <Eye className="h-3 w-3" />
                </Button>
            </div>

            {/* Move Actions */}
            {onMove && (
                <div className="flex gap-2 mt-2 pt-2 border-t border-stone-50">
                    {currentStatus !== 'not_contacted' && (
                        <Button
                            size="sm"
                            variant="ghost"
                            className="text-[10px] h-7 px-2 flex-1 text-stone-400 hover:text-stone-600"
                            onClick={() => onMove('not_contacted')}
                        >
                            Reset
                        </Button>
                    )}
                    {currentStatus !== 'needs_followup' && (
                        <Button
                            size="sm"
                            variant="ghost"
                            className="text-[10px] h-7 px-2 flex-1 text-amber-600 hover:bg-amber-50"
                            onClick={() => onMove('needs_followup')}
                        >
                            To Needs List
                        </Button>
                    )}
                    {currentStatus !== 'followed_up' && (
                        <Button
                            size="sm"
                            variant="ghost"
                            className="text-[10px] h-7 px-2 flex-1 text-emerald-600 hover:bg-emerald-50"
                            onClick={() => onMove('followed_up')}
                        >
                            Mark Followed
                        </Button>
                    )}
                </div>
            )}
        </div>
    );
}
