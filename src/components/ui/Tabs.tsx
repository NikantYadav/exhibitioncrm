import { ReactNode } from 'react';

interface TabsProps {
    value: string;
    onValueChange: (value: string) => void;
    children: ReactNode;
    className?: string;
}

interface TabsListProps {
    children: ReactNode;
    className?: string;
}

interface TabsTriggerProps {
    value: string;
    children: ReactNode;
    className?: string;
}

interface TabsContentProps {
    value: string;
    children: ReactNode;
    className?: string;
}

export function Tabs({ value, onValueChange, children, className = '' }: TabsProps) {
    return (
        <div className={`tabs ${className}`} data-value={value}>
            {children}
        </div>
    );
}

export function TabsList({ children, className = '' }: TabsListProps) {
    return (
        <div className={`flex gap-1 border-b border-gray-200 ${className}`}>
            {children}
        </div>
    );
}

export function TabsTrigger({ value, children, className = '' }: TabsTriggerProps) {
    return (
        <button
            type="button"
            className={`px-4 py-2.5 text-sm font-medium transition-colors border-b-2 ${className}`}
            data-value={value}
            style={{
                borderColor: 'transparent',
                color: '#6b7280'
            }}
            onMouseEnter={(e) => {
                e.currentTarget.style.color = '#111827';
            }}
            onMouseLeave={(e) => {
                const isActive = e.currentTarget.closest('.tabs')?.getAttribute('data-value') === value;
                e.currentTarget.style.color = isActive ? '#2563eb' : '#6b7280';
            }}
        >
            {children}
        </button>
    );
}

export function TabsContent({ value, children, className = '' }: TabsContentProps) {
    return (
        <div className={`tabs-content ${className}`} data-value={value}>
            {children}
        </div>
    );
}

// Add CSS to handle active states
if (typeof document !== 'undefined') {
    const style = document.createElement('style');
    style.textContent = `
        .tabs [data-value] {
            cursor: pointer;
        }
        .tabs-content {
            display: none;
        }
        .tabs-content[data-value] {
            display: block;
        }
    `;
    document.head.appendChild(style);
}
