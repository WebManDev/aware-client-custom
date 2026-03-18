# Installing Java for Android Development

Your build failed because Java is not installed. Here's how to fix it:

## Quick Install (Recommended)

Run this command in your terminal (it will ask for your password):

```bash
brew install --cask temurin@11
```

Or for Java 17:

```bash
brew install --cask temurin@17
```

## After Installation

1. **Close and reopen your terminal** (or run `source ~/.zshrc`)

2. **Verify Java is installed**:
   ```bash
   java -version
   ```

3. **Set JAVA_HOME** (add to your `~/.zshrc`):
   ```bash
   # For Java 11
   export JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-11.jdk/Contents/Home
   
   # OR for Java 17
   export JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home
   ```

4. **Reload your shell**:
   ```bash
   source ~/.zshrc
   ```

5. **Try building again**:
   ```bash
   cd /Users/andyluu/aware-client
   ./build-and-install.sh
   ```

## Alternative: Manual Installation

If Homebrew doesn't work, download Java directly:

1. Visit: https://adoptium.net/temurin/releases/
2. Download Java 11 or 17 for macOS (ARM64 if you have Apple Silicon)
3. Install the .pkg file
4. Set JAVA_HOME as shown above

## Verify Installation

After installing, verify with:

```bash
java -version
javac -version
echo $JAVA_HOME
```

You should see version information for both commands.

