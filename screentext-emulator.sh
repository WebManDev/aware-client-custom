#!/usr/bin/env bash
#
# One-shot: Android SDK on PATH → start emulator (if needed) → pull ScreenText DBs.
#
# Usage:
#   bash screentext-emulator.sh                 # start AVD if needed, pull, extract (--engine all)
#   bash screentext-emulator.sh --pull-only     # only pull + extract (emulator must be running)
#   bash screentext-emulator.sh --no-extract     # pull only, no extract_searches.py
#
# Env:
#   ANDROID_HOME          default: ~/Library/Android/sdk
#   SCREENTEXT_AVD        default: Medium_Phone_API_36.0
#   EMULATOR_DNS_SERVERS  default: 8.8.8.8,1.1.1.1  (passed to emulator -dns-server;
#                         helps Yahoo / regional sites that hammer DNS on the AVD)
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=emulator-dns.inc.sh
source "$REPO_ROOT/emulator-dns.inc.sh"

AVD="${SCREENTEXT_AVD:-Medium_Phone_API_36.0}"
ADB="$ANDROID_HOME/platform-tools/adb"
EMULATOR_BIN="$ANDROID_HOME/emulator/emulator"
LOG="${TMPDIR:-/tmp}/aware-screentext-emulator.log"

PULL_ONLY=0
NO_EXTRACT=0
for arg in "$@"; do
  case "$arg" in
    --pull-only) PULL_ONLY=1 ;;
    --no-extract) NO_EXTRACT=1 ;;
  esac
done

device_connected() {
  # Any line: serial + tab + "device" (not "offline" / "unauthorized")
  "$ADB" devices 2>/dev/null | awk 'NR>1 && $2=="device" { f=1 } END { exit !f }'
}

wait_for_boot() {
  echo "Waiting for adb device..."
  local i=0
  until "$ADB" shell echo ok 2>/dev/null | grep -q ok; do
    sleep 2
    i=$((i + 1))
    if [[ $i -gt 120 ]]; then
      echo "error: adb did not see a device within ~4 minutes." >&2
      exit 1
    fi
  done
  echo "Waiting for Android boot (sys.boot_completed)..."
  local state=""
  for _ in $(seq 1 90); do
    state=$("$ADB" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || echo 0)
    if [[ "$state" == "1" ]]; then
      echo "Emulator is ready: $("$ADB" devices -l | grep device | head -1)"
      return 0
    fi
    sleep 2
  done
  echo "error: boot did not complete in time." >&2
  exit 1
}

if [[ ! -x "$EMULATOR_BIN" ]]; then
  echo "error: emulator not found at $EMULATOR_BIN" >&2
  echo "Install Android Studio → SDK, or set ANDROID_HOME." >&2
  exit 1
fi

if [[ "$PULL_ONLY" -eq 1 ]]; then
  if ! device_connected; then
    echo "error: no device/emulator connected. Start the emulator or omit --pull-only." >&2
    exit 1
  fi
else
  if device_connected; then
    echo "Device already connected; skipping emulator start."
    "$ADB" devices -l
  else
    if ! "$EMULATOR_BIN" -list-avds 2>/dev/null | grep -qx "$AVD"; then
      echo "error: AVD '$AVD' not found. Available:" >&2
      "$EMULATOR_BIN" -list-avds >&2 || true
      exit 1
    fi
    echo "Starting emulator AVD: $AVD (DNS: $EMULATOR_DNS_SERVERS) (log: $LOG)"
    nohup "$EMULATOR_BIN" -avd "$AVD" -no-boot-anim \
      -dns-server "$EMULATOR_DNS_SERVERS" >>"$LOG" 2>&1 &
    echo "Emulator PID $!"
    # New emulator listens on emulator-5554 first
    sleep 3
    wait_for_boot
  fi
fi

cd "$REPO_ROOT"
echo ""
echo "Pulling screentext*.db → screentext_dbs/"
# Use the same device adb picks (first online)
SERIAL=$("$ADB" devices | awk '/\tdevice$/{print $1; exit}')
if [[ -n "${SERIAL:-}" ]]; then
  bash "$REPO_ROOT/pull_screentext_dbs.sh" "$SERIAL"
else
  bash "$REPO_ROOT/pull_screentext_dbs.sh"
fi

if [[ "$NO_EXTRACT" -eq 0 ]]; then
  echo ""
  echo "Extracting searches from pulled DBs (--engine all)..."
  shopt -s nullglob
  for db in "$REPO_ROOT"/screentext_dbs/*.db; do
    [[ -s "$db" ]] || continue
    echo "---------- $(basename "$db") ----------"
    python3 "$REPO_ROOT/extract_searches.py" "$db" --engine all || true
    echo ""
  done
fi

echo "Done."
