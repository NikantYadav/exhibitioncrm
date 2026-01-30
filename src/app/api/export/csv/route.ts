import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { ExcelService } from '@/lib/services/excel';

export async function GET(request: NextRequest) {
    try {
        const supabase = createClient();

        // Fetch all contacts
        const { data: contacts, error } = await supabase
            .from('contacts')
            .select(`
                *,
                company:companies(name)
            `)
            .order('created_at', { ascending: false });

        if (error) {
            return NextResponse.json({ error: error.message }, { status: 400 });
        }

        const csv = ExcelService.exportContactsToCSV(contacts || []);

        return new NextResponse(csv, {
            headers: {
                'Content-Type': 'text/csv',
                'Content-Disposition': 'attachment; filename="contacts.csv"'
            }
        });
    } catch (error) {
        console.error('CSV export error:', error);
        return NextResponse.json(
            { error: 'Failed to export CSV' },
            { status: 500 }
        );
    }
}
