'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { OfflineIndicator } from '../ui/OfflineIndicator';
import { Button } from '@/components/ui/Button';

export function Header() {
    const pathname = usePathname();

    const navItems = [
        { href: '/', label: 'Dashboard' },
        { href: '/events', label: 'Events' },
        { href: '/contacts', label: 'Contacts' },
        { href: '/capture', label: 'Capture' },
        { href: '/settings', label: 'Settings' },
    ];

    return (
        <>
            <header className="sticky top-0 z-30 flex h-16 items-center justify-between border-b border-stone-200 bg-white px-8">
                <Link href="/" className="font-bold text-lg text-stone-900">
                    Exhibition CRM
                </Link>

                <nav className="flex items-center gap-6">
                    {navItems.map((item) => {
                        const isActive = pathname === item.href;
                        return (
                            <Link
                                key={item.href}
                                href={item.href}
                                className={`text-sm font-medium transition-colors ${isActive
                                        ? 'text-stone-900'
                                        : 'text-stone-600 hover:text-stone-900'
                                    }`}
                            >
                                {item.label}
                            </Link>
                        );
                    })}
                </nav>

                <div className="flex items-center gap-4">
                    <Button size="sm">
                        + New
                    </Button>
                </div>
            </header>

            <OfflineIndicator />
        </>
    );
}
