# Source-only: sets SDK path + public DNS defaults for Android Emulator.
#   source "$(dirname "$0")/emulator-dns.inc.sh"
# Fixes many DNS_PROBE_* errors (Yahoo / regional URLs) on macOS AVDs.
if [[ -z "${ANDROID_HOME:-}" ]]; then
  export ANDROID_HOME="$HOME/Library/Android/sdk"
fi
export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$ANDROID_HOME}"
export EMULATOR_DNS_SERVERS="${EMULATOR_DNS_SERVERS:-8.8.8.8,1.1.1.1}"
export PATH="$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$PATH"
if [[ -d "$ANDROID_HOME/tools" ]]; then
  export PATH="$PATH:$ANDROID_HOME/tools"
fi
