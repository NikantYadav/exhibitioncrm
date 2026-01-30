'use client';

import { FollowUpCard } from './FollowUpCard';
import { Users } from 'lucide-react';

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
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            {columns.map((column) => (
                <div key={column.id} className="flex flex-col">
                    {/* Column Header */}
                    <div className={`${column.color} rounded-t-lg p-4 border-b-4 border-opacity-50`}>
                        <h3 className="font-semibold text-gray-900 flex items-center justify-between">
                            <span>{column.title}</span>
                            <span className="bg-white bg-opacity-50 px-2 py-0.5 rounded-full text-sm">
                                {column.contacts.length}
                            </span>
                        </h3>
                    </div>

                    {/* Content Area */}
                    <div className="flex-1 bg-gray-50 rounded-b-lg p-4 min-h-[400px] space-y-3">
                        {column.contacts.length === 0 ? (
                            <div className="text-center py-12">
                                <Users className="h-12 w-12 text-gray-400 mx-auto mb-3" />
                                <p className="text-gray-600 text-sm">No contacts</p>
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
