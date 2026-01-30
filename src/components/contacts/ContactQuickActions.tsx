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
        <div className="grid grid-cols-2 gap-2">
            <Button
                variant="outline"
                size="sm"
                className="justify-start"
                onClick={onEmail}
                disabled={!email}
            >
                <Mail className="mr-2 h-4 w-4" />
                Email
            </Button>

            <Button
                variant="outline"
                size="sm"
                className="justify-start"
                asChild={!!phone}
                disabled={!phone}
            >
                {phone ? (
                    <a href={`tel:${phone}`}>
                        <Phone className="mr-2 h-4 w-4" />
                        Call
                    </a>
                ) : (
                    <>
                        <Phone className="mr-2 h-4 w-4" />
                        Call
                    </>
                )}
            </Button>

            <Button
                variant="outline"
                size="sm"
                className="justify-start"
                onClick={onAddNote}
            >
                <FileText className="mr-2 h-4 w-4" />
                Add Note
            </Button>

            <Button
                variant="outline"
                size="sm"
                className="justify-start"
                onClick={onScheduleMeeting}
            >
                <Calendar className="mr-2 h-4 w-4" />
                Meeting
            </Button>
        </div>
    );
}
