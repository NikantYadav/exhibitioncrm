import { useState, useEffect } from 'react';
import { Event, TargetCompany, Capture, Company } from '@/types';
import { CaptureMode } from '@/components/events/CaptureFlow';
import { CompanyResearchResult } from '@/lib/services/company-research';
import { MarketingAsset } from '@/app/actions/assets';
import { toast } from 'sonner';
import {
    searchCompanyAction,
    addTargetCompany,
    generateEmailDraftAction,
    saveEmailDraftAction
} from '@/app/actions/preparation';
import { getAssets } from '@/app/actions/assets';
import { syncChannel, SyncEventType } from '@/lib/events';

export function useEventDetail(eventId: string) {
    const [event, setEvent] = useState<Event | null>(null);
    const [stats, setStats] = useState({
        targets: 0,
        captures: 0,
        contacts: 0,
        followUps: 0
    });
    const [targets, setTargets] = useState<TargetCompany[]>([]);
    const [captures, setCaptures] = useState<Capture[]>([]);
    const [loading, setLoading] = useState(true);
    const [activeTab, setActiveTab] = useState<'research' | 'captures' | 'followups'>('research');
    const [activePrepTab, setActivePrepTab] = useState<'targets' | 'emails'>('targets');



    // Email Drafter State
    const [selectedEmailTargetId, setSelectedEmailTargetId] = useState<string>('');
    const [contactName, setContactName] = useState('');
    const [emailType, setEmailType] = useState('pre_event');
    const [generatedDraft, setGeneratedDraft] = useState<{ subject: string, body: string } | null>(null);
    const [isGeneratingEmail, setIsGeneratingEmail] = useState(false);
    const [isSavingDraft, setIsSavingDraft] = useState(false);
    const [availableAssets, setAvailableAssets] = useState<MarketingAsset[]>([]);
    const [selectedAssetIds, setSelectedAssetIds] = useState<string[]>([]);

    // Modal States
    const [showCompanySearch, setShowCompanySearch] = useState(false);
    const [showTargetModal, setShowTargetModal] = useState(false);
    const [selectedCompany, setSelectedCompany] = useState<Company | null>(null);
    const [selectedTarget, setSelectedTarget] = useState<TargetCompany | null>(null);
    const [activeCaptureMode, setActiveCaptureMode] = useState<CaptureMode | null>(null);
    const [showCaptureModal, setShowCaptureModal] = useState(false);
    const [showEditEventModal, setShowEditEventModal] = useState(false);
    const [itemToDelete, setItemToDelete] = useState<{ id: string; type: 'target' | 'capture' | 'event' } | null>(null);
    const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);
    const [isDeleting, setIsDeleting] = useState(false);
    const [viewingTarget, setViewingTarget] = useState<TargetCompany | null>(null);
    const [showDetailModal, setShowDetailModal] = useState(false);

    useEffect(() => {
        if (eventId) {
            fetchEventData();
            getAssets().then(setAvailableAssets);

            // Listen for sync events from other components/tabs
            if (syncChannel) {
                const handleMessage = (event: MessageEvent) => {
                    if (event.data.type === SyncEventType.CONTACT_UPDATED && event.data.eventId === eventId) {
                        fetchEventData();
                    }
                };
                syncChannel.addEventListener('message', handleMessage);
                return () => {
                    syncChannel?.removeEventListener('message', handleMessage);
                };
            }
        }
    }, [eventId]);

    const fetchEventData = async () => {
        try {
            const eventRes = await fetch(`/api/events/${eventId}`);
            const eventData = await eventRes.json();
            setEvent(eventData.data);

            const statsRes = await fetch(`/api/events/${eventId}/stats`, { cache: 'no-store' });
            const statsData = await statsRes.json();
            setStats(statsData.data);

            const targetsRes = await fetch(`/api/events/${eventId}/targets`, { cache: 'no-store' });
            const targetsData = await targetsRes.json();
            setTargets(targetsData.data || []);

            const capturesRes = await fetch(`/api/events/${eventId}/captures`, { cache: 'no-store' });
            const capturesData = await capturesRes.json();
            setCaptures(capturesData.data || []);
        } catch (error) {
            console.error('Error fetching event data:', error);
            toast.error('Failed to load event data');
        } finally {
            setLoading(false);
        }
    };

    const handleCompanySelect = async (company: Company) => {
        setSelectedCompany(company);
        setShowCompanySearch(false);
        setShowTargetModal(true);
    };

    const handleSaveTarget = async (targetData: any) => {
        try {
            const body = selectedTarget
                ? { ...targetData, id: selectedTarget.id }
                : { ...targetData, company_id: selectedCompany?.id };

            const url = selectedTarget
                ? `/api/events/${eventId}/targets/${selectedTarget.id}`
                : `/api/events/${eventId}/targets`;

            const response = await fetch(url, {
                method: selectedTarget ? 'PUT' : 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(body)
            });

            if (!response.ok) throw new Error('Failed to save target');

            toast.success(selectedTarget ? 'Target updated successfully' : 'Target added successfully');
            setShowTargetModal(false);
            setSelectedCompany(null);
            setSelectedTarget(null);
            fetchEventData();
        } catch (error) {
            console.error('Error saving target:', error);
            toast.error('Failed to save target');
        }
    };

    const handleEditTarget = (target: TargetCompany) => {
        setSelectedTarget(target);
        setSelectedCompany(target.company || null);
        setShowDetailModal(false);
        setShowTargetModal(true);
    };

    const handleDeleteTarget = (targetId: string) => {
        setItemToDelete({ id: targetId, type: 'target' });
        setShowDeleteConfirm(true);
    };

    const handleDeleteCapture = (e: React.MouseEvent, captureId: string) => {
        e.stopPropagation();
        setItemToDelete({ id: captureId, type: 'capture' });
        setShowDeleteConfirm(true);
    };

    const handleConfirmDelete = async () => {
        if (!itemToDelete) return;

        setIsDeleting(true);
        try {
            let endpoint = '';
            if (itemToDelete.type === 'target') {
                endpoint = `/api/events/${eventId}/targets/${itemToDelete.id}`;
            } else if (itemToDelete.type === 'capture') {
                endpoint = `/api/captures/${itemToDelete.id}`;
            } else if (itemToDelete.type === 'event') {
                endpoint = `/api/events/${itemToDelete.id}`;
            }

            const response = await fetch(endpoint, { method: 'DELETE' });

            if (!response.ok) throw new Error('Failed to delete');

            toast.success(`${itemToDelete.type.charAt(0).toUpperCase() + itemToDelete.type.slice(1)} deleted successfully`);

            if (itemToDelete.type === 'event') {
                window.location.href = '/events';
                return;
            }

            fetchEventData();
        } catch (error) {
            console.error('Error deleting:', error);
            toast.error('Failed to delete');
        } finally {
            setIsDeleting(false);
            setShowDeleteConfirm(false);
            setItemToDelete(null);
        }
    };

    const handleDeleteEvent = () => {
        setItemToDelete({ id: eventId, type: 'event' });
        setShowDeleteConfirm(true);
    };

    const handleUpdateEvent = async (eventData: any) => {
        try {
            const response = await fetch(`/api/events/${eventId}`, {
                method: 'PUT',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(eventData)
            });

            if (!response.ok) throw new Error('Failed to update event');

            toast.success('Event updated successfully');
            setShowEditEventModal(false);
            fetchEventData();
        } catch (error) {
            console.error('Error updating event:', error);
            toast.error('Failed to update event');
        }
    };

    const handleExportData = () => {
        if (!captures.length) {
            toast.error('No data to export');
            return;
        }

        try {
            const headers = ['Name', 'Email', 'Phone', 'Job Title', 'Company', 'Captured At'];
            const csvRows = captures.map(c => [
                `${c.contact?.first_name || ''} ${c.contact?.last_name || ''}`.trim(),
                c.contact?.email || '',
                c.contact?.phone || '',
                c.contact?.job_title || '',
                c.contact?.company?.name || '',
                new Date(c.created_at).toLocaleString()
            ].map(val => `"${val.replace(/"/g, '""')}"`).join(','));

            const csvContent = [headers.join(','), ...csvRows].join('\n');
            const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
            const url = URL.createObjectURL(blob);
            const link = document.createElement('a');
            link.setAttribute('href', url);
            link.setAttribute('download', `${event?.name || 'event'}_leads.csv`);
            link.style.visibility = 'hidden';
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);
            toast.success('Data exported successfully');
        } catch (error) {
            console.error('Error exporting data:', error);
            toast.error('Failed to export data');
        }
    };

    const handleOpenCapture = (mode: CaptureMode) => {
        setActiveCaptureMode(mode);
        setShowCaptureModal(true);
    };

    const handleCaptureComplete = () => {
        setShowCaptureModal(false);
        setActiveCaptureMode(null);
        fetchEventData();
    };

    const handleViewTarget = (target: TargetCompany) => {
        setViewingTarget(target);
        setShowDetailModal(true);
    };



    return {
        // State
        event,
        stats,
        targets,
        captures,
        loading,
        activeTab,
        setActiveTab,
        activePrepTab,
        setActivePrepTab,



        // Email
        selectedEmailTargetId,
        setSelectedEmailTargetId,
        contactName,
        setContactName,
        emailType,
        setEmailType,
        generatedDraft,
        setGeneratedDraft,
        isGeneratingEmail,
        setIsGeneratingEmail,
        isSavingDraft,
        setIsSavingDraft,
        availableAssets,
        selectedAssetIds,
        setSelectedAssetIds,

        // Modals
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
        showEditEventModal,
        setShowEditEventModal,
        itemToDelete,
        setItemToDelete,
        showDeleteConfirm,
        setShowDeleteConfirm,
        isDeleting,
        viewingTarget,
        setViewingTarget,
        showDetailModal,
        setShowDetailModal,

        // Handlers
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
        fetchEventData
    };
}
