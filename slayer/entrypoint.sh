#!/usr/bin/env bash
set -euo pipefail

STORAGE="/data"
PORT="${PORT:-5143}"

# Ensure datasource exists
if ! python -m slayer datasources --storage "$STORAGE" show exono >/dev/null 2>&1; then
  echo "Datasource 'exono' missing — creating..."
  python -m slayer datasources --storage "$STORAGE" create \
    "postgresql://${DB_USER}:${SLAYER_READONLY_PASSWORD}@${DB_HOST}:5432/${DB_NAME}" \
    --name exono
fi

# Re-ingest only when table list changes
CURRENT_HASH=$(PGPASSWORD="$SLAYER_READONLY_PASSWORD" psql \
  -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -t -A \
  -c "SELECT table_name FROM information_schema.tables
      WHERE table_schema='public' AND table_type='BASE TABLE'
      ORDER BY 1;" 2>/dev/null | sha256sum | cut -d' ' -f1)

SCHEMA_HASH_FILE="$STORAGE/.schema_hash"
STORED_HASH=""
[[ -f "$SCHEMA_HASH_FILE" ]] && STORED_HASH=$(cat "$SCHEMA_HASH_FILE")

if [[ "$CURRENT_HASH" != "$STORED_HASH" ]]; then
  echo "Table list changed — ingesting datasource 'exono'..."
  python -m slayer ingest --datasource exono --storage "$STORAGE"
  echo "$CURRENT_HASH" > "$SCHEMA_HASH_FILE"
else
  echo "Schema unchanged — skipping ingest."
fi

echo "Starting Slayer on port $PORT..."
exec python -m slayer serve \
  --storage "$STORAGE" \
  --host 0.0.0.0 \
  --port "$PORT"
