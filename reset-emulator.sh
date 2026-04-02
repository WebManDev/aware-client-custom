#!/usr/bin/env bash
#
# Hard reset: stop the Android Emulator, wipe AVD userdata, boot fresh with public DNS.
#
# Usage:
#   bash reset-emulator.sh                  # first listed AVD, or SCREENTEXT_AVD
#   bash reset-emulator.sh Medium_Phone_API_30
#
# Afterward: enable Accessibility for the test app again; ScreenText data is gone.
#
set -euo pipefail

_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=emulator-dns.inc.sh
source "$_REPO/emulator-dns.inc.sh"

ADB="$ANDROID_HOME/platform-tools/adb"
EMU="$ANDROID_HOME/emulator/emulator"

echo "Stopping adb / emulator processes…"
"$ADB" kill-server 2>/dev/null || true
sleep 1
"$ADB" start-server
# Android Emulator is backed by QEMU
pkill -TERM -f "qemu-system.*-avd" 2>/dev/null || true
sleep 2
pkill -KILL -f "qemu-system.*-avd" 2>/dev/null || true
sleep 1

if [[ -n "${1:-}" ]]; then
  AVD="$1"
else
  AVD="${SCREENTEXT_AVD:-$("$EMU" -list-avds 2>/dev/null | head -1)}"
fi

if [[ -z "$AVD" ]]; then
  echo "error: no AVD name. Create one in Android Studio or pass: bash reset-emulator.sh Your_Avd_Name" >&2
  exit 1
fi

if ! printf '%s\n' "$("$EMU" -list-avds 2>/dev/null)" | grep -qx "$AVD"; then
  echo "error: AVD '$AVD' not found. Available:" >&2
  "$EMU" -list-avds >&2 || true
  exit 1
fi

LOG="${TMPDIR:-/tmp}/aware-emulator-reset.log"
echo ""
echo "Wiping userdata and starting: $AVD"
echo "  DNS: $EMULATOR_DNS_SERVERS  (-dns-server)"
echo "  Log: $LOG"
echo ""

nohup "$EMU" -avd "$AVD" -wipe-data -no-boot-anim \
  -dns-server "$EMULATOR_DNS_SERVERS" >>"$LOG" 2>&1 &
echo "Emulator PID $! — waiting for adb…"

i=0
until "$ADB" shell echo ok 2>/dev/null | grep -q ok; do
  sleep 2
  i=$((i + 1))
  if [[ $i -gt 120 ]]; then
    echo "error: device did not come online in time. See $LOG" >&2
    exit 1
  fi
done

echo "Waiting for boot (sys.boot_completed)…"
for _ in $(seq 1 90); do
  state=$("$ADB" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || echo 0)
  if [[ "$state" == "1" ]]; then
    "$ADB" devices -l
    echo ""
    echo "Reset complete. Re-enable Accessibility for AWARE Tests if you use ScreenText."
    exit 0
  fi
  sleep 2
done

echo "Boot still in progress; check $LOG or the emulator window."
exit 0
