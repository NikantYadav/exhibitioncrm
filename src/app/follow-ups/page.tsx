'use client';

import { useState } from 'react';
import { AppShell } from '@/components/layout/AppShell';
import { Button } from '@/components/ui/Button';
import { Card, CardContent } from '@/components/ui/Card';
import { Clock, CheckCircle, XCircle, Mail, Phone, Calendar, ArrowRight } from 'lucide-react';
import Link from 'next/link';

// Mock data, replaced by real data fetch in production
const statuses = [
    { id: 'needs_follow_up', label: 'Needs Follow-Up', color: 'bg-yellow-100 text-yellow-800', icon: Clock },
    { id: 'followed_up', label: 'Followed Up', color: 'bg-green-100 text-green-800', icon: CheckCircle },
    { id: 'not_contacted', label: 'Not Contacted', color: 'bg-gray-100 text-gray-800', icon: XCircle },
];

export default function FollowUpDashboard() {
    const [filter, setFilter] = useState('needs_follow_up');

    return (
        <AppShell>
            <div className="max-w-7xl mx-auto">
                <div className="flex justify-between items-center mb-8">
                    <div>
                        <h1 className="text-display mb-2">Follow-Up Dashboard</h1>
                        <p className="text-body">Track and manage your post-exhibition connections</p>
                    </div>
                </div>

                {/* Status Stats */}
                <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
                    {statuses.map(status => (
                        <Card key={status.id} className="cursor-pointer hover:shadow-md transition-shadow" onClick={() => setFilter(status.id)}>
                            <CardContent className="p-6 flex items-center justify-between">
                                <div>
                                    <p className="text-sm font-medium text-gray-500 mb-1">{status.label}</p>
                                    <h3 className="text-3xl font-bold text-gray-900">0</h3>
                                </div>
                                <div className={`p-3 rounded-full ${status.color}`}>
                                    <status.icon className="h-6 w-6" />
                                </div>
                            </CardContent>
                        </Card>
                    ))}
                </div>

                {/* Kanban/List View */}
                <div className="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden">
                    <div className="p-6 border-b border-gray-100 flex justify-between items-center">
                        <h2 className="text-lg font-semibold text-gray-900">
                            {statuses.find(s => s.id === filter)?.label} Contacts
                        </h2>
                        <div className="flex gap-2">
                            {/* Filters could go here */}
                        </div>
                    </div>

                    {/* Empty State designed for MVP */}
                    <div className="p-12 text-center">
                        <div className="w-16 h-16 bg-gray-100 rounded-full flex items-center justify-center mx-auto mb-4">
                            <Clock className="h-8 w-8 text-gray-400" />
                        </div>
                        <h3 className="text-lg font-medium text-gray-900 mb-2">No pending follow-ups</h3>
                        <p className="text-gray-500 mb-6 max-w-sm mx-auto">
                            Great job! You're all caught up on your interactions for this category.
                        </p>
                        <Link href="/contacts">
                            <Button variant="outline">View All Contacts</Button>
                        </Link>
                    </div>
                </div>
            </div>
        </AppShell>
    );
}
