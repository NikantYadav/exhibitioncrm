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
            className={`bg-white rounded-[2rem] p-5 border border-stone-100 transition-all duration-300 cursor-grab active:cursor-grabbing ${isDragging ? 'opacity-50 rotate-2 shadow-2xl ring-4 ring-stone-900/5' : 'shadow-sm hover:border-stone-200'
                }`}
        >
            <div className="flex items-start gap-3">
                {/* Avatar */}
                <Avatar className="h-10 w-10 rounded-xl border border-white shadow-sm shrink-0">
                    <AvatarFallback className="text-xs bg-stone-900 text-white font-black tracking-tighter">
                        {getInitials()}
                    </AvatarFallback>
                </Avatar>

                {/* Info */}
                <div className="flex-1 min-w-0">
                    <h4 className="font-bold text-stone-900 text-sm truncate tracking-tight group-hover:text-stone-600 transition-colors">
                        {contact.first_name} {contact.last_name || ''}
                    </h4>
                    {contact.company && (
                        <p className="text-[11px] font-semibold text-stone-400 truncate mt-0.5">{contact.company.name}</p>
                    )}
                    <div className="flex items-center gap-1.5 mt-2">
                        <div className="h-1 w-1 rounded-full bg-stone-300" />
                        <p className="text-[9px] font-black text-stone-400 uppercase tracking-widest">
                            {formatDate(contact.last_interaction)}
                        </p>
                    </div>
                </div>

                <Button
                    variant="ghost"
                    size="sm"
                    onClick={() => router.push(`/contacts/${contact.id}`)}
                    className="h-8 w-8 p-0 rounded-lg text-stone-300 hover:text-stone-600 hover:bg-stone-50 transition-all shrink-0"
                >
                    <Eye className="h-4 w-4" />
                </Button>
            </div>

            {/* Actions Row */}
            <div className="flex gap-2 mt-5">
                <Button
                    size="sm"
                    variant="outline"
                    onClick={onEmail}
                    className="flex-1 h-9 text-[10px] font-black uppercase tracking-widest rounded-xl border-stone-200 hover:bg-stone-50 text-stone-900"
                >
                    <Mail className="h-3.5 w-3.5 mr-2" strokeWidth={3} />
                    Connect
                </Button>
                {contact.phone && (
                    <Button
                        size="sm"
                        variant="outline"
                        asChild
                        className="h-9 px-3 rounded-xl border-stone-200 hover:bg-stone-50 text-stone-900"
                    >
                        <a href={`tel:${contact.phone}`}>
                            <Phone className="h-3.5 w-3.5" strokeWidth={3} />
                        </a>
                    </Button>
                )}
            </div>

            {/* Move Actions (Only shown in Kanban) */}
            {onMove && (
                <div className="flex gap-1.5 mt-3 pt-3 border-t border-stone-100">
                    {currentStatus !== 'not_contacted' && (
                        <Button
                            size="sm"
                            variant="ghost"
                            className="h-7 px-0 flex-1 text-[9px] font-black text-stone-400 hover:text-stone-600 uppercase tracking-tighter"
                            onClick={() => onMove('not_contacted')}
                            title="Reset to New"
                        >
                            Reset
                        </Button>
                    )}
                    {currentStatus !== 'needs_followup' && (
                        <Button
                            size="sm"
                            variant="ghost"
                            className="h-7 px-0 flex-1 text-[9px] font-black text-amber-500 hover:bg-amber-50 uppercase tracking-tighter"
                            onClick={() => onMove('needs_followup')}
                        >
                            Needs F/U
                        </Button>
                    )}
                    {currentStatus !== 'followed_up' && (
                        <Button
                            size="sm"
                            variant="ghost"
                            className="h-7 px-0 flex-1 text-[9px] font-black text-emerald-500 hover:bg-emerald-50 uppercase tracking-tighter"
                            onClick={() => onMove('followed_up')}
                        >
                            Mark Done
                        </Button>
                    )}
                </div>
            )}
        </div>
    );
}
