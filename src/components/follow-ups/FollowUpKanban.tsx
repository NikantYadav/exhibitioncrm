'use client';

import { FollowUpCard } from './FollowUpCard';
import { Users } from 'lucide-react';
import { cn } from '@/lib/utils';

interface Contact {
    id: string;
    first_name: string;
    last_name?: string;
    email?: string;
    phone?: string;
    company?: { name: string };
    last_interaction?: string;
}

interface Column {
    id: string;
    title: string;
    contacts: Contact[];
    color: string;
}

interface FollowUpKanbanProps {
    columns: Column[];
    onContactMove: (contactId: string, newStatus: string) => void;
    onEmailContact: (contact: Contact) => void;
}

export function FollowUpKanban({ columns, onContactMove, onEmailContact }: FollowUpKanbanProps) {
    return (
        <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
            {columns.map((column) => (
                <div key={column.id} className="flex flex-col h-full">
                    {/* Column Header */}
                    <div className="flex items-center justify-between mb-5 px-3">
                        <div className="flex items-center gap-3">
                            <div className={cn(
                                "h-2 w-2 rounded-full",
                                column.id === 'not_contacted' ? "bg-stone-300" :
                                    column.id === 'needs_followup' ? "bg-stone-500" :
                                        "bg-stone-900"
                            )} />
                            <h3 className="font-black text-stone-900 text-[10px] uppercase tracking-[0.2em]">{column.title}</h3>
                        </div>
                        <span className="bg-stone-100/50 border border-stone-100 text-stone-900 px-3 py-1 rounded-lg text-[9px] font-black tracking-widest leading-none">
                            {column.contacts.length}
                        </span>
                    </div>

                    {/* Content Area */}
                    <div className="flex-1 bg-stone-50/50 rounded-[2rem] p-5 border border-stone-100/80 shadow-[inset_0_2px_4px_rgba(0,0,0,0.02)] space-y-4 min-h-[500px]">
                        {column.contacts.length === 0 ? (
                            <div className="h-full flex flex-col items-center justify-center text-center opacity-40 py-16">
                                <div className="p-4 bg-white rounded-2xl border border-stone-100 mb-4 shadow-sm">
                                    <Users className="h-8 w-8 text-stone-300" strokeWidth={2} />
                                </div>
                                <p className="text-stone-400 text-[9px] font-black uppercase tracking-widest">No connections</p>
                            </div>
                        ) : (
                            column.contacts.map((contact) => (
                                <FollowUpCard
                                    key={contact.id}
                                    contact={contact}
                                    currentStatus={column.id}
                                    onEmail={() => onEmailContact(contact)}
                                    onMove={(newStatus) => onContactMove(contact.id, newStatus)}
                                />
                            ))
                        )}
                    </div>
                </div>
            ))}
        </div>
    );
}
