#!/usr/bin/env node
/**
 * sync-slayer-password.mjs
 *
 * Reads SLAYER_READONLY_PASSWORD from backend/.env and applies it to the
 * slayer_readonly Postgres role by calling the set_slayer_password() RPC
 * function via the Supabase PostgREST API (service role key, HTTPS only —
 * no direct DB port needed).
 *
 * Usage:
 *   node scripts/sync-slayer-password.mjs
 *   # or via the shell wrapper:
 *   ./scripts/sync-slayer-password.sh
 */

import { readFileSync } from 'fs';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));

// ─── Parse .env ───────────────────────────────────────────────────────────────
function parseEnv(filePath) {
  const text = readFileSync(filePath, 'utf8');
  const env = {};
  for (const line of text.split('\n')) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const idx = trimmed.indexOf('=');
    if (idx === -1) continue;
    const key = trimmed.slice(0, idx).trim();
    let val = trimmed.slice(idx + 1).trim();
    val = val.replace(/#.*$/, '').trim();         // strip inline comments
    val = val.replace(/^['"]|['"]$/g, '').trim(); // strip surrounding quotes
    env[key] = val;
  }
  return env;
}

const envPath = resolve(__dirname, '../backend/.env');
let env;
try {
  env = parseEnv(envPath);
} catch (e) {
  console.error(`Error: could not read ${envPath}: ${e.message}`);
  process.exit(1);
}

const { SLAYER_READONLY_PASSWORD, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY } = env;

if (!SLAYER_READONLY_PASSWORD) {
  console.error('Error: SLAYER_READONLY_PASSWORD is not set in backend/.env');
  process.exit(1);
}
if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  console.error('Error: SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY is not set in backend/.env');
  process.exit(1);
}

if (SLAYER_READONLY_PASSWORD.length < 8) {
  console.error('Error: SLAYER_READONLY_PASSWORD must be at least 8 characters');
  process.exit(1);
}

const projectRef = SUPABASE_URL.replace('https://', '').split('.')[0];
console.log(`→ Syncing slayer_readonly password (project: ${projectRef}) ...`);

// ─── Call set_slayer_password() via PostgREST RPC ────────────────────────────
// This function is SECURITY DEFINER and only callable by service_role.
// It runs ALTER ROLE internally — no direct Postgres port needed.
const rpcUrl = `${SUPABASE_URL}/rest/v1/rpc/set_slayer_password`;

let response;
try {
  response = await fetch(rpcUrl, {
    method: 'POST',
    headers: {
      'apikey': SUPABASE_SERVICE_ROLE_KEY,
      'Authorization': `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ p_password: SLAYER_READONLY_PASSWORD }),
  });
} catch (e) {
  console.error(`Network error: ${e.message}`);
  process.exit(1);
}

if (response.ok) {
  console.log('✓ slayer_readonly password updated successfully.');
  console.log('\nRestart Slayer to pick up the new password:');
  console.log('  cd slayer && ./start.sh');
  process.exit(0);
}

const body = await response.text();
console.error(`\nFailed (HTTP ${response.status}): ${body}`);
console.error('\nFallback — run this in the Supabase Dashboard SQL editor:');
console.error(`  https://supabase.com/dashboard/project/${projectRef}/sql/new`);
console.error(`\n  ALTER ROLE slayer_readonly WITH PASSWORD '<your-new-password>';\n`);
process.exit(1);
