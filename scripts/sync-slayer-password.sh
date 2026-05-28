#!/usr/bin/env bash
# sync-slayer-password.sh
# Thin wrapper — delegates to the Node.js script in the same directory.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec node "$SCRIPT_DIR/sync-slayer-password.mjs" "$@"
