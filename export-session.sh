#!/usr/bin/env bash
#
# Export ScreenText data from the emulator to your Mac in one step.
#
# Usage:
#   bash export-session.sh session3_dog
#   bash export-session.sh my_test
#
# What it does:
#   1. Triggers an export on the emulator (creates a new screentext*.db)
#   2. Waits for the file to appear
#   3. Pulls it to screentext_dbs/<name>.db
#   4. Runs extract_searches.py on it
#   5. Opens the folder in Finder
#
set -euo pipefail

ADB="${ADB:-$(command -v adb 2>/dev/null || echo "$HOME/Library/Android/sdk/platform-tools/adb")}"
DEST_DIR="./screentext_dbs"

if [ $# -lt 1 ]; then
    echo "Usage: bash export-session.sh <session_name>"
    echo "  e.g. bash export-session.sh session3_dog"
    exit 1
fi

SESSION_NAME="$1"
DEST_FILE="${DEST_DIR}/${SESSION_NAME}.db"

if [ -f "$DEST_FILE" ]; then
    echo "Error: ${DEST_FILE} already exists. Pick a different name or delete it first."
    exit 1
fi

mkdir -p "$DEST_DIR"

# --- Step 1: snapshot which files exist before export ---
echo "Checking emulator..."
"$ADB" shell "echo ok" >/dev/null 2>&1 || { echo "Error: no emulator/device connected. Run: ~/Library/Android/sdk/emulator/emulator -avd Medium_Phone_API_36.0 &"; exit 1; }

BEFORE=$("$ADB" shell "run-as com.aware.tests ls files/" 2>/dev/null | grep '\.db$' | sort)

# --- Step 2: trigger export via intent ---
echo "Triggering export on emulator..."
"$ADB" shell "am start -a com.aware.tests.EXPORT_DB -n com.aware.tests/.ViewDataActivity" >/dev/null 2>&1
sleep 2

# --- Step 3: find the new file ---
AFTER=$("$ADB" shell "run-as com.aware.tests ls files/" 2>/dev/null | grep '\.db$' | sort)
NEW_FILE=$(comm -13 <(echo "$BEFORE") <(echo "$AFTER") | tail -1)

if [ -z "$NEW_FILE" ]; then
    echo "No new file created. The ContentProvider might be empty (nothing to export)."
    echo "Files on emulator:"
    "$ADB" shell "run-as com.aware.tests ls -la files/"
    exit 1
fi

NEW_FILE=$(echo "$NEW_FILE" | tr -d '\r')

# --- Step 4: pull to Mac ---
echo "Pulling ${NEW_FILE} -> ${DEST_FILE}"
"$ADB" exec-out run-as com.aware.tests cat "files/${NEW_FILE}" > "$DEST_FILE"

# Verify it's a real SQLite file
if ! file "$DEST_FILE" | grep -q "SQLite"; then
    echo "Error: pulled file is not a valid SQLite database."
    rm -f "$DEST_FILE"
    exit 1
fi

# --- Step 5: extract and show ---
echo ""
python3 extract_searches.py "$DEST_FILE"

echo ""
echo "Saved to: ${DEST_FILE}"

# --- Step 6: open in Finder ---
open "$DEST_DIR"
