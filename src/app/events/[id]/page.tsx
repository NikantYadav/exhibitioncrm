'use client';

import { useParams, useRouter } from 'next/navigation';
import { Header } from '@/components/layout/Header';
import { Button } from '@/components/ui/Button';
import { Skeleton } from '@/components/ui/Skeleton';
import { EventStats } from '@/components/events/EventStats';
import { CompanySearchModal } from '@/components/events/CompanySearchModal';
import { TargetCompanyModal } from '@/components/events/TargetCompanyModal';
import { CompanyDetailModal } from '@/components/events/CompanyDetailModal';
import { Modal } from '@/components/ui/Modal';
import { ConfirmDialog } from '@/components/ui/ConfirmDialog';
import { CaptureFlow } from '@/components/events/CaptureFlow';
import { Input } from '@/components/ui/Input';
import { Textarea } from '@/components/ui/Textarea';
import { Select } from '@/components/ui/Select';
import {
    TargetListSection,
    CapturesSection,
    EmailDraftsSection,
    FollowUpsSection,
    EventSidebar
} from '@/components/events/detail';
import { useEventDetail } from '@/hooks/useEventDetail';
import { ArrowLeft, Mail } from 'lucide-react';

export default function EventDetailPage() {
    const params = useParams();
    const router = useRouter();
    const eventId = params.id as string;

    const {
        event,
        stats,
        targets,
        captures,
        loading,
        activeTab,
        setActiveTab,
        activePrepTab,
        setActivePrepTab,
        showCompanySearch,
        setShowCompanySearch,
        showTargetModal,
        setShowTargetModal,
        selectedCompany,
        setSelectedCompany,
        selectedTarget,
        setSelectedTarget,
        activeCaptureMode,
        showCaptureModal,
        setShowCaptureModal,
        itemToDelete,
        setItemToDelete,
        showDeleteConfirm,
        setShowDeleteConfirm,
        isDeleting,
        viewingTarget,
        showDetailModal,
        setShowDetailModal,
        handleCompanySelect,
        handleSaveTarget,
        handleDeleteTarget,
        handleDeleteCapture,
        handleConfirmDelete,
        handleOpenCapture,
        handleCaptureComplete,
        handleViewTarget,
        handleEditTarget,
        handleDeleteEvent,
        handleUpdateEvent,
        handleExportData,
        showEditEventModal,
        setShowEditEventModal,
        fetchEventData
    } = useEventDetail(eventId);

    if (loading) {
        return (
            <div className="min-h-screen pb-12" style={{ background: '#f9fafb' }}>
                <Header />
                <main className="container pt-8 space-y-8">
                    <Skeleton className="h-10 w-48 mb-6" />
                    <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
                        <div className="lg:col-span-1">
                            <Skeleton className="h-[500px] rounded-3xl" />
                        </div>
                        <div className="lg:col-span-2 space-y-6">
                            <div className="grid grid-cols-3 gap-4">
                                <Skeleton className="h-28 rounded-2xl" />
                                <Skeleton className="h-28 rounded-2xl" />
                                <Skeleton className="h-28 rounded-2xl" />
                            </div>
                            <Skeleton className="h-[400px] rounded-3xl" />
                        </div>
                    </div>
                </main>
            </div>
        );
    }

    if (!event) {
        return (
            <div className="min-h-screen" style={{ background: '#f9fafb' }}>
                <Header />
                <main className="container" style={{ paddingTop: '2rem' }}>
                    <div className="card">
                        <p>Event not found</p>
                    </div>
                </main>
            </div>
        );
    }

    return (
        <div className="min-h-screen" style={{ background: '#f9fafb' }}>
            <Header />

            <main className="container" style={{ paddingTop: '2rem', paddingBottom: '2rem' }}>
                {/* Back Button */}
                <Button
                    variant="ghost"
                    size="sm"
                    onClick={() => router.push('/events')}
                    style={{ marginBottom: '1.5rem' }}
                >
                    <ArrowLeft className="mr-2 h-4 w-4" />
                    Back to Events
                </Button>

                {/* Split Panel Layout */}
                <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
                    {/* Left Panel - Event Info */}
                    <div className="lg:col-span-1">
                        <EventSidebar
                            event={event}
                            onOpenCapture={handleOpenCapture}
                            onExportData={handleExportData}
                            onEditEvent={() => setShowEditEventModal(true)}
                            onDeleteEvent={handleDeleteEvent}
                        />
                    </div>

                    {/* Right Panel - Tabs */}
                    <div className="lg:col-span-2">
                        {/* Stats */}
                        <div className="mb-6">
                            <EventStats stats={stats} />
                        </div>

                        {/* Tabs */}
                        <div className="card" style={{ padding: 0 }}>
                            {/* Tab Headers */}
                            <div className="flex border-b border-gray-200">
                                <button
                                    onClick={() => setActiveTab('research')}
                                    className={`px-6 py-3 text-sm font-medium border-b-2 transition-colors ${activeTab === 'research'
                                        ? 'border-blue-600 text-blue-600'
                                        : 'border-transparent text-gray-600 hover:text-gray-900'
                                        }`}
                                >
                                    Research & Prep
                                </button>
                                <button
                                    onClick={() => setActiveTab('captures')}
                                    className={`px-6 py-3 text-sm font-medium border-b-2 transition-colors ${activeTab === 'captures'
                                        ? 'border-blue-600 text-blue-600'
                                        : 'border-transparent text-gray-600 hover:text-gray-900'
                                        }`}
                                >
                                    Captures
                                </button>
                                <button
                                    onClick={() => setActiveTab('followups')}
                                    className={`px-6 py-3 text-sm font-medium border-b-2 transition-colors ${activeTab === 'followups'
                                        ? 'border-blue-600 text-blue-600'
                                        : 'border-transparent text-gray-600 hover:text-gray-900'
                                        }`}
                                >
                                    Follow-ups
                                </button>
                            </div>

                            {/* Tab Content */}
                            <div className="p-6">
                                {/* Research & Prep Tab */}
                                {activeTab === 'research' && (
                                    <div className="space-y-6">
                                        {/* Sub-Tabs */}
                                        <div className="flex gap-1 bg-gray-50 p-1 rounded-lg w-fit mb-6">
                                            <button
                                                onClick={() => setActivePrepTab('targets')}
                                                className={`px-4 py-1.5 text-xs font-medium rounded-md transition-all ${activePrepTab === 'targets'
                                                    ? 'bg-white text-blue-600 shadow-sm'
                                                    : 'text-gray-500 hover:text-gray-700'
                                                    }`}
                                            >
                                                Target List
                                            </button>

                                            <button
                                                onClick={() => setActivePrepTab('emails')}
                                                className={`px-4 py-1.5 text-xs font-medium rounded-md transition-all ${activePrepTab === 'emails'
                                                    ? 'bg-white text-blue-600 shadow-sm'
                                                    : 'text-gray-500 hover:text-gray-700'
                                                    }`}
                                            >
                                                Email Drafts
                                            </button>
                                        </div>

                                        {/* Target List Section */}
                                        {activePrepTab === 'targets' && (
                                            <TargetListSection
                                                targets={targets}
                                                onAddTarget={() => setShowCompanySearch(true)}
                                                onViewTarget={handleViewTarget}
                                                onDeleteTarget={handleDeleteTarget}
                                            />
                                        )}



                                        {/* Email Drafts Section */}
                                        {activePrepTab === 'emails' && (
                                            <EmailDraftsSection
                                                eventId={eventId}
                                                targets={targets}
                                            />
                                        )}
                                    </div>
                                )}

                                {/* Captures Tab */}
                                {activeTab === 'captures' && (
                                    <CapturesSection
                                        eventId={eventId}
                                        captures={captures}
                                        onDeleteCapture={handleDeleteCapture}
                                    />
                                )}

                                {/* Follow-ups Tab */}
                                {activeTab === 'followups' && (
                                    <FollowUpsSection
                                        eventId={eventId}
                                        event={event}
                                        onRefresh={fetchEventData}
                                    />
                                )}
                            </div>
                        </div>
                    </div>
                </div>
            </main>

            {/* Modals */}
            <CompanySearchModal
                isOpen={showCompanySearch}
                onClose={() => setShowCompanySearch(false)}
                onSelect={handleCompanySelect}
                eventId={eventId}
            />

            <TargetCompanyModal
                isOpen={showTargetModal}
                onClose={() => {
                    setShowTargetModal(false);
                    setSelectedCompany(null);
                    setSelectedTarget(null);
                }}
                onSave={handleSaveTarget}
                target={selectedTarget || undefined}
                company={selectedCompany || selectedTarget?.company}
            />

            <Modal
                isOpen={showCaptureModal}
                onClose={() => setShowCaptureModal(false)}
                size="lg"
            >
                {activeCaptureMode && (
                    <CaptureFlow
                        eventId={eventId}
                        mode={activeCaptureMode}
                        onClose={() => setShowCaptureModal(false)}
                        onComplete={handleCaptureComplete}
                    />
                )}
            </Modal>

            <ConfirmDialog
                isOpen={showDeleteConfirm}
                onClose={() => {
                    setShowDeleteConfirm(false);
                    setItemToDelete(null);
                }}
                onConfirm={handleConfirmDelete}
                title={`Delete ${itemToDelete?.type === 'target' ? 'Target Company' : itemToDelete?.type === 'event' ? 'Event' : 'Lead Capture'}?`}
                description={
                    itemToDelete?.type === 'target'
                        ? "Are you sure you want to remove this company from your target list? This action cannot be undone."
                        : itemToDelete?.type === 'event'
                            ? "Are you sure you want to delete this event? This will remove all associated lead captures and target lists. This action cannot be undone."
                            : "Are you sure you want to delete this lead capture? All associated OCR data will be removed."
                }
                confirmText="Delete"
                cancelText="Keep"
                isLoading={isDeleting}
            />

            {/* Edit Event Modal */}
            <Modal
                isOpen={showEditEventModal}
                onClose={() => setShowEditEventModal(false)}
                title="Edit Event Details"
                size="lg"
            >
                <form onSubmit={(e) => {
                    e.preventDefault();
                    const formData = new FormData(e.currentTarget);
                    handleUpdateEvent({
                        name: formData.get('name'),
                        description: formData.get('description'),
                        location: formData.get('location'),
                        start_date: formData.get('start_date'),
                        end_date: formData.get('end_date'),
                        event_type: formData.get('event_type'),
                    });
                }}>
                    <div className="space-y-4">
                        <Input
                            label="Event Name"
                            name="name"
                            required
                            defaultValue={event.name}
                        />

                        <Textarea
                            label="Description"
                            name="description"
                            rows={3}
                            defaultValue={event.description || ''}
                        />

                        <Input
                            label="Location"
                            name="location"
                            defaultValue={event.location || ''}
                        />

                        <div className="grid grid-cols-2 gap-4">
                            <Input
                                label="Start Date"
                                name="start_date"
                                type="date"
                                required
                                defaultValue={event.start_date.split('T')[0]}
                            />
                            <Input
                                label="End Date"
                                name="end_date"
                                type="date"
                                defaultValue={event.end_date?.split('T')[0]}
                            />
                        </div>

                        <Select
                            label="Event Type"
                            name="event_type"
                            defaultValue={event.event_type}
                        >
                            <option value="exhibition">Exhibition</option>
                            <option value="conference">Conference</option>
                            <option value="meeting">Meeting</option>
                        </Select>
                    </div>

                    <div className="modal-footer mt-6 pt-6">
                        <Button type="button" variant="secondary" onClick={() => setShowEditEventModal(false)}>
                            Cancel
                        </Button>
                        <Button type="submit" variant="primary">
                            Save Changes
                        </Button>
                    </div>
                </form>
            </Modal>

            <CompanyDetailModal
                isOpen={showDetailModal}
                onClose={() => setShowDetailModal(false)}
                target={viewingTarget || undefined}
                onEdit={() => viewingTarget && handleEditTarget(viewingTarget)}
            />
        </div>
    );
}
