'use client';

import React, { useState, useMemo } from 'react';
import { useRouter } from 'next/navigation';
import {
    format,
    startOfMonth,
    endOfMonth,
    eachDayOfInterval,
    isSameDay,
    isToday,
    startOfWeek,
    endOfWeek,
    addMonths,
    subMonths,
    addWeeks,
    subWeeks,
    addDays,
    subDays,
    isSameMonth,
    parseISO
} from 'date-fns';
import { motion, AnimatePresence } from 'framer-motion';
import {
    ChevronLeft,
    ChevronRight,
    Calendar as CalendarIcon,
    Clock,
    MapPin,
    ArrowUpRight
} from 'lucide-react';
import { cn, formatLabel } from '@/lib/utils';

interface Meeting {
    id: string;
    meeting_date: string;
    meeting_type: string;
    status: string;
    contact: {
        first_name: string;
        last_name?: string;
        company?: {
            name: string;
        };
    };
}

interface MeetingsCalendarProps {
    meetings: Meeting[];
    initialView?: 'day' | 'week' | 'month';
    showToolbar?: boolean;
    availableViews?: ('day' | 'week' | 'month')[];
}

export function MeetingsCalendar({
    meetings,
    initialView = 'month',
    showToolbar = true,
    availableViews = ['day', 'week', 'month']
}: MeetingsCalendarProps) {
    const router = useRouter();
    const [viewType, setViewType] = useState<'day' | 'week' | 'month'>(initialView);
    const [viewDate, setViewDate] = useState(new Date());
    const [selectedDate, setSelectedDate] = useState(new Date());

    // --- Helper Logic ---
    const meetingsByDay = useMemo(() => {
        const map: Record<string, Meeting[]> = {};
        meetings.forEach(m => {
            const dateStr = format(parseISO(m.meeting_date), 'yyyy-MM-dd');
            if (!map[dateStr]) map[dateStr] = [];
            map[dateStr].push(m);
        });
        return map;
    }, [meetings]);

    const navigate = (direction: 'next' | 'prev') => {
        if (viewType === 'month') {
            setViewDate(prev => direction === 'next' ? addMonths(prev, 1) : subMonths(prev, 1));
        } else if (viewType === 'week') {
            setViewDate(prev => direction === 'next' ? addWeeks(prev, 1) : subWeeks(prev, 1));
        } else {
            setViewDate(prev => direction === 'next' ? addDays(prev, 1) : subDays(prev, 1));
        }
    };

    const handleToday = () => {
        const now = new Date();
        setViewDate(now);
        setSelectedDate(now);
    };

    const getStatusColor = (status: string) => {
        switch (status) {
            case 'scheduled':
                return 'bg-blue-600 border-blue-600 text-white';
            case 'completed':
                return 'bg-emerald-600 border-emerald-600 text-white';
            default:
                return 'bg-stone-600 border-stone-600 text-white';
        }
    };

    const getStatusBadgeColor = (status: string) => {
        switch (status) {
            case 'scheduled':
                return 'bg-blue-600 text-white';
            case 'completed':
                return 'bg-emerald-600 text-white';
            default:
                return 'bg-stone-600 text-white';
        }
    };

    // --- Sub-Components ---

    const ControlBar = () => (
        <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between mb-6 gap-4">
            <div>
                <h2 className="text-2xl font-bold text-stone-900 tracking-tight flex items-center gap-2">
                    {viewType === 'day' && format(viewDate, 'EEEE, MMMM do, yyyy')}
                    {viewType === 'week' && `Week of ${format(startOfWeek(viewDate), 'MMM do')}`}
                    {viewType === 'month' && format(viewDate, 'MMMM yyyy')}
                </h2>
            </div>

            <div className="flex items-center gap-4">
                {/* View Switcher */}
                <div className="flex bg-stone-100 p-1 rounded-lg border border-stone-200">
                    {availableViews.map((vt) => (
                        <button
                            key={vt}
                            onClick={() => setViewType(vt)}
                            className={cn(
                                "px-3 py-1.5 text-xs font-semibold rounded-md transition-all capitalize",
                                viewType === vt ? "bg-white shadow-sm text-stone-900" : "text-stone-500 hover:text-stone-900"
                            )}
                        >
                            {vt}
                        </button>
                    ))}
                </div>

                {/* Navigation */}
                <div className="flex items-center gap-1 bg-stone-100 p-1 rounded-lg border border-stone-200">
                    <button onClick={() => navigate('prev')} className="p-1.5 hover:bg-white rounded-md transition-all text-stone-600">
                        <ChevronLeft className="w-4 h-4" />
                    </button>
                    <button onClick={handleToday} className="px-3 py-1 text-xs font-bold uppercase tracking-wider text-stone-600 hover:bg-white rounded-md transition-all">
                        Today
                    </button>
                    <button onClick={() => navigate('next')} className="p-1.5 hover:bg-white rounded-md transition-all text-stone-600">
                        <ChevronRight className="w-4 h-4" />
                    </button>
                </div>
            </div>
        </div>
    );

    const DayView = () => {
        const dateStr = format(viewDate, 'yyyy-MM-dd');
        const dayMeetings = meetingsByDay[dateStr] || [];

        return (
            <div className="flex flex-col gap-4 animate-in fade-in duration-500">
                {dayMeetings.length === 0 ? (
                    <div className="flex flex-col items-center justify-center py-20 bg-stone-50 rounded-2xl border border-dashed border-stone-200">
                        <CalendarIcon className="w-10 h-10 mb-3 text-stone-300 stroke-[1.5]" />
                        <p className="text-stone-400 font-medium">No meetings scheduled for this day</p>
                    </div>
                ) : (
                    <div className="space-y-4">
                        {dayMeetings.sort((a, b) => a.meeting_date.localeCompare(b.meeting_date)).map((meeting) => (
                            <div
                                key={meeting.id}
                                onClick={() => router.push(`/meetings/${meeting.id}`)}
                                className="group flex gap-4 p-4 bg-white border border-stone-200 rounded-xl hover:shadow-md transition-all cursor-pointer relative overflow-hidden"
                            >
                                <div className={cn("absolute left-0 top-0 bottom-0 w-1.5", meeting.status === 'scheduled' ? 'bg-blue-600' : 'bg-emerald-600')} />

                                <div className="flex flex-col items-center justify-center px-4 border-r border-stone-100 min-w-[100px]">
                                    <span className="text-2xl font-bold text-stone-900">
                                        {format(parseISO(meeting.meeting_date), 'h:mm')}
                                    </span>
                                    <span className="text-xs font-bold text-stone-400 uppercase">
                                        {format(parseISO(meeting.meeting_date), 'a')}
                                    </span>
                                </div>

                                <div className="flex-1 py-1">
                                    <div className="flex justify-between items-start mb-2">
                                        <h3 className="text-lg font-bold text-stone-900 group-hover:text-indigo-600 transition-colors">
                                            {meeting.contact.first_name} {meeting.contact.last_name}
                                        </h3>
                                        <ArrowUpRight className="w-4 h-4 text-stone-300 group-hover:text-indigo-600" />
                                    </div>
                                    <p className="text-sm text-stone-500 mb-3">{meeting.contact.company?.name || 'Unknown Company'}</p>

                                    <div className="flex items-center gap-3">
                                        <span className={cn("px-2.5 py-0.5 rounded-full text-[10px] font-bold uppercase tracking-wider", getStatusBadgeColor(meeting.status))}>
                                            {meeting.status}
                                        </span>
                                        <span className="text-xs text-stone-400 font-medium flex items-center gap-1.5">
                                            <Clock className="w-3.5 h-3.5" />
                                            {formatLabel(meeting.meeting_type)}
                                        </span>
                                    </div>
                                </div>
                            </div>
                        ))}
                    </div>
                )}
            </div>
        );
    };

    const WeekView = () => {
        const start = startOfWeek(viewDate, { weekStartsOn: 0 }); // Sunday start
        const end = endOfWeek(viewDate, { weekStartsOn: 0 });
        const days = eachDayOfInterval({ start, end });

        return (
            <div className="grid grid-cols-7 gap-px bg-stone-200 border border-stone-200 rounded-xl overflow-hidden animate-in fade-in duration-500">
                {days.map((day) => {
                    const dateStr = format(day, 'yyyy-MM-dd');
                    const dayMeetings = meetingsByDay[dateStr] || [];
                    const isTodayDate = isToday(day);

                    return (
                        <div key={dateStr} className="bg-white min-h-[400px] flex flex-col group relative">
                            {/* Header */}
                            <div className={cn(
                                "p-3 text-center border-b border-stone-50",
                                isTodayDate ? "bg-stone-50" : ""
                            )}>
                                <span className="block text-[10px] font-bold text-stone-400 uppercase tracking-widest mb-1">
                                    {format(day, 'EEE')}
                                </span>
                                <span className={cn(
                                    "flex items-center justify-center w-8 h-8 rounded-full text-sm font-bold mx-auto transition-colors",
                                    isTodayDate ? "bg-stone-900 text-white" : "text-stone-700 group-hover:bg-stone-100"
                                )}>
                                    {format(day, 'd')}
                                </span>
                            </div>

                            {/* Content */}
                            <div className="flex-1 p-2 space-y-2 overflow-y-auto custom-scrollbar">
                                {dayMeetings.map(m => (
                                    <div
                                        key={m.id}
                                        onClick={() => router.push(`/meetings/${m.id}`)}
                                        className={cn(
                                            "p-2 rounded-lg text-xs cursor-pointer hover:brightness-95 transition-all shadow-sm",
                                            getStatusColor(m.status)
                                        )}
                                    >
                                        <div className="font-bold truncate mb-0.5">
                                            {format(parseISO(m.meeting_date), 'h:mm a')}
                                        </div>
                                        <div className="font-semibold truncate leading-tight">
                                            {m.contact.first_name}
                                        </div>
                                        <div className="opacity-80 truncate text-[10px] mt-1">
                                            {m.contact.company?.name}
                                        </div>
                                    </div>
                                ))}
                            </div>
                        </div>
                    );
                })}
            </div>
        );
    };

    const MonthView = () => {
        const start = startOfWeek(startOfMonth(viewDate));
        const end = endOfWeek(endOfMonth(viewDate));
        const days = eachDayOfInterval({ start, end });
        const weekDays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

        return (
            <div className="flex flex-col h-full animate-in fade-in duration-500">
                <div className="grid grid-cols-7 mb-2">
                    {weekDays.map(day => (
                        <div key={day} className="text-center text-[10px] font-bold text-stone-400 uppercase tracking-widest py-2">
                            {day}
                        </div>
                    ))}
                </div>

                <div className="grid grid-cols-7 border-t border-l border-stone-100 rounded-2xl overflow-hidden shadow-sm bg-stone-100 gap-px">
                    {days.map((day, idx) => {
                        const dateStr = format(day, 'yyyy-MM-dd');
                        const dayMeetings = meetingsByDay[dateStr] || [];
                        const isCurrentMonth = isSameMonth(day, viewDate);

                        return (
                            <div
                                key={idx}
                                onClick={() => {
                                    setViewDate(day);
                                    setViewType('day');
                                }}
                                className={cn(
                                    "min-h-[100px] p-2 bg-white hover:bg-stone-50 transition-all cursor-pointer relative flex flex-col",
                                    !isCurrentMonth && "bg-stone-50/50 text-stone-300"
                                )}
                            >
                                <span className={cn(
                                    "text-xs font-bold w-6 h-6 flex items-center justify-center rounded-full mb-1 transition-all",
                                    isToday(day) ? "bg-stone-900 text-white" : "text-stone-500",
                                )}>
                                    {format(day, 'd')}
                                </span>

                                <div className="flex-1 flex flex-col gap-1 overflow-hidden">
                                    {dayMeetings.slice(0, 3).map(m => (
                                        <div
                                            key={m.id}
                                            className={cn(
                                                "px-1.5 py-0.5 rounded text-[9px] font-bold truncate",
                                                getStatusBadgeColor(m.status)
                                            )}
                                        >
                                            {m.contact.first_name}
                                        </div>
                                    ))}
                                    {dayMeetings.length > 3 && (
                                        <div className="text-[9px] font-bold text-stone-400 px-1">
                                            + {dayMeetings.length - 3} more
                                        </div>
                                    )}
                                </div>
                            </div>
                        );
                    })}
                </div>
            </div>
        );
    };

    return (
        <div className="w-full flex flex-col h-full bg-white p-6 rounded-3xl">
            <ControlBar />
            <div className="flex-1 min-h-0 overflow-y-auto custom-scrollbar">
                {viewType === 'day' && <DayView />}
                {viewType === 'week' && <WeekView />}
                {viewType === 'month' && <MonthView />}
            </div>
        </div>
    );
}
