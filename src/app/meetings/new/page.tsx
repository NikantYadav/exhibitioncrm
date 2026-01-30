'use client';

import { useState, useEffect } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { AppShell } from '@/components/layout/AppShell';
import { Button } from '@/components/ui/Button';
import { Input } from '@/components/ui/Input';
import { Textarea } from '@/components/ui/Textarea';
import { Select } from '@/components/ui/Select';
import { Avatar, AvatarFallback } from '@/components/ui/Avatar';
import { ArrowLeft, Search, Calendar, MapPin, Info } from 'lucide-react';
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
            toast.error(error instanceof Error ? error.message : 'Failed to create meeting');
        } finally {
            setSubmitting(false);
        }
    };

    return (
        <AppShell>
            <div className="max-w-3xl mx-auto">
                <button
                    onClick={() => router.back()}
                    className="text-caption hover:text-stone-900 transition-colors mb-4 flex items-center gap-1"
                >
                    <ArrowLeft className="h-4 w-4" strokeWidth={2} />
                    Back
                </button>

                <h1 className="text-display mb-8">Schedule New Meeting</h1>

                <form onSubmit={handleSubmit} className="space-y-8">
                    {/* Contact Selection */}
                    <section className="premium-card p-6">
                        <h2 className="text-section-header mb-4">1. Select Contact</h2>

                        {selectedContact ? (
                            <div className="flex items-center justify-between p-4 bg-stone-50 rounded-xl border border-stone-200">
                                <div className="flex items-center gap-3">
                                    <Avatar className="h-10 w-10">
                                        <AvatarFallback className="bg-indigo-600 text-white">
                                            {selectedContact.first_name[0]}{selectedContact.last_name?.[0] || ''}
                                        </AvatarFallback>
                                    </Avatar>
                                    <div>
                                        <p className="font-medium text-stone-900">
                                            {selectedContact.first_name} {selectedContact.last_name || ''}
                                        </p>
                                        <p className="text-caption">{selectedContact.company?.name || 'No Company'}</p>
                                    </div>
                                </div>
                                <Button
                                    type="button"
                                    variant="secondary"
                                    size="sm"
                                    onClick={() => setSelectedContact(null)}
                                >
                                    Change
                                </Button>
                            </div>
                        ) : (
                            <div className="space-y-4">
                                <div className="relative">
                                    <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-stone-400" />
                                    <Input
                                        placeholder="Search contacts..."
                                        value={searchQuery}
                                        onChange={(e) => setSearchQuery(e.target.value)}
                                        className="pl-9"
                                    />
                                </div>

                                {loading ? (
                                    <div className="p-4 text-center text-caption italic text-stone-400">Loading contacts...</div>
                                ) : filteredContacts.length > 0 ? (
                                    <div className="max-h-60 overflow-y-auto border border-stone-200 rounded-xl divide-y divide-stone-100">
                                        {filteredContacts.map(contact => (
                                            <button
                                                key={contact.id}
                                                type="button"
                                                onClick={() => setSelectedContact(contact)}
                                                className="w-full flex items-center gap-3 p-3 hover:bg-stone-50 transition-colors text-left"
                                            >
                                                <Avatar className="h-8 w-8">
                                                    <AvatarFallback className="text-xs bg-stone-200 text-stone-600">
                                                        {contact.first_name[0]}{contact.last_name?.[0] || ''}
                                                    </AvatarFallback>
                                                </Avatar>
                                                <div>
                                                    <p className="text-sm font-medium text-stone-900">
                                                        {contact.first_name} {contact.last_name || ''}
                                                    </p>
                                                    <p className="text-xs text-stone-500">{contact.company?.name}</p>
                                                </div>
                                            </button>
                                        ))}
                                    </div>
                                ) : searchQuery.trim() ? (
                                    <div className="p-4 text-center text-caption italic text-stone-400">No contacts found for "{searchQuery}"</div>
                                ) : null}
                            </div>
                        )}
                    </section>

                    {/* Meeting Details */}
                    <section className="premium-card p-6 space-y-6">
                        <h2 className="text-section-header mb-4">2. Meeting Details</h2>

                        <div className="grid grid-cols-2 gap-4">
                            <Input
                                label="Date"
                                type="date"
                                required
                                value={formData.meeting_date}
                                onChange={(e) => setFormData({ ...formData, meeting_date: e.target.value })}
                            />
                            <Input
                                label="Time"
                                type="time"
                                required
                                value={formData.meeting_time}
                                onChange={(e) => setFormData({ ...formData, meeting_time: e.target.value })}
                            />
                        </div>

                        <div className="grid grid-cols-2 gap-4">
                            <Select
                                label="Type"
                                value={formData.meeting_type}
                                onChange={(e) => setFormData({ ...formData, meeting_type: e.target.value })}
                            >
                                <option value="in_person">In Person</option>
                                <option value="virtual">Virtual (Zoom/Teams)</option>
                                <option value="phone">Phone Call</option>
                            </Select>
                            <Input
                                label="Location / Link"
                                placeholder="Booth 402, Zoom link, etc."
                                value={formData.meeting_location}
                                onChange={(e) => setFormData({ ...formData, meeting_location: e.target.value })}
                            />
                        </div>

                        <Textarea
                            label="Pre-Meeting Notes"
                            placeholder="What do you want to discuss? Any specific goals?"
                            rows={4}
                            value={formData.pre_meeting_notes}
                            onChange={(e) => setFormData({ ...formData, pre_meeting_notes: e.target.value })}
                        />

                        <div className="bg-indigo-50 p-4 rounded-xl flex gap-3 text-indigo-700">
                            <Info className="h-5 w-5 shrink-0" />
                            <p className="text-sm">
                                After scheduling, our AI will generate professional talking points based on your relationship history and company research.
                            </p>
                        </div>
                    </section>

                    <div className="flex justify-end gap-3">
                        <Button
                            type="button"
                            variant="secondary"
                            onClick={() => router.back()}
                            disabled={submitting}
                        >
                            Cancel
                        </Button>
                        <Button
                            type="submit"
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
