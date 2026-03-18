#!/bin/bash

# Script to build and install the test app for TimeLatency testing

# Set Android SDK path
export ANDROID_HOME=~/Library/Android/sdk
export ANDROID_SDK_ROOT=~/Library/Android/sdk
export PATH=$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$PATH

# Try to find and set JAVA_HOME
if [ -z "$JAVA_HOME" ]; then
    if [ -d "/opt/homebrew/opt/openjdk@11" ]; then
        export JAVA_HOME=/opt/homebrew/opt/openjdk@11
    elif [ -d "/Library/Java/JavaVirtualMachines/temurin-11.jdk/Contents/Home" ]; then
        export JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-11.jdk/Contents/Home
    elif [ -d "/Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home" ]; then
        export JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home
    fi
fi

if [ -n "$JAVA_HOME" ]; then
    export PATH=$JAVA_HOME/bin:$PATH
fi

# Check if device is connected
echo "Checking for connected devices..."
DEVICES=$($ANDROID_HOME/platform-tools/adb devices | grep -v "List" | grep "device" | wc -l | tr -d ' ')

if [ "$DEVICES" -eq "0" ]; then
    echo "Error: No Android device or emulator found."
    echo "Please start an emulator first using: ./start-emulator.sh"
    exit 1
fi

echo "Found $DEVICES device(s)"
$ANDROID_HOME/platform-tools/adb devices

# Build the test app
echo ""
echo "Building the test app..."
./gradlew :aware-tests:assembleDebug

if [ $? -ne 0 ]; then
    echo "Build failed!"
    exit 1
fi

# Install the test app
echo ""
echo "Installing test app on device..."
$ANDROID_HOME/platform-tools/adb install -r aware-tests/build/outputs/apk/debug/aware-tests-debug.apk

if [ $? -eq 0 ]; then
    echo ""
    echo "Test app installed successfully!"
    echo ""
    echo "To test TimeLatency:"
    echo "1. Open the 'AWARE Tests' app on your emulator"
    echo "2. Tap the 'Test TimeLatency' button"
    echo "3. Answer the question and see the timing results!"
    echo ""
    echo "You can also launch it directly with:"
    echo "  adb shell am start -n com.aware.tests/.TestActivity"
else
    echo "Installation failed!"
    exit 1
fi

