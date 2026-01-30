'use client';

import { useState, useEffect } from 'react';
import Link from 'next/link';
import { AppShell } from '@/components/layout/AppShell';
import { Button } from '@/components/ui/Button';
import { Modal } from '@/components/ui/Modal';
import { Input } from '@/components/ui/Input';
import { Textarea } from '@/components/ui/Textarea';
import { Select } from '@/components/ui/Select';
import { Event } from '@/types';
import { Skeleton } from '@/components/ui/Skeleton';
import { Calendar, MapPin, Clock, ChevronRight, Search, Filter, X, Plus, Briefcase } from 'lucide-react';

export default function EventsPage() {
    const [events, setEvents] = useState<Event[]>([]);
    const [loading, setLoading] = useState(true);
    const [showModal, setShowModal] = useState(false);
    const [formData, setFormData] = useState({
        name: '',
        description: '',
        location: '',
        start_date: '',
        end_date: '',
        event_type: 'exhibition' as const,
    });

    // Filter states
    const [searchQuery, setSearchQuery] = useState('');
    const [filterStatus, setFilterStatus] = useState('all');
    const [filterType, setFilterType] = useState('all');

    useEffect(() => {
        fetchEvents();

        // Listen for sync/refresh events to update list without reload
        const handleRefresh = () => fetchEvents();
        window.addEventListener('sync:complete', handleRefresh);
        window.addEventListener('events:refresh', handleRefresh);

        return () => {
            window.removeEventListener('sync:complete', handleRefresh);
            window.removeEventListener('events:refresh', handleRefresh);
        };
    }, []);

    const fetchEvents = async () => {
        try {
            const response = await fetch('/api/events');
            const data = await response.json();
            setEvents(data.data || []);
        } catch (error) {
            console.error('Failed to fetch events:', error);
        } finally {
            setLoading(false);
        }
    };

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        try {
            const response = await fetch('/api/events', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(formData),
            });

            if (response.ok) {
                setShowModal(false);
                fetchEvents();
                setFormData({
                    name: '',
                    description: '',
                    location: '',
                    start_date: '',
                    end_date: '',
                    event_type: 'exhibition',
                });
            }
        } catch (error) {
            console.error('Failed to create event:', error);
        }
    };

    const getStatusBadge = (status: string) => {
        const badges = {
            upcoming: 'bg-blue-100 text-blue-800',
            ongoing: 'bg-green-100 text-green-800',
            completed: 'bg-stone-100 text-stone-800',
        };
        return badges[status as keyof typeof badges] || 'bg-blue-100 text-blue-800';
    };

    const filteredEvents = events.filter(event => {
        const matchesSearch =
            event.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
            (event.location?.toLowerCase().includes(searchQuery.toLowerCase()));

        const matchesStatus = filterStatus === 'all' || event.status === filterStatus;
        const matchesType = filterType === 'all' || event.event_type === filterType;

        return matchesSearch && matchesStatus && matchesType;
    });

    const resetFilters = () => {
        setSearchQuery('');
        setFilterStatus('all');
        setFilterType('all');
    };

    return (
        <AppShell>
            <div className="max-w-7xl mx-auto px-4 py-8">
                {/* Page Header */}
                <div className="mb-12">
                    <div className="flex flex-col md:flex-row md:items-end justify-between gap-8 mb-10">
                        <div>
                            <h1 className="text-4xl font-black text-stone-900 tracking-tight leading-tight mb-2">Events</h1>
                            <p className="text-sm font-medium text-stone-500 italic">
                                {filteredEvents.length} active events
                                {events.length !== filteredEvents.length && ` (from ${events.length} total events)`}
                            </p>
                        </div>
                        <Button
                            onClick={() => setShowModal(true)}
                            className="h-11 px-8 bg-stone-900 hover:bg-stone-800 text-white rounded-xl shadow-xl shadow-stone-900/10 font-black uppercase tracking-widest text-[10px] transition-all active:scale-95"
                        >
                            <Plus className="mr-2 h-4 w-4" strokeWidth={2.5} />
                            Add Event
                        </Button>
                    </div>

                    {/* Filter Ecosystem */}
                    <div className="bg-white rounded-[2rem] border border-stone-100 p-6 shadow-sm">
                        <div className="flex flex-col xl:flex-row items-center gap-6">
                            <div className="relative flex-1 w-full group">
                                <div className="absolute left-4 top-1/2 -translate-y-1/2 p-1.5 bg-stone-900 rounded-lg text-white shadow-lg transition-transform group-focus-within:scale-110">
                                    <Search className="w-3.5 h-3.5" strokeWidth={2.5} />
                                </div>
                                <input
                                    type="text"
                                    placeholder="Search events..."
                                    className="w-full h-12 pl-14 pr-10 bg-stone-50/50 border border-stone-100 rounded-xl text-sm font-bold placeholder:text-stone-400 focus:outline-none focus:ring-4 focus:ring-stone-900/5 focus:border-stone-900 transition-all"
                                    value={searchQuery}
                                    onChange={(e) => setSearchQuery(e.target.value)}
                                />
                                {searchQuery && (
                                    <button
                                        onClick={() => setSearchQuery('')}
                                        className="absolute right-4 top-1/2 -translate-y-1/2 text-stone-300 hover:text-stone-900 transition-colors"
                                    >
                                        <X className="h-4 w-4" strokeWidth={2.5} />
                                    </button>
                                )}
                            </div>

                            <div className="flex flex-wrap items-center gap-6 w-full xl:w-auto">
                                <div className="flex items-center gap-4 min-w-[200px]">
                                    <span className="text-[10px] font-black text-stone-400 uppercase tracking-widest">Status:</span>
                                    <select
                                        className="flex-1 h-12 bg-stone-50/50 border border-stone-100 rounded-xl px-4 text-xs font-bold focus:outline-none focus:ring-4 focus:ring-stone-900/5 focus:border-stone-900 transition-all appearance-none cursor-pointer text-stone-600"
                                        value={filterStatus}
                                        onChange={(e) => setFilterStatus(e.target.value)}
                                    >
                                        <option value="all">All Statuses</option>
                                        <option value="upcoming">Upcoming</option>
                                        <option value="ongoing">Active Now</option>
                                        <option value="completed">Analyzed</option>
                                    </select>
                                </div>

                                <div className="flex items-center gap-4 min-w-[200px]">
                                    <span className="text-[10px] font-black text-stone-400 uppercase tracking-widest">Type:</span>
                                    <select
                                        className="flex-1 h-12 bg-stone-50/50 border border-stone-100 rounded-xl px-4 text-xs font-bold focus:outline-none focus:ring-4 focus:ring-stone-900/5 focus:border-stone-900 transition-all appearance-none cursor-pointer text-stone-600"
                                        value={filterType}
                                        onChange={(e) => setFilterType(e.target.value)}
                                    >
                                        <option value="all">All Types</option>
                                        <option value="exhibition">Exhibition</option>
                                        <option value="conference">Conference</option>
                                        <option value="meeting">Meeting</option>
                                    </select>
                                </div>

                                {(searchQuery || filterStatus !== 'all' || filterType !== 'all') && (
                                    <button
                                        onClick={resetFilters}
                                        className="text-[10px] font-black uppercase tracking-widest text-stone-400 hover:text-stone-900 transition-colors px-4"
                                    >
                                        Reset Filters
                                    </button>
                                )}
                            </div>
                        </div>
                    </div>
                </div>

                {/* Events List */}
                {loading ? (
                    <div className="grid gap-6">
                        {[1, 2, 3].map((i) => (
                            <div key={i} className="bg-white rounded-[2rem] border border-stone-100 p-8 flex flex-col gap-6">
                                <div className="flex justify-between items-start">
                                    <div className="space-y-3 flex-1">
                                        <div className="flex items-center gap-4">
                                            <Skeleton className="h-8 w-1/3 rounded-lg" />
                                            <Skeleton className="h-6 w-24 rounded-full" />
                                        </div>
                                        <Skeleton className="h-4 w-1/2 rounded-lg" />
                                    </div>
                                    <Skeleton className="h-6 w-6 rounded-md" />
                                </div>
                                <div className="flex gap-6">
                                    <Skeleton className="h-4 w-32 rounded-lg" />
                                    <Skeleton className="h-4 w-32 rounded-lg" />
                                    <Skeleton className="h-4 w-32 rounded-lg" />
                                </div>
                            </div>
                        ))}
                    </div>
                ) : filteredEvents.length === 0 ? (
                    <div className="bg-stone-50/50 rounded-[3rem] p-24 text-center border-2 border-dashed border-stone-100 flex flex-col items-center">
                        <div className="mb-8 flex h-20 w-20 items-center justify-center rounded-[2rem] bg-stone-900 text-white shadow-2xl shadow-stone-900/10">
                            {searchQuery || filterStatus !== 'all' || filterType !== 'all' ? (
                                <Filter className="h-8 w-8" strokeWidth={2.5} />
                            ) : (
                                <Calendar className="h-8 w-8" strokeWidth={2.5} />
                            )}
                        </div>
                        <h3 className="text-2xl font-black text-stone-900 mb-3 tracking-tight">
                            {searchQuery || filterStatus !== 'all' || filterType !== 'all'
                                ? "No events found"
                                : "No events yet"}
                        </h3>
                        <p className="text-stone-500 font-medium italic mb-10 max-w-[380px]">
                            {searchQuery || filterStatus !== 'all' || filterType !== 'all'
                                ? "Try adjusting your search filters to find what you're looking for."
                                : "Add your first exhibition or conference to get started."}
                        </p>
                        {searchQuery || filterStatus !== 'all' || filterType !== 'all' ? (
                            <Button onClick={resetFilters} className="h-14 px-10 rounded-2xl bg-stone-900 hover:bg-stone-800 text-white font-black uppercase tracking-[0.2em] text-[10px] shadow-2xl shadow-stone-900/20 active:scale-95 transition-all">
                                Reset Filters
                            </Button>
                        ) : (
                            <Button onClick={() => setShowModal(true)} size="lg" className="h-14 px-10 rounded-2xl bg-stone-900 hover:bg-stone-800 text-white font-black uppercase tracking-[0.2em] text-[10px] shadow-2xl shadow-stone-900/20 active:scale-95 transition-all">
                                <Plus className="mr-3 h-5 w-5" strokeWidth={3} />
                                Add First Event
                            </Button>
                        )}
                    </div>
                ) : (
                    <div className="grid grid-cols-1 gap-6">
                        {filteredEvents.map((event) => (
                            <Link
                                key={event.id}
                                href={`/events/${event.id}`}
                                className="group bg-white rounded-[2.5rem] border border-stone-100 p-8 shadow-sm hover:shadow-2xl hover:shadow-stone-900/5 hover:border-stone-200 transition-all duration-500 cursor-pointer"
                            >
                                <div className="flex items-center justify-between">
                                    <div className="flex-1 min-w-0" >
                                        <div className="flex items-center gap-4 mb-4">
                                            <h3 className="text-2xl font-black text-stone-900 tracking-tight group-hover:text-stone-600 transition-colors">
                                                {event.name}
                                            </h3>
                                            <span className={`px-3 py-1 text-[9px] font-black uppercase tracking-[0.15em] rounded-full border shadow-sm ${event.status === 'ongoing'
                                                ? 'bg-emerald-50 text-emerald-600 border-emerald-100'
                                                : event.status === 'upcoming'
                                                    ? 'bg-stone-900 text-white border-stone-800'
                                                    : 'bg-stone-50 text-stone-500 border-stone-100'
                                                }`}>
                                                {event.status === 'ongoing' ? 'Active now' : event.status}
                                            </span>
                                        </div>
                                        {event.description && (
                                            <p className="text-sm font-medium text-stone-400 italic mb-6 max-w-3xl line-clamp-1">
                                                "{event.description}"
                                            </p>
                                        )}
                                        <div className="flex flex-wrap items-center gap-x-10 gap-y-4">
                                            <div className="flex items-center gap-3">
                                                <div className="p-2 bg-stone-900 rounded-xl text-white shadow-lg">
                                                    <Calendar className="w-4 h-4" strokeWidth={2.5} />
                                                </div>
                                                <span className="text-sm font-bold text-stone-600">
                                                    {new Date(event.start_date).toLocaleDateString(undefined, { month: 'short', day: 'numeric' })}
                                                    {event.end_date && ` — ${new Date(event.end_date).toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' })}`}
                                                </span>
                                            </div>
                                            {event.location && (
                                                <div className="flex items-center gap-3">
                                                    <div className="p-2 bg-stone-900 rounded-xl text-white shadow-lg">
                                                        <MapPin className="w-4 h-4" strokeWidth={2.5} />
                                                    </div>
                                                    <span className="text-sm font-bold text-stone-600">{event.location}</span>
                                                </div>
                                            )}
                                            <div className="flex items-center gap-3">
                                                <div className="p-2 bg-stone-900 rounded-xl text-white shadow-lg">
                                                    <Briefcase className="w-4 h-4" strokeWidth={2.5} />
                                                </div>
                                                <span className="text-sm font-bold text-stone-400 uppercase tracking-widest">{event.event_type}</span>
                                            </div>
                                        </div>
                                    </div>
                                    <div className="ml-8 p-6 bg-stone-50 rounded-[1.5rem] group-hover:bg-stone-900 transition-all duration-500 border border-stone-100 group-hover:border-stone-800 shrink-0">
                                        <ChevronRight className="w-6 h-6 text-stone-300 group-hover:text-white transition-colors" strokeWidth={3} />
                                    </div>
                                </div>
                            </Link>
                        ))}
                    </div>
                )}
            </div>

            {/* Create Event Modal */}
            <Modal
                isOpen={showModal}
                onClose={() => setShowModal(false)}
                title="Create New Event"
                size="lg"
            >
                <form onSubmit={handleSubmit}>
                    <div className="space-y-4">
                        <Input
                            label="Event Name"
                            required
                            value={formData.name}
                            onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                            placeholder="Tech Conference 2024"
                        />

                        <Textarea
                            label="Description"
                            rows={3}
                            value={formData.description}
                            onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                            placeholder="Brief description of the event..."
                        />

                        <Input
                            label="Location"
                            value={formData.location}
                            onChange={(e) => setFormData({ ...formData, location: e.target.value })}
                            placeholder="San Francisco, CA"
                        />

                        <div className="grid grid-cols-2 gap-4">
                            <Input
                                label="Start Date"
                                type="date"
                                required
                                value={formData.start_date}
                                onChange={(e) => setFormData({ ...formData, start_date: e.target.value })}
                            />
                            <Input
                                label="End Date"
                                type="date"
                                value={formData.end_date}
                                onChange={(e) => setFormData({ ...formData, end_date: e.target.value })}
                            />
                        </div>

                        <Select
                            label="Event Type"
                            value={formData.event_type}
                            onChange={(e) => setFormData({ ...formData, event_type: e.target.value as any })}
                        >
                            <option value="exhibition">Exhibition</option>
                            <option value="conference">Conference</option>
                            <option value="meeting">Meeting</option>
                        </Select>
                    </div>

                    <div className="modal-footer mt-6 pt-6">
                        <Button type="button" variant="secondary" onClick={() => setShowModal(false)}>
                            Cancel
                        </Button>
                        <Button type="submit" variant="primary">
                            Create Event
                        </Button>
                    </div>
                </form>
            </Modal>
        </AppShell>
    );
}
