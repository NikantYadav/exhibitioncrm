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

# Query column fingerprint from live DB (table+column+type, sorted).
DB_HOST="aws-1-ap-northeast-2.pooler.supabase.com"
DB_USER="slayer_readonly.ezammzqvbjgpuzleqmla"
DB_NAME="postgres"
CURRENT_HASH=$(PGPASSWORD="$SLAYER_READONLY_PASSWORD" psql \
  -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -t -A \
  -c "SELECT table_name||'.'||column_name||':'||data_type
      FROM information_schema.columns
      WHERE table_schema='public'
      ORDER BY 1;" 2>/dev/null | sha256sum | cut -d' ' -f1)

STORED_HASH=""
[[ -f "$SCHEMA_HASH_FILE" ]] && STORED_HASH=$(cat "$SCHEMA_HASH_FILE")

echo "→ Starting Slayer on http://localhost:5143 (storage: $STORAGE)"
if [[ "$CURRENT_HASH" != "$STORED_HASH" ]]; then
  echo "   Schema changed — re-ingesting datasource 'exono'…"
  "$SCRIPT_DIR/env/bin/python" -m slayer ingest --datasource exono --storage "$STORAGE"
  echo "$CURRENT_HASH" > "$SCHEMA_HASH_FILE"
else
  echo "   Schema unchanged — skipping ingest."
fi

exec "$SCRIPT_DIR/env/bin/python" -m slayer serve \
  --storage "$STORAGE" \
  --host 127.0.0.1 \
  --port 5143
