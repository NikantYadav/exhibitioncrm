import { Button } from '@/components/ui/Button';
import { Event } from '@/types';
import { CaptureMode } from '@/components/events/CaptureFlow';
import { Calendar, MapPin, Target, Camera, Download, Edit, Trash2, MoreVertical, QrCode, IdCard, Keyboard, Mic } from 'lucide-react';

interface EventSidebarProps {
    event: Event;
    onOpenCapture: (mode: CaptureMode) => void;
    onExportData: () => void;
    onEditEvent: () => void;
    onDeleteEvent: () => void;
}

export function EventSidebar({ event, onOpenCapture, onExportData, onEditEvent, onDeleteEvent }: EventSidebarProps) {
    return (
        <div className="card sticky top-4">
            <h2 className="text-xl font-bold mb-4">{event.name}</h2>

            <div className="space-y-3 mb-6">
                <div className="flex items-start gap-2 text-sm">
                    <Calendar className="h-4 w-4 text-gray-500 mt-0.5" />
                    <div>
                        <p className="font-medium">
                            {new Date(event.start_date).toLocaleDateString('en-US', {
                                month: 'short',
                                day: 'numeric',
                                year: 'numeric'
                            })}
                        </p>
                        {event.end_date && (
                            <p className="text-gray-600 text-xs">
                                to {new Date(event.end_date).toLocaleDateString('en-US', {
                                    month: 'short',
                                    day: 'numeric',
                                    year: 'numeric'
                                })}
                            </p>
                        )}
                    </div>
                </div>

                {event.location && (
                    <div className="flex items-start gap-2 text-sm">
                        <MapPin className="h-4 w-4 text-gray-500 mt-0.5" />
                        <p className="text-gray-700">{event.location}</p>
                    </div>
                )}

                {event.description && (
                    <p className="text-sm text-gray-600 pt-2 border-t">{event.description}</p>
                )}
            </div>

            <div className="space-y-2">
                <div className="relative group">
                    <Button
                        variant="outline"
                        size="sm"
                        className="w-full justify-start overflow-hidden relative"
                    >
                        <Camera className="mr-2 h-4 w-4" />
                        Capture Lead
                        <MoreVertical className="ml-auto h-4 w-4" />
                    </Button>

                    <div className="absolute left-0 w-full mt-1 bg-white border border-gray-200 rounded-lg shadow-xl opacity-0 invisible group-hover:opacity-100 group-hover:visible transition-all z-20 overflow-hidden">
                        <button
                            onClick={() => onOpenCapture('camera')}
                            className="w-full text-left px-4 py-2 text-sm hover:bg-blue-50 flex items-center gap-2"
                        >
                            <Camera className="h-4 w-4 text-blue-600" />
                            Scan Card
                        </button>
                        <button
                            onClick={() => onOpenCapture('badge')}
                            className="w-full text-left px-4 py-2 text-sm hover:bg-cyan-50 flex items-center gap-2"
                        >
                            <IdCard className="h-4 w-4 text-cyan-600" />
                            Scan Badge
                        </button>
                        <button
                            onClick={() => onOpenCapture('qr')}
                            className="w-full text-left px-4 py-2 text-sm hover:bg-amber-50 flex items-center gap-2"
                        >
                            <QrCode className="h-4 w-4 text-amber-600" />
                            Scan QR Code
                        </button>
                        <button
                            onClick={() => onOpenCapture('photo_note')}
                            className="w-full text-left px-4 py-2 text-sm hover:bg-teal-50 flex items-center gap-2"
                        >
                            <Camera className="h-4 w-4 text-teal-600" />
                            Photo + Notes
                        </button>
                        <button
                            onClick={() => onOpenCapture('manual')}
                            className="w-full text-left px-4 py-2 text-sm hover:bg-emerald-50 flex items-center gap-2"
                        >
                            <Keyboard className="h-4 w-4 text-emerald-600" />
                            Manual Entry
                        </button>
                        <button
                            onClick={() => onOpenCapture('voice')}
                            className="w-full text-left px-4 py-2 text-sm hover:bg-rose-50 flex items-center gap-2"
                        >
                            <Mic className="h-4 w-4 text-rose-600" />
                            Voice Note
                        </button>
                        <button
                            onClick={() => onOpenCapture('upload')}
                            className="w-full text-left px-4 py-2 text-sm hover:bg-purple-50 flex items-center gap-2 border-t border-gray-100"
                        >
                            <Download className="h-4 w-4 text-purple-600" />
                            Upload Photo
                        </button>
                    </div>
                </div>
                <Button
                    variant="outline"
                    size="sm"
                    className="w-full justify-start"
                    onClick={onExportData}
                >
                    <Download className="mr-2 h-4 w-4" />
                    Export Data
                </Button>

                <Button
                    variant="outline"
                    size="sm"
                    className="w-full justify-start"
                    onClick={onEditEvent}
                >
                    <Edit className="mr-2 h-4 w-4" />
                    Edit Event
                </Button>
                <Button
                    variant="outline"
                    size="sm"
                    className="w-full justify-start text-red-600 hover:text-red-700 hover:bg-red-50"
                    onClick={onDeleteEvent}
                >
                    <Trash2 className="mr-2 h-4 w-4" />
                    Delete Event
                </Button>
            </div>
        </div>
    );
}
