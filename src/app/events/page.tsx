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
import { Calendar, MapPin, Clock, ChevronRight, Search, Filter, X } from 'lucide-react';

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
            <div className="max-w-7xl mx-auto">
                {/* Page Header */}
                <div className="mb-8">
                    <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 mb-8">
                        <div>
                            <h1 className="text-display mb-1">Events</h1>
                            <p className="text-body">
                                {filteredEvents.length} {filteredEvents.length === 1 ? 'event' : 'events'} found
                                {events.length !== filteredEvents.length && ` (out of ${events.length} total)`}
                            </p>
                        </div>
                        <Button onClick={() => setShowModal(true)} className="w-full md:w-auto">
                            + Create Event
                        </Button>
                    </div>

                    {/* Filter Bar */}
                    <div className="premium-card p-4 mb-8">
                        <div className="flex flex-col lg:flex-row items-center gap-4">
                            <div className="relative flex-1 w-full">
                                <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-stone-400" />
                                <input
                                    type="text"
                                    placeholder="Search events by name or location..."
                                    className="w-full pl-10 pr-4 py-2 bg-stone-50 border border-stone-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500 transition-all"
                                    value={searchQuery}
                                    onChange={(e) => setSearchQuery(e.target.value)}
                                />
                                {searchQuery && (
                                    <button
                                        onClick={() => setSearchQuery('')}
                                        className="absolute right-3 top-1/2 -translate-y-1/2 text-stone-400 hover:text-stone-600"
                                    >
                                        <X className="h-4 w-4" />
                                    </button>
                                )}
                            </div>

                            <div className="flex flex-wrap items-center gap-4 w-full lg:w-auto">
                                <div className="flex items-center gap-2 min-w-[140px]">
                                    <span className="text-xs font-semibold text-stone-500 uppercase tracking-wider">Status:</span>
                                    <select
                                        className="flex-1 bg-stone-50 border border-stone-200 rounded-xl px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500 transition-all appearance-none cursor-pointer"
                                        value={filterStatus}
                                        onChange={(e) => setFilterStatus(e.target.value)}
                                    >
                                        <option value="all">All Occurrences</option>
                                        <option value="upcoming">Upcoming</option>
                                        <option value="ongoing">Ongoing</option>
                                        <option value="completed">Completed</option>
                                    </select>
                                </div>

                                <div className="flex items-center gap-2 min-w-[140px]">
                                    <span className="text-xs font-semibold text-stone-500 uppercase tracking-wider">Type:</span>
                                    <select
                                        className="flex-1 bg-stone-50 border border-stone-200 rounded-xl px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500 transition-all appearance-none cursor-pointer"
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
                                    <Button
                                        variant="ghost"
                                        size="sm"
                                        onClick={resetFilters}
                                        className="text-stone-500 hover:text-stone-700"
                                    >
                                        Clear Filters
                                    </Button>
                                )}
                            </div>
                        </div>
                    </div>
                </div>

                {loading ? (
                    <div className="grid gap-4">
                        {[1, 2, 3].map((i) => (
                            <div key={i} className="premium-card p-6 flex flex-col gap-4">
                                <div className="flex justify-between items-start">
                                    <div className="space-y-2 flex-1">
                                        <div className="flex items-center gap-3">
                                            <Skeleton className="h-6 w-1/3" />
                                            <Skeleton className="h-5 w-20 rounded-full" />
                                        </div>
                                        <Skeleton className="h-4 w-1/2" />
                                    </div>
                                    <Skeleton className="h-5 w-5 rounded-md" />
                                </div>
                                <div className="flex gap-4">
                                    <Skeleton className="h-4 w-24" />
                                    <Skeleton className="h-4 w-24" />
                                    <Skeleton className="h-4 w-32" />
                                </div>
                            </div>
                        ))}
                    </div>
                ) : filteredEvents.length === 0 ? (
                    <div className="premium-card p-12 text-center">
                        <div className="mb-4 flex h-12 w-12 items-center justify-center rounded-full bg-stone-100 text-stone-400 mx-auto">
                            {searchQuery || filterStatus !== 'all' || filterType !== 'all' ? (
                                <Filter className="h-6 w-6" strokeWidth={2} />
                            ) : (
                                <Calendar className="h-6 w-6" strokeWidth={2} />
                            )}
                        </div>
                        <h3 className="text-card-title mb-2">
                            {searchQuery || filterStatus !== 'all' || filterType !== 'all'
                                ? "No events match your filters"
                                : "No events yet"}
                        </h3>
                        <p className="text-body mb-6">
                            {searchQuery || filterStatus !== 'all' || filterType !== 'all'
                                ? "Try adjusting your search query or filters to find what you're looking for."
                                : "Create your first exhibition or conference to start capturing leads"}
                        </p>
                        {searchQuery || filterStatus !== 'all' || filterType !== 'all' ? (
                            <Button onClick={resetFilters} variant="secondary">
                                Reset Filters
                            </Button>
                        ) : (
                            <Button onClick={() => setShowModal(true)}>
                                + Create First Event
                            </Button>
                        )}
                    </div>
                ) : (
                    <div className="grid gap-4">
                        {filteredEvents.map((event) => (
                            <Link
                                key={event.id}
                                href={`/events/${event.id}`}
                                className="premium-card p-6 hover:shadow-lg transition-smooth cursor-pointer group"
                            >
                                <div className="flex items-center justify-between">
                                    <div className="flex-1">
                                        <div className="flex items-center gap-3 mb-2">
                                            <h3 className="text-card-title group-hover:text-indigo-600 transition-colors">
                                                {event.name}
                                            </h3>
                                            <span className={`px-2 py-1 text-xs font-medium rounded-full ${getStatusBadge(event.status)}`}>
                                                {event.status}
                                            </span>
                                        </div>
                                        {event.description && (
                                            <p className="text-body mb-3">{event.description}</p>
                                        )}
                                        <div className="flex items-center gap-4 text-caption">
                                            <span className="flex items-center gap-1.5 capitalize">
                                                <Calendar className="w-4 h-4" strokeWidth={2} />
                                                {event.event_type}
                                            </span>
                                            {event.location && (
                                                <span className="flex items-center gap-1.5">
                                                    <MapPin className="w-4 h-4" strokeWidth={2} />
                                                    {event.location}
                                                </span>
                                            )}
                                            <span className="flex items-center gap-1.5">
                                                <Clock className="w-4 h-4" strokeWidth={2} />
                                                {new Date(event.start_date).toLocaleDateString()}
                                                {event.end_date && ` - ${new Date(event.end_date).toLocaleDateString()}`}
                                            </span>
                                        </div>
                                    </div>
                                    <ChevronRight className="w-5 h-5 text-stone-400 group-hover:text-indigo-600 transition-colors" strokeWidth={2} />
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
