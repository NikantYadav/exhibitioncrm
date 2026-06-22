#!/usr/bin/env bash
# Start the Slayer semantic layer server.
# Reads SUPABASE_PASSWORD from the backend .env if not already exported.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKEND_ENV="$SCRIPT_DIR/../backend/.env"

# Load backend .env so Slayer uses those values only.
if [[ -f "$BACKEND_ENV" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$BACKEND_ENV"
  set +a
fi

STORAGE="$SCRIPT_DIR/slayer_data"
SCHEMA_HASH_FILE="$STORAGE/.schema_hash"

DB_HOST="aws-1-ap-northeast-2.pooler.supabase.com"
DB_USER="slayer_readonly.ezammzqvbjgpuzleqmla"
DB_NAME="postgres"

# Self-heal: if slayer_data (or the 'exono' datasource within it) was deleted,
# recreate the datasource config before ingesting so a fresh/partial storage
# dir doesn't hard-fail with "Datasource 'exono' not found".
if ! "$SCRIPT_DIR/env/bin/python" -m slayer datasources --storage "$STORAGE" show exono >/dev/null 2>&1; then
  echo "   Datasource 'exono' missing — recreating…"
  "$SCRIPT_DIR/env/bin/python" -m slayer datasources --storage "$STORAGE" create \
    "postgresql://${DB_USER}:\${SLAYER_READONLY_PASSWORD}@${DB_HOST}:5432/${DB_NAME}" \
    --name exono
  # Force a re-ingest below regardless of the stored schema hash.
  rm -f "$SCHEMA_HASH_FILE"
fi

# Hash only table names — column-level changes don't require a full re-ingest
# because ingest is additive (new columns get appended) and sample profiling
# is cached per-column (only new/uncached columns are profiled).
# Re-ingest only when tables are added or dropped.
CURRENT_HASH=$(PGPASSWORD="$SLAYER_READONLY_PASSWORD" psql \
  -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -t -A \
  -c "SELECT table_name FROM information_schema.tables
      WHERE table_schema='public' AND table_type='BASE TABLE'
      ORDER BY 1;" 2>/dev/null | sha256sum | cut -d' ' -f1)

STORED_HASH=""
[[ -f "$SCHEMA_HASH_FILE" ]] && STORED_HASH=$(cat "$SCHEMA_HASH_FILE")

echo "→ Starting Slayer on http://localhost:5143 (storage: $STORAGE)"
if [[ "$CURRENT_HASH" != "$STORED_HASH" ]]; then
  echo "   Table list changed — re-ingesting datasource 'exono'…"
  "$SCRIPT_DIR/env/bin/python" -m slayer ingest --datasource exono --storage "$STORAGE"
  echo "$CURRENT_HASH" > "$SCHEMA_HASH_FILE"
else
  echo "   Schema unchanged — skipping ingest."
fi

exec "$SCRIPT_DIR/env/bin/python" -m slayer serve \
  --storage "$STORAGE" \
  --host 127.0.0.1 \
  --port 5143
