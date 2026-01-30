import { Button } from '@/components/ui/Button';
import { TargetCompany } from '@/types';
import { Target, MapPin, Trash2 } from 'lucide-react';

interface TargetListSectionProps {
    targets: TargetCompany[];
    onAddTarget: () => void;
    onViewTarget: (target: TargetCompany) => void;
    onDeleteTarget: (targetId: string) => void;
}

export function TargetListSection({
    targets,
    onAddTarget,
    onViewTarget,
    onDeleteTarget
}: TargetListSectionProps) {
    return (
        <div>
            <div className="flex items-center justify-between mb-4">
                <h3 className="text-lg font-semibold">Target Companies</h3>
                <Button size="sm" onClick={onAddTarget}>
                    <Target className="mr-2 h-4 w-4" />
                    Add Target
                </Button>
            </div>

            {targets.length === 0 ? (
                <div className="text-center py-12">
                    <Target className="h-12 w-12 text-gray-400 mx-auto mb-3" />
                    <p className="text-gray-600 mb-4">No target companies yet</p>
                    <Button size="sm" onClick={onAddTarget}>Add First Target</Button>
                </div>
            ) : (
                <div className="space-y-3">
                    {targets.map((target) => (
                        <div
                            key={target.id}
                            className="border border-gray-200 rounded-lg p-4 hover:shadow-md transition-shadow group flex items-start justify-between cursor-pointer hover:border-blue-200"
                            onClick={() => onViewTarget(target)}
                        >
                            <div className="flex-1">
                                <div className="flex items-center gap-3 mb-1">
                                    <h4 className="font-semibold text-gray-900 group-hover:text-blue-600 transition-colors">
                                        {target.company?.name || 'Company Name Missing'}
                                    </h4>
                                    <span
                                        className={`px-2 py-0.5 rounded text-[10px] font-medium uppercase tracking-wider ${target.priority === 'high'
                                            ? 'bg-red-100 text-red-700'
                                            : target.priority === 'medium'
                                                ? 'bg-yellow-100 text-yellow-700'
                                                : 'bg-gray-100 text-gray-700'
                                            }`}
                                    >
                                        {target.priority}
                                    </span>
                                    {target.status === 'contacted' && (
                                        <span className="bg-emerald-100 text-emerald-700 px-2 py-0.5 rounded text-[10px] font-bold uppercase tracking-wider">
                                            Contacted
                                        </span>
                                    )}
                                </div>
                                {target.booth_location && (
                                    <p className="text-sm text-gray-500 flex items-center gap-1">
                                        <MapPin className="h-3 w-3" />
                                        Booth: {target.booth_location}
                                    </p>
                                )}
                            </div>
                            <Button
                                variant="ghost"
                                size="sm"
                                className="text-gray-400 hover:text-red-600 relative z-10"
                                onClick={(e) => {
                                    e.stopPropagation();
                                    onDeleteTarget(target.id);
                                }}
                            >
                                <Trash2 className="h-4 w-4" />
                            </Button>
                        </div>
                    ))}
                </div>
            )}
        </div>
    );
}
