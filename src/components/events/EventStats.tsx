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
            label: 'Target Companies',
            value: stats.targets,
            icon: Target,
            color: 'text-blue-600',
            bgColor: 'bg-blue-50'
        },
        {
            label: 'Captures',
            value: stats.captures,
            icon: Camera,
            color: 'text-purple-600',
            bgColor: 'bg-purple-50'
        },
        {
            label: 'Contacts Made',
            value: stats.contacts,
            icon: Users,
            color: 'text-green-600',
            bgColor: 'bg-green-50'
        },
        {
            label: 'Follow-ups Sent',
            value: stats.followUps,
            icon: Mail,
            color: 'text-amber-600',
            bgColor: 'bg-amber-50'
        }
    ];

    return (
        <div className="space-y-4">
            <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                {statItems.map((item) => {
                    const Icon = item.icon;
                    return (
                        <div
                            key={item.label}
                            className="bg-white rounded-lg border border-gray-200 p-4 hover:shadow-md transition-shadow"
                        >
                            <div className="flex items-center gap-3">
                                <div className={`${item.bgColor} ${item.color} p-2 rounded-lg`}>
                                    <Icon className="h-5 w-5" />
                                </div>
                                <div>
                                    <p className="text-2xl font-bold text-gray-900">
                                        {item.value}
                                    </p>
                                    <p className="text-xs text-gray-600 mt-0.5">
                                        {item.label}
                                    </p>
                                </div>
                            </div>
                        </div>
                    );
                })}
            </div>

            {total > 0 && (
                <div className="bg-white rounded-lg border border-gray-200 p-4">
                    <div className="flex items-center justify-between mb-2">
                        <span className="text-sm font-medium text-gray-700 font-outfit">Follow-up Progress</span>
                        <span className="text-sm font-bold text-indigo-600">{progress}%</span>
                    </div>
                    <div className="w-full h-2 bg-gray-100 rounded-full overflow-hidden flex">
                        <div
                            style={{ width: `${(stats.followUps / total) * 100}%` }}
                            className="bg-emerald-500 h-full transition-all duration-500"
                        />
                        <div
                            style={{ width: `${((stats.needsFollowup || 0) / total) * 100}%` }}
                            className="bg-amber-400 h-full transition-all duration-500"
                        />
                        <div
                            style={{ width: `${((stats.notContacted || 0) / total) * 100}%` }}
                            className="bg-stone-200 h-full transition-all duration-500"
                        />
                    </div>
                    <div className="flex justify-between mt-2">
                        <div className="flex items-center gap-1.5">
                            <div className="w-2 h-2 rounded-full bg-emerald-500" />
                            <span className="text-[10px] text-gray-500">Followed Up ({stats.followUps})</span>
                        </div>
                        <div className="flex items-center gap-1.5">
                            <div className="w-2 h-2 rounded-full bg-amber-400" />
                            <span className="text-[10px] text-gray-500">Needs Follow-up ({stats.needsFollowup || 0})</span>
                        </div>
                        <div className="flex items-center gap-1.5">
                            <div className="w-2 h-2 rounded-full bg-stone-200" />
                            <span className="text-[10px] text-gray-500">Not Contacted ({stats.notContacted || 0})</span>
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
}
