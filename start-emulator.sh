#!/bin/bash

# Script to start Android emulator for testing TimeLatency
# This script sets up the Android SDK paths and launches the emulator

# Set Android SDK path
export ANDROID_HOME=~/Library/Android/sdk
export ANDROID_SDK_ROOT=~/Library/Android/sdk
export PATH=$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$ANDROID_HOME/tools:$PATH

# Check if emulator exists
if [ ! -f "$ANDROID_HOME/emulator/emulator" ]; then
    echo "Error: Android emulator not found at $ANDROID_HOME/emulator/emulator"
    exit 1
fi

# List available AVDs
echo "Available Android Virtual Devices:"
$ANDROID_HOME/emulator/emulator -list-avds

# Check if AVD name is provided as argument
if [ -z "$1" ]; then
    # Use the first available AVD or default
    AVD_NAME=$(~/Library/Android/sdk/emulator/emulator -list-avds | head -1)
    if [ -z "$AVD_NAME" ]; then
        echo "Error: No AVD found. Please create an AVD first."
        echo "You can create one using Android Studio or the command line."
        exit 1
    fi
    echo "Using AVD: $AVD_NAME"
else
    AVD_NAME=$1
fi

# Start the emulator
echo "Starting emulator: $AVD_NAME"
echo "This may take a minute or two..."
$ANDROID_HOME/emulator/emulator -avd "$AVD_NAME" &

# Wait for emulator to boot
echo "Waiting for emulator to boot..."
$ANDROID_HOME/platform-tools/adb wait-for-device

# Wait a bit more for the system to fully start
sleep 5

# Check if device is ready
DEVICE_STATE=$($ANDROID_HOME/platform-tools/adb shell getprop sys.boot_completed | tr -d '\r')
while [ "$DEVICE_STATE" != "1" ]; do
    echo "Waiting for device to fully boot..."
    sleep 2
    DEVICE_STATE=$($ANDROID_HOME/platform-tools/adb shell getprop sys.boot_completed | tr -d '\r')
done

echo "Emulator is ready!"
echo "You can now build and install your app to test TimeLatency."

