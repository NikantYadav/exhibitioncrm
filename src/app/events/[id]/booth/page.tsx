import { getTargets } from '@/app/actions/preparation';
import Link from 'next/link';
import { ArrowLeft, MapPin, CheckCircle, Circle } from 'lucide-react';

export default async function BoothPage({ params }: { params: { id: string } }) {
    const targets = await getTargets(params.id);

    // Sort by priority (High -> Medium -> Low)
    const priorityOrder = { high: 0, medium: 1, low: 2 };
    const sortedTargets = targets.sort((a: any, b: any) =>
        (priorityOrder[a.priority as keyof typeof priorityOrder] || 2) -
        (priorityOrder[b.priority as keyof typeof priorityOrder] || 2)
    );

    return (
        <div className="min-h-screen bg-black text-white p-4">
            <div className="max-w-md mx-auto space-y-4">
                <header className="flex items-center justify-between pb-4 border-b border-gray-800">
                    <Link href={`/events/${params.id}`} className="p-2 -ml-2 text-gray-400 hover:text-white">
                        <ArrowLeft className="h-6 w-6" />
                    </Link>
                    <h1 className="text-xl font-bold tracking-tight">Booth Mode</h1>
                    <div className="w-8" />
                </header>

                <div className="space-y-4">
                    {sortedTargets.map((target: any) => (
                        <BoothCard key={target.id} target={target} />
                    ))}

                    {sortedTargets.length === 0 && (
                        <div className="text-center py-10 text-gray-500">
                            No targets found.
                        </div>
                    )}
                </div>
            </div>
        </div>
    );
}

function BoothCard({ target }: any) {
    const isHigh = target.priority === 'high';

    return (
        <div className={`
            relative overflow-hidden rounded-xl border border-gray-800 bg-gray-900 p-5
            ${isHigh ? 'ring-2 ring-red-500' : ''}
        `}>
            {isHigh && (
                <div className="absolute top-0 right-0 bg-red-600 text-white text-[10px] font-bold px-2 py-1 rounded-bl-lg">
                    HIGH PRIORITY
                </div>
            )}

            <div className="mb-2">
                <h3 className="text-2xl font-bold text-white leading-none mb-1">{target.company.name}</h3>
                <p className="text-gray-400 text-sm flex items-center gap-1">
                    <MapPin className="h-3 w-3" />
                    {target.booth_location || 'Booth ???'}
                </p>
            </div>

            <div className="space-y-3 mt-4">
                <div className="bg-gray-800/50 p-3 rounded-lg">
                    <p className="text-sm text-gray-300 line-clamp-2">
                        {target.company.description || 'No description'}
                    </p>
                </div>

                {target.talking_points && (
                    <div>
                        <p className="text-xs text-gray-500 uppercase font-bold mb-1">Talking Points</p>
                        <ul className="text-sm text-green-400 space-y-1 ml-4 list-disc">
                            {target.talking_points.split('\n').slice(0, 3).map((pt: string, i: number) => (
                                <li key={i}>{pt.replace(/^-\s*/, '')}</li>
                            ))}
                        </ul>
                    </div>
                )}
            </div>

            {/* Simple status toggle could be added here later with Client Component */}
        </div>
    );
}
