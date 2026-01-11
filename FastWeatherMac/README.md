# FastWeather for macOS

A native, fully accessible weather application for macOS built with SwiftUI. FastWeather provides fast, reliable weather information with complete VoiceOver support and WCAG 2.2 AA compliance.

## ✨ Features

- **🌤️ Comprehensive Weather Data**: Current conditions, hourly forecasts, and 7-day outlook
- ♿ **Full VoiceOver Support**: Every element is properly labeled and navigable with screen readers
- ⌨️ **Complete Keyboard Navigation**: Navigate the entire app without a mouse
- 🎨 **WCAG 2.2 AA Compliant**: High contrast ratios, proper focus indicators, and accessible color schemes
- 🌡️ **Flexible Units**: Switch between metric and imperial units
- 🏙️ **Multiple Cities**: Track weather for unlimited cities
- 🔒 **Privacy First**: No tracking, no analytics, data stored locally
- 🆓 **No API Key Required**: Uses free Open-Meteo weather service
- 📱 **Native macOS**: Built with SwiftUI for optimal performance

## 📋 System Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15.0 or later (for building from source)
- Active internet connection

## 🚀 Installation

### Option 1: Build from Source

1. **Clone or download** this repository
2. **Open the project** in Xcode:
   ```bash
   cd FastWeatherMac
   open FastWeatherMac.xcodeproj
   ```
3. **Build and run** (⌘R) or **Archive** the app (Product → Archive)

### Option 2: Install Pre-built App

1. Download the latest `FastWeather.app` from releases
2. Move to your Applications folder
3. Open the app (you may need to right-click and select "Open" the first time)

## 🎯 Usage

### Adding Cities

1. **Click** the "+" button or press **⌘N**
2. **Type** a city name or zip code
3. **Select** from the search results
4. The city will be added to your list

### Viewing Weather

1. **Select** a city from the sidebar
2. The detailed weather view appears on the right
3. **Scroll** to view hourly and daily forecasts

### Managing Cities

- **Remove**: Right-click a city and select "Remove" or select it and press **Delete**
- **Reorder**: Drag cities to reorder them in the list
- **Refresh**: Click the refresh button or press **⌘R**

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| ⌘N | Add new city |
| ⌘R | Refresh selected city |
| Delete | Remove selected city |
| ⌘, | Open settings |
| ⌘? | Show help |
| ⌘Q | Quit app |

## ♿ Accessibility Features

FastWeather is designed from the ground up to be fully accessible:

### VoiceOver Support

- **All UI elements** are properly labeled with descriptive accessibility labels
- **Hints** provide context-sensitive guidance
- **Status announcements** notify users of important updates (e.g., "City added", "Weather loaded")
- **Semantic grouping** keeps related information together
- **Proper heading hierarchy** for easy navigation

### Keyboard Navigation

- **Full keyboard access** to all features
- **Visible focus indicators** with high contrast
- **Logical tab order** follows visual flow
- **Keyboard shortcuts** for common actions

### Visual Accessibility

- **High contrast ratios** meet WCAG 2.2 AA standards (4.5:1 for text, 3:1 for UI components)
- **Dynamic Type** support for adjustable text sizes
- **No reliance on color alone** for information
- **Clear visual hierarchy** with proper spacing
- **Sufficient touch/click targets** (minimum 44x44 points)

### WCAG 2.2 AA Compliance

FastWeather meets or exceeds all Level AA success criteria:

#### Perceivable
- ✅ **1.1.1 Non-text Content**: All icons have text alternatives
- ✅ **1.3.1 Info and Relationships**: Semantic structure preserved
- ✅ **1.4.3 Contrast (Minimum)**: 4.5:1 for text, 3:1 for UI
- ✅ **1.4.11 Non-text Contrast**: UI components have 3:1 contrast
- ✅ **1.4.13 Content on Hover/Focus**: No loss of content

#### Operable
- ✅ **2.1.1 Keyboard**: All functionality keyboard accessible
- ✅ **2.4.3 Focus Order**: Logical focus sequence
- ✅ **2.4.6 Headings and Labels**: Descriptive headings
- ✅ **2.4.7 Focus Visible**: Clear focus indicators
- ✅ **2.5.3 Label in Name**: Accessible names match visible text

#### Understandable
- ✅ **3.2.2 On Input**: No unexpected changes
- ✅ **3.3.1 Error Identification**: Clear error messages
- ✅ **3.3.2 Labels or Instructions**: All inputs labeled

#### Robust
- ✅ **4.1.2 Name, Role, Value**: Proper ARIA attributes
- ✅ **4.1.3 Status Messages**: Announced to assistive tech

## ⚙️ Settings

Access settings via **FastWeather → Settings** or press **⌘,**

### General
- **Temperature Units**: Celsius or Fahrenheit
- **Weather Alerts**: Enable/disable alert notifications

### Accessibility
- **Enhanced Descriptions**: More detailed weather info for VoiceOver
- **Keyboard Shortcuts**: View all available shortcuts

## 🔧 Development

### Project Structure

```
FastWeatherMac/
├── FastWeatherMac/
│   ├── FastWeatherMacApp.swift      # App entry point
│   ├── Models/
│   │   └── WeatherModels.swift      # Data models
│   ├── Services/
│   │   ├── WeatherService.swift     # API service
│   │   └── CityManager.swift        # City persistence
│   ├── Views/
│   │   ├── ContentView.swift        # Main view
│   │   ├── WeatherDetailView.swift  # Weather display
│   │   ├── CitySearchSheet.swift    # City search
│   │   └── SettingsView.swift       # Settings
│   └── Assets.xcassets/             # Assets
└── FastWeatherMac.xcodeproj/        # Xcode project
```

### Building

```bash
# Build for debug
xcodebuild -project FastWeatherMac.xcodeproj -scheme FastWeatherMac -configuration Debug

# Build for release
xcodebuild -project FastWeatherMac.xcodeproj -scheme FastWeatherMac -configuration Release

# Archive
xcodebuild archive -project FastWeatherMac.xcodeproj -scheme FastWeatherMac -archivePath ./build/FastWeather.xcarchive
```

### Testing Accessibility

1. **Enable VoiceOver**: System Settings → Accessibility → VoiceOver
2. **Test keyboard navigation**: Use Tab, arrow keys, and shortcuts
3. **Check contrast**: Use Accessibility Inspector (Xcode → Developer Tools)
4. **Verify focus**: Visual focus indicators should be clear
5. **Test Dynamic Type**: System Settings → Accessibility → Display → Text Size

## 📊 Weather Data

Weather data provided by [Open-Meteo.com](https://open-meteo.com/) (CC BY 4.0)

- **No API key required**
- **Free for personal use**
- **Accurate global coverage**
- **Real-time updates**

## 🔒 Privacy

FastWeather respects your privacy:

- ✅ **No tracking or analytics**
- ✅ **No personal data collection**
- ✅ **Cities stored locally only**
- ✅ **No third-party SDKs**
- ✅ **Minimal network requests** (only for weather data)

## 📝 License

This project is licensed under the MIT License - see the original FastWeather project for details.

## 🙏 Acknowledgments

- Based on the FastWeather Python application
- Weather data from Open-Meteo.com
- Geocoding from Nominatim/OpenStreetMap
- Built with SwiftUI and macOS frameworks

## 🐛 Troubleshooting

### App won't open
- **Right-click** the app and select "Open"
- Go to **System Settings → Privacy & Security** and allow the app

### No weather data loading
- Check your **internet connection**
- Verify the city coordinates are correct
- Try removing and re-adding the city

### VoiceOver not working properly
- Restart VoiceOver (**⌘F5**)
- Restart the app
- Check System Settings → Accessibility → VoiceOver

## 📞 Support

For issues, suggestions, or accessibility concerns, please open an issue on GitHub or contact the developer.

## 🔄 Differences from Python Version

This macOS version maintains feature parity with the original FastWeather while adding:

- **Native macOS integration** with system appearance
- **Enhanced accessibility** with comprehensive VoiceOver support
- **Better performance** with native Swift code
- **macOS-specific features** like menu bar, settings panel, and keyboard shortcuts
- **Modern UI** with SwiftUI adaptive layouts

---

**Made with ❤️ for accessibility and great user experience**
