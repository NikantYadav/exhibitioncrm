#!/usr/bin/env node
// Purge (hard-delete) rows that were soft-deleted (deleted_at IS NOT NULL) more
// than RETENTION_DAYS ago. Soft deletes keep rows around so that offline clients
// can learn a row was removed during delta sync; this script reclaims that space
// once every client has had ample time to catch up.
//
// MANUAL USE ONLY. This permanently removes rows. It is NOT wired into any cron
// or request path — run it by hand (or from a deliberately-scheduled job).
//
// Usage:
//   node scripts/purge-soft-deleted.mjs                 # purge rows deleted > 30 days ago
//   RETENTION_DAYS=7 node scripts/purge-soft-deleted.mjs
//   DRY_RUN=1 node scripts/purge-soft-deleted.mjs       # report only, delete nothing
//   RETENTION_DAYS=0 node scripts/purge-soft-deleted.mjs # purge ALL soft-deleted rows
//
// Env required (read from backend/.env or the process env):
//   SUPABASE_URL                (or NEXT_PUBLIC_SUPABASE_URL)
//   SUPABASE_SERVICE_ROLE_KEY   (or SUPABASE_SERVICE_KEY)

import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

// Load backend/.env regardless of the directory the script is invoked from.
const __dirname = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.resolve(__dirname, '../backend/.env') });

const SUPABASE_URL = process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL;
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_KEY;

if (!SUPABASE_URL || !SERVICE_KEY) {
  console.error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY. Set them in backend/.env or the environment.');
  process.exit(1);
}

const RETENTION_DAYS = process.env.RETENTION_DAYS !== undefined ? Number(process.env.RETENTION_DAYS) : 30;
const DRY_RUN = process.env.DRY_RUN === '1' || process.env.DRY_RUN === 'true';

if (Number.isNaN(RETENTION_DAYS) || RETENTION_DAYS < 0) {
  console.error(`Invalid RETENTION_DAYS: "${process.env.RETENTION_DAYS}". Must be a number >= 0.`);
  process.exit(1);
}

// Every table that participates in the soft-delete sync model. Keep this list in
// sync with the `deleted_at`-bearing tables in plan.md (section 3). A table absent
// from this array is simply never purged.
const SYNCED_TABLES = [
  'events',
  'contacts',
  'captures',
  'target_companies',
  'contact_events',
  'event_goals',
  'email_drafts',
  'interactions',
];

const supabase = createClient(SUPABASE_URL, SERVICE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false, detectSessionInUrl: false },
});

// Cutoff: rows with deleted_at <= cutoff are eligible. RETENTION_DAYS=0 => now (all soft-deleted rows).
const cutoff = new Date(Date.now() - RETENTION_DAYS * 24 * 60 * 60 * 1000).toISOString();

async function purgeTable(table) {
  // Count first so the report is meaningful even in dry-run.
  const { count, error: countError } = await supabase
    .from(table)
    .select('id', { count: 'exact', head: true })
    .not('deleted_at', 'is', null)
    .lte('deleted_at', cutoff);

  if (countError) {
    console.error(`  [${table}] count failed: ${countError.message}`);
    return { table, purged: 0, error: countError.message };
  }

  const eligible = count || 0;
  if (eligible === 0) {
    console.log(`  [${table}] nothing to purge`);
    return { table, purged: 0 };
  }

  if (DRY_RUN) {
    console.log(`  [${table}] would purge ${eligible} row(s)`);
    return { table, purged: 0, wouldPurge: eligible };
  }

  const { error: delError } = await supabase
    .from(table)
    .delete()
    .not('deleted_at', 'is', null)
    .lte('deleted_at', cutoff);

  if (delError) {
    console.error(`  [${table}] delete failed: ${delError.message}`);
    return { table, purged: 0, error: delError.message };
  }

  console.log(`  [${table}] purged ${eligible} row(s)`);
  return { table, purged: eligible };
}

async function main() {
  console.log(`Purge soft-deleted rows`);
  console.log(`  retention : ${RETENTION_DAYS} day(s)  (cutoff = ${cutoff})`);
  console.log(`  mode      : ${DRY_RUN ? 'DRY RUN (no deletes)' : 'LIVE'}`);
  console.log('');

  const results = [];
  for (const table of SYNCED_TABLES) {
    results.push(await purgeTable(table));
  }

  const totalPurged = results.reduce((n, r) => n + (r.purged || 0), 0);
  const totalWould = results.reduce((n, r) => n + (r.wouldPurge || 0), 0);
  const errors = results.filter((r) => r.error);

  console.log('');
  if (DRY_RUN) {
    console.log(`Done (dry run). Would purge ${totalWould} row(s) across ${SYNCED_TABLES.length} table(s).`);
  } else {
    console.log(`Done. Purged ${totalPurged} row(s) across ${SYNCED_TABLES.length} table(s).`);
  }
  if (errors.length > 0) {
    console.log(`${errors.length} table(s) errored — see above.`);
    process.exit(1);
  }
}

main().catch((err) => {
  console.error('Fatal:', err);
  process.exit(1);
});
