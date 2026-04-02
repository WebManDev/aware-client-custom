#!/usr/bin/env bash
#
# Fix common Android Emulator DNS / "no internet" issues from the host (adb).
#
# Yahoo (especially regional URLs like au.search.yahoo.com) tends to trigger this more
# often than simple sites: more DNS lookups and redirects on the AVD’s flaky resolver.
# For a persistent fix, always boot the emulator with -dns-server (see start-emulator.sh
# and screentext-emulator.sh).
#
# Does NOT toggle Wi‑Fi via `svc wifi` — that often hangs or wedges the AVD.
#
# Usage:
#   bash fix-emulator-network.sh
#
# If adb shows "offline", close the emulator window and start it again (or Cold Boot
# from Device Manager), then run this script.
#
set -u
_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=emulator-dns.inc.sh
source "$_REPO/emulator-dns.inc.sh"
ADB="$ANDROID_HOME/platform-tools/adb"

if [[ ! -x "$ADB" ]]; then
  echo "error: adb not found at $ADB" >&2
  exit 1
fi

if ! "$ADB" devices 2>/dev/null | awk 'NR>1 && $2=="device" { f=1 } END { exit !f }'; then
  echo "No emulator/device in the \"device\" state."
  echo "  adb devices:"
  "$ADB" devices
  echo ""
  echo "If you see \"offline\": quit the emulator (or run: adb emu kill), start the AVD again,"
  echo "wait for the home screen, then re-run: bash fix-emulator-network.sh"
  exit 1
fi

echo "Applying: airplane mode off + Private DNS (dns.google) …"

"$ADB" shell cmd connectivity airplane-mode disable 2>/dev/null || true
"$ADB" shell settings put global airplane_mode_on 0 2>/dev/null || true

# Private DNS — fixes many DNS_PROBE_FINISHED_* errors on macOS-hosted emulators
"$ADB" shell settings put global private_dns_mode hostname
"$ADB" shell settings put global private_dns_specifier dns.google

echo ""
echo "Current settings:"
echo -n "  airplane_mode_on: "
"$ADB" shell settings get global airplane_mode_on
echo -n "  private_dns_mode: "
"$ADB" shell settings get global private_dns_mode
echo -n "  private_dns_specifier: "
"$ADB" shell settings get global private_dns_specifier
echo ""
echo "Done. In the emulator: open Chrome and try the page again."
echo "Host tips: pause VPN; if it still fails, Device Manager → Cold Boot AVD."
echo "Boot tip: bash ${_REPO}/start-emulator.sh (or screentext-emulator.sh) — uses emulator-dns.inc.sh"
echo "  so the AVD always gets -dns-server ${EMULATOR_DNS_SERVERS}."
