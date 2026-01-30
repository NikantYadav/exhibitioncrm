'use client';

import { useState, useEffect } from 'react';
import { FollowUpKanban } from '@/components/follow-ups/FollowUpKanban';
import { EmailComposer } from '@/components/follow-ups/EmailComposer';
import { Loader2, Mail } from 'lucide-react';
import { toast } from 'sonner';
import { syncChannel, emitSyncEvent, SyncEventType } from '@/lib/events';

interface FollowUpsSectionProps {
    eventId: string;
    event?: any;
    onRefresh?: () => void;
}

export function FollowUpsSection({ eventId, event, onRefresh }: FollowUpsSectionProps) {
    const [loading, setLoading] = useState(true);
    const [followUpData, setFollowUpData] = useState<any>(null);
    const [selectedContact, setSelectedContact] = useState<any>(null);
    const [isEmailOpen, setIsEmailOpen] = useState(false);

    useEffect(() => {
        fetchFollowUps();

        // Listen for sync events from other tabs/pages
        if (syncChannel) {
            const handleMessage = (event: MessageEvent) => {
                if (event.data.type === SyncEventType.CONTACT_UPDATED) {
                    // Only refresh if we're not the source of the update
                    // or if it's a cross-tab update
                    fetchFollowUps();
                }
            };
            syncChannel.addEventListener('message', handleMessage);
            return () => {
                syncChannel?.removeEventListener('message', handleMessage);
            };
        }
    }, [eventId]);

    const fetchFollowUps = async () => {
        try {
            const response = await fetch(`/api/follow-ups?event_id=${eventId}`);
            const data = await response.json();
            setFollowUpData(data.data);
        } catch (error) {
            console.error('Failed to fetch follow-ups:', error);
            toast.error('Failed to load follow-ups');
        } finally {
            setLoading(false);
        }
    };

    const handleContactMove = async (contactId: string, newStatus: string) => {
        try {
            // Optimistic UI update
            const updatedData = { ...followUpData };
            // Remove contact from all columns
            Object.keys(updatedData).forEach(key => {
                updatedData[key] = updatedData[key].filter((c: any) => c.id !== contactId);
            });

            // Find the contact to move
            let contactToMove: any = null;
            Object.values(followUpData).forEach((list: any) => {
                const found = list.find((c: any) => c.id === contactId);
                if (found) contactToMove = found;
            });

            if (contactToMove) {
                // Add to new column
                if (!updatedData[newStatus]) updatedData[newStatus] = [];
                updatedData[newStatus].push({ ...contactToMove, follow_up_status: newStatus });
                setFollowUpData(updatedData);

                // Update DB
                const response = await fetch(`/api/contacts/${contactId}`, {
                    method: 'PUT',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ follow_up_status: newStatus })
                });

                if (!response.ok) throw new Error('Failed to update status');
                toast.success('Status updated');

                // Notify other components/tabs
                emitSyncEvent(SyncEventType.CONTACT_UPDATED, { contactId, newStatus, eventId });

                if (onRefresh) onRefresh();
            }
        } catch (error) {
            console.error('Failed to move contact:', error);
            toast.error('Failed to update status');
            fetchFollowUps(); // Revert on failure
        }
    };

    const handleEmailContact = (contact: any) => {
        setSelectedContact(contact);
        setIsEmailOpen(true);
    };

    if (loading) {
        return (
            <div className="flex items-center justify-center py-24">
                <Loader2 className="h-8 w-8 animate-spin text-stone-200" />
            </div>
        );
    }

    if (!followUpData) return null;

    const columns = [
        {
            id: 'not_contacted',
            title: 'Not Contacted',
            contacts: followUpData.not_contacted || [],
            color: 'bg-stone-50 border-stone-200'
        },
        {
            id: 'needs_followup',
            title: 'Needs Follow-up',
            contacts: followUpData.needs_followup || [],
            color: 'bg-amber-50 border-amber-200'
        },
        {
            id: 'followed_up',
            title: 'Followed Up',
            contacts: followUpData.followed_up || [],
            color: 'bg-emerald-50 border-emerald-200'
        }
    ];

    return (
        <div className="space-y-6">
            <div className="flex items-center justify-between">
                <h3 className="text-lg font-semibold text-stone-900 flex items-center gap-2">
                    <Mail className="h-5 w-5 text-stone-400" />
                    Follow-up Tracker
                </h3>
                <p className="text-sm text-stone-500">

                </p>
            </div>

            <FollowUpKanban
                columns={columns}
                onContactMove={handleContactMove}
                onEmailContact={handleEmailContact}
            />

            {selectedContact && (
                <EmailComposer
                    isOpen={isEmailOpen}
                    onClose={() => setIsEmailOpen(false)}
                    contact={selectedContact}
                    event={event}
                />
            )}
        </div>
    );
}
