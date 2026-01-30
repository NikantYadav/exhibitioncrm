import { Button } from '@/components/ui/Button';
import { Capture } from '@/types';
import { Camera, Trash2, MoreVertical, IdCard, Briefcase, Calendar, ExternalLink, User, Mail, Phone } from 'lucide-react';
import { useRouter } from 'next/navigation';
import { useState } from 'react';
import { Modal } from '@/components/ui/Modal';
import { CaptureDropdown } from '@/components/capture/CaptureDropdown';

interface CapturesSectionProps {
    eventId: string;
    captures: Capture[];
    onDeleteCapture: (e: React.MouseEvent, captureId: string) => void;
}

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
        <div className="max-w-5xl mx-auto">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 mb-8">
                <div>
                    <h3 className="text-xl font-black text-stone-900 tracking-tight">Business Cards</h3>
                    <p className="text-[10px] text-stone-400 font-bold uppercase tracking-widest mt-0.5">Scanned contact cards from this event.</p>
                </div>
                {filteredCaptures.length > 0 && (
                    <CaptureDropdown
                        eventId={eventId}
                        trigger={
                            <Button className="h-10 px-5 bg-stone-900 hover:bg-stone-800 text-white rounded-xl shadow-lg shadow-stone-900/10 font-black uppercase tracking-widest text-[10px] transition-all">
                                <Camera className="mr-2.5 h-4 w-4" strokeWidth={3} />
                                New Scan
                                <MoreVertical className="ml-2.5 h-4 w-4 opacity-30" />
                            </Button>
                        }
                    />
                )}
            </div>

            {filteredCaptures.length === 0 ? (
                <div className="bg-stone-50 rounded-[2.5rem] border border-stone-100 border-dashed p-12 text-center">
                    <div className="p-5 bg-stone-900 rounded-2xl w-fit mx-auto mb-6 text-white shadow-xl shadow-stone-900/10">
                        <Camera className="h-8 w-8" strokeWidth={2.5} />
                    </div>
                    <h4 className="text-lg font-black text-stone-900 tracking-tight mb-2">No Contact Cards Yet</h4>
                    <p className="text-stone-500 text-xs font-medium mb-8 max-w-[240px] mx-auto leading-relaxed">Scan a business card to automatically save lead details and company info.</p>
                    <CaptureDropdown
                        eventId={eventId}
                        trigger={
                            <Button
                                className="h-11 px-6 bg-stone-900 hover:bg-stone-800 text-white rounded-xl font-black uppercase tracking-widest text-[10px] shadow-lg shadow-stone-900/10 transition-all"
                            >
                                <Camera className="mr-2.5 h-4 w-4" strokeWidth={3} />
                                Start Scanning
                            </Button>
                        }
                    />
                </div>
            ) : (
                <div className="grid gap-3">
                    {filteredCaptures.map((capture) => (
                        <div
                            key={capture.id}
                            onClick={() => handleCaptureClick(capture)}
                            className="group bg-white rounded-2xl border border-stone-100 p-4 shadow-sm hover:shadow-md hover:border-stone-200 transition-all duration-300 cursor-pointer flex items-center justify-between"
                        >
                            <div className="flex items-center gap-4 min-w-0">
                                <div className="h-11 w-11 bg-stone-900 rounded-xl flex items-center justify-center text-white shadow-md">
                                    <IdCard className="h-5 w-5" strokeWidth={2.5} />
                                </div>
                                <div className="min-w-0">
                                    <p className="font-black text-stone-900 truncate tracking-tight">
                                        {capture.contact?.first_name} {capture.contact?.last_name || 'Unknown'}
                                    </p>
                                    <div className="flex items-center gap-3 mt-1 text-[9px] font-black text-stone-400 uppercase tracking-widest">
                                        <span className="flex items-center gap-1.5">
                                            <Calendar className="h-3 w-3 text-stone-900" strokeWidth={3} />
                                            {new Date(capture.created_at).toLocaleDateString(undefined, { month: 'short', day: 'numeric' })}
                                        </span>
                                        {capture.contact?.company?.name && (
                                            <span className="flex items-center gap-1.5 max-w-[150px] truncate">
                                                <Briefcase className="h-3 w-3 text-stone-900" strokeWidth={3} />
                                                {capture.contact.company.name}
                                            </span>
                                        )}
                                    </div>
                                </div>
                            </div>
                            <Button
                                variant="ghost"
                                className="h-10 w-10 p-0 text-stone-200 hover:text-red-600 hover:bg-red-50 opacity-100 sm:opacity-0 group-hover:opacity-100 transition-all rounded-xl ml-2"
                                onClick={(e) => {
                                    e.stopPropagation();
                                    onDeleteCapture(e, capture.id);
                                }}
                            >
                                <Trash2 className="h-4 w-4" strokeWidth={2.5} />
                            </Button>
                        </div>
                    ))}
                </div>
            )}

            {/* Contact Preview Modal */}
            <Modal
                isOpen={showPreview}
                onClose={() => setShowPreview(false)}
                title="Card Detail"
                size="md"
            >
                {selectedCapturePreview && (
                    <div className="space-y-6">
                        {/* Header Profile Section */}
                        <div className="flex flex-col items-center text-center space-y-3">
                            <div className="h-20 w-20 rounded-2xl bg-stone-900 flex items-center justify-center border-2 border-white shadow-lg">
                                <User className="h-9 w-9 text-white" />
                            </div>
                            <div className="space-y-1">
                                <h3 className="text-xl font-black text-stone-900 tracking-tight">
                                    {selectedCapturePreview.contact
                                        ? [selectedCapturePreview.contact.first_name, selectedCapturePreview.contact.last_name].filter(Boolean).join(' ')
                                        : 'Contact Found'}
                                </h3>
                                {(selectedCapturePreview.contact?.job_title || selectedCapturePreview.contact?.company?.name) && (
                                    <div className="flex items-center justify-center gap-2 text-stone-500 font-medium">
                                        <Briefcase className="h-3.5 w-3.5 shrink-0 text-stone-400" />
                                        <p className="text-xs">
                                            {[
                                                selectedCapturePreview.contact.job_title,
                                                selectedCapturePreview.contact.company?.name
                                            ].filter(Boolean).join(' @ ')}
                                        </p>
                                    </div>
                                )}
                                <div className="flex items-center justify-center gap-3 mt-1.5">
                                    <p className="text-[10px] text-stone-400 font-bold uppercase tracking-widest flex items-center gap-1.5">
                                        <Calendar className="h-3 w-3 text-stone-300" strokeWidth={3} />
                                        Scanned {new Date(selectedCapturePreview.created_at).toLocaleDateString(undefined, {
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
                                <h4 className="text-[10px] uppercase tracking-widest font-black text-stone-400 ml-1">Information</h4>
                                <div className="grid gap-2">
                                    {selectedCapturePreview.contact.email && (
                                        <div className="flex items-center justify-between p-3 bg-white border border-stone-100 rounded-xl shadow-sm">
                                            <div className="flex items-center gap-3 min-w-0">
                                                <div className="h-9 w-9 rounded-lg bg-stone-900 flex items-center justify-center text-white shadow-sm">
                                                    <Mail className="h-4 w-4" />
                                                </div>
                                                <div className="min-w-0">
                                                    <p className="text-[9px] font-black text-stone-400 uppercase tracking-widest leading-none mb-1">Email</p>
                                                    <p className="text-xs font-bold text-stone-900 truncate">{selectedCapturePreview.contact.email}</p>
                                                </div>
                                            </div>
                                            <Button variant="ghost" size="sm" className="h-8 w-8 p-0 text-stone-400 hover:text-stone-900 transition-colors" onClick={() => window.open(`mailto:${selectedCapturePreview.contact?.email}`)}>
                                                <ExternalLink className="h-3.5 w-3.5" />
                                            </Button>
                                        </div>
                                    )}

                                    {selectedCapturePreview.contact.phone && (
                                        <div className="flex items-center justify-between p-3 bg-white border border-stone-100 rounded-xl shadow-sm">
                                            <div className="flex items-center gap-3 min-w-0">
                                                <div className="h-9 w-9 rounded-lg bg-stone-900 flex items-center justify-center text-white shadow-sm">
                                                    <Phone className="h-4 w-4" />
                                                </div>
                                                <div className="min-w-0">
                                                    <p className="text-[9px] font-black text-stone-400 uppercase tracking-widest leading-none mb-1">Phone</p>
                                                    <p className="text-xs font-bold text-stone-900 truncate">{selectedCapturePreview.contact.phone}</p>
                                                </div>
                                            </div>
                                            <Button variant="ghost" size="sm" className="h-8 w-8 p-0 text-stone-400 hover:text-stone-900 transition-colors" onClick={() => window.open(`tel:${selectedCapturePreview.contact?.phone}`)}>
                                                <Phone className="h-3.5 w-3.5" />
                                            </Button>
                                        </div>
                                    )}
                                </div>
                            </div>
                        ) : (
                            <div className="p-6 bg-stone-50 rounded-2xl border border-dashed border-stone-200 text-center">
                                <p className="text-xs text-stone-400 font-medium italic">Scanning details... please wait.</p>
                            </div>
                        )}

                        {/* Business Card Reference Image */}
                        {selectedCapturePreview.image_url && (
                            <div className="space-y-2 pt-1">
                                <h4 className="text-[10px] uppercase tracking-widest font-black text-stone-400 ml-1">Photo Reference</h4>
                                <div className="aspect-[1.6/1] w-full rounded-2xl overflow-hidden border border-stone-100 bg-stone-50 relative">
                                    <img
                                        src={selectedCapturePreview.image_url}
                                        alt="Business Card"
                                        className="w-full h-full object-contain"
                                    />
                                </div>
                            </div>
                        )}

                        {/* Footer Actions */}
                        <div className="flex flex-col gap-2 pt-2">
                            {selectedCapturePreview.contact_id && (
                                <Button
                                    className="w-full bg-stone-900 hover:bg-stone-800 text-white h-11 rounded-xl shadow-lg shadow-stone-900/10 font-black uppercase tracking-widest text-[10px] transition-all"
                                    onClick={() => router.push(`/contacts/${selectedCapturePreview.contact_id}`)}
                                >
                                    <User className="mr-2 h-4 w-4" />
                                    Open Contact
                                </Button>
                            )}
                            <Button
                                variant="outline"
                                className="w-full border-stone-200 text-stone-500 hover:bg-stone-50 h-11 rounded-xl font-bold transition-all text-[10px] uppercase tracking-widest"
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
