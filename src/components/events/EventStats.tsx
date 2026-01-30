import { Target, Camera, Users, Mail } from 'lucide-react';

interface EventStatsProps {
    stats: {
        targets: number;
        captures: number;
        contacts: number;
        followUps: number;
    };
}

export function EventStats({ stats }: EventStatsProps) {
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
    );
}
