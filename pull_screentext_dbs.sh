#!/usr/bin/env bash
set -euo pipefail

ADB_DEVICE="${1:-emulator-5554}"

echo "Pulling screentext*.db from emulator (${ADB_DEVICE}) into repo..."

# Export-internal folder (matches ViewDataActivity internalCopy destination)
INTERNAL_DIR="files"

mkdir -p "./screentext_dbs"

pull_one () {
  name="$1"
  tmp="./screentext_dbs/${name}"
  # Only pull if the file exists inside the app's internal storage.
  if adb -s "${ADB_DEVICE}" shell "run-as com.aware.tests test -f /data/data/com.aware.tests/${INTERNAL_DIR}/${name}" >/dev/null 2>&1; then
    adb -s "${ADB_DEVICE}" exec-out run-as com.aware.tests cat "${INTERNAL_DIR}/${name}" > "${tmp}" 2>/dev/null || true
  fi
}

# Pull a reasonable range; add more if you expect more exports.
pull_one "screentext.db"
for i in {2..20}; do
  pull_one "screentext${i}.db"
done

echo "Done. Files in ./screentext_dbs:"
ls -la ./screentext_dbs | sed -n '1,50p'

