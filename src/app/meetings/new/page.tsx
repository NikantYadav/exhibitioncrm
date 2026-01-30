'use client';

import { useState, useEffect } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { AppShell } from '@/components/layout/AppShell';
import { Button } from '@/components/ui/Button';
import { Input } from '@/components/ui/Input';
import { Textarea } from '@/components/ui/Textarea';
import { Select } from '@/components/ui/Select';
import { Avatar, AvatarFallback } from '@/components/ui/Avatar';
import { ArrowLeft, Search, Calendar, MapPin, Info, Zap } from 'lucide-react';
import { Contact } from '@/types';

import { toast } from 'sonner';

export default function NewMeetingPage() {
    const router = useRouter();
    const searchParams = useSearchParams();
    const preselectedContactId = searchParams.get('contactId');

    const [contacts, setContacts] = useState<Contact[]>([]);
    const [searchQuery, setSearchQuery] = useState('');
    const [selectedContact, setSelectedContact] = useState<Contact | null>(null);
    const [loading, setLoading] = useState(true);
    const [submitting, setSubmitting] = useState(false);

    const [formData, setFormData] = useState({
        meeting_date: '',
        meeting_time: '',
        meeting_type: 'in_person',
        meeting_location: '',
        pre_meeting_notes: '',
    });

    useEffect(() => {
        fetchContacts();
    }, []);

    const fetchContacts = async () => {
        try {
            const response = await fetch('/api/contacts');
            const data = await response.json();
            const allContacts = data.data || [];
            setContacts(allContacts);

            if (preselectedContactId) {
                const contact = allContacts.find((c: Contact) => c.id === preselectedContactId);
                if (contact) setSelectedContact(contact);
            }
        } catch (error) {
            console.error('Failed to fetch contacts:', error);
            toast.error('Failed to load contacts');
        } finally {
            setLoading(false);
        }
    };

    const filteredContacts = searchQuery.trim()
        ? contacts.filter(contact => {
            const query = searchQuery.toLowerCase();
            return (
                contact.first_name.toLowerCase().includes(query) ||
                contact.last_name?.toLowerCase().includes(query) ||
                contact.company?.name.toLowerCase().includes(query)
            );
        })
        : [];

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        if (!selectedContact) {
            toast.error('Please select a contact');
            return;
        }

        setSubmitting(true);
        try {
            const meetingDate = new Date(`${formData.meeting_date}T${formData.meeting_time || '00:00'}`);

            const response = await fetch('/api/meetings', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    contact_id: selectedContact.id,
                    company_id: selectedContact.company_id,
                    meeting_date: meetingDate.toISOString(),
                    meeting_type: formData.meeting_type,
                    meeting_location: formData.meeting_location,
                    pre_meeting_notes: formData.pre_meeting_notes,
                }),
            });

            if (!response.ok) {
                const error = await response.json();
                throw new Error(error.error || 'Failed to create meeting');
            }

            const data = await response.json();
            toast.success('Meeting scheduled successfully!');
            router.push(`/meetings/${data.meeting.id}`);
        } catch (error) {
            console.error('Error creating meeting:', error);
            toast.error('Internal Server Error');
        } finally {
            setSubmitting(false);
        }
    };

    return (
        <AppShell>
            <div className="max-w-3xl mx-auto py-8">
                <button
                    onClick={() => router.back()}
                    className="text-stone-400 hover:text-stone-900 transition-all mb-6 flex items-center gap-2 group font-bold text-xs uppercase tracking-widest"
                >
                    <ArrowLeft className="h-4 w-4 group-hover:-translate-x-1 transition-transform" strokeWidth={2.5} />
                    Meetings
                </button>

                <h1 className="text-4xl font-black text-stone-900 tracking-tight leading-tight mb-8">Schedule Meeting</h1>

                <form onSubmit={handleSubmit} className="space-y-8">
                    {/* Contact Selection */}
                    <section className="premium-card p-8">
                        <div className="flex items-center gap-3 mb-6">
                            <div className="p-2 bg-stone-900 text-white rounded-lg shadow-md">
                                <Search className="w-4 h-4" strokeWidth={2.5} />
                            </div>
                            <h2 className="text-xs font-black text-stone-900 uppercase tracking-[0.2em]">1. Choose Contact</h2>
                        </div>

                        {selectedContact ? (
                            <div className="flex items-center justify-between p-5 bg-stone-50 rounded-2xl border border-stone-100 shadow-inner">
                                <div className="flex items-center gap-4">
                                    <Avatar className="h-12 w-12 border-2 border-white shadow-sm">
                                        <AvatarFallback className="bg-stone-900 text-white font-black text-xs">
                                            {selectedContact.first_name[0]}{selectedContact.last_name?.[0] || ''}
                                        </AvatarFallback>
                                    </Avatar>
                                    <div>
                                        <p className="font-bold text-stone-900 text-lg">
                                            {selectedContact.first_name} {selectedContact.last_name || ''}
                                        </p>
                                        <p className="text-xs font-semibold text-stone-500 uppercase tracking-wider">{selectedContact.company?.name || 'No Company'}</p>
                                    </div>
                                </div>
                                <Button
                                    type="button"
                                    variant="ghost"
                                    size="sm"
                                    className="text-stone-400 hover:text-stone-900 font-bold"
                                    onClick={() => setSelectedContact(null)}
                                >
                                    Change
                                </Button>
                            </div>
                        ) : (
                            <div className="space-y-4">
                                <div className="relative">
                                    <Search className="absolute left-4 top-1/2 transform -translate-y-1/2 w-4 h-4 text-stone-400" />
                                    <Input
                                        placeholder="Search for a contact..."
                                        value={searchQuery}
                                        onChange={(e) => setSearchQuery(e.target.value)}
                                        className="pl-12 h-12 rounded-xl bg-stone-50/50 border-stone-100 focus:bg-white transition-all shadow-inner"
                                    />
                                </div>

                                {loading ? (
                                    <div className="p-8 text-center text-xs font-bold text-stone-400 uppercase tracking-widest animate-pulse">Searching contacts...</div>
                                ) : filteredContacts.length > 0 ? (
                                    <div className="max-h-60 overflow-y-auto border border-stone-100 rounded-2xl divide-y divide-stone-50 shadow-sm bg-white">
                                        {filteredContacts.map(contact => (
                                            <button
                                                key={contact.id}
                                                type="button"
                                                onClick={() => setSelectedContact(contact)}
                                                className="w-full flex items-center gap-4 p-4 hover:bg-stone-50 transition-all text-left group"
                                            >
                                                <Avatar className="h-10 w-10 border border-stone-100 group-hover:border-stone-200 transition-all">
                                                    <AvatarFallback className="text-xs bg-stone-100 text-stone-600 font-bold">
                                                        {contact.first_name[0]}{contact.last_name?.[0] || ''}
                                                    </AvatarFallback>
                                                </Avatar>
                                                <div>
                                                    <p className="text-sm font-bold text-stone-900 group-hover:text-stone-600 transition-colors">
                                                        {contact.first_name} {contact.last_name || ''}
                                                    </p>
                                                    <p className="text-[10px] font-black text-stone-400 uppercase tracking-widest leading-none mt-1">{contact.company?.name}</p>
                                                </div>
                                            </button>
                                        ))}
                                    </div>
                                ) : searchQuery.trim() ? (
                                    <div className="p-8 text-center text-xs font-bold text-stone-400 italic">No exact matches for "{searchQuery}"</div>
                                ) : null}
                            </div>
                        )}
                    </section>

                    {/* Meeting Details */}
                    <section className="premium-card p-8 space-y-8">
                        <div className="flex items-center gap-3">
                            <div className="p-2 bg-stone-900 text-white rounded-lg shadow-md">
                                <Calendar className="w-4 h-4" strokeWidth={2.5} />
                            </div>
                            <h2 className="text-xs font-black text-stone-900 uppercase tracking-[0.2em]">2. Meeting Details</h2>
                        </div>

                        <div className="grid grid-cols-2 gap-6">
                            <Input
                                label="Date"
                                type="date"
                                required
                                value={formData.meeting_date}
                                onChange={(e) => setFormData({ ...formData, meeting_date: e.target.value })}
                                className="h-11 rounded-xl"
                            />
                            <Input
                                label="Scheduled Time"
                                type="time"
                                required
                                value={formData.meeting_time}
                                onChange={(e) => setFormData({ ...formData, meeting_time: e.target.value })}
                                className="h-11 rounded-xl"
                            />
                        </div>

                        <div className="grid grid-cols-2 gap-6">
                            <Select
                                label="Meeting Type"
                                value={formData.meeting_type}
                                onChange={(e) => setFormData({ ...formData, meeting_type: e.target.value })}
                                className="h-11 rounded-xl"
                            >
                                <option value="in_person">In Person / Onsite</option>
                                <option value="virtual">Virtual / Video Conferencing</option>
                                <option value="phone">Direct Voice Call</option>
                            </Select>
                            <Input
                                label="Location"
                                placeholder="e.g. Hall 4 Booth 202, Zoom URL"
                                value={formData.meeting_location}
                                onChange={(e) => setFormData({ ...formData, meeting_location: e.target.value })}
                                className="h-11 rounded-xl"
                            />
                        </div>

                        <Textarea
                            label="Notes"
                            placeholder="Enter any notes for this meeting..."
                            rows={6}
                            value={formData.pre_meeting_notes}
                            onChange={(e) => setFormData({ ...formData, pre_meeting_notes: e.target.value })}
                            className="rounded-[1.5rem] bg-stone-50/30 p-4 border-stone-100"
                        />

                        <div className="bg-stone-900 p-6 rounded-[2rem] flex gap-4 text-white shadow-2xl relative overflow-hidden group">
                            <div className="absolute top-0 right-0 p-8 opacity-5 -rotate-12 translate-x-4 -translate-y-4 group-hover:scale-110 transition-transform duration-700">
                                <Zap size={80} strokeWidth={2.5} />
                            </div>
                            <div className="h-10 w-10 bg-white/10 rounded-xl flex items-center justify-center shrink-0 border border-white/20">
                                <Info className="h-5 w-5 text-white" strokeWidth={2.5} />
                            </div>
                            <div>
                                <p className="text-xs font-black uppercase tracking-widest mb-1 opacity-60">AI Insight</p>
                                <p className="text-sm font-medium leading-relaxed">
                                    AI will suggest talking points based on your interaction history and market research.
                                </p>
                            </div>
                        </div>
                    </section>

                    <div className="flex justify-end items-center gap-6 pt-4 pb-12">
                        <button
                            type="button"
                            className="text-xs font-black uppercase tracking-[0.2em] text-stone-400 hover:text-stone-900 transition-colors"
                            onClick={() => router.back()}
                            disabled={submitting}
                        >
                            Cancel
                        </button>
                        <Button
                            type="submit"
                            className="h-14 px-10 bg-stone-900 hover:bg-stone-800 text-white rounded-[1.25rem] shadow-xl shadow-stone-900/20 font-black uppercase tracking-widest text-xs transition-all hover:scale-[1.02] active:scale-[0.98]"
                            disabled={submitting || !selectedContact}
                        >
                            {submitting ? 'Scheduling...' : 'Schedule Meeting'}
                        </Button>
                    </div>
                </form>
            </div>
        </AppShell>
    );
}
