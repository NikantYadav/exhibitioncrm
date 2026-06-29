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
  'target_company_met',
] as const;

type SyncedTable = (typeof SYNCED_TABLES)[number];

interface TableDelta {
  upserts: Record<string, unknown>[];
  deleted_ids: string[];
}

// Per-table page size for the keyset-paginated full sync. The initial pull
// (since = epoch) of a heavy account can be thousands of rows per table; sending
// them all in one response spikes memory and risks a gateway timeout. Instead we
// cap each table at PAGE_SIZE rows ordered by updated_at ASC and tell the client
// whether more remain, so it loops until drained. Deltas (small `since`) finish
// in a single page and never notice the cap.
const PAGE_SIZE = 500;

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
        // Fetch PAGE_SIZE + 1: the extra row (if present) tells us more remain
        // without a second count query. We return only PAGE_SIZE and signal more.
        const { data: rows, error } = await supabase
          .from(table)
          .select('*')
          .eq('user_id', userId)
          .gt('updated_at', since)
          .order('updated_at', { ascending: true })
          .limit(PAGE_SIZE + 1);
        if (error) throw error;
        return { table, rows: rows ?? [] };
      })
    );

    // True if ANY table still has rows beyond this page; the client keeps
    // looping `/sync` (advancing `since`) until every table is drained.
    let hasMore = false;
    // The cursor for the NEXT page: the latest updated_at actually delivered in
    // this response. The client advances `since` to this (not server_time) while
    // paging, so page N+1 picks up exactly where page N stopped — storing
    // server_time mid-pagination would skip every row between the last paged row
    // and now. Only when has_more is false does the client commit server_time.
    let maxUpdatedAt = since;

    for (const { table, rows } of tableResults) {
      const page = rows.slice(0, PAGE_SIZE);
      if (rows.length > PAGE_SIZE) { hasMore = true; }
      for (const r of page as any[]) {
        if (typeof r.updated_at === 'string' && r.updated_at > maxUpdatedAt) {
          maxUpdatedAt = r.updated_at;
        }
      }
      const upserts = page.filter((r: any) => r.deleted_at == null);
      const deletedIds = page.filter((r: any) => r.deleted_at != null).map((r: any) => r.id);
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

    // `next_since`: cursor to pass back as `since` on the next page (only
    // meaningful while has_more). `server_time`: the watermark to commit once
    // has_more is false (delta path is unchanged — single page, has_more false).
    res.json({ server_time: serverTime, next_since: maxUpdatedAt, has_more: hasMore, data });
  } catch (error) {
    console.error('GET /sync failed:', error);
    res.status(500).json({ error: 'Failed to fetch sync delta' });
  }
});

export default router;
