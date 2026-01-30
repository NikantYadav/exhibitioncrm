import { ReactNode } from 'react';
import { cn } from '@/lib/utils';

interface EmptyStateProps {
    icon: ReactNode;
    title: string;
    description: string;
    action?: ReactNode;
    className?: string;
}

export function EmptyState({ icon, title, description, action, className }: EmptyStateProps) {
    return (
        <div className={cn("flex flex-col items-center justify-center py-12 px-4 text-center", className)}>
            <div className="mb-4 flex h-24 w-24 items-center justify-center rounded-full bg-stone-100 text-stone-300">
                {icon}
            </div>
            <h3 className="text-lg font-semibold text-stone-900 mt-4">{title}</h3>
            <p className="text-sm text-stone-500 mt-1 max-w-sm">{description}</p>
            {action && <div className="mt-6">{action}</div>}
        </div>
    );
}
