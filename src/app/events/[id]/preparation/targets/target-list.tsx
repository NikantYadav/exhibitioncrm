'use client';

import { useState } from 'react';
import { TargetCompany } from '@/types';
import { updateTargetPriority, deleteTarget, generateTalkingPointsAction, saveTalkingPoints } from '@/app/actions/preparation';
import { Loader2, Trash2, Mic, ChevronDown, ChevronUp, GripVertical, AlertCircle } from 'lucide-react';

interface TargetListProps {
    initialTargets: any[];
    eventId: string;
}

import { toast } from 'sonner';

export default function TargetList({ initialTargets, eventId }: TargetListProps) {
    const [targets, setTargets] = useState(initialTargets);
    const [loadingIds, setLoadingIds] = useState<Set<string>>(new Set());
    const [expandedIds, setExpandedIds] = useState<Set<string>>(new Set());

    const handlePriorityChange = async (targetId: string, newPriority: 'low' | 'medium' | 'high') => {
        // Optimistic update
        setTargets(targets.map(t => t.id === targetId ? { ...t, priority: newPriority } : t));

        const result = await updateTargetPriority(targetId, newPriority);
        if (result.error) {
            toast.error('Failed to update priority');
        } else {
            toast.success('Priority updated');
        }
    };

    const handleDelete = async (targetId: string) => {
        // We'll keep confirm() for destructive actions for now as it's a standard pattern, 
        // but replacing with a custom modal is better. For now, alerts are the main priority.
        if (!confirm('Are you sure you want to remove this company from your target list?')) return;

        setTargets(targets.filter(t => t.id !== targetId));
        const result = await deleteTarget(targetId);
        if (result.success) {
            toast.success('Target removed');
        }
    };

    const handleGenerateTalkingPoints = async (target: any) => {
        const targetId = target.id;
        setLoadingIds(prev => new Set(prev).add(targetId));
        const genToast = toast.loading(`Generating talking points for ${target.company.name}...`);

        // Prepare company data for AI
        const companyData = {
            name: target.company.name,
            industry: target.company.industry,
            description: target.company.description,
            products_services: target.company.products_services
        };

        const result = await generateTalkingPointsAction(companyData);

        if (result.points) {
            const saveResult = await saveTalkingPoints(targetId, result.points);
            if (saveResult.success) {
                setTargets(targets.map(t => t.id === targetId ? { ...t, talking_points: result.points.map((p: string) => `- ${p}`).join('\n') } : t));
                // Auto-expand to show points
                setExpandedIds(prev => new Set(prev).add(targetId));
                toast.success('Talking points generated!', { id: genToast });
            } else {
                toast.error('Failed to save talking points', { id: genToast });
            }
        } else {
            toast.error('Failed to generate talking points', { id: genToast });
        }

        setLoadingIds(prev => {
            const next = new Set(prev);
            next.delete(targetId);
            return next;
        });
    };

    const toggleExpand = (id: string) => {
        setExpandedIds(prev => {
            const next = new Set(prev);
            if (next.has(id)) next.delete(id);
            else next.add(id);
            return next;
        });
    };

    // Group targets by priority for display
    const high = targets.filter(t => t.priority === 'high');
    const medium = targets.filter(t => t.priority === 'medium');
    const low = targets.filter(t => t.priority === 'low');

    return (
        <div className="space-y-8">
            <PrioritySection title="High Priority" items={high} color="red" actions={{ handlePriorityChange, handleDelete, handleGenerateTalkingPoints, toggleExpand }} loadingIds={loadingIds} expandedIds={expandedIds} />
            <PrioritySection title="Medium Priority" items={medium} color="yellow" actions={{ handlePriorityChange, handleDelete, handleGenerateTalkingPoints, toggleExpand }} loadingIds={loadingIds} expandedIds={expandedIds} />
            <PrioritySection title="Low Priority" items={low} color="blue" actions={{ handlePriorityChange, handleDelete, handleGenerateTalkingPoints, toggleExpand }} loadingIds={loadingIds} expandedIds={expandedIds} />

            {targets.length === 0 && (
                <div className="text-center py-12 text-gray-500 bg-white rounded-lg border border-dashed border-gray-300">
                    <p>No target companies yet.</p>
                    <p className="text-sm">Go to the Research tab to find and add companies.</p>
                </div>
            )}
        </div>
    );
}

function PrioritySection({ title, items, color, actions, loadingIds, expandedIds }: any) {
    if (items.length === 0) return null;

    const colorClasses = {
        red: 'bg-red-50 text-red-700 border-red-200',
        yellow: 'bg-yellow-50 text-yellow-700 border-yellow-200',
        blue: 'bg-blue-50 text-blue-700 border-blue-200'
    };

    return (
        <section>
            <h3 className={`font-semibold mb-3 px-3 py-1 inline-block rounded-full text-sm border ${colorClasses[color as keyof typeof colorClasses]}`}>
                {title} ({items.length})
            </h3>
            <div className="space-y-3">
                {items.map((target: any) => (
                    <TargetCard
                        key={target.id}
                        target={target}
                        actions={actions}
                        isLoading={loadingIds.has(target.id)}
                        isExpanded={expandedIds.has(target.id)}
                    />
                ))}
            </div>
        </section>
    );
}

function TargetCard({ target, actions, isLoading, isExpanded }: any) {
    const { company } = target;

    return (
        <div className="bg-white border border-gray-200 rounded-lg shadow-sm hover:shadow-md transition-shadow">
            <div className="p-4 flex items-center justify-between">
                <div className="flex items-center gap-3 flex-1">
                    <div className="h-10 w-10 bg-gray-100 rounded-lg flex items-center justify-center text-gray-500 font-bold">
                        {company.name.substring(0, 2).toUpperCase()}
                    </div>
                    <div>
                        <h4 className="font-medium text-gray-900">{company.name}</h4>
                        <div className="text-xs text-gray-500 flex gap-2">
                            <span>{company.industry || 'No industry'}</span>
                            {company.location && <span>• {company.location}</span>}
                        </div>
                    </div>
                </div>

                <div className="flex items-center gap-2">
                    <select
                        value={target.priority}
                        onChange={(e) => actions.handlePriorityChange(target.id, e.target.value as any)}
                        className="text-xs border-gray-300 rounded-md shadow-sm focus:border-blue-500 focus:ring-blue-500"
                    >
                        <option value="high">High</option>
                        <option value="medium">Medium</option>
                        <option value="low">Low</option>
                    </select>

                    <button
                        onClick={() => actions.toggleExpand(target.id)}
                        className="p-2 text-gray-400 hover:text-gray-600 rounded-full hover:bg-gray-50"
                    >
                        {isExpanded ? <ChevronUp className="h-4 w-4" /> : <ChevronDown className="h-4 w-4" />}
                    </button>

                    <button
                        onClick={() => actions.handleDelete(target.id)}
                        className="p-2 text-gray-400 hover:text-red-500 rounded-full hover:bg-gray-50"
                    >
                        <Trash2 className="h-4 w-4" />
                    </button>
                </div>
            </div>

            {isExpanded && (
                <div className="border-t border-gray-100 p-4 bg-gray-50/50 rounded-b-lg space-y-4">
                    <div>
                        <div className="flex items-center justify-between mb-2">
                            <h5 className="text-xs font-semibold text-gray-500 uppercase tracking-wider">Talking Points</h5>
                            <button
                                onClick={() => actions.handleGenerateTalkingPoints(target)}
                                disabled={isLoading}
                                className="text-xs flex items-center text-blue-600 hover:text-blue-700 disabled:opacity-50"
                            >
                                {isLoading ? <Loader2 className="h-3 w-3 animate-spin mr-1" /> : <Mic className="h-3 w-3 mr-1" />}
                                {target.talking_points ? 'Regenerate with AI' : 'Generate with AI'}
                            </button>
                        </div>

                        {target.talking_points ? (
                            <div className="bg-white p-3 rounded border border-gray-200 text-sm text-gray-700 whitespace-pre-wrap">
                                {target.talking_points}
                            </div>
                        ) : (
                            <div className="text-sm text-gray-500 italic flex items-center gap-2">
                                <AlertCircle className="h-4 w-4" />
                                No talking points generated yet.
                            </div>
                        )}
                    </div>

                    <div>
                        <h5 className="text-xs font-semibold text-gray-500 uppercase tracking-wider mb-2">Notes</h5>
                        {/* Notes editing could be added here, currently just display or use generic notes field from previous schema */}
                        <p className="text-sm text-gray-700">{target.notes || 'No notes.'}</p>
                    </div>
                </div>
            )}
        </div>
    );
}
