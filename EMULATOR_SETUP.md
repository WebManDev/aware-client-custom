# Android Emulator Setup Guide for TimeLatency Testing

This guide will help you set up an Android emulator to test your `TimeLatency` sensor.

## Prerequisites

- Android SDK is installed at `~/Library/Android/sdk`
- Java Development Kit (JDK) installed
- Gradle installed (or use the Gradle wrapper included in the project)

## Quick Start

### 1. Start the Emulator

You can use the existing AVD or create a new one:

```bash
# Make scripts executable
chmod +x start-emulator.sh build-and-install.sh test-timelatency.sh

# Start the emulator (uses the first available AVD)
./start-emulator.sh

# Or specify an AVD name
./start-emulator.sh Medium_Phone_API_36.0
```

### 2. Build and Install the App

Once the emulator is running:

```bash
./build-and-install.sh
```

This will:
- Build the debug APK
- Install it on the emulator

### 3. Test TimeLatency

You can monitor logs while testing:

```bash
# In a separate terminal, monitor TimeLatency logs
./test-timelatency.sh
```

## Manual Setup

### Option 1: Using Android Studio

1. Open Android Studio
2. Go to **Tools > Device Manager**
3. Click **Create Device**
4. Select a device (e.g., Pixel 4)
5. Select a system image:
   - **Recommended**: API 28 (Android 9.0 Pie) to match your project's target SDK
   - **Alternative**: API 35/36 (will work due to backward compatibility)
6. Click **Finish**
7. Start the emulator from Device Manager

### Option 2: Using Command Line

#### Install System Image (if needed)

If you need SDK 28 system image:

```bash
export ANDROID_HOME=~/Library/Android/sdk
export ANDROID_SDK_ROOT=~/Library/Android/sdk

# Find sdkmanager location
SDKMANAGER=$(find $ANDROID_HOME -name sdkmanager | head -1)

# Install system image for API 28
$SDKMANAGER "system-images;android-28;google_apis;x86_64"
```

#### Create AVD

```bash
export ANDROID_HOME=~/Library/Android/sdk
export ANDROID_SDK_ROOT=~/Library/Android/sdk

# Create AVD (replace with your system image path)
$ANDROID_HOME/emulator/emulator -avd <AVD_NAME> -list-avds  # First, list available
avdmanager create avd -n TimeLatencyTest -k "system-images;android-28;google_apis;x86_64"
```

## Testing TimeLatency

### Understanding TimeLatency

Your `TimeLatency` class tracks:
- **Start time**: When a question appears (`startTime(questionId)`)
- **End time**: When a question is answered (`questionAnswered(questionId)`)
- **Duration**: Calculated as `end_time - start_time`

### Testing Steps

1. **Launch the app** on the emulator
2. **Trigger a question** in your app
3. **Call `startTime(questionId)`** when the question appears
4. **Answer the question** (simulate user interaction)
5. **Call `questionAnswered(questionId)`** when answered
6. **Check the logs** to see timing data

### View Logs

```bash
# View all logs
adb logcat

# Filter for your app
adb logcat | grep "com.aware.phone"

# Filter for TimeLatency
adb logcat | grep -i "timelatency"
```

### Debugging Tips

1. **Check if emulator is connected**:
   ```bash
   adb devices
   ```

2. **View app logs**:
   ```bash
   adb logcat -s "YourAppTag"
   ```

3. **Uninstall and reinstall**:
   ```bash
   adb uninstall com.aware.phone
   ./build-and-install.sh
   ```

4. **Clear app data**:
   ```bash
   adb shell pm clear com.aware.phone
   ```

## Troubleshooting

### Emulator won't start
- Check if virtualization is enabled in your system BIOS
- Try using a different system image (x86_64 vs arm64)
- Increase emulator RAM in AVD settings

### App won't install
- Make sure emulator is fully booted (wait for home screen)
- Check `adb devices` shows the device
- Try uninstalling existing version first: `adb uninstall com.aware.phone`

### Build errors
- Make sure you're using the correct Java version
- Check that Android SDK path is correct
- Verify Gradle wrapper is working: `./gradlew --version`

### TimeLatency not working
- Check that `startTime()` is called before `questionAnswered()`
- Verify question IDs match between calls
- Add logging to see when methods are called
- Check that the TimeLatency instance is properly initialized

## Project Configuration

Your project is configured for:
- **Target SDK**: 28 (Android 9.0 Pie)
- **Minimum SDK**: 24 (Android 7.0 Nougat)
- **Application ID**: `com.aware.phone`

The existing AVD (API 36) will work fine due to Android's backward compatibility.

## Next Steps

1. Create a test activity or modify existing code to use TimeLatency
2. Add logging to see timing data
3. Test with multiple questions
4. Verify timing accuracy

For more information, see the `TimeLatency.java` source code comments.

