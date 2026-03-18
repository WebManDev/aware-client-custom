#!/bin/bash

# Script to build and install the AWARE app on the emulator
# This script builds the app and installs it on the connected emulator/device

# Set Android SDK path
export ANDROID_HOME=~/Library/Android/sdk
export ANDROID_SDK_ROOT=~/Library/Android/sdk
export PATH=$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$PATH

# Try to find and set JAVA_HOME
if [ -z "$JAVA_HOME" ]; then
    # Check for Homebrew Java installations
    if [ -d "/opt/homebrew/opt/openjdk@11" ]; then
        export JAVA_HOME=/opt/homebrew/opt/openjdk@11
    elif [ -d "/opt/homebrew/opt/openjdk@17" ]; then
        export JAVA_HOME=/opt/homebrew/opt/openjdk@17
    elif [ -d "/opt/homebrew/opt/openjdk" ]; then
        export JAVA_HOME=/opt/homebrew/opt/openjdk
    elif [ -d "/Library/Java/JavaVirtualMachines/temurin-11.jdk/Contents/Home" ]; then
        export JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-11.jdk/Contents/Home
    elif [ -d "/Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home" ]; then
        export JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home
    else
        # Try to use /usr/libexec/java_home if available
        JAVA_HOME_CMD=$(/usr/libexec/java_home 2>/dev/null)
        if [ $? -eq 0 ] && [ -n "$JAVA_HOME_CMD" ]; then
            export JAVA_HOME="$JAVA_HOME_CMD"
        fi
    fi
fi

# Add Java to PATH if JAVA_HOME is set
if [ -n "$JAVA_HOME" ]; then
    export PATH=$JAVA_HOME/bin:$PATH
    echo "Using Java at: $JAVA_HOME"
    java -version 2>&1 | head -1 || echo "Warning: Java found but may not be working"
else
    echo "Warning: JAVA_HOME not set. Java may not be found."
    echo "Please install Java 11 or 17:"
    echo "  brew install --cask temurin@11"
    echo "  OR"
    echo "  brew install --cask temurin@17"
    echo ""
    echo "Then run this script again."
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

# Build the app
echo ""
echo "Building the app..."
./gradlew assembleDebug

if [ $? -ne 0 ]; then
    echo "Build failed!"
    exit 1
fi

# Install the app
echo ""
echo "Installing app on device..."
$ANDROID_HOME/platform-tools/adb install -r aware-phone/build/outputs/apk/debug/aware-phone-debug.apk

if [ $? -eq 0 ]; then
    echo ""
    echo "App installed successfully!"
    echo "You can now launch the app and test TimeLatency."
else
    echo "Installation failed!"
    exit 1
fi

