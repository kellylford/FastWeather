# Building FastWeather for macOS

This guide walks you through building and running FastWeather on your Mac.

## Prerequisites

### Required Software

- **macOS 13.0 (Ventura)** or later
- **Xcode 15.0** or later
  - Download from the Mac App Store
  - Or download from [Apple Developer](https://developer.apple.com/xcode/)

### Verify Installation

```bash
# Check macOS version
sw_vers

# Check Xcode version
xcodebuild -version

# Should output:
# Xcode 15.0 or higher
# Build version XXXXX
```

## Quick Start

### 1. Open the Project

```bash
cd /Users/kellyford/Documents/FastWeather/FastWeatherMac
open FastWeatherMac.xcodeproj
```

Or in Xcode:
- **File → Open**
- Navigate to `FastWeatherMac.xcodeproj`
- Click **Open**

### 2. Build and Run

**Option A: Using Xcode**
1. Select "My Mac" as the destination in the toolbar
2. Press **⌘R** or click the ▶️ Play button
3. The app will build and launch automatically

**Option B: Using Terminal**
```bash
# Navigate to project directory
cd FastWeatherMac

# Build and run
xcodebuild -project FastWeatherMac.xcodeproj \
           -scheme FastWeatherMac \
           -configuration Debug \
           build

# Or use the open command
open -a Xcode FastWeatherMac.xcodeproj
```

## Building for Release

### Create a Release Build

1. In Xcode, select **Product → Archive**
2. Wait for the archive to complete
3. The Organizer window opens automatically
4. Select your archive
5. Click **Distribute App**

### Distribution Options

#### Option 1: Export for Direct Distribution
- Select **Copy App**
- Choose a location
- The `.app` bundle is ready to share

#### Option 2: Export for Testing
- Select **Development**
- Code sign with your Apple ID (free)
- Creates a signed app for testing

#### Option 3: Submit to App Store
- Select **App Store Connect**
- Requires paid Apple Developer account
- Follow App Store submission guidelines

## Build Configurations

### Debug Build (Default)

```bash
xcodebuild -project FastWeatherMac.xcodeproj \
           -scheme FastWeatherMac \
           -configuration Debug \
           clean build
```

**Features**:
- Debugging symbols included
- Assertions enabled
- Console logging active
- SwiftUI previews work

### Release Build

```bash
xcodebuild -project FastWeatherMac.xcodeproj \
           -scheme FastWeatherMac \
           -configuration Release \
           clean build
```

**Features**:
- Optimized code
- Smaller binary size
- No debugging symbols
- Better performance

## Code Signing

### For Personal Use (Free)

1. In Xcode, select the project in the navigator
2. Select the **FastWeatherMac** target
3. Go to **Signing & Capabilities**
4. Check **Automatically manage signing**
5. Select your **Personal Team** (your Apple ID)

### For Distribution (Paid Account)

1. Join the [Apple Developer Program](https://developer.apple.com/programs/) ($99/year)
2. Create a **Developer ID Application** certificate
3. In Xcode **Signing & Capabilities**:
   - Select your **Team**
   - Choose **Developer ID Application** certificate

## Running from Terminal

### Build Only

```bash
xcodebuild -project FastWeatherMac.xcodeproj \
           -scheme FastWeatherMac \
           -configuration Release \
           -derivedDataPath ./build \
           build
```

### Run the Built App

```bash
# After building
open ./build/Build/Products/Release/FastWeatherMac.app
```

### Create a Standalone Package

```bash
# Build
xcodebuild -project FastWeatherMac.xcodeproj \
           -scheme FastWeatherMac \
           -configuration Release \
           -derivedDataPath ./build \
           build

# Copy to Applications (optional)
cp -R ./build/Build/Products/Release/FastWeatherMac.app /Applications/
```

## Project Structure

```
FastWeatherMac/
├── FastWeatherMac.xcodeproj/        # Xcode project file
│   └── project.pbxproj              # Project configuration
└── FastWeatherMac/                  # Source directory
    ├── FastWeatherMacApp.swift      # App entry point
    ├── FastWeatherMac.entitlements  # App permissions
    ├── Models/                      # Data models
    │   └── WeatherModels.swift
    ├── Services/                    # Business logic
    │   ├── WeatherService.swift
    │   └── CityManager.swift
    ├── Views/                       # UI components
    │   ├── ContentView.swift
    │   ├── WeatherDetailView.swift
    │   ├── CitySearchSheet.swift
    │   └── SettingsView.swift
    ├── Assets.xcassets/             # Images and colors
    │   ├── AppIcon.appiconset/
    │   └── AccentColor.colorset/
    └── Preview Content/             # Preview assets
        └── Preview Assets.xcassets/
```

## Customization

### Change App Name

1. Select project in Xcode navigator
2. Select **FastWeatherMac** target
3. Go to **General** tab
4. Edit **Display Name**

### Change Bundle Identifier

1. In target settings → **General**
2. Edit **Bundle Identifier**
3. Use reverse domain notation: `com.yourname.fastweather`

### Change App Icon

1. Create icons at these sizes:
   - 16x16, 32x32, 128x128, 256x256, 512x512 (1x and 2x)
2. Add to `Assets.xcassets/AppIcon.appiconset/`
3. Or drag images into Xcode's asset catalog

### Change Accent Color

1. Open `Assets.xcassets/AccentColor.colorset/Contents.json`
2. Or use Xcode's color picker in the asset catalog

## Troubleshooting

### Build Errors

#### "Command CodeSign failed"
**Solution**: Check code signing settings in target → Signing & Capabilities

#### "Swift Compiler Error"
**Solution**: 
```bash
# Clean build folder
xcodebuild clean -project FastWeatherMac.xcodeproj

# Or in Xcode: Product → Clean Build Folder (Shift+⌘K)
```

#### "No such module 'SwiftUI'"
**Solution**: Ensure macOS deployment target is set to 13.0 or later

### Runtime Errors

#### App crashes on launch
**Solution**: Check console logs in Xcode or Console.app for error messages

#### "App is damaged and can't be opened"
**Solution**: 
```bash
# Remove quarantine attribute
xattr -cr /path/to/FastWeatherMac.app
```

#### Network requests fail
**Solution**: Verify `FastWeatherMac.entitlements` includes:
```xml
<key>com.apple.security.network.client</key>
<true/>
```

### Xcode Issues

#### Xcode won't open project
**Solution**: 
```bash
# Repair project
cd FastWeatherMac
rm -rf xcuserdata/
```

#### Previews not working
**Solution**:
1. Restart Xcode
2. Product → Clean Build Folder
3. Restart Mac (if needed)

## Advanced Build Options

### Optimizing Build Time

Add to `User-Defined` settings:
```
SWIFT_COMPILATION_MODE = incremental
SWIFT_OPTIMIZATION_LEVEL = -Onone  # For Debug only
```

### Enable Hardened Runtime

For distribution outside App Store:
1. Target → **Signing & Capabilities**
2. Click **+ Capability**
3. Add **Hardened Runtime**

### Notarization (for distribution)

```bash
# Archive and export
xcodebuild archive ...

# Notarize
xcrun notarytool submit FastWeatherMac.zip \
  --apple-id "your@email.com" \
  --team-id "TEAMID" \
  --password "app-specific-password" \
  --wait

# Staple notarization
xcrun stapler staple FastWeatherMac.app
```

## Testing

### Run Tests

```bash
xcodebuild test -project FastWeatherMac.xcodeproj \
                -scheme FastWeatherMac \
                -destination 'platform=macOS'
```

### Accessibility Testing

1. Enable VoiceOver: **⌘F5**
2. Use Accessibility Inspector:
   - Xcode → Developer Tools → Accessibility Inspector
3. Check contrast ratios and focus indicators

### Performance Testing

```bash
# Profile with Instruments
xcodebuild build -project FastWeatherMac.xcodeproj
instruments -t "Time Profiler" ./build/.../FastWeatherMac.app
```

## Continuous Integration

### GitHub Actions Example

```yaml
name: Build FastWeather

on: [push, pull_request]

jobs:
  build:
    runs-on: macos-13
    steps:
      - uses: actions/checkout@v3
      - name: Build
        run: |
          cd FastWeatherMac
          xcodebuild -project FastWeatherMac.xcodeproj \
                     -scheme FastWeatherMac \
                     -configuration Release \
                     build
```

## Resources

- [Xcode Documentation](https://developer.apple.com/documentation/xcode)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [App Distribution Guide](https://developer.apple.com/distribute/)
- [Code Signing Guide](https://developer.apple.com/support/code-signing/)

## Getting Help

- Check the [README](README.md) for usage instructions
- See [ACCESSIBILITY.md](ACCESSIBILITY.md) for accessibility features
- Open an issue on GitHub for bugs or questions

---

**Happy Building! 🚀**
