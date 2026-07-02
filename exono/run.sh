#!/usr/bin/env bash
# Reads .env and runs Flutter with Supabase config injected via --dart-define.
# Usage:
#   ./run.sh                        # flutter run (debug, default device)
#   ./run.sh -d chrome              # run on Chrome
#   ./run.sh -d waydroid -h 1920 -w 1080   # boot waydroid at HxW, then run on it
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
API_BASE_URL="${env_vars[API_BASE_URL]:-https://exhibitioncrm.vercel.app/}"
SENTRY_DSN="${env_vars[SENTRY_DSN]:-}"
SENTRY_ENV="${env_vars[SENTRY_ENV]:-development}"
UXCAM_APP_KEY="${env_vars[UXCAM_APP_KEY]:-}"

if [[ -z "$SUPABASE_URL" || -z "$SUPABASE_ANON_KEY" ]]; then
  echo "Error: SUPABASE_URL and SUPABASE_ANON_KEY must be set in .env" >&2
  exit 1
fi

DEFINES=(
  "--dart-define=SUPABASE_URL=$SUPABASE_URL"
  "--dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY"
  "--dart-define=API_BASE_URL=$API_BASE_URL"
  "--dart-define=SENTRY_DSN=$SENTRY_DSN"
  "--dart-define=SENTRY_ENV=$SENTRY_ENV"
  "--dart-define=UXCAM_APP_KEY=$UXCAM_APP_KEY"
)

# Waydroid: when invoked as `-d waydroid -h <height> -w <width>`, boot Waydroid
# at the requested resolution, connect adb, and then run flutter on that device.
# We pull -h/-w out of the args (they are not flutter flags) and translate
# `-d waydroid` into the actual adb device id below.
WAYDROID=0
WD_HEIGHT=""
WD_WIDTH=""
WD_DENSITY=""
REMAINING_ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -d)
      if [[ "${2:-}" == "waydroid" ]]; then
        WAYDROID=1
        shift 2
      else
        REMAINING_ARGS+=("$1" "${2:-}")
        shift 2
      fi
      ;;
    -h)
      WD_HEIGHT="${2:-}"
      shift 2
      ;;
    -w)
      WD_WIDTH="${2:-}"
      shift 2
      ;;
    --density|-density)
      WD_DENSITY="${2:-}"
      shift 2
      ;;
    *)
      REMAINING_ARGS+=("$1")
      shift
      ;;
  esac
done
set -- "${REMAINING_ARGS[@]+"${REMAINING_ARGS[@]}"}"

if [[ "$WAYDROID" == "1" ]]; then
  if [[ -z "$WD_WIDTH" || -z "$WD_HEIGHT" ]]; then
    echo "Error: -d waydroid requires both -w <width> and -h <height>" >&2
    exit 1
  fi
  WAYDROID_BIN=(/usr/bin/python3 /usr/bin/waydroid)

  # Tear down Waydroid when run.sh exits — whether that's Ctrl-C (SIGINT),
  # flutter's `q` quit (flutter exits, script falls through to EXIT), or a
  # normal/erroring end. Guarded so it only runs once and never masks the
  # original exit status.
  waydroid_cleanup() {
    trap - INT TERM EXIT
    echo
    echo "→ Stopping Waydroid session/container"
    "${WAYDROID_BIN[@]}" session stop >/dev/null 2>&1 || true
    sudo systemctl stop waydroid-container >/dev/null 2>&1 || true
  }
  trap waydroid_cleanup INT TERM EXIT

  echo "→ Setting Waydroid resolution to ${WD_WIDTH}x${WD_HEIGHT}"
  "${WAYDROID_BIN[@]}" prop set persist.waydroid.width "$WD_WIDTH"
  "${WAYDROID_BIN[@]}" prop set persist.waydroid.height "$WD_HEIGHT"

  # Waydroid has no internet unless the host forwards/NATs its traffic. Enable
  # IP forwarding and allow the FORWARD chain so the container can reach the net.
  echo "→ Enabling network forwarding for Waydroid"
  sudo sysctl -w net.ipv4.ip_forward=1 >/dev/null
  sudo iptables -P FORWARD ACCEPT

  echo "→ Restarting waydroid-container"
  sudo systemctl restart waydroid-container

  # `session start` blocks until the session is up, so background it; the
  # status poll below is what we actually gate on. `show-full-ui` opens the
  # device window and also blocks, so it must be backgrounded too.
  echo "→ Starting Waydroid session"
  "${WAYDROID_BIN[@]}" session start >/dev/null 2>&1 &
  "${WAYDROID_BIN[@]}" show-full-ui >/dev/null 2>&1 &

  # Wait for the CONTAINER (not just the session) to be RUNNING. Waydroid freezes
  # the container whenever no UI window is in the foreground, and a FROZEN
  # container is unreachable over adb ("No route to host" / device shows
  # `offline`). `show-full-ui` above thaws it; we gate on `Container: RUNNING`
  # so we don't read a stale IP / connect before the device is actually awake.
  echo "→ Waiting for Waydroid container to be RUNNING"
  # `|| true` keeps `set -e` from aborting while status/grep exit non-zero.
  WD_IP=""
  for _ in $(seq 1 90); do
    status="$("${WAYDROID_BIN[@]}" status 2>/dev/null || true)"
    if grep -qiE 'Container:[[:space:]]*RUNNING' <<<"$status"; then
      WD_IP="$(grep -i 'IP address' <<<"$status" | awk '{print $NF}')"
      [[ "$WD_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && break
    fi
    WD_IP=""
    sleep 2
  done
  if [[ -z "$WD_IP" ]]; then
    echo "Error: timed out waiting for Waydroid container to be RUNNING" >&2
    exit 1
  fi

  echo "→ Connecting adb to ${WD_IP}:5555"
  # Networking can lag the session being RUNNING, so retry until the device
  # shows up as `device` (not `offline`/unreachable) in adb.
  connected=0
  for _ in $(seq 1 30); do
    adb connect "${WD_IP}:5555" >/dev/null 2>&1 || true
    if adb -s "${WD_IP}:5555" get-state 2>/dev/null | grep -q '^device$'; then
      connected=1
      break
    fi
    sleep 2
  done
  if [[ "$connected" != "1" ]]; then
    echo "Error: could not reach Waydroid via adb at ${WD_IP}:5555" >&2
    exit 1
  fi
  echo "→ adb device ${WD_IP}:5555 ready"

  # Match screen density to resolution so the UI looks like a real phone instead
  # of a congested high-DPI panel. A phone's baseline is ~360dp wide at 160dpi,
  # so density = width / 360 * 160 ≈ width * 0.444. Override with --density N.
  if [[ -z "$WD_DENSITY" ]]; then
    WD_DENSITY=$(( (WD_WIDTH * 160 + 180) / 360 ))   # rounded
  fi
  echo "→ Setting screen density to ${WD_DENSITY}dpi (width ${WD_WIDTH})"
  adb -s "${WD_IP}:5555" shell wm density "$WD_DENSITY" >/dev/null 2>&1 || true

  # Inside Waydroid, localhost is Android itself, NOT the host. When the backend
  # URL is local, tunnel it to the host with `adb reverse` so localhost:<port>
  # in the container reaches the same port on the dev machine. This keeps
  # API_BASE_URL as http://localhost unchanged (no app-side config change), so
  # nothing about the production build/config is touched.
  if [[ "$API_BASE_URL" == http://localhost:* || "$API_BASE_URL" == http://127.0.0.1:* ]]; then
    # Extract the port (the digits right after host: in http://host:PORT/...).
    LOCAL_PORT="$(sed -E 's#^http://[^:/]+:([0-9]+).*#\1#' <<<"$API_BASE_URL")"
    if [[ "$LOCAL_PORT" =~ ^[0-9]+$ ]]; then
      echo "→ adb reverse tcp:${LOCAL_PORT} → host localhost:${LOCAL_PORT}"
      adb -s "${WD_IP}:5555" reverse "tcp:${LOCAL_PORT}" "tcp:${LOCAL_PORT}" || true
    fi
  fi

  # Route flutter to this device.
  set -- -d "${WD_IP}:5555" "$@"
fi

# Wireless-debugging / plugged-in physical Android devices: localhost inside
# the device is the device itself, not this machine, so a local backend
# (API_BASE_URL=http://localhost:PORT/...) is unreachable unless we tunnel it
# over adb. Waydroid already does this above; mirror it here for any other
# connected device so the same .env works for both without edits.
if [[ "$WAYDROID" != "1" && ( "$API_BASE_URL" == http://localhost:* || "$API_BASE_URL" == http://127.0.0.1:* ) ]]; then
  LOCAL_PORT="$(sed -E 's#^http://[^:/]+:([0-9]+).*#\1#' <<<"$API_BASE_URL")"
  if [[ "$LOCAL_PORT" =~ ^[0-9]+$ ]]; then
    # Respect an explicit -d <device> if given; otherwise reverse on every
    # currently-connected/authorized adb device (harmless if there's just one).
    TARGET_DEVICE=""
    for ((i = 0; i < ${#REMAINING_ARGS[@]}; i++)); do
      if [[ "${REMAINING_ARGS[$i]}" == "-d" ]]; then
        TARGET_DEVICE="${REMAINING_ARGS[$((i + 1))]:-}"
        break
      fi
    done
    if [[ -n "$TARGET_DEVICE" ]]; then
      echo "→ adb -s $TARGET_DEVICE reverse tcp:${LOCAL_PORT} → host localhost:${LOCAL_PORT}"
      adb -s "$TARGET_DEVICE" reverse "tcp:${LOCAL_PORT}" "tcp:${LOCAL_PORT}" || true
    else
      while IFS=$'\t' read -r device state; do
        [[ "$state" == "device" ]] || continue
        echo "→ adb -s $device reverse tcp:${LOCAL_PORT} → host localhost:${LOCAL_PORT}"
        adb -s "$device" reverse "tcp:${LOCAL_PORT}" "tcp:${LOCAL_PORT}" || true
      done < <(adb devices | tail -n +2)
    fi
  fi
fi

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
  # For "build <target>", extract the target so defines come after it
  if [[ "$SUBCMD" == "build" && $# -gt 0 && "$1" != -* ]]; then
    BUILD_TARGET="$1"
    shift
    echo "→ flutter $SUBCMD $BUILD_TARGET ${DEFINES[*]} $*"
    flutter "$SUBCMD" "$BUILD_TARGET" "${DEFINES[@]}" "$@"
    exit $?
  fi
else
  SUBCMD="run"
fi

echo "→ flutter $SUBCMD ${DEFINES[*]} $*"
flutter "$SUBCMD" "${DEFINES[@]}" "$@"
