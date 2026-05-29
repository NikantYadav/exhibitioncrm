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

echo "→ Starting Slayer on http://localhost:5143 (storage: $SCRIPT_DIR/slayer_data)"
exec "$SCRIPT_DIR/env/bin/python" -m slayer serve \
  --storage "$SCRIPT_DIR/slayer_data" \
  --host 127.0.0.1 \
  --port 5143 \
  --ingest-on-startup
