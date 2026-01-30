import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { ExcelService } from '@/lib/services/excel';

export async function GET(request: NextRequest) {
    try {
        const supabase = createClient();

        // Fetch all contacts with related data
        const { data: contacts, error } = await supabase
            .from('contacts')
            .select(`
                *,
                company:companies(name, industry, website)
            `)
            .order('created_at', { ascending: false });

        if (error) {
            return NextResponse.json({ error: error.message }, { status: 400 });
        }

        const buffer = await ExcelService.exportContacts(contacts || []);

        return new NextResponse(buffer as any, {
            headers: {
                'Content-Type': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                'Content-Disposition': `attachment; filename="contacts-${new Date().toISOString().split('T')[0]}.xlsx"`,
            },
        });
    } catch (error) {
        console.error('Export error:', error);
        return NextResponse.json(
            { error: 'Failed to export data' },
            { status: 500 }
        );
    }
}
