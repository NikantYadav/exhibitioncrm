'use client';

import { useState, useEffect } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { AppShell } from '@/components/layout/AppShell';
import { Button } from '@/components/ui/Button';
import { Input } from '@/components/ui/Input';
import { Avatar, AvatarFallback } from '@/components/ui/Avatar';
import { Contact } from '@/types';
import { Skeleton } from '@/components/ui/Skeleton';
import { Search, Download, UserPlus, Mail, Phone, Briefcase, Trash2, Plus } from 'lucide-react';
import { toast } from 'sonner';
import { CaptureDropdown } from '@/components/capture/CaptureDropdown';

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
            <div className="max-w-7xl mx-auto px-4 py-8">
                {/* Page Header */}
                <div className="mb-12">
                    <div className="flex flex-col md:flex-row md:items-end justify-between gap-8 mb-10">
                        <div>
                            <h1 className="text-4xl font-black text-stone-900 tracking-tight leading-tight mb-2">Contacts</h1>
                            <p className="text-sm font-medium text-stone-500 italic">{contacts.length} contacts in your network</p>
                        </div>
                        <div className="flex items-center gap-4">
                            <a href="/api/export/excel" download>
                                <Button variant="outline" className="h-11 px-6 rounded-xl border-stone-200 hover:bg-stone-50 text-stone-900 font-bold transition-all shadow-sm">
                                    <Download className="mr-2 h-4 w-4" strokeWidth={2.5} />
                                    Export List
                                </Button>
                            </a>
                            <CaptureDropdown
                                trigger={
                                    <Button className="h-11 px-8 bg-stone-900 hover:bg-stone-800 text-white rounded-xl shadow-xl shadow-stone-900/10 font-black uppercase tracking-widest text-[10px] transition-all active:scale-95">
                                        <UserPlus className="mr-2 h-4 w-4" strokeWidth={2.5} />
                                        Add Contact
                                    </Button>
                                }
                            />
                        </div>
                    </div>

                    {/* Search Ecosystem */}
                    <div className="relative group">
                        <div className="absolute left-4 top-1/2 -translate-y-1/2 p-2 bg-stone-900 rounded-lg text-white shadow-lg transition-transform group-focus-within:scale-110">
                            <Search className="w-4 h-4" strokeWidth={2.5} />
                        </div>
                        <input
                            type="text"
                            placeholder="Search by name, company, or email..."
                            value={searchQuery}
                            onChange={(e) => setSearchQuery(e.target.value)}
                            className="w-full h-14 pl-16 pr-6 bg-white border border-stone-100 rounded-2xl text-stone-900 placeholder:text-stone-400 font-bold focus:outline-none focus:ring-4 focus:ring-stone-900/5 focus:border-stone-900 transition-all shadow-sm"
                        />
                    </div>
                </div>

                {/* Contacts List */}
                {loading ? (
                    <div className="grid gap-6">
                        {[1, 2, 3, 4].map((i) => (
                            <div key={i} className="bg-white rounded-[2rem] border border-stone-100 p-8 flex items-center gap-6">
                                <Skeleton className="h-16 w-16 rounded-[1.25rem] shrink-0" />
                                <div className="flex-1 space-y-3">
                                    <Skeleton className="h-6 w-1/4 rounded-lg" />
                                    <div className="flex gap-4">
                                        <Skeleton className="h-4 w-32 rounded-lg" />
                                        <Skeleton className="h-3 w-32 rounded-lg" />
                                    </div>
                                </div>
                            </div>
                        ))}
                    </div>
                ) : filteredContacts.length === 0 ? (
                    <div className="bg-stone-50/50 rounded-[3rem] p-24 text-center border-2 border-dashed border-stone-100 flex flex-col items-center">
                        <div className="mb-8 flex h-20 w-20 items-center justify-center rounded-[2rem] bg-stone-900 text-white shadow-2xl shadow-stone-900/10">
                            <UserPlus className="h-8 w-8" strokeWidth={2.5} />
                        </div>
                        <h3 className="text-2xl font-black text-stone-900 mb-3 tracking-tight">
                            {searchQuery ? 'No contacts found' : 'No contacts yet'}
                        </h3>
                        <p className="text-stone-500 font-medium italic mb-10 max-w-[380px]">
                            {searchQuery
                                ? 'No contacts matched your search. Try adjusting your filters.'
                                : 'Start building your network. Add a contact manually or scan a business card.'}
                        </p>
                        {!searchQuery && (
                            <CaptureDropdown
                                trigger={
                                    <Button size="lg" className="h-14 px-10 rounded-2xl bg-stone-900 hover:bg-stone-800 text-white font-black uppercase tracking-[0.2em] text-[10px] shadow-2xl shadow-stone-900/20 active:scale-95 transition-all">
                                        <Plus className="mr-3 h-5 w-5" strokeWidth={3} />
                                        Add First Contact
                                    </Button>
                                }
                            />
                        )}
                    </div>
                ) : (
                    <div className="grid grid-cols-1 gap-6">
                        {filteredContacts.map((contact) => (
                            <div
                                key={contact.id}
                                onClick={() => router.push(`/contacts/${contact.id}`)}
                                className="group relative bg-white rounded-[2.5rem] border border-stone-100 p-8 shadow-sm transition-all duration-500 cursor-pointer hover:shadow-2xl hover:shadow-stone-900/5 hover:border-stone-200"
                            >
                                <div className="flex items-center gap-8">
                                    <Avatar className="h-20 w-20 rounded-[1.5rem] border-4 border-stone-50 shadow-xl overflow-hidden ring-1 ring-stone-100 group-hover:scale-105 transition-transform duration-500">
                                        <AvatarFallback className="text-2xl bg-stone-900 text-white font-black tracking-tighter">
                                            {contact.first_name[0]}{contact.last_name?.[0] || ''}
                                        </AvatarFallback>
                                    </Avatar>

                                    <div className="flex-1 min-w-0">
                                        <div className="flex items-center gap-4 mb-3">
                                            <h3 className="text-2xl font-black text-stone-900 tracking-tight group-hover:text-stone-600 transition-colors">
                                                {contact.first_name} {contact.last_name || ''}
                                            </h3>
                                            {contact.job_title && (
                                                <span className="px-3 py-1 rounded-full bg-stone-50 text-stone-500 text-[9px] font-black uppercase tracking-[0.15em] border border-stone-100 mt-0.5">
                                                    {contact.job_title}
                                                </span>
                                            )}
                                        </div>

                                        <div className="flex flex-wrap items-center gap-x-10 gap-y-3">
                                            {contact.company?.name && (
                                                <div className="flex items-center gap-3">
                                                    <div className="p-1.5 bg-stone-900 rounded-lg text-white shadow-md">
                                                        <Briefcase className="w-3 h-3" strokeWidth={2.5} />
                                                    </div>
                                                    <span className="text-sm font-bold text-stone-600 truncate max-w-[200px]">{contact.company.name}</span>
                                                </div>
                                            )}
                                            {contact.email && (
                                                <div className="flex items-center gap-3">
                                                    <div className="p-1.5 bg-stone-900 rounded-lg text-white shadow-md">
                                                        <Mail className="w-3 h-3" strokeWidth={2.5} />
                                                    </div>
                                                    <span className="text-sm font-bold text-stone-600 truncate max-w-[250px]">{contact.email}</span>
                                                </div>
                                            )}
                                            {contact.phone && (
                                                <div className="flex items-center gap-3">
                                                    <div className="p-1.5 bg-stone-900 rounded-lg text-white shadow-md">
                                                        <Phone className="w-3 h-3" strokeWidth={2.5} />
                                                    </div>
                                                    <span className="text-sm font-bold text-stone-600">{contact.phone}</span>
                                                </div>
                                            )}
                                        </div>
                                    </div>

                                    <div className="hidden sm:flex flex-col items-end gap-5 shrink-0 ml-4">
                                        <div className="text-[10px] font-black text-stone-300 uppercase tracking-widest bg-stone-50 border border-stone-100 px-4 py-1.5 rounded-full">
                                            {new Date(contact.created_at).toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' })}
                                        </div>
                                        <div className="flex items-center gap-2">
                                            <Button
                                                variant="ghost"
                                                size="sm"
                                                onClick={(e) => handleDeleteContact(e, contact)}
                                                className="h-11 w-11 p-0 text-stone-200 hover:text-stone-900 hover:bg-stone-50 rounded-2xl opacity-0 group-hover:opacity-100 translate-x-4 group-hover:translate-x-0 transition-all duration-500"
                                            >
                                                <Trash2 className="w-5 h-5" strokeWidth={2} />
                                            </Button>
                                        </div>
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
