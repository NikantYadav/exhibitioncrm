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
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-6 mb-10">
                <div>
                    <h3 className="text-2xl font-black text-stone-900 tracking-tighter leading-tight">Targets</h3>
                    <p className="text-[10px] text-stone-400 font-black uppercase tracking-[0.2em] mt-1">Companies identified for this event.</p>
                </div>
                <Button
                    onClick={onAddTarget}
                    className="h-11 px-6 bg-stone-900 hover:bg-stone-800 text-white rounded-xl shadow-xl shadow-stone-900/10 font-black uppercase tracking-widest text-[10px] transition-all"
                >
                    <Target className="mr-2 h-4 w-4" strokeWidth={3} />
                    Add Target
                </Button>
            </div>

            {targets.length === 0 ? (
                <div className="bg-stone-50 rounded-[3rem] border border-stone-100 border-dashed p-20 text-center">
                    <div className="p-6 bg-stone-900 rounded-[2rem] w-fit mx-auto mb-8 text-white shadow-2xl shadow-stone-900/20">
                        <Target className="h-10 w-10" strokeWidth={3} />
                    </div>
                    <h4 className="text-2xl font-black text-stone-900 tracking-tight mb-3">No Targets Defined</h4>
                    <p className="text-stone-500 text-xs font-medium mb-10 max-w-[280px] mx-auto leading-relaxed">Select companies to target before the event starts.</p>
                    <Button
                        size="lg"
                        className="h-12 px-8 bg-stone-900 hover:bg-stone-800 text-white rounded-xl font-black uppercase tracking-widest text-[10px] shadow-xl shadow-stone-900/20 transition-all"
                        onClick={onAddTarget}
                    >
                        Add First Target
                    </Button>
                </div>
            ) : (
                <div className="grid gap-4">
                    {targets.map((target) => (
                        <div
                            key={target.id}
                            className="bg-white rounded-[2rem] border border-stone-100 p-6 shadow-sm hover:border-stone-200 transition-all group flex items-center justify-between cursor-pointer"
                            onClick={() => onViewTarget(target)}
                        >
                            <div className="flex items-center gap-6 flex-1 min-w-0">
                                <div className="h-14 w-14 rounded-2xl bg-stone-900 flex items-center justify-center text-white font-black text-xl shadow-lg shadow-stone-900/10">
                                    {target.company?.name?.[0] || 'T'}
                                </div>
                                <div className="flex-1 min-w-0">
                                    <div className="flex items-center gap-3 mb-2 overflow-hidden">
                                        <h4 className="text-xl font-black text-stone-900 truncate tracking-tight">
                                            {target.company?.name || 'Company Name'}
                                        </h4>
                                        <div className="flex gap-2 shrink-0">
                                            <span
                                                className={`px-3 py-1 rounded-lg text-[9px] font-black uppercase tracking-widest border ${target.priority === 'high'
                                                    ? 'bg-stone-900 text-white border-stone-900'
                                                    : target.priority === 'medium'
                                                        ? 'bg-stone-400 text-white border-stone-400'
                                                        : 'bg-stone-50 text-stone-400 border-stone-100'
                                                    }`}
                                            >
                                                {target.priority}
                                            </span>
                                            {target.status === 'contacted' && (
                                                <span className="bg-stone-50 text-stone-900 border border-stone-200 px-3 py-1 rounded-lg text-[9px] font-black uppercase tracking-widest">
                                                    Engaged
                                                </span>
                                            )}
                                        </div>
                                    </div>
                                    {target.booth_location && (
                                        <div className="flex items-center gap-4">
                                            <p className="text-[10px] font-black text-stone-400 flex items-center gap-2 uppercase tracking-widest">
                                                <MapPin className="h-3 w-3 text-stone-900" strokeWidth={3} />
                                                Location: <span className="text-stone-900">{target.booth_location}</span>
                                            </p>
                                        </div>
                                    )}
                                </div>
                            </div>
                            <Button
                                variant="ghost"
                                className="h-12 w-12 p-0 text-stone-200 hover:text-red-600 hover:bg-red-50 transition-all rounded-2xl ml-4"
                                onClick={(e) => {
                                    e.stopPropagation();
                                    onDeleteTarget(target.id);
                                }}
                            >
                                <Trash2 className="h-5 w-5" strokeWidth={3} />
                            </Button>
                        </div>
                    ))}
                </div>
            )}
        </div>
    );
}
