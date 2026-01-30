import { Mail, Phone, FileText, Calendar } from 'lucide-react';
import { Button } from '@/components/ui/Button';

interface ContactQuickActionsProps {
    email?: string;
    phone?: string;
    onEmail?: () => void;
    onAddNote?: () => void;
    onScheduleMeeting?: () => void;
}

export function ContactQuickActions({
    email,
    phone,
    onEmail,
    onAddNote,
    onScheduleMeeting
}: ContactQuickActionsProps) {
    return (
        <div className="grid grid-cols-2 gap-3">
            <Button
                variant="outline"
                size="sm"
                className="justify-start h-10 rounded-xl border-stone-200 hover:bg-stone-50 text-stone-600 font-bold"
                onClick={onEmail}
                disabled={!email}
            >
                <Mail className="mr-2 h-4 w-4 text-stone-900" strokeWidth={2.5} />
                Email
            </Button>

            <Button
                variant="outline"
                size="sm"
                className="justify-start h-10 rounded-xl border-stone-200 hover:bg-stone-50 text-stone-600 font-bold"
                asChild={!!phone}
                disabled={!phone}
            >
                {phone ? (
                    <a href={`tel:${phone}`}>
                        <Phone className="mr-2 h-4 w-4 text-stone-900" strokeWidth={2.5} />
                        Call
                    </a>
                ) : (
                    <div className="flex items-center">
                        <Phone className="mr-2 h-4 w-4 text-stone-400" strokeWidth={2.5} />
                        Call
                    </div>
                )}
            </Button>

            <Button
                variant="outline"
                size="sm"
                className="justify-start h-10 rounded-xl border-stone-200 hover:bg-stone-50 text-stone-600 font-bold"
                onClick={onAddNote}
            >
                <FileText className="mr-2 h-4 w-4 text-stone-900" strokeWidth={2.5} />
                Add Note
            </Button>

            <Button
                variant="outline"
                size="sm"
                className="justify-start h-10 rounded-xl border-stone-200 hover:bg-stone-50 text-stone-600 font-bold"
                onClick={onScheduleMeeting}
            >
                <Calendar className="mr-2 h-4 w-4 text-stone-900" strokeWidth={2.5} />
                Meeting
            </Button>
        </div>
    );
}
