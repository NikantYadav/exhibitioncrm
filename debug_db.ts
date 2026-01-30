import { createClient } from './src/lib/supabase/server';

async function check() {
    const supabase = createClient();
    const eventId = 'REPLACE_WITH_ACTUAL_ID'; // I can't know the ID yet

    const { count } = await supabase
        .from('target_companies')
        .select('*', { count: 'exact', head: true });

    console.log('Total targets in DB:', count);
}
