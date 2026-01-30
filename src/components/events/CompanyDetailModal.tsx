'use client';

import { Modal } from '@/components/ui/Modal';
import { Button } from '@/components/ui/Button';
import { TargetCompany, Company } from '@/types';
import {
    Globe,
    MapPin,
    Building2,
    Target,
    MessageSquare,
    Lightbulb,
    ExternalLink,
    Briefcase,
    Calendar,
    Edit
} from 'lucide-react';

interface CompanyDetailModalProps {
    isOpen: boolean;
    onClose: () => void;
    target?: TargetCompany;
    company?: Company; // For companies not yet added as targets (e.g. search results)
    onEdit?: () => void;
}

export function CompanyDetailModal({ isOpen, onClose, target, company, onEdit }: CompanyDetailModalProps) {
    const activeCompany = target?.company || company;
    if (!activeCompany) return null;

    return (
        <Modal
            isOpen={isOpen}
            onClose={onClose}
            size="xl"
            title={activeCompany.name}
            headerActions={
                <div className="flex items-center gap-2">
                    {onEdit && (
                        <Button size="sm" onClick={onEdit} className="h-8 py-0">
                            <Edit className="h-3.5 w-3.5 mr-1.5" />
                            Edit Details
                        </Button>
                    )}
                    <Button variant="outline" size="sm" onClick={onClose} className="h-8 py-0">
                        Close
                    </Button>
                </div>
            }
        >
            <div className="space-y-8 py-2">
                {/* Header Info */}
                <div className="flex flex-wrap gap-4 items-center text-sm text-stone-500 border-b border-stone-100 pb-6">
                    {activeCompany.website && (
                        <a
                            href={activeCompany.website.startsWith('http')
                                ? activeCompany.website
                                : `https://www.${activeCompany.website.replace(/^www\./, '')}`}
                            target="_blank"
                            rel="noopener noreferrer"
                            className="flex items-center gap-1.5 hover:text-blue-600 transition-colors bg-blue-50 text-blue-700 px-3 py-1.5 rounded-full font-medium"
                        >
                            <Globe className="h-4 w-4" />
                            www.{activeCompany.website.replace(/^https?:\/\/(www\.)?/, '').replace(/\/$/, '')}
                            <ExternalLink className="h-3 w-3" />
                        </a>
                    )}
                    {activeCompany.industry && (
                        <div className="flex items-center gap-1.5 bg-stone-100 px-3 py-1.5 rounded-full font-medium text-stone-700">
                            <Building2 className="h-4 w-4" />
                            {activeCompany.industry}
                        </div>
                    )}
                    {activeCompany.location && (
                        <div className="flex items-center gap-1.5 bg-stone-100 px-3 py-1.5 rounded-full font-medium text-stone-700">
                            <MapPin className="h-4 w-4" />
                            {activeCompany.location}
                        </div>
                    )}
                </div>

                <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
                    {/* Left Column: Business Info */}
                    <div className="space-y-6">
                        {/* Company Overview */}
                        <div>
                            <h3 className="text-xs font-bold text-stone-400 uppercase tracking-widest mb-3 flex items-center gap-2">
                                <Briefcase className="h-4 w-4 text-stone-300" />
                                Business Overview
                            </h3>
                            <p className="text-stone-700 leading-relaxed text-sm bg-stone-50/50 p-4 rounded-2xl border border-stone-100">
                                {activeCompany.description || 'No detailed overview available.'}
                            </p>
                        </div>

                        {/* Products & Services */}
                        {activeCompany.products_services && (
                            <div>
                                <h3 className="text-xs font-bold text-stone-400 uppercase tracking-widest mb-3 flex items-center gap-2">
                                    <Target className="h-4 w-4 text-stone-300" />
                                    Products & Services
                                </h3>
                                <div className="text-stone-700 text-sm bg-stone-50/50 p-4 rounded-2xl border border-stone-100">
                                    {activeCompany.products_services}
                                </div>
                            </div>
                        )}
                    </div>

                    {/* Right Column: Event Specific Info */}
                    <div className="space-y-6">
                        {target ? (
                            <>
                                {/* Target Status & Priority */}
                                <div className="grid grid-cols-2 gap-4">
                                    <div className="bg-white p-4 rounded-2xl border border-stone-200">
                                        <h4 className="text-[10px] font-bold text-stone-400 uppercase tracking-widest mb-1">Priority</h4>
                                        <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${target.priority === 'high' ? 'bg-red-100 text-red-700' :
                                            target.priority === 'medium' ? 'bg-yellow-100 text-yellow-700' : 'bg-gray-100 text-gray-700'
                                            }`}>
                                            {target.priority.charAt(0).toUpperCase() + target.priority.slice(1)}
                                        </span>
                                    </div>
                                    <div className="bg-white p-4 rounded-2xl border border-stone-200">
                                        <h4 className="text-[10px] font-bold text-stone-400 uppercase tracking-widest mb-1">Booth Location</h4>
                                        <div className="flex items-center gap-2 text-stone-700 font-medium">
                                            <MapPin className="h-3 w-3 text-stone-400" />
                                            {target.booth_location || 'Not Specified'}
                                        </div>
                                    </div>
                                </div>

                                {/* Talking Points */}
                                <div>
                                    <h3 className="text-xs font-bold text-stone-400 uppercase tracking-widest mb-3 flex items-center gap-2">
                                        <MessageSquare className="h-4 w-4 text-stone-300" />
                                        Meeting Talking Points
                                    </h3>
                                    <div className="text-stone-700 text-sm bg-blue-50/30 p-4 rounded-2xl border border-blue-100/50 min-h-[100px] whitespace-pre-line">
                                        {target.talking_points || 'No talking points defined yet.'}
                                    </div>
                                </div>

                                {/* Notes / AI Insights */}
                                {target.notes && (
                                    <div>
                                        <h3 className="text-xs font-bold text-stone-400 uppercase tracking-widest mb-3 flex items-center gap-2">
                                            <Lightbulb className="h-4 w-4 text-stone-300" />
                                            Additional Notes & Insights
                                        </h3>
                                        <div className="text-stone-700 text-sm bg-stone-50/50 p-4 rounded-2xl border border-stone-100 whitespace-pre-line">
                                            {target.notes}
                                        </div>
                                    </div>
                                )}
                            </>
                        ) : (
                            <div className="h-full flex flex-col items-center justify-center p-8 border-2 border-dashed border-stone-200 rounded-2xl text-center">
                                <Calendar className="h-8 w-8 text-stone-300 mb-3" />
                                <p className="text-sm text-stone-500">
                                    This company hasn't been added to your target list for this event yet.
                                </p>
                            </div>
                        )}
                    </div>
                </div>
            </div>
        </Modal>
    );
}
