import { SuggestedNote } from '@/lib/services/note-service';
import { Button } from '@/components/ui/Button';
import { Card, CardContent } from '@/components/ui/Card';
import { Input } from '@/components/ui/Input';
import { Check, X, User, Calendar, Edit2, Search, Loader2 } from 'lucide-react';
import { useState, useEffect } from 'react';

interface NoteReviewProps {
    note: SuggestedNote;
    onSave: (note: SuggestedNote) => Promise<void>;
    onCancel: () => void;
    isSaving: boolean;
}

interface Contact {
    id: string;
    first_name: string;
    last_name: string;
    company?: { name: string };
}

interface Event {
    id: string;
    name: string;
}

export function NoteReview({ note, onSave, onCancel, isSaving }: NoteReviewProps) {
    const [editedNote, setEditedNote] = useState(note);
    const [isEditingContent, setIsEditingContent] = useState(false);

    const [isSelectingContact, setIsSelectingContact] = useState(false);
    const [isSelectingEvent, setIsSelectingEvent] = useState(false);

    const [contacts, setContacts] = useState<Contact[]>([]);
    const [events, setEvents] = useState<Event[]>([]);
    const [isLoadingData, setIsLoadingData] = useState(false);

    const [contactSearch, setContactSearch] = useState('');
    const [eventSearch, setEventSearch] = useState('');

    useEffect(() => {
        const fetchData = async () => {
            setIsLoadingData(true);
            try {
                const [contactsRes, eventsRes] = await Promise.all([
                    fetch('/api/contacts'),
                    fetch('/api/events')
                ]);
                const contactsData = await contactsRes.json();
                const eventsData = await eventsRes.json();
                setContacts(contactsData.data || []);
                setEvents(eventsData.data || []);
            } catch (error) {
                console.error('Failed to fetch selection data:', error);
            } finally {
                setIsLoadingData(false);
            }
        };
        fetchData();
    }, []);

    const filteredContacts = contacts.filter(c =>
        contactSearch === '' ||
        `${c.first_name} ${c.last_name}`.toLowerCase().includes(contactSearch.toLowerCase()) ||
        c.company?.name.toLowerCase().includes(contactSearch.toLowerCase())
    );

    const filteredEvents = events.filter(e =>
        eventSearch === '' || e.name.toLowerCase().includes(eventSearch.toLowerCase())
    );

    return (
        <div className="space-y-4 animate-in fade-in slide-in-from-bottom-4 duration-300">
            <div className="bg-indigo-50 border border-indigo-100 rounded-lg p-4">
                <div className="flex items-start gap-3">
                    <div className="p-2 bg-white rounded-full shadow-sm">
                        <Check className="h-5 w-5 text-indigo-600" />
                    </div>
                    <div className="flex-1">
                        <h3 className="font-semibold text-indigo-900">Interpretation</h3>
                        <p className="text-sm text-indigo-700 mt-1">
                            Verify the details below before saving your note.
                        </p>
                    </div>
                </div>
            </div>

            <Card className="border-indigo-200 shadow-md overflow-hidden">
                <CardContent className="p-0">
                    {/* Content Preview */}
                    <div className="p-4 border-b border-gray-100">
                        <div className="flex justify-between items-start mb-2">
                            <h4 className="text-[10px] font-bold text-gray-400 uppercase tracking-widest">Note Content</h4>
                            <Button
                                variant="ghost"
                                size="sm"
                                onClick={() => setIsEditingContent(!isEditingContent)}
                                className="h-6 px-2 text-[10px] font-bold text-indigo-600 hover:bg-indigo-50"
                            >
                                <Edit2 className="h-3 w-3 mr-1" />
                                Edit Text
                            </Button>
                        </div>
                        {isEditingContent ? (
                            <textarea
                                className="w-full text-sm p-3 border border-indigo-100 rounded-xl focus:ring-2 focus:ring-indigo-500/20 focus:border-indigo-500 transition-all outline-none"
                                value={editedNote.formatted_content}
                                onChange={(e) => setEditedNote({ ...editedNote, formatted_content: e.target.value })}
                                rows={3}
                                autoFocus
                            />
                        ) : (
                            <p className="text-gray-800 text-sm leading-relaxed italic border-l-2 border-indigo-200 pl-4 py-1">
                                "{editedNote.formatted_content}"
                            </p>
                        )}
                    </div>

                    {/* Links */}
                    <div className="p-4 bg-gray-50/50 space-y-4">
                        {/* Contact Selection */}
                        <div className="space-y-2">
                            <div className="flex justify-between items-center">
                                <span className="text-[10px] font-bold text-gray-400 uppercase tracking-widest">Linked Contact</span>
                                <Button
                                    variant="ghost"
                                    size="sm"
                                    onClick={() => {
                                        setIsSelectingContact(!isSelectingContact);
                                        setIsSelectingEvent(false);
                                    }}
                                    className="h-6 px-2 text-[10px] font-bold text-indigo-600 hover:bg-indigo-50"
                                >
                                    {isSelectingContact ? 'Cancel' : (editedNote.contact_id ? 'Change' : 'Link Contact')}
                                </Button>
                            </div>

                            {isSelectingContact ? (
                                <div className="space-y-2 animate-in fade-in slide-in-from-top-2 duration-200">
                                    <div className="relative">
                                        <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-3.5 w-3.5 text-gray-400" />
                                        <input
                                            value={contactSearch}
                                            onChange={e => setContactSearch(e.target.value)}
                                            placeholder="Search contacts..."
                                            className="w-full pl-9 pr-4 py-2 text-sm bg-white border border-gray-200 rounded-lg focus:ring-2 focus:ring-indigo-500/10 outline-none"
                                            autoFocus
                                        />
                                    </div>
                                    <div className="max-h-40 overflow-y-auto border border-gray-100 rounded-lg bg-white shadow-inner">
                                        {isLoadingData ? (
                                            <div className="p-4 flex justify-center"><Loader2 className="h-4 w-4 animate-spin text-indigo-400" /></div>
                                        ) : filteredContacts.length > 0 ? (
                                            filteredContacts.map(c => (
                                                <button
                                                    key={c.id}
                                                    onClick={() => {
                                                        const name = `${c.first_name} ${c.last_name}${c.company ? ` (${c.company.name})` : ''}`;
                                                        setEditedNote({ ...editedNote, contact_id: c.id, contact_name: name });
                                                        setIsSelectingContact(false);
                                                    }}
                                                    className="w-full text-left px-4 py-2 text-sm hover:bg-indigo-50 transition-colors border-b border-gray-50 last:border-0"
                                                >
                                                    <div className="font-semibold text-gray-900">{c.first_name} {c.last_name}</div>
                                                    {c.company && <div className="text-[10px] text-gray-400 uppercase font-bold">{c.company.name}</div>}
                                                </button>
                                            ))
                                        ) : (
                                            <div className="p-4 text-center text-xs text-gray-400 italic">No contacts found</div>
                                        )}
                                    </div>
                                </div>
                            ) : (
                                <div className={`flex items-center gap-3 p-3 rounded-xl border ${editedNote.contact_id ? 'bg-white border-indigo-100 shadow-sm' : 'bg-gray-100/50 border-dashed border-gray-200'}`}>
                                    <div className={`p-2 rounded-lg ${editedNote.contact_id ? 'bg-indigo-50' : 'bg-gray-200'}`}>
                                        <User className={`h-4 w-4 ${editedNote.contact_id ? 'text-indigo-600' : 'text-gray-500'}`} />
                                    </div>
                                    <span className={`text-sm font-bold ${editedNote.contact_id ? 'text-gray-900' : 'text-gray-400 italic'}`}>
                                        {editedNote.contact_name || 'No contact specified'}
                                    </span>
                                    {editedNote.contact_id && <Check className="h-3.5 w-3.5 text-green-500 ml-auto" />}
                                </div>
                            )}
                        </div>

                        {/* Event Selection */}
                        <div className="space-y-2">
                            <div className="flex justify-between items-center">
                                <span className="text-[10px] font-bold text-gray-400 uppercase tracking-widest">Linked Event</span>
                                <Button
                                    variant="ghost"
                                    size="sm"
                                    onClick={() => {
                                        setIsSelectingEvent(!isSelectingEvent);
                                        setIsSelectingContact(false);
                                    }}
                                    className="h-6 px-2 text-[10px] font-bold text-indigo-600 hover:bg-indigo-50"
                                >
                                    {isSelectingEvent ? 'Cancel' : (editedNote.event_id ? 'Change' : 'Link Event')}
                                </Button>
                            </div>

                            {isSelectingEvent ? (
                                <div className="space-y-2 animate-in fade-in slide-in-from-top-2 duration-200">
                                    <div className="relative">
                                        <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-3.5 w-3.5 text-gray-400" />
                                        <input
                                            value={eventSearch}
                                            onChange={e => setEventSearch(e.target.value)}
                                            placeholder="Search events..."
                                            className="w-full pl-9 pr-4 py-2 text-sm bg-white border border-gray-200 rounded-lg focus:ring-2 focus:ring-indigo-500/10 outline-none"
                                            autoFocus
                                        />
                                    </div>
                                    <div className="max-h-40 overflow-y-auto border border-gray-100 rounded-lg bg-white shadow-inner">
                                        {isLoadingData ? (
                                            <div className="p-4 flex justify-center"><Loader2 className="h-4 w-4 animate-spin text-indigo-400" /></div>
                                        ) : filteredEvents.length > 0 ? (
                                            filteredEvents.map(e => (
                                                <button
                                                    key={e.id}
                                                    onClick={() => {
                                                        setEditedNote({ ...editedNote, event_id: e.id, event_name: e.name });
                                                        setIsSelectingEvent(false);
                                                    }}
                                                    className="w-full text-left px-4 py-2 text-sm hover:bg-indigo-50 transition-colors border-b border-gray-50 last:border-0"
                                                >
                                                    <div className="font-semibold text-gray-900">{e.name}</div>
                                                </button>
                                            ))
                                        ) : (
                                            <div className="p-4 text-center text-xs text-gray-400 italic">No events found</div>
                                        )}
                                    </div>
                                </div>
                            ) : (
                                <div className={`flex items-center gap-3 p-3 rounded-xl border ${editedNote.event_id ? 'bg-white border-indigo-100 shadow-sm' : 'bg-gray-100/50 border-dashed border-gray-200'}`}>
                                    <div className={`p-2 rounded-lg ${editedNote.event_id ? 'bg-indigo-50' : 'bg-gray-200'}`}>
                                        <Calendar className={`h-4 w-4 ${editedNote.event_id ? 'text-indigo-600' : 'text-gray-500'}`} />
                                    </div>
                                    <span className={`text-sm font-bold ${editedNote.event_id ? 'text-gray-900' : 'text-gray-400 italic'}`}>
                                        {editedNote.event_name || 'No event specified'}
                                    </span>
                                    {editedNote.event_id && <Check className="h-3.5 w-3.5 text-green-500 ml-auto" />}
                                </div>
                            )}
                        </div>
                    </div>

                    {/* Actions */}
                    <div className="p-4 flex gap-3 bg-white">
                        <Button
                            variant="secondary"
                            className="flex-1 rounded-xl"
                            onClick={onCancel}
                            disabled={isSaving}
                        >
                            <X className="h-4 w-4 mr-2" />
                            Discard
                        </Button>
                        <Button
                            className="flex-1 bg-stone-900 hover:bg-black text-white rounded-xl shadow-lg shadow-indigo-100"
                            onClick={() => onSave(editedNote)}
                            disabled={isSaving || isSelectingContact || isSelectingEvent}
                        >
                            {isSaving ? (
                                <Loader2 className="h-4 w-4 animate-spin mr-2" />
                            ) : (
                                <>
                                    <Check className="h-4 w-4 mr-2" />
                                    Confirm & Save
                                </>
                            )}
                        </Button>
                    </div>
                </CardContent>
            </Card>
        </div>
    );
}
