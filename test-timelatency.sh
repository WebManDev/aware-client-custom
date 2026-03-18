#!/bin/bash

# Script to help test TimeLatency functionality
# This script provides utilities to test the TimeLatency sensor

# Set Android SDK path
export ANDROID_HOME=~/Library/Android/sdk
export ANDROID_SDK_ROOT=~/Library/Android/sdk
export PATH=$ANDROID_HOME/platform-tools:$PATH

echo "TimeLatency Testing Helper"
echo "=========================="
echo ""

# Check if device is connected
DEVICES=$($ANDROID_HOME/platform-tools/adb devices | grep -v "List" | grep "device" | wc -l | tr -d ' ')

if [ "$DEVICES" -eq "0" ]; then
    echo "Error: No Android device or emulator found."
    echo "Please start an emulator first using: ./start-emulator.sh"
    exit 1
fi

echo "Device connected: ✓"
echo ""

# Show logcat for TimeLatency related logs
echo "Monitoring TimeLatency logs..."
echo "Press Ctrl+C to stop"
echo ""
echo "Filtering for TimeLatency related logs..."
$ANDROID_HOME/platform-tools/adb logcat | grep -i "timelatency\|time_latency\|question"

