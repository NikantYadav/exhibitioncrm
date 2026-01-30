import { Button } from '@/components/ui/Button';
import { Badge } from '@/components/ui/Badge';
import { Capture } from '@/types';
import { CaptureMode } from '@/components/events/CaptureFlow';
import { Camera, Trash2, MoreVertical, IdCard, QrCode, Keyboard, Mic, Download, Mail, Phone, Briefcase, Calendar, ExternalLink, User } from 'lucide-react';
import { useRouter } from 'next/navigation';
import { useState } from 'react';
import { Modal } from '@/components/ui/Modal';

interface CapturesSectionProps {
    eventId: string;
    captures: Capture[];
    onDeleteCapture: (e: React.MouseEvent, captureId: string) => void;
}

import { toast } from 'sonner';
import { CaptureDropdown } from '@/components/capture/CaptureDropdown';

export function CapturesSection({ eventId, captures, onDeleteCapture }: CapturesSectionProps) {
    const router = useRouter();
    const [selectedCapturePreview, setSelectedCapturePreview] = useState<Capture | null>(null);
    const [showPreview, setShowPreview] = useState(false);

    // Filter out captures without associated contacts when they are in completed status (orphaned captures)
    const filteredCaptures = captures.filter(c => c.status !== 'completed' || c.contact);

    const handleCaptureClick = (capture: Capture) => {
        setSelectedCapturePreview(capture);
        setShowPreview(true);
    };

    return (
        <div>
            <div className="flex items-center justify-between mb-4">
                <h3 className="text-lg font-semibold">Business Card Captures</h3>
                {filteredCaptures.length > 0 && (
                    <CaptureDropdown
                        eventId={eventId}
                        trigger={
                            <Button size="sm">
                                <Camera className="mr-2 h-4 w-4" />
                                New Capture
                                <MoreVertical className="ml-2 h-4 w-4" />
                            </Button>
                        }
                    />
                )}
            </div>

            {filteredCaptures.length === 0 ? (
                <div className="text-center py-12">
                    <Camera className="h-12 w-12 text-gray-400 mx-auto mb-3" />
                    <p className="text-gray-600 mb-4">No captures yet</p>
                    <CaptureDropdown
                        eventId={eventId}
                        trigger={
                            <Button size="sm">
                                <Camera className="mr-2 h-4 w-4" />
                                Start Capturing
                                <MoreVertical className="ml-2 h-4 w-4" />
                            </Button>
                        }
                    />
                </div>
            ) : (
                <div className="space-y-3">
                    {filteredCaptures.map((capture) => (
                        <div
                            key={capture.id}
                            onClick={() => handleCaptureClick(capture)}
                            className="w-full text-left border border-gray-200 rounded-lg p-4 hover:border-blue-300 hover:bg-blue-50/30 transition-all group cursor-pointer"
                        >
                            <div className="flex items-center justify-between">
                                <div>
                                    <p className="font-medium group-hover:text-blue-600 transition-colors">
                                        {capture.contact?.first_name} {capture.contact?.last_name || 'Unknown'}
                                    </p>
                                    <p className="text-sm text-gray-600">
                                        {new Date(capture.created_at).toLocaleDateString()}
                                    </p>
                                </div>
                                <Button
                                    variant="ghost"
                                    size="sm"
                                    className="h-8 w-8 p-0 text-gray-400 hover:text-red-600 hover:bg-red-50"
                                    onClick={(e) => {
                                        e.stopPropagation();
                                        onDeleteCapture(e, capture.id);
                                    }}
                                >
                                    <Trash2 className="h-4 w-4" />
                                </Button>
                            </div>
                        </div>
                    ))}
                </div>
            )}

            {/* Contact Preview Modal */}
            <Modal
                isOpen={showPreview}
                onClose={() => setShowPreview(false)}
                title="Lead Preview"
                size="md"
            >
                {selectedCapturePreview && (
                    <div className="space-y-8">
                        {/* Header Profile Section */}
                        <div className="flex flex-col items-center text-center space-y-4">
                            <div className="h-24 w-24 rounded-3xl bg-blue-50 flex items-center justify-center border-2 border-blue-100/50 shadow-inner relative group transition-all duration-500 hover:scale-105">
                                <div className="absolute inset-0 bg-blue-400/5 rounded-3xl animate-pulse group-hover:animate-none opacity-0 group-hover:opacity-100 transition-opacity"></div>
                                <User className="h-10 w-10 text-blue-500" />
                            </div>
                            <div className="space-y-1.5">
                                <h3 className="text-2xl font-black text-stone-900 tracking-tight">
                                    {selectedCapturePreview.contact
                                        ? [selectedCapturePreview.contact.first_name, selectedCapturePreview.contact.last_name].filter(Boolean).join(' ')
                                        : 'Lead Found'}
                                </h3>
                                {(selectedCapturePreview.contact?.job_title || selectedCapturePreview.contact?.company?.name) && (
                                    <div className="flex items-center justify-center gap-2 text-stone-500 font-medium">
                                        <Briefcase className="h-4 w-4 shrink-0 text-blue-400" />
                                        <p className="text-sm">
                                            {[
                                                selectedCapturePreview.contact.job_title,
                                                selectedCapturePreview.contact.company?.name
                                            ].filter(Boolean).join(' @ ')}
                                        </p>
                                    </div>
                                )}
                                <div className="flex items-center justify-center gap-3 mt-2">
                                    <p className="text-xs text-stone-400 font-medium flex items-center gap-1.5">
                                        <Calendar className="h-3.5 w-3.5 text-stone-300" />
                                        Captured {new Date(selectedCapturePreview.created_at).toLocaleDateString(undefined, {
                                            month: 'short',
                                            day: 'numeric',
                                            year: 'numeric'
                                        })}
                                    </p>
                                </div>
                            </div>
                        </div>

                        {/* Contact Information List */}
                        {selectedCapturePreview.contact ? (
                            <div className="space-y-3">
                                <h4 className="text-[10px] uppercase tracking-[0.2em] font-black text-stone-400 ml-1">Contact Information</h4>
                                <div className="space-y-2">
                                    {selectedCapturePreview.contact.email && (
                                        <div className="flex items-center justify-between p-4 bg-white border border-stone-200 rounded-2xl shadow-sm hover:border-blue-300 hover:shadow-md transition-all group">
                                            <div className="flex items-center gap-4 min-w-0">
                                                <div className="h-10 w-10 rounded-xl bg-blue-50 flex items-center justify-center text-blue-500 group-hover:bg-blue-500 group-hover:text-white transition-all">
                                                    <Mail className="h-5 w-5" />
                                                </div>
                                                <div className="min-w-0">
                                                    <p className="text-[10px] font-bold text-stone-400 uppercase tracking-wider leading-none mb-1">Email</p>
                                                    <p className="text-sm font-semibold text-stone-900 truncate">{selectedCapturePreview.contact.email}</p>
                                                </div>
                                            </div>
                                            <Button variant="ghost" size="sm" className="h-8 w-8 p-0 text-stone-400 hover:text-blue-600 transition-colors shrink-0" onClick={() => window.open(`mailto:${selectedCapturePreview.contact?.email}`)}>
                                                <ExternalLink className="h-4 w-4" />
                                            </Button>
                                        </div>
                                    )}

                                    {selectedCapturePreview.contact.phone && (
                                        <div className="flex items-center justify-between p-4 bg-white border border-stone-200 rounded-2xl shadow-sm hover:border-emerald-300 hover:shadow-md transition-all group">
                                            <div className="flex items-center gap-4 min-w-0">
                                                <div className="h-10 w-10 rounded-xl bg-emerald-50 flex items-center justify-center text-emerald-500 group-hover:bg-emerald-500 group-hover:text-white transition-all">
                                                    <Phone className="h-5 w-5" />
                                                </div>
                                                <div className="min-w-0">
                                                    <p className="text-[10px] font-bold text-stone-400 uppercase tracking-wider leading-none mb-1">Phone</p>
                                                    <p className="text-sm font-semibold text-stone-900 truncate">{selectedCapturePreview.contact.phone}</p>
                                                </div>
                                            </div>
                                            <Button variant="ghost" size="sm" className="h-8 w-8 p-0 text-stone-400 hover:text-emerald-600 transition-colors shrink-0" onClick={() => window.open(`tel:${selectedCapturePreview.contact?.phone}`)}>
                                                <Phone className="h-4 w-4" />
                                            </Button>
                                        </div>
                                    )}
                                </div>
                            </div>
                        ) : (
                            <div className="p-8 bg-stone-50 rounded-2xl border border-dashed border-stone-200 text-center">
                                <p className="text-sm text-stone-400 font-medium">Data extraction in progress. Please check back in a few seconds.</p>
                            </div>
                        )}

                        {/* Business Card Reference Image */}
                        {selectedCapturePreview.image_url && (
                            <div className="space-y-3 pt-2">
                                <div className="ml-1">
                                    <h4 className="text-[10px] uppercase tracking-[0.2em] font-black text-stone-400">Captured Reference</h4>
                                </div>
                                <div className="aspect-[1.6/1] w-full rounded-2xl overflow-hidden border border-stone-200 bg-stone-100 relative shadow-sm">
                                    <img
                                        src={selectedCapturePreview.image_url}
                                        alt="Business Card"
                                        className="w-full h-full object-contain"
                                    />
                                </div>
                            </div>
                        )}

                        {/* Footer Actions */}
                        <div className="flex flex-col gap-3 pt-4 pb-2">
                            {selectedCapturePreview.contact_id && (
                                <Button
                                    className="w-full bg-blue-600 hover:bg-blue-700 text-white h-12 rounded-2xl shadow-lg shadow-blue-500/20 font-bold transition-all hover:translate-y-[-2px] hover:shadow-blue-500/40"
                                    onClick={() => router.push(`/contacts/${selectedCapturePreview.contact_id}`)}
                                >
                                    <User className="mr-2 h-4 w-4" />
                                    View Full Profile
                                </Button>
                            )}
                            <Button
                                variant="outline"
                                className="w-full border-stone-200 text-stone-500 hover:bg-stone-50 h-12 rounded-2xl font-semibold transition-all"
                                onClick={() => setShowPreview(false)}
                            >
                                Close
                            </Button>
                        </div>
                    </div>
                )}
            </Modal>
        </div>
    );
}
