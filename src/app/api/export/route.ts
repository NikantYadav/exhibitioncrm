import { NextRequest, NextResponse } from 'next/server';
import { ExcelService } from '@/lib/services/excel';
import { createServerClient } from '@/lib/supabase/client';

export async function GET(request: NextRequest) {
    try {
        const { searchParams } = new URL(request.url);
        const type = searchParams.get('type') || 'contacts';
        const event_id = searchParams.get('event_id');

        const supabase = createServerClient();

        if (type === 'contacts') {
            // Export contacts
            const { data: contacts } = await supabase
                .from('contacts')
                .select('*, company:companies(*)')
                .order('created_at', { ascending: false });

            const buffer = await ExcelService.exportContacts(contacts || []);

            return new NextResponse(new Uint8Array(buffer), {
                headers: {
                    'Content-Type': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                    'Content-Disposition': `attachment; filename="contacts-${new Date().toISOString().split('T')[0]}.xlsx"`,
                },
            });
        } else if (type === 'companies') {
            // Export companies
            const { data: companies } = await supabase
                .from('companies')
                .select('*')
                .order('name', { ascending: true });

            const buffer = await ExcelService.exportCompanies(companies || []);

            return new NextResponse(new Uint8Array(buffer), {
                headers: {
                    'Content-Type': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                    'Content-Disposition': `attachment; filename="companies-${new Date().toISOString().split('T')[0]}.xlsx"`,
                },
            });
        } else if (type === 'event' && event_id) {
            // Export full event data
            const { data: event } = await supabase
                .from('events')
                .select('*')
                .eq('id', event_id)
                .single();

            const { data: contacts } = await supabase
                .from('contacts')
                .select('*, company:companies(*)')
                .order('created_at', { ascending: false });

            const { data: companies } = await supabase
                .from('companies')
                .select('*');

            const buffer = await ExcelService.exportEventData({
                event: event!,
                contacts: contacts || [],
                companies: companies || [],
            });

            return new NextResponse(new Uint8Array(buffer), {
                headers: {
                    'Content-Type': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                    'Content-Disposition': `attachment; filename="event-${event?.name.replace(/\s+/g, '-')}-${new Date().toISOString().split('T')[0]}.xlsx"`,
                },
            });
        } else if (type === 'template') {
            // Generate import template
            const buffer = await ExcelService.generateContactTemplate();

            return new NextResponse(new Uint8Array(buffer), {
                headers: {
                    'Content-Type': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                    'Content-Disposition': 'attachment; filename="contact-import-template.xlsx"',
                },
            });
        }

        return NextResponse.json(
            { error: 'Invalid export type' },
            { status: 400 }
        );
    } catch (error) {
        console.error('Export error:', error);
        return NextResponse.json(
            { error: 'Failed to export data' },
            { status: 500 }
        );
    }
}
