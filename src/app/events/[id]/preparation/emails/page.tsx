import { getTargets } from '@/app/actions/preparation';
import EmailDrafter from './email-drafter';

export default async function EmailsPage({ params }: { params: { id: string } }) {
    const targets = await getTargets(params.id);

    return (
        <div className="max-w-6xl mx-auto">

            <EmailDrafter targets={targets} eventId={params.id} />
        </div>
    );
}
