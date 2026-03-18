# Testing TimeLatency

Your TimeLatency sensor is now set up and ready to test!

## Quick Start

1. **The test app is already installed** on your emulator
2. **Open the "AWARE Tests" app** on your emulator (or it may have opened automatically)
3. **Tap the "Test TimeLatency" button**
4. **Answer the question** that appears
5. **View the timing results** showing:
   - Start time (when question appeared)
   - End time (when you answered)
   - Time taken (duration in milliseconds and seconds)

## What Was Created

### Test Class
- `aware-tests/src/main/java/com/aware/tests/TestTimeLatency.java`
  - Creates a TimeLatency instance
  - Shows a question dialog
  - Records start time when question appears
  - Records end time when you answer
  - Displays timing results

### Test Activity
- Updated `TestActivity.java` to include a "Test TimeLatency" button
- Updated `activity_test.xml` layout to show the button

## How It Works

1. When you tap "Test TimeLatency":
   - A new `TimeLatency` instance is created
   - `startTime(questionId)` is called when the question dialog appears
   - The question ID and start timestamp are stored

2. When you answer the question:
   - `questionAnswered(questionId)` is called
   - The method finds the question by ID
   - Calculates: `time_taken = end_time - start_time`
   - Returns all timing data

3. Results are displayed showing:
   - Question ID
   - Your answer
   - Start time (milliseconds since epoch)
   - End time (milliseconds since epoch)
   - Time taken (milliseconds and seconds)

## Testing Multiple Questions

The test supports multiple questions:
- After viewing results, tap "Next Question"
- A new question will appear with a new ID
- Each question's timing is tracked independently

## Rebuilding and Reinstalling

If you make changes to TimeLatency.java:

```bash
# Build and install the test app
./test-timelatency-app.sh

# Or manually:
./gradlew :aware-tests:assembleDebug
adb install -r aware-tests/build/outputs/apk/debug/aware-tests-debug.apk
```

## Viewing Logs

To see detailed logs while testing:

```bash
# In a separate terminal
adb logcat | grep -i "timelatency"
```

Or use the provided script:
```bash
./test-timelatency.sh
```

## What to Test

1. **Basic functionality**: Answer a question and verify timing is calculated
2. **Multiple questions**: Test several questions in sequence
3. **Edge cases**: 
   - What happens if you try to answer a question that wasn't started?
   - Verify question IDs are tracked correctly
4. **Timing accuracy**: Check that the calculated time matches the actual time taken

## Expected Behavior

- ✅ `startTime(questionId)` should store the question with start timestamp
- ✅ `questionAnswered(questionId)` should find the question and calculate duration
- ✅ Results should show accurate timing in milliseconds
- ✅ Multiple questions should be tracked independently
- ❌ Answering a question that wasn't started should return `null`

## Troubleshooting

**App doesn't appear:**
```bash
adb shell pm list packages | grep aware
adb shell am start -n com.aware.tests/.TestActivity
```

**Build errors:**
- Make sure Java 11 is set: `echo $JAVA_HOME`
- Check that local.properties exists with correct SDK path

**TimeLatency not working:**
- Check logs: `adb logcat | grep TimeLatency`
- Verify TimeLatency.java is in aware-core module
- Make sure aware-tests depends on aware-core (it does)

## Next Steps

Once you've verified TimeLatency works:
1. Integrate it into your main app (aware-phone)
2. Connect it to your actual question/answer flow
3. Store results in a database or send to server
4. Add more test cases as needed

Happy testing! 🚀

