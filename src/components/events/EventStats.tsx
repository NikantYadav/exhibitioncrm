import { Target, Camera, Users, Mail } from 'lucide-react';

interface EventStatsProps {
    stats: {
        targets: number;
        captures: number;
        contacts: number;
        followUps: number;
        needsFollowup?: number;
        notContacted?: number;
    };
}

export function EventStats({ stats }: EventStatsProps) {
    const total = stats.contacts || 0;
    const progress = total > 0 ? Math.round((stats.followUps / total) * 100) : 0;

    const statItems = [
        {
            label: 'Strategic Targets',
            value: stats.targets,
            icon: Target,
        },
        {
            label: 'Intelligence Captures',
            value: stats.captures,
            icon: Camera,
        },
        {
            label: 'Net Contacts',
            value: stats.contacts,
            icon: Users,
        }
    ];

    return (
        <div className="space-y-6">
            <div className="grid grid-cols-1 sm:grid-cols-3 gap-6">
                {statItems.map((item) => {
                    const Icon = item.icon;
                    return (
                        <div
                            key={item.label}
                            className="bg-white rounded-[2rem] border border-stone-100 p-6 shadow-sm hover:border-stone-200 transition-all duration-300 group"
                        >
                            <div className="flex items-center gap-5">
                                <div className="bg-stone-900 text-white p-3.5 rounded-2xl shadow-xl shadow-stone-900/10">
                                    <Icon className="h-5 w-5" strokeWidth={3} />
                                </div>
                                <div className="space-y-0.5">
                                    <p className="text-3xl font-black text-stone-900 tracking-tighter leading-none">
                                        {item.value}
                                    </p>
                                    <p className="text-[10px] font-black text-stone-400 uppercase tracking-widest">
                                        {item.label}
                                    </p>
                                </div>
                            </div>
                        </div>
                    );
                })}
            </div>

            {total > 0 && (
                <div className="bg-white rounded-[2.5rem] border border-stone-100 p-8 shadow-sm hover:border-stone-200 transition-all duration-300">
                    <div className="flex items-center justify-between mb-5">
                        <span className="text-[10px] font-black text-stone-400 uppercase tracking-widest">Reach Velocity</span>
                        <span className="text-xl font-black text-stone-900 tracking-tighter">{Math.round((stats.followUps / total) * 100)}%</span>
                    </div>
                    <div className="w-full h-3 bg-stone-50 rounded-full overflow-hidden flex border border-stone-100/50 shadow-inner">
                        <div
                            style={{ width: `${(stats.followUps / total) * 100}%` }}
                            className="bg-stone-900 h-full transition-all duration-1000 origin-left"
                        />
                        <div
                            style={{ width: `${((stats.needsFollowup || 0) / total) * 100}%` }}
                            className="bg-stone-400 h-full transition-all duration-1000 origin-left"
                        />
                    </div>
                    <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 mt-6">
                        <div className="flex items-center gap-2.5 p-3 rounded-xl bg-stone-50/50 border border-stone-100">
                            <div className="w-2 h-2 rounded-full bg-stone-900" />
                            <span className="text-[9px] font-black text-stone-900 uppercase tracking-widest">Completed ({stats.followUps})</span>
                        </div>
                        <div className="flex items-center gap-2.5 p-3 rounded-xl bg-stone-50/50 border border-stone-100">
                            <div className="w-2 h-2 rounded-full bg-stone-400" />
                            <span className="text-[9px] font-black text-stone-900 uppercase tracking-widest">Pending ({stats.needsFollowup || 0})</span>
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
}
