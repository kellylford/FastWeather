# FastWeather Mac Build Scripts

## Overview
This directory contains scripts to build and launch the FastWeather Mac app using Xcode command line tools.

## Prerequisites
- macOS with Xcode installed
- Xcode Command Line Tools: `xcode-select --install`

## Scripts

### 1. `build-app.sh` - Build the Mac App
Builds the FastWeather Mac app using xcodebuild.

**Usage:**
```bash
./build-app.sh [Configuration]
```

**Examples:**
```bash
# Build Release version (default)
./build-app.sh

# Build Debug version
./build-app.sh Debug
```

**What it does:**
- Cleans previous build
- Builds the app with the specified configuration (Release or Debug)
- Disables code signing for development
- Shows build location and app size
- Checks for required data files (us-cities-cached.json, international-cities-cached.json)

**Output:**
The built app will be located at:
```
build/Build/Products/Release/FastWeatherMac.app
```

### 2. `launch-app.sh` - Launch the Built App
Launches the most recently built app.

**Usage:**
```bash
./launch-app.sh
```

**What it does:**
- Searches for the built app in both Release and Debug configurations
- If app is already running, brings it to front
- Otherwise, opens the app
- Shows the app location

**Note:** You must build the app first using `build-app.sh`

### 3. `build-and-launch.sh` - Build and Launch
Convenience wrapper that builds and then launches the app.

**Usage:**
```bash
./build-and-launch.sh [Configuration]
```

**Examples:**
```bash
# Build Release and launch
./build-and-launch.sh

# Build Debug and launch
./build-and-launch.sh Debug
```

## Quick Start

### First Time Setup
1. Ensure Xcode is installed
2. Open the project in Xcode to verify it loads correctly
3. **Important:** Add the data files to the Xcode project:
   - In Xcode, right-click on the project navigator
   - Select "Add Files to 'FastWeatherMac'..."
   - Add `us-cities-cached.json` and `international-cities-cached.json`
   - Make sure "Copy items if needed" is checked
   - Make sure "Add to targets: FastWeatherMac" is checked

### Build and Run
```bash
# Navigate to the FastWeatherMac directory
cd /Users/kellyford/Documents/GitHub/FastWeather/FastWeatherMac

# Build and launch
./build-and-launch.sh
```

## Opening from Finder

### Method 1: Double-Click the Built App
After building, you can find the app at:
```
/Users/kellyford/Documents/GitHub/FastWeather/FastWeatherMac/build/Build/Products/Release/FastWeatherMac.app
```

Simply double-click it in Finder to launch.

### Method 2: Create an Alias
1. Build the app first: `./build-app.sh`
2. Find the built app in Finder (use the path shown after building)
3. Right-click → "Make Alias"
4. Move the alias to your Desktop or Applications folder
5. Double-click the alias to launch the app

### Method 3: Add to Dock
1. Build the app first
2. Open the app using `./launch-app.sh` or double-click in Finder
3. Right-click the app icon in the Dock
4. Options → Keep in Dock

## Troubleshooting

### Build Fails
If the build fails, check:
1. Xcode is properly installed: `xcode-select -p`
2. Command Line Tools are installed: `xcode-select --install`
3. Open the project in Xcode to see detailed errors
4. Check that all Swift files compile correctly

### App Not Found
If `launch-app.sh` can't find the app:
1. Build the app first: `./build-app.sh`
2. Check the build output for the app location
3. Verify the build was successful

### Data Files Missing
If you see warnings about missing data files:
1. Ensure `us-cities-cached.json` and `international-cities-cached.json` are in the FastWeatherMac directory
2. Add them to the Xcode project (see First Time Setup above)
3. In Xcode, verify they appear under "Copy Bundle Resources" in Build Phases

### Code Signing Issues
The scripts disable code signing for development. If you want to distribute the app:
1. Remove the `CODE_SIGN_IDENTITY=""` lines from `build-app.sh`
2. Set up proper code signing in Xcode
3. Use Xcode's Archive feature for distribution

## Advanced Usage

### Custom Build Settings
Edit `build-app.sh` to customize:
- Build configuration (Debug/Release)
- Code signing settings
- Build location
- Additional xcodebuild flags

### Continuous Integration
These scripts can be used in CI/CD pipelines:
```bash
# Non-interactive build
./build-app.sh Release

# Check exit code
if [ $? -eq 0 ]; then
    echo "Build successful"
else
    echo "Build failed"
    exit 1
fi
```

### Clean Build
To force a complete rebuild:
```bash
# The build-app.sh already includes a clean step
./build-app.sh
```

Or manually:
```bash
xcodebuild clean -project FastWeatherMac.xcodeproj -scheme FastWeatherMac
```

## Files Structure
```
FastWeatherMac/
├── build-app.sh                    # Build script
├── launch-app.sh                   # Launch script
├── build-and-launch.sh            # Combined script
├── BUILD_SCRIPTS_README.md        # This file
├── FastWeatherMac.xcodeproj/      # Xcode project
├── FastWeatherMac/                # Source files
├── us-cities-cached.json          # City data (must be in Xcode project)
├── international-cities-cached.json # City data (must be in Xcode project)
└── build/                         # Build output (created by scripts)
    └── Build/
        └── Products/
            ├── Release/
            │   └── FastWeatherMac.app
            └── Debug/
                └── FastWeatherMac.app
```

## Additional Resources
- [Xcode Build Settings Reference](https://developer.apple.com/documentation/xcode/build-settings-reference)
- [xcodebuild Man Page](https://keith.github.io/xcode-man-pages/xcodebuild.1.html)
- Main Project README: `../README.md`
- Build Guide: `BUILD.md`
