'use client';

import { useState, useEffect } from 'react';
import dynamic from 'next/dynamic';
import { Card, CardContent } from '@/components/ui/Card';
import { Button } from '@/components/ui/Button';
import { Input } from '@/components/ui/Input';
import { Textarea } from '@/components/ui/Textarea';
import { useCamera } from '@/lib/hooks/useCamera';
import { toast } from 'sonner';
import {
    Camera,
    Upload,
    Keyboard,
    QrCode,
    Mic,
    X,
    Check,
    Loader2,
    RefreshCw,
    IdCard,
    Download,
    Plus,
    Search,
    ChevronRight,
    ChevronLeft,
    CheckCircle2,
    MapPin
} from 'lucide-react';

const QrScanner = dynamic(() => import('@/components/capture/QrScanner'), {
    ssr: false,
    loading: () => <div className="h-[400px] flex items-center justify-center text-white bg-black rounded-lg">Loading Scanner...</div>
});

const VoiceRecorder = dynamic(() => import('@/components/capture/VoiceRecorder'), {
    ssr: false,
    loading: () => <div className="p-12 text-center text-gray-500">Loading Recorder...</div>
});

// Capture modes: Smart Scan (AI), QR, Voice, Manual, Upload
export type CaptureMode = 'camera' | 'qr' | 'manual' | 'voice' | 'upload';

interface CaptureFlowProps {
    eventId?: string;
    mode: CaptureMode | null;
    onClose: () => void;
    onComplete: (data: any) => void;
}

export function CaptureFlow({ eventId, mode, onClose, onComplete }: CaptureFlowProps) {
    const [captureMode, setCaptureMode] = useState<CaptureMode | null>(mode);
    const [capturedImage, setCapturedImage] = useState<string | null>(null);
    const [isProcessing, setIsProcessing] = useState(false);
    const [step, setStep] = useState<'capture' | 'assign'>('capture');
    const [pendingData, setPendingData] = useState<any>(null);

    // For manual mode tracking
    const [manualData, setManualData] = useState({
        first_name: '',
        last_name: '',
        email: '',
        phone: '',
        company_name: '',
        job_title: '',
        notes: ''
    });

    const camera = useCamera({ facingMode: 'environment' });

    useEffect(() => {
        setCaptureMode(mode);
        setStep('capture');
        setPendingData(null);
        setCapturedImage(null);
    }, [mode]);

    const handleCameraCapture = () => {
        const photo = camera.capturePhoto();
        if (photo) {
            setCapturedImage(photo);
            camera.stopCamera();
        }
    };

    const handleFileUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
        const file = e.target.files?.[0];
        if (file) {
            const reader = new FileReader();
            reader.onload = (event) => {
                setCapturedImage(event.target?.result as string);
            };
            reader.readAsDataURL(file);
        }
    };

    const handleQrScan = (rawValue: string) => {
        toast.success(`QR Code Scanned: ${rawValue}`);
        setPendingData({ qr_data: rawValue, type: 'qr' });
        setStep('assign');
    };

    const processImage = async () => {
        if (!capturedImage) return;

        setIsProcessing(true);
        const processingToast = toast.loading('Reading card info...');
        try {
            const analyzeResponse = await fetch('/api/ai/analyze-card', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ image: capturedImage }),
            });

            if (!analyzeResponse.ok) {
                const errorData = await analyzeResponse.json();
                throw new Error(errorData.error || 'Extraction failed');
            }

            const { data: aiResult } = await analyzeResponse.json();

            setPendingData({
                image: capturedImage,
                capture_type: captureMode === 'camera' ? 'smart_scan' : 'photo_upload',
                extracted_data: {
                    name: aiResult.name || `${aiResult.first_name} ${aiResult.last_name}`.trim(),
                    first_name: aiResult.first_name,
                    last_name: aiResult.last_name,
                    email: aiResult.email,
                    phone: aiResult.phone,
                    company: aiResult.company,
                    jobTitle: aiResult.job_title,
                    website: aiResult.website,
                    address: aiResult.address
                },
                raw_text: JSON.stringify(aiResult, null, 2)
            });

            toast.success('Details saved!', { id: processingToast });
            setStep('assign');
        } catch (error: any) {
            console.error('Processing error:', error);
            toast.error(error.message || 'Failed to process image', { id: processingToast });
        } finally {
            setIsProcessing(false);
        }
    };

    const finalizeCapture = async (selectedEventId: string) => {
        if (!pendingData) return;

        const finalizeToast = toast.loading('Saving contact to event...');
        try {
            let endpoint = '/api/captures';
            let body = { ...pendingData, event_id: selectedEventId };

            // If it was manual entry, we use the contacts API
            if (captureMode === 'manual') {
                endpoint = '/api/contacts';
                body = { ...manualData, event_id: selectedEventId } as any;
            }

            const response = await fetch(endpoint, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(body),
            });

            const result = await response.json();

            if (response.ok) {
                toast.success('Contact successfully saved!', { id: finalizeToast });
                onComplete(result);
            } else {
                toast.error(result.error || 'Failed to save contact', { id: finalizeToast });
            }
        } catch (error) {
            console.error('Finalize error:', error);
            toast.error('Connection error while saving', { id: finalizeToast });
        }
    };

    if (!captureMode) return null;

    return (
        <div className="w-full">
            {/* Step 1: Capture */}
            {step === 'capture' && (
                <>
                    {captureMode === 'camera' && !capturedImage && (
                        <div className="bg-stone-900 rounded-[2.5rem] overflow-hidden relative min-h-[400px] flex flex-col shadow-2xl shadow-stone-900/10">
                            {/* Permission/Start View */}
                            <div className={cn("flex-1 flex flex-col items-center justify-center p-10 text-white text-center transition-opacity duration-300", camera.isActive ? "hidden" : "opacity-100")}>
                                <div className="w-16 h-16 bg-white/5 rounded-[1.5rem] flex items-center justify-center mb-6">
                                    <Camera className="h-8 w-8 text-white/40" />
                                </div>
                                <h3 className="text-xl font-black mb-2 tracking-tight uppercase">Ready to Scan</h3>
                                <p className="text-stone-500 text-xs mb-8 max-w-[200px]">Use your camera to scan contact cards automatically.</p>
                                <Button
                                    onClick={camera.startCamera}
                                    disabled={camera.isLoading}
                                    className="bg-white text-stone-900 hover:bg-stone-100 px-8 h-12 rounded-xl font-black uppercase tracking-widest text-[10px] transition-all"
                                >
                                    {camera.isLoading ? <Loader2 className="h-4 w-4 animate-spin" /> : 'Turn On Camera'}
                                </Button>
                                {camera.error && (
                                    <p className="mt-4 text-red-400 text-[10px] font-black uppercase tracking-widest">{camera.error}</p>
                                )}
                            </div>

                            {/* Active Camera View */}
                            <div className={cn("relative flex-1 flex flex-col items-center justify-center bg-black", !camera.isActive && "hidden")}>
                                <video
                                    ref={camera.videoRef}
                                    autoPlay
                                    playsInline
                                    muted
                                    className={cn(
                                        "w-full h-full object-cover transition-opacity duration-500",
                                        camera.isReady ? "opacity-100" : "opacity-0"
                                    )}
                                />
                                {!camera.isReady && (
                                    <div className="absolute inset-0 flex items-center justify-center bg-black/60 backdrop-blur-md">
                                        <div className="flex flex-col items-center gap-4">
                                            <Loader2 className="h-8 w-8 text-white animate-spin" />
                                            <span className="text-white text-[10px] font-black uppercase tracking-widest">Loading camera...</span>
                                        </div>
                                    </div>
                                )}

                                <div className="absolute inset-x-0 bottom-8 flex justify-center items-center gap-6 z-10">
                                    <button
                                        onClick={camera.stopCamera}
                                        className="h-11 w-11 rounded-full bg-white/5 border border-white/10 flex items-center justify-center text-white hover:bg-white/10 transition-all active:scale-95"
                                    >
                                        <X className="h-5 w-5" />
                                    </button>
                                    <button
                                        onClick={handleCameraCapture}
                                        disabled={!camera.isReady}
                                        className="h-20 w-20 rounded-full border-4 border-white/20 flex items-center justify-center transition-all disabled:opacity-50"
                                    >
                                        <div className="h-14 w-14 bg-white rounded-full shadow-2xl active:bg-stone-200 transition-colors" />
                                    </button>
                                    <button
                                        onClick={camera.switchCamera}
                                        className="h-11 w-11 rounded-full bg-white/5 border border-white/10 flex items-center justify-center text-white hover:bg-white/10 transition-all active:scale-95"
                                    >
                                        <RefreshCw className="h-5 w-5" />
                                    </button>
                                </div>
                            </div>
                        </div>
                    )}

                    {captureMode === 'upload' && !capturedImage && (
                        <div className="border border-stone-100 rounded-[2.5rem] p-12 text-center hover:bg-stone-50/50 transition-colors group cursor-pointer bg-stone-50/30 relative">
                            <input type="file" accept="image/*" onChange={handleFileUpload} className="absolute inset-0 opacity-0 cursor-pointer" />
                            <div className="h-16 w-16 bg-stone-900 rounded-[1.5rem] flex items-center justify-center mx-auto mb-6 text-white shadow-xl shadow-stone-900/10">
                                <Upload className="h-8 w-8" />
                            </div>
                            <h3 className="text-xl font-black text-stone-900 mb-2 tracking-tight uppercase">Upload Card</h3>
                            <p className="text-stone-400 text-xs font-medium max-w-[200px] mx-auto">Select a business card photo from your library.</p>
                        </div>
                    )}

                    {captureMode === 'qr' && (
                        <div className="rounded-[2.5rem] overflow-hidden shadow-2xl">
                            <QrScanner onScan={handleQrScan} />
                        </div>
                    )}

                    {captureMode === 'voice' && (
                        <div className="bg-white rounded-[2.5rem] border border-stone-100 p-8">
                            <VoiceRecorder
                                onComplete={(data) => {
                                    setPendingData({ ...data, type: 'voice' });
                                    setStep('assign');
                                }}
                                onCancel={onClose}
                            />
                        </div>
                    )}

                    {captureMode === 'manual' && (
                        <div className="space-y-4">
                            <div className="grid grid-cols-2 gap-4">
                                <div className="space-y-1.5">
                                    <label className="text-[10px] font-black text-stone-300 uppercase tracking-widest ml-1">First Name</label>
                                    <Input placeholder="John" value={manualData.first_name} onChange={(e) => setManualData({ ...manualData, first_name: e.target.value })} className="h-11 rounded-xl bg-stone-50 border-stone-100 focus:bg-white focus:ring-stone-200 transition-all font-bold" />
                                </div>
                                <div className="space-y-1.5">
                                    <label className="text-[10px] font-black text-stone-300 uppercase tracking-widest ml-1">Last Name</label>
                                    <Input placeholder="Doe" value={manualData.last_name} onChange={(e) => setManualData({ ...manualData, last_name: e.target.value })} className="h-11 rounded-xl bg-stone-50 border-stone-100 focus:bg-white focus:ring-stone-200 transition-all font-bold" />
                                </div>
                            </div>
                            <div className="grid grid-cols-2 gap-4">
                                <div className="space-y-1.5">
                                    <label className="text-[10px] font-black text-stone-300 uppercase tracking-widest ml-1">Email</label>
                                    <Input type="email" placeholder="john@example.com" value={manualData.email} onChange={(e) => setManualData({ ...manualData, email: e.target.value })} className="h-11 rounded-xl bg-stone-50 border-stone-100 focus:bg-white focus:ring-stone-200 transition-all font-bold" />
                                </div>
                                <div className="space-y-1.5">
                                    <label className="text-[10px] font-black text-stone-300 uppercase tracking-widest ml-1">Phone</label>
                                    <Input placeholder="+1 555 0000" value={manualData.phone} onChange={(e) => setManualData({ ...manualData, phone: e.target.value })} className="h-11 rounded-xl bg-stone-50 border-stone-100 focus:bg-white focus:ring-stone-200 transition-all font-bold" />
                                </div>
                            </div>
                            <div className="space-y-1.5">
                                <label className="text-[10px] font-black text-stone-300 uppercase tracking-widest ml-1">Company</label>
                                <Input placeholder="Acme Inc" value={manualData.company_name} onChange={(e) => setManualData({ ...manualData, company_name: e.target.value })} className="h-11 rounded-xl bg-stone-50 border-stone-100 focus:bg-white focus:ring-stone-200 transition-all font-bold" />
                            </div>
                            <div className="space-y-1.5">
                                <label className="text-[10px] font-black text-stone-300 uppercase tracking-widest ml-1">Quick Note</label>
                                <Textarea placeholder="Context about this person..." value={manualData.notes} onChange={(e) => setManualData({ ...manualData, notes: e.target.value })} className="h-24 rounded-2xl bg-stone-50 border-stone-100 focus:bg-white focus:ring-stone-200 transition-all font-bold resize-none" />
                            </div>
                            <div className="flex justify-end pt-4">
                                <Button
                                    onClick={() => setStep('assign')}
                                    disabled={!manualData.first_name.trim()}
                                    className="bg-stone-900 text-white hover:bg-stone-800 h-12 px-8 rounded-xl font-black uppercase tracking-widest text-[10px] shadow-xl shadow-stone-900/10 transition-all active:scale-95"
                                >
                                    Select Event <ChevronRight className="ml-3 h-4 w-4" />
                                </Button>
                            </div>
                        </div>
                    )}

                    {capturedImage && (
                        <div className="space-y-6 animate-in fade-in duration-500">
                            <div className="bg-stone-50 rounded-[2rem] p-4 flex justify-center border border-stone-100">
                                <img src={capturedImage} alt="Captured" className="max-h-[300px] rounded-xl shadow-2xl" />
                            </div>
                            <div className="flex gap-4">
                                <Button variant="outline" className="flex-1 h-12 rounded-xl border-stone-200 text-[10px] font-black uppercase tracking-widest text-stone-400 hover:text-stone-900 hover:bg-stone-50 transition-all active:scale-95" onClick={() => setCapturedImage(null)}>
                                    Retake
                                </Button>
                                <Button
                                    onClick={processImage}
                                    disabled={isProcessing}
                                    className="flex-[2.5] h-12 rounded-xl bg-stone-900 hover:bg-stone-800 text-white font-black uppercase tracking-widest text-[10px] shadow-xl shadow-stone-900/10 transition-all active:scale-95"
                                >
                                    {isProcessing ? <Loader2 className="mr-3 h-4 w-4 animate-spin text-white" /> : <Check className="mr-3 h-4 w-4 text-white" strokeWidth={3} />}
                                    Continue
                                </Button>
                            </div>
                        </div>
                    )}
                </>
            )}

            {/* Step 2: Assign Event */}
            {step === 'assign' && (
                <EventAssignment
                    initialEventId={eventId}
                    onBack={() => setStep('capture')}
                    onAssign={finalizeCapture}
                    leadName={pendingData?.extracted_data?.name || manualData.first_name + ' ' + manualData.last_name}
                />
            )}
        </div>
    );
}

// Sub-component for Event Assignment
function EventAssignment({ initialEventId, onBack, onAssign, leadName }: {
    initialEventId?: string,
    onBack: () => void,
    onAssign: (id: string) => void,
    leadName: string
}) {
    const [events, setEvents] = useState<any[]>([]);
    const [search, setSearch] = useState('');
    const [selectedId, setSelectedId] = useState(initialEventId || '');
    const [loading, setLoading] = useState(true);
    const [isCreating, setIsCreating] = useState(false);
    const [newEventData, setNewEventData] = useState({
        name: '',
        location: '',
        event_type: 'exhibition' as 'exhibition' | 'conference' | 'meeting'
    });

    useEffect(() => {
        fetch('/api/events')
            .then(res => res.json())
            .then(data => {
                const list = data.data || [];
                setEvents(list);
                if (!initialEventId && list.length > 0) {
                    const ongoing = list.find((e: any) => e.status === 'ongoing');
                    setSelectedId(ongoing?.id || list[0].id);
                }
                setLoading(false);
            });
    }, [initialEventId]);

    const filteredEvents = events.filter(e =>
        e.name.toLowerCase().includes(search.toLowerCase())
    );

    const handleCreateEvent = async () => {
        if (!newEventData.name.trim()) return;

        const loadingToast = toast.loading('Creating event...');
        try {
            const res = await fetch('/api/events', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    name: newEventData.name.trim(),
                    location: newEventData.location.trim(),
                    event_type: newEventData.event_type,
                    start_date: new Date().toISOString(),
                    status: 'ongoing'
                })
            });
            const data = await res.json();
            if (res.ok) {
                toast.success('Event created!', { id: loadingToast });
                setEvents([data.data, ...events]);
                setSelectedId(data.data.id);
                setIsCreating(false);
                setNewEventData({ name: '', location: '', event_type: 'exhibition' });
                // Signal other pages to refresh their event lists
                window.dispatchEvent(new CustomEvent('events:refresh'));
            } else {
                toast.error(data.error || 'Failed to create event', { id: loadingToast });
            }
        } catch (err) {
            toast.error('Error reaching server', { id: loadingToast });
        }
    };

    return (
        <div className="space-y-8 animate-in backdrop-blur-sm">
            <div className="flex items-center gap-4 mb-2">
                <Button variant="ghost" size="icon" onClick={onBack} className="rounded-full">
                    <ChevronLeft className="h-5 w-5" />
                </Button>
                <div>
                    <h3 className="font-bold text-xl text-stone-900">Assign to Event</h3>
                    <p className="text-sm text-stone-500 font-medium italic">Contact: {leadName}</p>
                </div>
            </div>

            <div className="bg-white border border-stone-200 rounded-3xl p-6 shadow-sm overflow-hidden">
                {!isCreating ? (
                    <>
                        <div className="relative mb-6">
                            <Search className="absolute left-4 top-1/2 -translate-y-1/2 h-5 w-5 text-stone-400" />
                            <Input
                                placeholder="Search events..."
                                value={search}
                                onChange={(e) => setSearch(e.target.value)}
                                className="pl-12 h-14 bg-stone-50 border-none rounded-2xl focus:ring-2 focus:ring-indigo-100"
                            />
                        </div>

                        <div className="max-h-[300px] overflow-y-auto custom-scrollbar space-y-2 mb-8 px-1">
                            {loading ? (
                                [1, 2, 3].map(i => <div key={i} className="h-14 bg-stone-50 rounded-xl animate-pulse" />)
                            ) : filteredEvents.length > 0 ? (
                                filteredEvents.map(event => (
                                    <button
                                        key={event.id}
                                        onClick={() => setSelectedId(event.id)}
                                        className={cn(
                                            "w-full flex items-center justify-between p-4 rounded-2xl transition-all border",
                                            selectedId === event.id
                                                ? "bg-indigo-50 border-indigo-200 text-indigo-900 shadow-sm"
                                                : "bg-white border-stone-100 text-stone-600 hover:border-stone-300"
                                        )}
                                    >
                                        <div className="flex items-center gap-3">
                                            <div className={cn(
                                                "h-10 w-10 rounded-xl flex items-center justify-center font-bold text-xs",
                                                selectedId === event.id ? "bg-indigo-600 text-white" : "bg-stone-100 text-stone-400"
                                            )}>
                                                {event.name[0].toUpperCase()}
                                            </div>
                                            <div className="text-left">
                                                <p className="font-bold text-sm">{event.name}</p>
                                                <p className="text-[10px] uppercase font-bold tracking-widest opacity-60">
                                                    {event.status} • {new Date(event.start_date).toLocaleDateString()}
                                                </p>
                                            </div>
                                        </div>
                                        {selectedId === event.id && <Check className="h-5 w-5" />}
                                    </button>
                                ))
                            ) : (
                                <div className="py-8 text-center text-stone-400 font-medium">No events found matching your search.</div>
                            )}
                        </div>

                        <div className="flex flex-col gap-3">
                            <Button
                                onClick={() => onAssign(selectedId)}
                                disabled={!selectedId}
                                className="w-full h-14 bg-stone-900 text-white hover:bg-stone-800 rounded-2xl font-bold flex items-center justify-center gap-2"
                            >
                                <CheckCircle2 className="h-5 w-5" />
                                Save Contact
                            </Button>
                            <Button
                                variant="outline"
                                onClick={() => setIsCreating(true)}
                                className="w-full h-12 border-stone-200 rounded-2xl font-bold text-stone-600"
                            >
                                <Plus className="mr-2 h-4 w-4" /> Create New Event
                            </Button>
                        </div>
                    </>
                ) : (
                    <div className="space-y-4 animate-in zoom-in-95">
                        <div className="space-y-1.5">
                            <label className="text-[10px] font-black text-stone-400 uppercase tracking-widest ml-1">Event Name</label>
                            <Input
                                placeholder="E.g. Web Summit 2026"
                                value={newEventData.name}
                                onChange={(e) => setNewEventData({ ...newEventData, name: e.target.value })}
                                className="h-12 rounded-2xl"
                                autoFocus
                            />
                        </div>

                        <div className="space-y-1.5">
                            <label className="text-[10px] font-black text-stone-400 uppercase tracking-widest ml-1">Location</label>
                            <div className="relative">
                                <MapPin className="absolute left-4 top-1/2 -translate-y-1/2 h-4 w-4 text-stone-300" />
                                <Input
                                    placeholder="E.g. Lisbon, Portugal"
                                    value={newEventData.location}
                                    onChange={(e) => setNewEventData({ ...newEventData, location: e.target.value })}
                                    className="h-12 pl-12 rounded-2xl"
                                />
                            </div>
                        </div>

                        <div className="space-y-1.5">
                            <label className="text-[10px] font-black text-stone-400 uppercase tracking-widest ml-1">Event Type</label>
                            <div className="grid grid-cols-3 gap-2">
                                {(['exhibition', 'conference', 'meeting'] as const).map((type) => (
                                    <button
                                        key={type}
                                        type="button"
                                        onClick={() => setNewEventData({ ...newEventData, event_type: type })}
                                        className={cn(
                                            "py-2 rounded-xl text-[10px] font-bold uppercase tracking-wider border transition-all",
                                            newEventData.event_type === type
                                                ? "bg-stone-900 text-white border-stone-900"
                                                : "bg-white text-stone-500 border-stone-100 hover:border-stone-200"
                                        )}
                                    >
                                        {type}
                                    </button>
                                ))}
                            </div>
                        </div>

                        <div className="flex gap-3 pt-2">
                            <Button
                                variant="ghost"
                                onClick={() => setIsCreating(false)}
                                className="flex-1 h-12 rounded-xl text-stone-400 font-bold"
                            >
                                Back
                            </Button>
                            <Button
                                onClick={handleCreateEvent}
                                disabled={!newEventData.name.trim()}
                                className="flex-[2] h-12 bg-indigo-600 text-white hover:bg-indigo-700 rounded-xl font-bold shadow-lg shadow-indigo-200"
                            >
                                <Plus className="mr-2 h-4 w-4" />
                                Create Event
                            </Button>
                        </div>
                    </div>
                )}
            </div>
        </div>
    );
}

// Adding missing imports
import { cn } from '@/lib/utils';
