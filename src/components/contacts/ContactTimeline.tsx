import { Camera, Users, Mail, FileText, Calendar, Mic, ExternalLink, Hash, Sparkles, Clock, MapPin, CheckCircle, AlertCircle } from 'lucide-react';
import { useState } from 'react';
import { toast } from 'sonner';
import { Button } from '@/components/ui/Button';
import { Textarea } from '@/components/ui/Textarea';
import { VoiceNotePlayer } from '@/components/ui/VoiceNotePlayer';
import Link from 'next/link';

interface TimelineItem {
    id: string;
    type: 'interaction' | 'note' | 'meeting';
    date: string;
    interaction_type?: 'capture' | 'meeting' | 'email' | 'note';
    summary?: string;
    content?: string;
    note_type?: 'text' | 'voice' | 'photo';
    source_url?: string;
    details?: Record<string, any>;
    status?: string;
    post_meeting_notes?: string;
    meeting_type?: string;
    meeting_location?: string;
    event?: {
        id: string;
        name: string;
    };
}

interface ContactTimelineProps {
    timeline: TimelineItem[];
    onAddNote?: () => void;
    onRefresh?: () => void;
    hideBriefingLinks?: boolean;
}

export function ContactTimeline({ timeline, onAddNote, onRefresh, hideBriefingLinks }: ContactTimelineProps) {
    const [editingMeetingId, setEditingMeetingId] = useState<string | null>(null);
    const [tempNotes, setTempNotes] = useState<string>('');
    const [isSaving, setIsSaving] = useState(false);

    const getIcon = (item: TimelineItem) => {
        if (item.type === 'meeting') {
            if (item.status === 'completed') return <CheckCircle className="h-4 w-4" />;
            const isUpcoming = new Date(item.date) > new Date();
            return isUpcoming ? <Clock className="h-4 w-4" /> : <Calendar className="h-4 w-4" />;
        }
        if (item.type === 'note') {
            // Check if it's a voice note
            if (item.note_type === 'voice') {
                return <Mic className="h-4 w-4" />;
            }
            return <FileText className="h-4 w-4" />;
        }

        switch (item.interaction_type) {
            case 'capture':
                return <Camera className="h-4 w-4" />;
            case 'meeting':
                return <Calendar className="h-4 w-4" />;
            case 'email':
                return <Mail className="h-4 w-4" />;
            case 'note':
                return <FileText className="h-4 w-4" />;
            default:
                return <Users className="h-4 w-4" />;
        }
    };

    const getColor = (item: TimelineItem) => {
        if (item.type === 'meeting') {
            if (item.status === 'completed') return 'text-green-600 bg-green-100';
            const isUpcoming = new Date(item.date) > new Date();
            return isUpcoming ? 'text-amber-600 bg-amber-100' : 'text-indigo-600 bg-indigo-100';
        }
        if (item.type === 'note') {
            if (item.note_type === 'voice') {
                return 'text-purple-600 bg-purple-100';
            }
            return 'text-gray-600 bg-gray-100';
        }

        switch (item.interaction_type) {
            case 'capture':
                return 'text-purple-600 bg-purple-100';
            case 'meeting':
                return 'text-blue-600 bg-blue-100';
            case 'email':
                return 'text-green-600 bg-green-100';
            case 'note':
                return 'text-gray-600 bg-gray-100';
            default:
                return 'text-gray-600 bg-gray-100';
        }
    };

    const formatSource = (source?: string) => {
        if (!source) return 'System';
        return source
            .split('_')
            .map(word => word.charAt(0).toUpperCase() + word.slice(1))
            .join(' ');
    };

    const formatDate = (dateString: string) => {
        const date = new Date(dateString);
        const now = new Date();
        const diffMs = now.getTime() - date.getTime();
        const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24));

        if (diffDays === 0) return 'Today';
        if (diffDays === 1) return 'Yesterday';
        if (diffDays < 7) return `${diffDays} days ago`;
        return date.toLocaleDateString();
    };

    return (
        <div className="space-y-4">
            {/* Add Note Button */}
            {onAddNote && (
                <button
                    onClick={onAddNote}
                    className="w-full p-4 border-2 border-dashed border-gray-300 rounded-lg text-gray-600 hover:border-blue-500 hover:text-blue-600 transition-colors"
                >
                    + Add Note
                </button>
            )}

            {/* Timeline Items */}
            {timeline.length === 0 ? (
                <div className="text-center py-12">
                    <Users className="h-12 w-12 text-gray-400 mx-auto mb-3" />
                    <p className="text-gray-600">No interactions yet</p>
                </div>
            ) : (
                <div className="relative">
                    {/* Timeline Line */}
                    <div className="absolute left-6 top-0 bottom-0 w-0.5 bg-gray-200" />

                    {/* Timeline Items */}
                    <div className="space-y-6">
                        {timeline.map((item, index) => {
                            const isUpcomingMeeting = item.type === 'meeting' && new Date(item.date) > new Date() && item.status !== 'completed';
                            const isPastMeetingWithoutNotes = item.type === 'meeting' && !isUpcomingMeeting && !item.post_meeting_notes;

                            const handleSavePostNotes = async (id: string) => {
                                setIsSaving(true);
                                try {
                                    const res = await fetch(`/api/meetings/${id}`, {
                                        method: 'PATCH',
                                        headers: { 'Content-Type': 'application/json' },
                                        body: JSON.stringify({ post_meeting_notes: tempNotes, status: 'completed' })
                                    });
                                    if (res.ok) {
                                        toast.success('Post-meeting notes saved');
                                        setEditingMeetingId(null);
                                        if (onRefresh) {
                                            onRefresh();
                                        }
                                    } else {
                                        toast.error('Failed to save notes');
                                    }
                                } catch (error) {
                                    toast.error('Error saving notes');
                                } finally {
                                    setIsSaving(false);
                                }
                            };

                            return (
                                <div key={item.id} className="relative pl-14">
                                    {/* Icon */}
                                    <div
                                        className={`absolute left-0 w-12 h-12 rounded-full flex items-center justify-center ${getColor(item)}`}
                                    >
                                        {getIcon(item)}
                                    </div>

                                    {/* Content */}
                                    <div className="bg-white border border-gray-200 rounded-lg p-4 hover:shadow-md transition-shadow">
                                        <div className="flex items-start justify-between mb-2">
                                            <div>
                                                <p className="font-semibold text-gray-900 flex items-center gap-2">
                                                    {item.type === 'meeting' ? (
                                                        <>
                                                            {item.status === 'completed' ? 'Completed Meeting' : (isUpcomingMeeting ? 'Upcoming Meeting' : 'Past Meeting')}
                                                            {isUpcomingMeeting && (
                                                                <span className="px-2 py-0.5 rounded text-[10px] bg-amber-100 text-amber-700 uppercase tracking-wider font-bold">
                                                                    Scheduled
                                                                </span>
                                                            )}
                                                            {item.status === 'completed' && (
                                                                <span className="px-2 py-0.5 rounded text-[10px] bg-green-100 text-green-700 uppercase tracking-wider font-bold">
                                                                    Finished
                                                                </span>
                                                            )}
                                                        </>
                                                    ) : item.type === 'note'
                                                        ? 'Note'
                                                        : item.interaction_type ? item.interaction_type.charAt(0).toUpperCase() + item.interaction_type.slice(1) : 'Interaction'}
                                                </p>
                                                <p className="text-sm text-gray-600">
                                                    {item.type === 'meeting' ? (
                                                        new Date(item.date).toLocaleString([], { dateStyle: 'medium', timeStyle: 'short' })
                                                    ) : formatDate(item.date)}
                                                </p>
                                            </div>
                                            {item.type === 'meeting' && !hideBriefingLinks && (
                                                <Link
                                                    href={`/meetings/${item.id}`}
                                                    className="text-xs text-indigo-600 hover:text-indigo-800 font-medium flex items-center gap-1"
                                                >
                                                    {item.status === 'completed' ? 'Review Archive' : 'View Briefing'}
                                                    <ExternalLink className="h-3 w-3" />
                                                </Link>
                                            )}
                                        </div>

                                        {/* Meeting Specific Details */}
                                        {item.type === 'meeting' && (
                                            <div className="mt-3 space-y-2">
                                                <div className="flex flex-wrap gap-4 text-xs text-gray-500">
                                                    <span className="flex items-center gap-1.5 capitalize">
                                                        <Hash className="w-3.5 h-3.5" />
                                                        {item.meeting_type?.replace('_', ' ')}
                                                    </span>
                                                    {item.meeting_location && (
                                                        <span className="flex items-center gap-1.5">
                                                            <MapPin className="w-3.5 h-3.5" />
                                                            {item.meeting_location}
                                                        </span>
                                                    )}
                                                </div>

                                                {item.summary && (
                                                    <p className="text-sm text-gray-700 bg-stone-50 p-3 rounded-lg border border-stone-100">
                                                        {item.summary}
                                                    </p>
                                                )}

                                                {/* Post Meeting Notes Display */}
                                                {item.post_meeting_notes && (
                                                    <div className="mt-4 pt-3 border-t border-gray-100">
                                                        <p className="text-[10px] font-bold text-indigo-500 uppercase tracking-widest mb-1.5 flex items-center gap-1">
                                                            <CheckCircle className="h-3 w-3" />
                                                            Post-Meeting Notes
                                                        </p>
                                                        <p className="text-sm text-gray-700 italic">
                                                            "{item.post_meeting_notes}"
                                                        </p>
                                                    </div>
                                                )}

                                                {/* Post Meeting Notes Editor */}
                                                {isPastMeetingWithoutNotes && (
                                                    <div className="mt-4 pt-3 border-t border-gray-100">
                                                        {editingMeetingId === item.id ? (
                                                            <div className="space-y-3">
                                                                <Textarea
                                                                    value={tempNotes}
                                                                    onChange={(e) => setTempNotes(e.target.value)}
                                                                    placeholder="How did the meeting go? Any follow-up items?"
                                                                    className="text-sm min-h-[100px]"
                                                                />
                                                                <div className="flex gap-2">
                                                                    <Button
                                                                        size="sm"
                                                                        onClick={() => handleSavePostNotes(item.id)}
                                                                        disabled={isSaving}
                                                                    >
                                                                        {isSaving ? 'Saving...' : 'Save Notes'}
                                                                    </Button>
                                                                    <Button
                                                                        size="sm"
                                                                        variant="ghost"
                                                                        onClick={() => setEditingMeetingId(null)}
                                                                    >
                                                                        Cancel
                                                                    </Button>
                                                                </div>
                                                            </div>
                                                        ) : (
                                                            <Button
                                                                variant="outline"
                                                                size="sm"
                                                                className="w-full bg-indigo-50 border-indigo-100 text-indigo-700 hover:bg-indigo-100"
                                                                onClick={() => {
                                                                    setEditingMeetingId(item.id);
                                                                    setTempNotes('');
                                                                }}
                                                            >
                                                                <AlertCircle className="w-4 h-4 mr-2" />
                                                                Add Post-Meeting Notes
                                                            </Button>
                                                        )}
                                                    </div>
                                                )}
                                            </div>
                                        )}

                                        {/* Summary/Content */}
                                        {item.interaction_type === 'capture' ? (
                                            <div className="text-sm text-gray-700 mt-2">
                                                <span>Captured via <strong>{formatSource(item.details?.source)}</strong></span>
                                                {item.event && (
                                                    <>
                                                        {' at '}
                                                        <Link
                                                            href={`/events/${item.event.id}`}
                                                            className="text-indigo-600 hover:text-indigo-700 font-medium inline-flex items-center gap-0.5"
                                                        >
                                                            {item.event.name}
                                                            <ExternalLink className="h-3 w-3" />
                                                        </Link>
                                                    </>
                                                )}
                                            </div>
                                        ) : (
                                            <>
                                                {item.summary && (
                                                    <p className="text-sm text-gray-700 mt-2">
                                                        {item.summary}
                                                    </p>
                                                )}
                                                {item.content && (
                                                    <div className="mt-2">
                                                        {item.note_type === 'voice' && (
                                                            <div className="flex items-center gap-1.5 text-[10px] font-bold text-indigo-500 uppercase tracking-widest mb-1.5">
                                                                <Sparkles className="h-3 w-3" />
                                                                AI Transcript
                                                            </div>
                                                        )}
                                                        <p className="text-sm text-gray-700 italic bg-gray-50/50 p-3 rounded-lg border border-gray-100/50">
                                                            "{item.content}"
                                                        </p>
                                                    </div>
                                                )}
                                            </>
                                        )}

                                        {/* Voice Note Player */}
                                        {item.type === 'note' && item.note_type === 'voice' && (item.source_url || item.details?.source_url) && (
                                            <div className="mt-3">
                                                <VoiceNotePlayer
                                                    audioURL={item.source_url || item.details?.source_url}
                                                    duration={item.details?.duration}
                                                />
                                            </div>
                                        )}

                                        {/* Capture Photo Reference (Dropdown) */}
                                        {item.interaction_type === 'capture' && item.details?.image_url && (
                                            <div className="mt-4 pt-3 border-t border-gray-100">
                                                <details className="group">
                                                    <summary className="text-xs font-semibold text-stone-500 uppercase tracking-wider cursor-pointer hover:text-stone-900 transition-colors flex items-center gap-1 list-none">
                                                        <span className="group-open:rotate-90 transition-transform">▶</span>
                                                        View Photo Scan
                                                    </summary>
                                                    <div className="mt-3">
                                                        <div className="bg-stone-50 p-4 rounded-xl border border-stone-200 shadow-inner">
                                                            <div className="flex items-center justify-between mb-3">
                                                                <div className="flex items-center gap-1.5 text-[10px] font-bold text-stone-400 uppercase tracking-widest">
                                                                    <Camera className="h-3 w-3" />
                                                                    Photo Reference
                                                                </div>
                                                                <a
                                                                    href={item.details.image_url}
                                                                    target="_blank"
                                                                    rel="noopener noreferrer"
                                                                    className="text-[10px] font-bold text-indigo-600 hover:text-indigo-700 uppercase tracking-widest flex items-center gap-1 bg-white px-2 py-1 rounded-md shadow-sm border border-stone-100 transition-all hover:scale-105"
                                                                >
                                                                    View Original
                                                                    <ExternalLink className="h-2.5 w-2.5" />
                                                                </a>
                                                            </div>
                                                            <div className="relative aspect-[4/3] w-full max-w-sm rounded-lg overflow-hidden border border-stone-200 bg-white shadow-md">
                                                                <img
                                                                    src={item.details.image_url}
                                                                    alt="Capture Reference"
                                                                    className="w-full h-full object-contain"
                                                                />
                                                            </div>
                                                        </div>
                                                    </div>
                                                </details>
                                            </div>
                                        )}

                                        {/* Additional Metadata Toggle (Hidden for captures) */}
                                        {/* Additional Metadata Toggle (Hidden if no relevant details) */}
                                        {(() => {
                                            if (item.interaction_type === 'capture' || !item.details) return null;

                                            const ignoredKeys = ['source', 'raw_text', 'source_url', 'duration', 'event_name', 'image_url', 'extracted_data', 'transcript'];
                                            const visibleDetails = Object.entries(item.details).filter(([key]) => !ignoredKeys.includes(key));

                                            if (visibleDetails.length === 0) return null;

                                            return (
                                                <div className="mt-4 pt-3 border-t border-gray-100">
                                                    <details className="group">
                                                        <summary className="text-xs font-semibold text-stone-500 uppercase tracking-wider cursor-pointer hover:text-stone-900 transition-colors flex items-center gap-1 list-none">
                                                            <span className="group-open:rotate-90 transition-transform">▶</span>
                                                            More Details
                                                        </summary>
                                                        <div className="mt-3 space-y-3">
                                                            <div className="grid grid-cols-1 gap-1.5 px-1">
                                                                {visibleDetails.map(([key, value]) => (
                                                                    <div key={key} className="flex items-baseline gap-2 text-xs">
                                                                        <span className="text-stone-400 font-medium min-w-[70px] capitalize">{key.replace(/_/g, ' ')}:</span>
                                                                        <span className="text-stone-700 break-all">{typeof value === 'object' ? JSON.stringify(value) : String(value)}</span>
                                                                    </div>
                                                                ))}
                                                            </div>
                                                        </div>
                                                    </details>
                                                </div>
                                            );
                                        })()}
                                    </div>
                                </div>
                            );
                        })}
                    </div>
                </div>
            )}
        </div>
    );
}
