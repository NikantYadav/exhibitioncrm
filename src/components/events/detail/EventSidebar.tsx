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
                <CaptureDropdown
                    eventId={event.id}
                    trigger={
                        <Button
                            variant="outline"
                            size="sm"
                            className="w-full justify-start overflow-hidden relative border-stone-200"
                        >
                            <Camera className="mr-2 h-4 w-4" />
                            Capture Lead
                            <MoreVertical className="ml-auto h-4 w-4" />
                        </Button>
                    }
                />
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
