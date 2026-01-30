import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';

export async function GET(request: NextRequest) {
    try {
        const supabase = createClient();

        // Fetch user settings (or return defaults)
        const { data: settings, error } = await supabase
            .from('user_settings')
            .select('*')
            .single();

        // If no settings exist, return defaults
        if (error || !settings) {
            return NextResponse.json({
                data: {
                    ai_provider: 'openai',
                    ai_model: 'gpt-4',
                    ai_api_key: '',
                    enrichment_enabled: true,
                    smtp_host: '',
                    smtp_port: 587,
                    smtp_user: '',
                    smtp_password: '',
                    email_signature: ''
                }
            });
        }

        return NextResponse.json({ data: settings });
    } catch (error) {
        console.error('Settings fetch error:', error);
        return NextResponse.json(
            { error: 'Failed to fetch settings' },
            { status: 500 }
        );
    }
}

export async function PUT(request: NextRequest) {
    try {
        const supabase = createClient();
        const body = await request.json();

        // Upsert settings
        const { data, error } = await supabase
            .from('user_settings')
            .upsert(body)
            .select()
            .single();

        if (error) {
            return NextResponse.json({ error: error.message }, { status: 400 });
        }

        return NextResponse.json({ data });
    } catch (error) {
        console.error('Settings update error:', error);
        return NextResponse.json(
            { error: 'Failed to update settings' },
            { status: 500 }
        );
    }
}
