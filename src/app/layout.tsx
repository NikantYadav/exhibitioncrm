import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
    title: 'Exhibition CRM - Personal Assistant for Events',
    description: 'Capture leads, remember interactions, and manage relationships at exhibitions and meetings',
};

import { Toaster } from 'sonner';

export default function RootLayout({
    children,
}: {
    children: React.ReactNode;
}) {
    return (
        <html lang="en">
            <body>
                {children}
                <Toaster richColors position="top-right" />
            </body>
        </html>
    );
}
