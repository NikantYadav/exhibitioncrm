import { getTargets } from '@/app/actions/preparation';
import TargetList from './target-list';

export default async function TargetsPage({ params }: { params: { id: string } }) {
    const targets = await getTargets(params.id);

    return (
        <div className="max-w-4xl mx-auto space-y-8">

            <TargetList initialTargets={targets} eventId={params.id} />
        </div>
    );
}
