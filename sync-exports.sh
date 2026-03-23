#!/usr/bin/env bash
#
# Runs in the background. Watches the emulator for new export files
# and auto-copies them to ~/Downloads when they appear.
#
# Start it once:
#   bash sync-exports.sh &
#
# Stop it:
#   kill %1   (or close the terminal)
#
set -euo pipefail

ADB="${ADB:-$(command -v adb 2>/dev/null || echo "$HOME/Library/Android/sdk/platform-tools/adb")}"
DEST="$HOME/Downloads"
POLL_INTERVAL=2

KNOWN_FILES=""

echo "Watching emulator for new exports → ~/Downloads"
echo "Press Ctrl+C to stop."
echo ""

update_known_files() {
    KNOWN_FILES=$("$ADB" shell "run-as com.aware.tests ls files/ 2>/dev/null" 2>/dev/null | tr -d '\r' | sort || echo "")
}

update_known_files

while true; do
    sleep "$POLL_INTERVAL"

    CURRENT=$("$ADB" shell "run-as com.aware.tests ls files/ 2>/dev/null" 2>/dev/null | tr -d '\r' | sort || echo "")

    NEW_FILES=$(comm -13 <(echo "$KNOWN_FILES") <(echo "$CURRENT") || true)

    if [ -n "$NEW_FILES" ]; then
        while IFS= read -r fname; do
            [ -z "$fname" ] && continue
            dest_path="${DEST}/${fname}"
            echo "New file: ${fname} → ${dest_path}"
            "$ADB" exec-out run-as com.aware.tests cat "files/${fname}" > "$dest_path" 2>/dev/null || true

            if file "$dest_path" | grep -q "SQLite\|CSV\|ASCII\|UTF-8"; then
                osascript -e "display notification \"${fname} saved to Downloads\" with title \"ScreenText Export\"" 2>/dev/null || true
                echo "  ✓ Saved and notified"
            else
                echo "  ✓ Saved"
            fi
        done <<< "$NEW_FILES"
    fi

    KNOWN_FILES="$CURRENT"
done
