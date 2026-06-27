import { Router } from 'express';
import { requireAuth } from '../middleware/requireAuth';

const router = Router();

router.use(requireAuth);

// Tables denormalized with user_id for direct delta queries + Realtime RLS.
// `companies` is handled separately below (shared lookup, no user_id/tombstones).
const SYNCED_TABLES = [
  'events',
  'contacts',
  'captures',
  'target_companies',
  'contact_events',
  'event_goals',
  'email_drafts',
  'interactions',
  'follow_ups',
] as const;

type SyncedTable = (typeof SYNCED_TABLES)[number];

interface TableDelta {
  upserts: Record<string, unknown>[];
  deleted_ids: string[];
}

router.get('/', async (req, res) => {
  try {
    const supabase = req.supabase!;
    const userId = req.user!.id;
    const serverTime = new Date().toISOString();

    const since = typeof req.query.since === 'string' && req.query.since.length > 0
      ? req.query.since
      : new Date(0).toISOString();

    const requestedTables: string[] = typeof req.query.tables === 'string' && req.query.tables.length > 0
      ? req.query.tables.split(',').map((t) => t.trim())
      : [...SYNCED_TABLES, 'companies'];

    const tables = SYNCED_TABLES.filter((t) => requestedTables.includes(t));

    const data: Record<string, TableDelta> = {};

    // Fetch every requested table in parallel. Previously this was a serial
    // `for await` loop — 9 sequential round-trips to the Supabase REST gateway,
    // which dominated latency (~6s). Parallel collapses it to ~1 round-trip.
    const tableResults = await Promise.all(
      tables.map(async (table) => {
        const { data: rows, error } = await supabase
          .from(table)
          .select('*')
          .eq('user_id', userId)
          .gt('updated_at', since)
          .order('updated_at', { ascending: true });
        if (error) throw error;
        return { table, rows: rows ?? [] };
      })
    );

    for (const { table, rows } of tableResults) {
      const upserts = rows.filter((r: any) => r.deleted_at == null);
      const deletedIds = rows.filter((r: any) => r.deleted_at != null).map((r: any) => r.id);
      data[table] = { upserts, deleted_ids: deletedIds };
    }

    // companies: shared lookup, no user_id/tombstones — sync only rows referenced
    // through this user's contacts/target_companies, changed since `since`.
    if (requestedTables.includes('companies')) {
      const [{ data: userContacts, error: contactsErr }, { data: userTargets, error: targetsErr }] =
        await Promise.all([
          supabase.from('contacts').select('company_id').eq('user_id', userId).not('company_id', 'is', null),
          supabase.from('target_companies').select('company_id').eq('user_id', userId).not('company_id', 'is', null),
        ]);

      if (contactsErr) throw contactsErr;
      if (targetsErr) throw targetsErr;

      const referencedCompanyIds = [...new Set([
        ...(userContacts ?? []).map((c: any) => c.company_id),
        ...(userTargets ?? []).map((t: any) => t.company_id),
      ])];

      let companies: Record<string, unknown>[] = [];
      if (referencedCompanyIds.length > 0) {
        const { data: companyRows, error } = await supabase
          .from('companies')
          .select('*')
          .in('id', referencedCompanyIds)
          .gt('updated_at', since);

        if (error) throw error;
        companies = companyRows ?? [];
      }

      data.companies = { upserts: companies, deleted_ids: [] };
    }

    res.json({ server_time: serverTime, data });
  } catch (error) {
    console.error('GET /sync failed:', error);
    res.status(500).json({ error: 'Failed to fetch sync delta' });
  }
});

export default router;
