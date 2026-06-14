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
while IFS='=' read -r key value || [[ -n "$key" ]]; do
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
API_BASE_URL="${env_vars[API_BASE_URL]:-http://localhost:3001/api}"

if [[ -z "$SUPABASE_URL" || -z "$SUPABASE_ANON_KEY" ]]; then
  echo "Error: SUPABASE_URL and SUPABASE_ANON_KEY must be set in .env" >&2
  exit 1
fi

DEFINES=(
  "--dart-define=SUPABASE_URL=$SUPABASE_URL"
  "--dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY"
  "--dart-define=API_BASE_URL=$API_BASE_URL"
)

# Use a native (non-Flatpak) Chromium/Chrome for web. A Flatpak-sandboxed
# browser brokers the file dialog through the XDG portal, which never returns
# the selection to the page, so the image-upload picker silently does nothing.
# Force a native binary unless CHROME_EXECUTABLE already points to one.
if [[ -z "${CHROME_EXECUTABLE:-}" || "$CHROME_EXECUTABLE" == *flatpak* ]]; then
  unset CHROME_EXECUTABLE
  for candidate in \
    /usr/bin/chromium \
    /usr/bin/chromium-browser \
    /usr/bin/google-chrome-stable \
    /usr/bin/google-chrome; do
    if [[ -x "$candidate" ]]; then
      export CHROME_EXECUTABLE="$candidate"
      break
    fi
  done
fi

if [[ -n "${CHROME_EXECUTABLE:-}" ]]; then
  echo "→ CHROME_EXECUTABLE=$CHROME_EXECUTABLE"
fi

# First arg is a flutter subcommand only if it's not a flag (e.g. "build",
# "test"). Bare "./run.sh" or "./run.sh -d chrome" both default to "run".
if [[ $# -gt 0 && "$1" != -* ]]; then
  SUBCMD="$1"
  shift
else
  SUBCMD="run"
fi

echo "→ flutter $SUBCMD ${DEFINES[*]} $*"
flutter "$SUBCMD" "${DEFINES[@]}" "$@"
