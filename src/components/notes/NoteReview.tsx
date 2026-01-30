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
        <div className="space-y-4 animate-in fade-in duration-300">
            <div className="bg-stone-50 border border-stone-100 rounded-2xl p-4">
                <div className="flex items-start gap-4">
                    <div className="p-2.5 bg-stone-900 rounded-xl shadow-md">
                        <Check className="h-5 w-5 text-white" strokeWidth={3} />
                    </div>
                    <div className="flex-1">
                        <h3 className="font-black text-stone-900 tracking-tight leading-tight">Review Note</h3>
                        <p className="text-xs text-stone-400 font-bold uppercase tracking-widest mt-1">
                            Please check these details before saving.
                        </p>
                    </div>
                </div>
            </div>

            <Card className="border-stone-100 shadow-xl shadow-stone-900/5 overflow-hidden rounded-[2rem]">
                <CardContent className="p-0">
                    {/* Content Preview */}
                    <div className="p-6 border-b border-stone-50">
                        <div className="flex justify-between items-start mb-4">
                            <h4 className="text-[10px] font-black text-stone-300 uppercase tracking-widest">Note Details</h4>
                            <Button
                                variant="ghost"
                                size="sm"
                                onClick={() => setIsEditingContent(!isEditingContent)}
                                className="h-7 px-3 text-[10px] font-black text-stone-900 hover:bg-stone-50 rounded-lg uppercase tracking-widest"
                            >
                                <Edit2 className="h-3 w-3 mr-2" strokeWidth={3} />
                                Edit
                            </Button>
                        </div>
                        {isEditingContent ? (
                            <textarea
                                className="w-full text-sm font-medium p-4 border border-stone-100 rounded-2xl focus:ring-2 focus:ring-stone-200 focus:border-stone-300 transition-all outline-none bg-stone-50/50"
                                value={editedNote.formatted_content}
                                onChange={(e) => setEditedNote({ ...editedNote, formatted_content: e.target.value })}
                                rows={3}
                                autoFocus
                            />
                        ) : (
                            <p className="text-stone-800 text-sm font-medium leading-relaxed italic border-l-3 border-stone-900 pl-4 py-1">
                                "{editedNote.formatted_content}"
                            </p>
                        )}
                    </div>

                    {/* Links */}
                    <div className="p-6 bg-stone-50/50 space-y-4">
                        {/* Contact Selection */}
                        <div className="space-y-2">
                            <div className="flex justify-between items-center">
                                <span className="text-[10px] font-black text-stone-300 uppercase tracking-widest">Link to Person</span>
                                <Button
                                    variant="ghost"
                                    size="sm"
                                    onClick={() => {
                                        setIsSelectingContact(!isSelectingContact);
                                        setIsSelectingEvent(false);
                                    }}
                                    className="h-7 px-3 text-[10px] font-black text-stone-900 hover:bg-stone-100 rounded-lg uppercase tracking-widest"
                                >
                                    {isSelectingContact ? 'Cancel' : (editedNote.contact_id ? 'Change' : 'Find Person')}
                                </Button>
                            </div>

                            {isSelectingContact ? (
                                <div className="space-y-2 animate-in fade-in duration-300">
                                    <div className="relative">
                                        <Search className="absolute left-4 top-1/2 -translate-y-1/2 h-4 w-4 text-stone-300" />
                                        <input
                                            value={contactSearch}
                                            onChange={e => setContactSearch(e.target.value)}
                                            placeholder="Search people..."
                                            className="w-full pl-11 pr-4 h-11 text-sm bg-white border border-stone-100 rounded-xl focus:ring-2 focus:ring-stone-200 outline-none font-medium"
                                            autoFocus
                                        />
                                    </div>
                                    <div className="max-h-40 overflow-y-auto border border-stone-100 rounded-xl bg-white shadow-xl shadow-stone-900/5">
                                        {isLoadingData ? (
                                            <div className="p-6 flex justify-center"><Loader2 className="h-5 w-5 animate-spin text-stone-300" /></div>
                                        ) : filteredContacts.length > 0 ? (
                                            filteredContacts.map(c => (
                                                <button
                                                    key={c.id}
                                                    onClick={() => {
                                                        const name = `${c.first_name} ${c.last_name}${c.company ? ` (${c.company.name})` : ''}`;
                                                        setEditedNote({ ...editedNote, contact_id: c.id, contact_name: name });
                                                        setIsSelectingContact(false);
                                                    }}
                                                    className="w-full text-left px-5 py-3 text-sm hover:bg-stone-50 transition-colors border-b border-stone-50 last:border-0 font-bold text-stone-900 flex flex-col"
                                                >
                                                    <span>{c.first_name} {c.last_name}</span>
                                                    {c.company && <span className="text-[9px] text-stone-400 font-black uppercase tracking-widest mt-0.5">{c.company.name}</span>}
                                                </button>
                                            ))
                                        ) : (
                                            <div className="p-6 text-center text-xs text-stone-400 font-bold uppercase tracking-widest">No results</div>
                                        )}
                                    </div>
                                </div>
                            ) : (
                                <div className={`flex items-center gap-4 p-4 rounded-2xl border transition-all ${editedNote.contact_id ? 'bg-white border-stone-200 shadow-sm' : 'bg-stone-100/50 border-dashed border-stone-200'}`}>
                                    <div className={`h-10 w-10 rounded-xl flex items-center justify-center shadow-sm ${editedNote.contact_id ? 'bg-stone-900 text-white' : 'bg-stone-200 text-stone-400'}`}>
                                        <User className="h-5 w-5" strokeWidth={2.5} />
                                    </div>
                                    <span className={`text-sm font-black tracking-tight ${editedNote.contact_id ? 'text-stone-900' : 'text-stone-400 italic'}`}>
                                        {editedNote.contact_name || 'No person linked'}
                                    </span>
                                    {editedNote.contact_id && <Check className="h-4 w-4 text-stone-900 ml-auto" strokeWidth={3} />}
                                </div>
                            )}
                        </div>

                        {/* Event Selection */}
                        <div className="space-y-2">
                            <div className="flex justify-between items-center">
                                <span className="text-[10px] font-black text-stone-300 uppercase tracking-widest">Link to Event</span>
                                <Button
                                    variant="ghost"
                                    size="sm"
                                    onClick={() => {
                                        setIsSelectingEvent(!isSelectingEvent);
                                        setIsSelectingContact(false);
                                    }}
                                    className="h-7 px-3 text-[10px] font-black text-stone-900 hover:bg-stone-100 rounded-lg uppercase tracking-widest"
                                >
                                    {isSelectingEvent ? 'Cancel' : (editedNote.event_id ? 'Change' : 'Find Event')}
                                </Button>
                            </div>

                            {isSelectingEvent ? (
                                <div className="space-y-2 animate-in fade-in duration-300">
                                    <div className="relative">
                                        <Search className="absolute left-4 top-1/2 -translate-y-1/2 h-4 w-4 text-stone-300" />
                                        <input
                                            value={eventSearch}
                                            onChange={e => setEventSearch(e.target.value)}
                                            placeholder="Search events..."
                                            className="w-full pl-11 pr-4 h-11 text-sm bg-white border border-stone-100 rounded-xl focus:ring-2 focus:ring-stone-200 outline-none font-medium"
                                            autoFocus
                                        />
                                    </div>
                                    <div className="max-h-40 overflow-y-auto border border-stone-100 rounded-xl bg-white shadow-xl shadow-stone-900/5">
                                        {isLoadingData ? (
                                            <div className="p-6 flex justify-center"><Loader2 className="h-5 w-5 animate-spin text-stone-300" /></div>
                                        ) : filteredEvents.length > 0 ? (
                                            filteredEvents.map(e => (
                                                <button
                                                    key={e.id}
                                                    onClick={() => {
                                                        setEditedNote({ ...editedNote, event_id: e.id, event_name: e.name });
                                                        setIsSelectingEvent(false);
                                                    }}
                                                    className="w-full text-left px-5 py-3 text-sm hover:bg-stone-50 transition-colors border-b border-stone-50 last:border-0 font-bold text-stone-900"
                                                >
                                                    {e.name}
                                                </button>
                                            ))
                                        ) : (
                                            <div className="p-6 text-center text-xs text-stone-400 font-bold uppercase tracking-widest">No results</div>
                                        )}
                                    </div>
                                </div>
                            ) : (
                                <div className={`flex items-center gap-4 p-4 rounded-2xl border transition-all ${editedNote.event_id ? 'bg-white border-stone-200 shadow-sm' : 'bg-stone-100/50 border-dashed border-stone-200'}`}>
                                    <div className={`h-10 w-10 rounded-xl flex items-center justify-center shadow-sm ${editedNote.event_id ? 'bg-stone-900 text-white' : 'bg-stone-200 text-stone-400'}`}>
                                        <Calendar className="h-5 w-5" strokeWidth={2.5} />
                                    </div>
                                    <span className={`text-sm font-black tracking-tight ${editedNote.event_id ? 'text-stone-900' : 'text-stone-400 italic'}`}>
                                        {editedNote.event_name || 'No event linked'}
                                    </span>
                                    {editedNote.event_id && <Check className="h-4 w-4 text-stone-900 ml-auto" strokeWidth={3} />}
                                </div>
                            )}
                        </div>
                    </div>

                    {/* Actions */}
                    <div className="p-6 flex gap-4 bg-white">
                        <Button
                            variant="outline"
                            className="flex-1 h-12 rounded-xl border-stone-100 text-stone-400 font-black uppercase tracking-widest text-[10px] hover:bg-stone-50 hover:text-stone-900 transition-all active:scale-95"
                            onClick={onCancel}
                            disabled={isSaving}
                        >
                            Discard
                        </Button>
                        <Button
                            className="flex-[2] h-12 bg-stone-900 hover:bg-stone-800 text-white rounded-xl shadow-xl shadow-stone-900/10 font-black uppercase tracking-widest text-[10px] transition-all active:scale-95"
                            onClick={() => onSave(editedNote)}
                            disabled={isSaving || isSelectingContact || isSelectingEvent}
                        >
                            {isSaving ? (
                                <Loader2 className="h-4 w-4 animate-spin mr-3 text-white" />
                            ) : (
                                <>
                                    <Check className="h-4 w-4 mr-3 text-white" strokeWidth={3} />
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
