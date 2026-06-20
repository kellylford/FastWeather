# Controlling Your iPhone from Your Mac: A Guide for Blind Developers

**Purpose:** How to build, install, test, and debug an iOS app on your iPhone without touching the phone — using only your Mac and the command line.

---

## Why This Matters

If you're a blind developer building iOS apps, you already know the friction: you're working on your Mac with VoiceOver, your phone is across the room or in your pocket, and you don't want to switch headphones or pick up the device just to test a build. You also don't want to navigate Xcode's UI every time you need to deploy.

The good news: you can do almost everything from the terminal. Build, install, launch, capture logs, reboot, and even take screenshots — all from your Mac, all with VoiceOver, all without touching the phone.

This guide covers the tools, the commands, and the workflow.

---

## Prerequisites

1. **Your iPhone must be paired with your Mac** — connect via USB once, tap "Trust This Computer," and enter your passcode. After that, it works over Wi-Fi (no cable needed).

2. **Developer Mode must be enabled** on the phone: Settings → Privacy & Security → Developer Mode → turn on → restart.

3. **Apple Intelligence** (if you're testing AI features): Settings → Apple Intelligence & Siri → enable.

4. **Xcode** installed (regular or beta, depending on your iOS version).

---

## The Core Tool: `devicectl`

`devicectl` is Apple's command-line tool for interacting with iOS devices. It replaced the older `ios-deploy` and `ideviceinstaller` tools. It's part of Xcode — no separate install needed.

### Finding Your Device

```bash
# List all connected devices (physical and simulators)
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcrun devicectl list devices
```

This shows every device `devicectl` knows about, including:
- Physical devices (paired over USB or Wi-Fi)
- Simulators (running or shutdown)

The output includes the device name, identifier (UUID), and state (available, shutdown, etc.).

### Getting Device Details

```bash
# Get full info about a specific device
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcrun devicectl device info details --device "Kelly Ford"
```

You can identify the device by:
- Name: `--device "Kelly Ford"`
- UUID: `--device EB74EBE4-9CDA-5D8F-8AFD-6F554257397F`
- UDID: `--device 00008130-000A11502811401C`

### Checking If a Device Is Ready

```bash
# Get detailed diagnostics
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcrun devicectl device info details --device "Kelly Ford" --show diagnostics
```

This shows:
- Boot state (booted, shutdown)
- Developer Mode status (enabled/disabled)
- Pairing state (paired, unpaired)
- OS version and build number
- Storage capacity
- Supported features

---

## Building Your App

### Building for the Device

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodebuild \
  -project MyProject.xcodeproj \
  -scheme MyScheme \
  -configuration Debug \
  -destination 'id=00008130-000A11502811401C' \
  build
```

Key flags:
- `DEVELOPER_DIR` — points to the Xcode version you want to use (regular or beta)
- `-destination 'id=UDID'` — builds for a specific physical device by UDID
- `build` — compiles but doesn't install (use `build install` or separate install step)

### Finding Your Device's UDID

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcrun devicectl list devices
```

Or get it from device details:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcrun devicectl device info details --device "Kelly Ford" --show diagnostics
```

Look for the `UDID` field in the output.

### Checking Build Results

```bash
# Build and show only errors and result
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodebuild \
  -project MyProject.xcodeproj \
  -scheme MyScheme \
  -configuration Debug \
  -destination 'id=00008130-000A11502811401C' \
  build 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

This filters the output to just errors and the final result — much easier to scan with a screen reader than the full build log.

---

## Installing and Launching

### Installing the App

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcrun devicectl device install app \
  --device "Kelly Ford" \
  "/Users/you/Library/Developer/Xcode/DerivedData/MyProject-abc123/Build/Products/Debug-iphoneos/MyApp.app"
```

The app path is in your DerivedData folder. You can find it with:

```bash
# Find the built .app
find ~/Library/Developer/Xcode/DerivedData/MyProject-* -name "MyApp.app" -path "*/Debug-iphoneos/*" 2>/dev/null
```

### Launching the App

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcrun devicectl device process launch \
  --device "Kelly Ford" \
  com.yourcompany.yourapp
```

Use the bundle identifier (not the app name). You can find it in your Xcode project's build settings, or:

```bash
# Get bundle ID from the built app
defaults read "/path/to/MyApp.app/Info.plist" CFBundleIdentifier
```

### Launching with Console Output

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcrun devicectl device process launch \
  --device "Kelly Ford" \
  --terminate-existing \
  --console \
  com.yourcompany.yourapp
```

Flags:
- `--terminate-existing` — kills the app if it's already running, then launches fresh
- `--console` — captures `print()` and `NSLog()` output from the app in real time

**Note:** `--console` blocks until the app terminates. For background capture, pipe to a file:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcrun devicectl device process launch \
  --device "Kelly Ford" \
  --terminate-existing \
  --console \
  com.yourcompany.yourapp 2>&1 | tee /tmp/app_logs.txt &
```

Then later:

```bash
# Check captured logs
grep -i "error\|warning" /tmp/app_logs.txt
```

---

## Capturing Logs

### Real-Time Console

The `--console` flag (above) captures `print()` output. For `os.Logger` output (which is what Apple recommends), you need a different approach.

### Listing Running Processes

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcrun devicectl device info processes \
  --device "Kelly Ford"
```

This shows all running processes with their PIDs — useful for checking if a daemon or service is active.

### Filtering Logs

If you captured logs to a file with `tee`, you can filter:

```bash
# Show only errors and warnings
grep -i "error\|⚠️\|warning" /tmp/app_logs.txt

# Show only your app's debug output
grep "📡\|🔧\|❄️" /tmp/app_logs.txt

# Show the last 20 lines
tail -20 /tmp/app_logs.txt
```

---

## Rebooting the Device

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcrun devicectl device reboot \
  --device "Kelly Ford"
```

This is useful when:
- The device is in a bad state
- A system daemon (like the model manager) needs to restart
- You want a clean test environment

The phone takes about 30-60 seconds to reboot. Wait for it to come back before trying to install or launch again.

---

## Taking Screenshots

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcrun devicectl device capture \
  --device "Kelly Ford" \
  /tmp/screenshot.png
```

This captures the current screen of your phone. You can then:
- Open it in Preview (`open /tmp/screenshot.png`)
- Use VoiceOver to read it if it contains text
- Send it to an AI model for analysis

---

## A Complete Build-Install-Launch Workflow

Here's a script that does everything in one shot:

```bash
#!/bin/bash
# Build, install, and launch — all in one command
# Usage: ./deploy.sh

DEVICE="Kelly Ford"
BUNDLE_ID="com.yourcompany.yourapp"
PROJECT="MyProject.xcodeproj"
SCHEME="MyScheme"
XCODE_DIR="/Applications/Xcode-beta.app/Contents/Developer"

export DEVELOPER_DIR="$XCODE_DIR"

echo "Building..."
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Debug \
  -destination "id=00008130-000A11502811401C" build 2>&1 | \
  grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"

if [ $? -ne 0 ]; then
  echo "Build failed"
  exit 1
fi

# Find the built app
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/MyProject-* \
  -name "MyApp.app" -path "*/Debug-iphoneos/*" 2>/dev/null | head -1)

if [ -z "$APP_PATH" ]; then
  echo "Could not find built app"
  exit 1
fi

echo "Installing..."
xcrun devicectl device install app --device "$DEVICE" "$APP_PATH"

echo "Launching..."
xcrun devicectl device process launch --device "$DEVICE" --terminate-existing "$BUNDLE_ID"

echo "Done!"
```

---

## Tips for Blind Developers

### Use `grep` to Filter Output

Build logs and device logs are verbose. Always pipe through `grep` to get just what you need:

```bash
# Just errors
xcodebuild ... 2>&1 | grep "error:"

# Just your app's debug logs
xcrun devicectl ... --console ... 2>&1 | grep "your-prefix"
```

### Use `tee` to Capture While Watching

```bash
xcrun devicectl ... --console ... 2>&1 | tee /tmp/logs.txt &
# Do other things...
grep "error" /tmp/logs.txt
```

### Set `DEVELOPER_DIR` Once Per Session

If you're using Xcode beta, set it once:

```bash
export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
```

Then all subsequent `xcrun` and `xcodebuild` commands use that Xcode version.

### Use Device Name Instead of UDID

`--device "Kelly Ford"` is easier to remember and type than `--device 00008130-000A11502811401C`. Both work.

### Keep the Phone on Wi-Fi

Once paired over USB, the phone works over Wi-Fi. No cable needed for builds, installs, or launches. Just make sure both devices are on the same network.

### Reboot When Things Get Weird

If the phone is in a bad state (app won't launch, logs won't capture, model manager fails):

```bash
xcrun devicectl device reboot --device "Kelly Ford"
```

Wait 60 seconds, then try again.

---

## Common Issues

### "Device not found"

Make sure the device is paired and on the same Wi-Fi:

```bash
xcrun devicectl list devices
```

If it shows as "offline," the phone may be asleep. Wake it (tap the screen) and try again.

### "Build failed" but no error shown

The grep filter may have missed the error. Try without the filter:

```bash
xcodebuild ... build 2>&1 | tail -30
```

### "App not installed" after build

The build succeeded but the app path is wrong. Find the correct path:

```bash
find ~/Library/Developer/Xcode/DerivedData/ -name "YourApp.app" -path "*/Debug-iphoneos/*" 2>/dev/null
```

### Console shows no output

`--console` only captures `print()` output, not `os.Logger`. If your app uses `os.Logger` (Apple's recommended logging), you won't see it in the console. Use `print()` for debug logging during development, or use Xcode's debugger to attach and view logs.

### Code signing errors

Make sure your Apple Developer account is set up in Xcode and the provisioning profile is valid. The first build may need to be done in Xcode's UI to set up signing. After that, command-line builds work.

---

## Quick Reference

| Task | Command |
|------|---------|
| List devices | `xcrun devicectl list devices` |
| Device details | `xcrun devicectl device info details --device "Name"` |
| Build for device | `xcodebuild -project X.xcodeproj -scheme S -destination 'id=UDID' build` |
| Install app | `xcrun devicectl device install app --device "Name" /path/to/App.app` |
| Launch app | `xcrun devicectl device process launch --device "Name" com.bundle.id` |
| Launch with logs | `xcrun devicectl device process launch --device "Name" --console com.bundle.id` |
| Reboot device | `xcrun devicectl device reboot --device "Name"` |
| Screenshot | `xcrun devicectl device capture --device "Name" /tmp/screenshot.png` |
| List processes | `xcrun devicectl device info processes --device "Name"` |

---

*Written by GitHub Copilot, June 2026. Based on real workflow building and testing the WeatherFast iOS app on an iPhone 15 Pro running iOS 27 beta, entirely from the command line.*