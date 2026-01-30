'use client';

import { useState, useEffect } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { AppShell } from '@/components/layout/AppShell';
import { Button } from '@/components/ui/Button';
import { Input } from '@/components/ui/Input';
import { Avatar, AvatarFallback } from '@/components/ui/Avatar';
import { Contact } from '@/types';
import { Search, Download, UserPlus, Mail, Phone, Briefcase, Trash2 } from 'lucide-react';
import { toast } from 'sonner';

export default function ContactsPage() {
    const router = useRouter();
    const [contacts, setContacts] = useState<Contact[]>([]);
    const [loading, setLoading] = useState(true);
    const [searchQuery, setSearchQuery] = useState('');

    useEffect(() => {
        fetchContacts();
    }, []);

    const fetchContacts = async () => {
        try {
            const response = await fetch('/api/contacts');
            const data = await response.json();
            setContacts(data.data || []);
        } catch (error) {
            console.error('Failed to fetch contacts:', error);
        } finally {
            setLoading(false);
        }
    };

    const handleDeleteContact = async (e: React.MouseEvent, contact: Contact) => {
        e.stopPropagation(); // Prevent navigating to contact details

        if (!confirm(`Are you sure you want to delete ${contact.first_name} ${contact.last_name || ''}?`)) {
            return;
        }

        const deleteToast = toast.loading('Deleting contact...');
        try {
            const response = await fetch(`/api/contacts/${contact.id}`, {
                method: 'DELETE',
            });

            if (response.ok) {
                toast.success('Contact deleted', { id: deleteToast });
                setContacts(contacts.filter(c => c.id !== contact.id));
            } else {
                const error = await response.json();
                toast.error(error.error || 'Failed to delete contact', { id: deleteToast });
            }
        } catch (error) {
            console.error('Failed to delete contact:', error);
            toast.error('Error deleting contact', { id: deleteToast });
        }
    };

    const filteredContacts = contacts.filter(contact => {
        const query = searchQuery.toLowerCase();
        return (
            contact.first_name.toLowerCase().includes(query) ||
            contact.last_name?.toLowerCase().includes(query) ||
            contact.email?.toLowerCase().includes(query) ||
            contact.company?.name.toLowerCase().includes(query)
        );
    });

    return (
        <AppShell>
            <div className="max-w-7xl mx-auto">
                {/* Page Header */}
                <div className="mb-8">
                    <div className="flex items-center justify-between mb-6">
                        <div>
                            <h1 className="text-display mb-1">Contacts</h1>
                            <p className="text-body">{contacts.length} total contacts</p>
                        </div>
                        <div className="flex items-center gap-3">
                            <a href="/api/export?type=contacts">
                                <Button variant="secondary">
                                    <Download className="mr-2 h-4 w-4" strokeWidth={2} />
                                    Export
                                </Button>
                            </a>
                            <Link href="/capture">
                                <Button>
                                    <UserPlus className="mr-2 h-4 w-4" strokeWidth={2} />
                                    Add Contact
                                </Button>
                            </Link>
                        </div>
                    </div>

                    {/* Search */}
                    <div className="relative">
                        <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 w-5 h-5 text-stone-400" strokeWidth={2} />
                        <Input
                            type="text"
                            placeholder="Search by name, email, or company..."
                            value={searchQuery}
                            onChange={(e) => setSearchQuery(e.target.value)}
                            className="pl-10 h-11 bg-white"
                        />
                    </div>
                </div>

                {/* Contacts List */}
                {loading ? (
                    <div className="premium-card p-12 text-center">
                        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-indigo-600 mx-auto mb-4"></div>
                        <p className="text-body">Loading contacts...</p>
                    </div>
                ) : filteredContacts.length === 0 ? (
                    <div className="premium-card p-12 text-center">
                        <div className="mb-4 flex h-12 w-12 items-center justify-center rounded-full bg-stone-100 text-stone-400 mx-auto">
                            <UserPlus className="h-6 w-6" strokeWidth={2} />
                        </div>
                        <h3 className="text-card-title mb-2">
                            {searchQuery ? 'No contacts found' : 'No contacts yet'}
                        </h3>
                        <p className="text-body mb-6">
                            {searchQuery
                                ? 'Try adjusting your search criteria'
                                : 'Start by capturing a business card or adding a contact manually'}
                        </p>
                        {!searchQuery && (
                            <Link href="/capture">
                                <Button>
                                    <UserPlus className="mr-2 h-4 w-4" strokeWidth={2} />
                                    Add First Contact
                                </Button>
                            </Link>
                        )}
                    </div>
                ) : (
                    <div className="grid gap-4">
                        {filteredContacts.map((contact) => (
                            <div
                                key={contact.id}
                                onClick={() => router.push(`/contacts/${contact.id}`)}
                                className="premium-card p-6 hover:shadow-lg transition-smooth cursor-pointer group"
                            >
                                <div className="flex items-center gap-4">
                                    <Avatar className="h-12 w-12">
                                        <AvatarFallback className="text-sm bg-gradient-to-br from-indigo-400 to-indigo-600 text-white font-medium">
                                            {contact.first_name[0]}{contact.last_name?.[0] || ''}
                                        </AvatarFallback>
                                    </Avatar>
                                    <div className="flex-1 min-w-0">
                                        <h3 className="text-card-title group-hover:text-indigo-600 transition-colors">
                                            {contact.first_name} {contact.last_name || ''}
                                        </h3>
                                        <div className="flex items-center gap-4 mt-1 text-caption">
                                            {contact.company?.name && (
                                                <span className="flex items-center gap-1.5">
                                                    <Briefcase className="w-3.5 h-3.5" strokeWidth={2} />
                                                    {contact.company.name}
                                                </span>
                                            )}
                                            {contact.job_title && (
                                                <span>• {contact.job_title}</span>
                                            )}
                                        </div>
                                        <div className="flex items-center gap-4 mt-2 text-caption">
                                            {contact.email && (
                                                <span className="flex items-center gap-1.5">
                                                    <Mail className="w-3.5 h-3.5" strokeWidth={2} />
                                                    {contact.email}
                                                </span>
                                            )}
                                            {contact.phone && (
                                                <span className="flex items-center gap-1.5">
                                                    <Phone className="w-3.5 h-3.5" strokeWidth={2} />
                                                    {contact.phone}
                                                </span>
                                            )}
                                        </div>
                                    </div>
                                    <div className="flex flex-col items-end gap-2">
                                        <div className="text-caption">
                                            Added {new Date(contact.created_at).toLocaleDateString()}
                                        </div>
                                        <button
                                            onClick={(e) => handleDeleteContact(e, contact)}
                                            className="p-2 text-stone-400 hover:text-red-600 hover:bg-red-50 rounded-full transition-colors opacity-0 group-hover:opacity-100"
                                            title="Delete Contact"
                                        >
                                            <Trash2 className="w-4 h-4" />
                                        </button>
                                    </div>
                                </div>
                            </div>
                        ))}
                    </div>
                )}
            </div>
        </AppShell>
    );
}
