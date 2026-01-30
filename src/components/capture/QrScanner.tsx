'use client';

import { Scanner } from '@yudiel/react-qr-scanner';
import { Card, CardContent } from '@/components/ui/Card';

interface QrScannerProps {
    onScan: (data: string) => void;
}

export default function QrScanner({ onScan }: QrScannerProps) {
    return (
        <Card className="overflow-hidden shadow-lg border-0 bg-black">
            <CardContent className="p-0 relative min-h-[400px] flex items-center justify-center bg-zinc-900">
                <div className="w-full h-[500px]">
                    <Scanner
                        onScan={(detectedCodes) => {
                            if (detectedCodes && detectedCodes.length > 0) {
                                onScan(detectedCodes[0].rawValue);
                            }
                        }}
                        styles={{
                            container: { height: '100%', width: '100%' },
                            video: { objectFit: 'cover' }
                        }}
                    />
                </div>
                <div className="absolute top-8 left-0 right-0 text-center pointer-events-none">
                    <span className="inline-block px-4 py-2 rounded-full bg-black/50 text-white backdrop-blur-md text-sm font-medium">
                        Point at a QR Code
                    </span>
                </div>
            </CardContent>
        </Card>
    );
}
