import { Button } from '@/components/ui/Button';
import { Event } from '@/types';
import { CaptureMode } from '@/components/events/CaptureFlow';
import { Calendar, MapPin, Target, Camera, Download, Edit, Trash2, MoreVertical, QrCode, IdCard, Keyboard, Mic } from 'lucide-react';
import { CaptureDropdown } from '@/components/capture/CaptureDropdown';

interface EventSidebarProps {
    event: Event;
    onOpenCapture: (mode: CaptureMode) => void;
    onExportData: () => void;
    onEditEvent: () => void;
    onDeleteEvent: () => void;
}

export function EventSidebar({ event, onOpenCapture, onExportData, onEditEvent, onDeleteEvent }: EventSidebarProps) {
    return (
        <div className="bg-white rounded-[3rem] border border-stone-100 shadow-sm p-10 sticky top-24 space-y-10 animate-in fade-in duration-700 hover:shadow-md transition-shadow">
            <div>
                <h2 className="text-3xl font-black text-stone-900 tracking-tighter leading-tight mb-8">{event.name}</h2>

                <div className="space-y-4">
                    <div className="flex items-center gap-5 p-5 rounded-[2rem] bg-stone-50 border border-stone-100/50 group">
                        <div className="p-3 bg-stone-900 rounded-xl shadow-lg shrink-0 text-white">
                            <Calendar className="h-4 w-4" strokeWidth={3} />
                        </div>
                        <div>
                            <p className="font-black text-stone-900 text-sm tracking-tight">
                                {new Date(event.start_date).toLocaleDateString('en-US', {
                                    month: 'long',
                                    day: 'numeric',
                                    year: 'numeric'
                                })}
                            </p>
                            {event.end_date && (
                                <p className="text-stone-400 text-[10px] font-black uppercase tracking-widest mt-1">
                                    through {new Date(event.end_date).toLocaleDateString('en-US', {
                                        month: 'short',
                                        day: 'numeric'
                                    })}
                                </p>
                            )}
                        </div>
                    </div>

                    {event.location && (
                        <div className="flex items-center gap-5 p-5 rounded-[2rem] bg-stone-50 border border-stone-100/50 group">
                            <div className="p-3 bg-stone-900 rounded-xl shadow-lg shrink-0 text-white">
                                <MapPin className="h-4 w-4" strokeWidth={3} />
                            </div>
                            <p className="text-sm font-black text-stone-900 tracking-tight leading-snug">{event.location}</p>
                        </div>
                    )}

                    {event.description && (
                        <div className="text-xs text-stone-400 font-medium leading-relaxed pt-6 px-2 border-t border-stone-50 italic">
                            "{event.description}"
                        </div>
                    )}
                </div>
            </div>

            <div className="space-y-4 pt-4">
                <CaptureDropdown
                    eventId={event.id}
                    trigger={
                        <Button
                            variant="primary"
                            className="w-full h-14 justify-between shadow-xl shadow-stone-900/10 bg-stone-900 hover:bg-stone-800 border-none rounded-2xl transition-all"
                        >
                            <span className="flex items-center gap-3">
                                <QrCode className="h-5 w-5 text-white" strokeWidth={3} />
                                <span className="font-black uppercase tracking-widest text-[10px]">Capture Lead</span>
                            </span>
                            <MoreVertical className="h-4 w-4 opacity-30" />
                        </Button>
                    }
                />

                <div className="grid grid-cols-2 gap-4">
                    <Button
                        variant="outline"
                        className="w-full justify-center h-12 border-stone-200 hover:bg-stone-50 text-stone-900 rounded-2xl transition-all shadow-sm"
                        onClick={onExportData}
                        title="Export Data"
                    >
                        <Download className="h-5 w-5" strokeWidth={3} />
                    </Button>

                    <Button
                        variant="outline"
                        className="w-full justify-center h-12 border-stone-200 hover:bg-stone-50 text-stone-900 rounded-2xl transition-all shadow-sm"
                        onClick={onEditEvent}
                        title="Edit Event"
                    >
                        <Edit className="h-5 w-5" strokeWidth={3} />
                    </Button>
                </div>

                <Button
                    variant="ghost"
                    className="w-full justify-center text-stone-300 hover:text-red-600 hover:bg-red-50/50 h-12 font-black text-[10px] uppercase tracking-widest rounded-2xl transition-all"
                    onClick={onDeleteEvent}
                >
                    <Trash2 className="mr-3 h-4 w-4" strokeWidth={3} />
                    Delete Event
                </Button>
            </div>
        </div>
    );
}
