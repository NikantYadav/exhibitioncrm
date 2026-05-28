#!/usr/bin/env bash
# Reads .env and runs Flutter with Supabase config injected via --dart-define.
# Usage:
#   ./run.sh                        # flutter run (debug, default device)
#   ./run.sh -d chrome              # run on Chrome
#   ./run.sh build apk              # flutter build apk
#   ./run.sh build web              # flutter build web

set -euo pipefail

ENV_FILE="$(dirname "$0")/.env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Error: .env file not found at $ENV_FILE" >&2
  exit 1
fi

# Parse .env — skip blank lines and comments
declare -A env_vars
while IFS='=' read -r key value; do
  [[ -z "$key" || "$key" == \#* ]] && continue
  # Strip inline comments and surrounding whitespace/quotes
  value="${value%%#*}"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  value="${value#\'}" ; value="${value%\'}"
  value="${value#\"}" ; value="${value%\"}"
  env_vars["$key"]="$value"
done < "$ENV_FILE"

SUPABASE_URL="${env_vars[SUPABASE_URL]:-}"
SUPABASE_ANON_KEY="${env_vars[SUPABASE_ANON_KEY]:-}"

if [[ -z "$SUPABASE_URL" || -z "$SUPABASE_ANON_KEY" ]]; then
  echo "Error: SUPABASE_URL and SUPABASE_ANON_KEY must be set in .env" >&2
  exit 1
fi

DEFINES=(
  "--dart-define=SUPABASE_URL=$SUPABASE_URL"
  "--dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY"
)

# First arg can be a flutter subcommand (run, build, test, etc.)
SUBCMD="${1:-run}"
shift || true

echo "→ flutter $SUBCMD ${DEFINES[*]} $*"
flutter "$SUBCMD" "${DEFINES[@]}" "$@"
