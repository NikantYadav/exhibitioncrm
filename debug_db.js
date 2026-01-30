
require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');

async function check() {
    const supabase = createClient(process.env.NEXT_PUBLIC_SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY);

    // List all captures
    const { data: captures, error: cErr } = await supabase.from('captures').select('*');
    console.log('All Captures:', captures?.length);
    if (captures) {
        captures.forEach(c => console.log(`Capture ID: ${c.id}, Event ID: ${c.event_id}, Contact ID: ${c.contact_id}`));
    }

    // List all targets
    const { data: targets, error: tErr } = await supabase.from('target_companies').select('*');
    console.log('All Targets:', targets?.length);
    if (targets) {
        targets.forEach(t => console.log(`Target ID: ${t.id}, Event ID: ${t.event_id}`));
    }
}

check();
