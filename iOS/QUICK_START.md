# Weather Fast iOS - Quick Start Guide

Get up and running with Weather Fast iOS development in minutes.

## Prerequisites

- macOS Sonoma or later
- Xcode 15.0 or later
- iOS 17.0 SDK or later

## Installation

1. **Clone or navigate to the repository**
   ```bash
   cd /Users/kellyford/Documents/GitHub/FastWeather/iOS
   ```

2. **Open the project**
   ```bash
   open FastWeather.xcodeproj
   ```
   Or double-click `FastWeather.xcodeproj` in Finder

## Building

### Using the Build Script

The easiest way to build:
```bash
./build.sh
```

### Using Xcode

1. Open `FastWeather.xcodeproj`
2. Select a simulator from the device menu (e.g., iPhone 17)
3. Press `Cmd + R` to build and run

### Using Command Line

```bash
xcodebuild -project FastWeather.xcodeproj \
    -scheme FastWeather \
    -configuration Debug \
    -sdk iphonesimulator \
    -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' \
    build
```

## Running

### In Simulator

After building with Xcode:
1. The app will automatically launch in the selected simulator
2. Use the app like you would on a real device

### On Physical Device

1. Connect your iPhone/iPad via USB
2. In Xcode, select your device from the device menu
3. You may need to enable Developer Mode on your device
4. Press `Cmd + R` to build and run

## Project Structure

```
iOS/
├── FastWeather.xcodeproj/          # Xcode project file
├── FastWeather/                     # Source code
│   ├── FastWeatherApp.swift        # App entry point
│   ├── Info.plist                  # App configuration
│   ├── Models/                     # Data models
│   │   ├── City.swift
│   │   ├── Weather.swift
│   │   └── Settings.swift
│   ├── Views/                      # SwiftUI views
│   │   ├── ContentView.swift
│   │   ├── MyCitiesView.swift
│   │   ├── FlatView.swift
│   │   ├── TableView.swift
│   │   ├── ListView.swift
│   │   ├── BrowseCitiesView.swift
│   │   ├── StateCitiesView.swift
│   │   ├── CityDetailView.swift
│   │   └── SettingsView.swift
│   ├── Services/                   # Business logic
│   │   ├── WeatherService.swift
│   │   ├── SettingsManager.swift
│   │   └── CityDataService.swift
│   └── Resources/                  # Data files
│       ├── us-cities-cached.json
│       └── international-cities-cached.json
├── build.sh                        # Build script
├── README.md                       # Project overview
├── ACCESSIBILITY.md                # Accessibility guide
├── DISTRIBUTION.md                 # Distribution guide
└── QUICK_START.md                  # This file
```

## Key Features

### 1. Browse Cities
- Tap the **Browse** tab
- Choose between US states or international countries
- Search for specific states/countries
- Browse cities within each region
- Tap the **+** button to add cities to your list

### 2. View Weather
Three view modes available:
- **Flat View**: Card layout with comprehensive weather details
- **Table View**: Compact tabular format
- **List View**: Minimalist single-line format

Switch views from the menu (⋯) in the top-right corner.

### 3. Manage Cities
- Swipe left on a city to delete it
- Drag to reorder cities (in Table and List views)
- Pull down to refresh weather data
- Tap a city to view detailed weather information

### 4. Customize Settings
- Tap the **Settings** tab
- Choose temperature units (°F or °C)
- Select wind speed units (mph or km/h)
- Configure which weather fields to display
- Set your default view mode

## Development Tips

### Live Previews

SwiftUI provides live previews in Xcode:
1. Open any view file (e.g., `FlatView.swift`)
2. Look for the canvas on the right (Cmd+Option+Enter to toggle)
3. Click "Resume" if paused
4. See live updates as you edit code

### Debugging

Use Xcode's debugging tools:
- **Breakpoints**: Click in the gutter next to line numbers
- **Print Statements**: Use `print()` for console output
- **View Hierarchy**: Debug > View Debugging > Capture View Hierarchy
- **Accessibility Inspector**: Xcode > Open Developer Tool > Accessibility Inspector

### Testing Accessibility

1. **VoiceOver**:
   - Enable on simulator: Settings > Accessibility > VoiceOver
   - Navigate with three-finger swipe
   - Double-tap to activate

2. **Dynamic Type**:
   - Environment > Text Size in Xcode settings
   - Or Settings > Display & Brightness > Text Size on device

3. **Color Contrast**:
   - Use Xcode Accessibility Inspector
   - Check contrast ratios for all text

## Common Tasks

### Add a New View

1. Create a new Swift file in the Views folder
2. Import SwiftUI
3. Create a struct conforming to View
4. Implement the body property
5. Add to the appropriate navigation hierarchy

### Modify the Data Model

1. Edit the appropriate model file (City.swift, Weather.swift, etc.)
2. Update any views that use the model
3. Handle data migration if needed

### Add a New Setting

1. Add property to `AppSettings` in Settings.swift
2. Add UI control in SettingsView.swift
3. Use the setting in relevant views
4. Test accessibility

## Troubleshooting

### Build Errors

**"Cannot find 'X' in scope"**
- Ensure all files are added to the target
- Check import statements
- Clean build folder (Cmd+Shift+K)

**"No such module 'SwiftUI'"**
- Check deployment target is iOS 17.0+
- Verify SDK is installed

**Code signing errors**
- Enable "Automatically manage signing" in project settings
- Or configure signing manually with valid certificate

### Runtime Errors

**"Thread 1: signal SIGABRT"**
- Check console for detailed error message
- Common causes: missing resources, invalid JSON, force unwrapping nil

**Weather data not loading**
- Check network connection
- Verify API URL is correct
- Check console for HTTP errors

**Cities not persisting**
- Check UserDefaults access
- Verify Codable implementation
- Check for serialization errors

### Simulator Issues

**Simulator won't launch**
- Restart Xcode
- Delete and recreate simulator: Window > Devices and Simulators

**App won't install**
- Delete app from simulator
- Clean build folder (Cmd+Shift+K)
- Rebuild

## Resources

- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [iOS Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/ios)
- [Xcode Help](https://developer.apple.com/documentation/xcode)
- [Open-Meteo API Docs](https://open-meteo.com/en/docs)

## Next Steps

1. **Read ACCESSIBILITY.md** - Learn about accessibility features
2. **Read DISTRIBUTION.md** - Prepare for App Store submission
3. **Customize** - Make the app your own
4. **Test** - Test on real devices
5. **Submit** - Submit to App Store

## Support

For issues or questions:
- Check the documentation in this repository
- File an issue on GitHub
- Consult Apple Developer Forums

Happy coding! 🚀
