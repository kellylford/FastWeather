# Weather Fast iOS

A native iOS weather application built with SwiftUI that provides fast, accessible weather information.

## Features

### City Management
- **Browse Cities**: Browse cities by US state or international country
- **Add Cities**: Add cities to your personal list from the browse interface
- **Remove Cities**: Remove cities from your list with swipe-to-delete
- **Reorder Cities**: Drag to reorder cities in table and list views

### Three View Modes
- **Flat View**: Card-based layout with full weather details
- **Table View**: Compact tabular format for quick scanning
- **List View**: Minimalist single-line format for maximum efficiency

### Weather Information
- Current temperature and conditions
- Feels-like temperature
- Humidity levels
- Wind speed and direction
- Daily high and low temperatures
- Sunrise and sunset times
- Pressure, visibility, cloud cover
- Precipitation (rain, showers, snow)

### Accessibility Features
- Full VoiceOver support with descriptive labels
- Dynamic Type support for text scaling
- Semantic labels for all interactive elements
- Keyboard navigation support
- High contrast compatible
- WCAG 2.2 AA compliant design

### Customization
- Choose temperature units (°F or °C)
- Select wind speed units (mph or km/h)
- Configure precipitation units (in or mm)
- Toggle visibility of weather fields
- Set default view mode

## Requirements

- iOS 17.0 or later
- Xcode 15.0 or later
- Swift 5.9 or later

## Building

### Using Xcode
1. Open `FastWeather.xcodeproj` in Xcode
   - The project name remains FastWeather.xcodeproj for now, but the app displays as "Weather Fast"
2. Select your target device or simulator
3. Press Cmd+R to build and run

### Using Command Line
```bash
cd iOS
xcodebuild -project FastWeather.xcodeproj -scheme FastWeather -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 15' build
```

## Project Structure

```
FastWeather/
├── FastWeatherApp.swift          # App entry point
├── Models/
│   ├── City.swift                # City data models
│   ├── Weather.swift             # Weather data models
│   └── Settings.swift            # App settings models
├── Views/
│   ├── ContentView.swift         # Main tab view
│   ├── MyCitiesView.swift        # Saved cities view
│   ├── FlatView.swift            # Card-based weather view
│   ├── TableView.swift           # Table weather view
│   ├── ListView.swift            # List weather view
│   ├── BrowseCitiesView.swift    # City browsing interface
│   ├── StateCitiesView.swift     # State/country city lists
│   ├── CityDetailView.swift      # Detailed weather view
│   └── SettingsView.swift        # Settings interface
├── Services/
│   ├── WeatherService.swift      # Weather API service
│   ├── SettingsManager.swift     # Settings management
│   └── CityDataService.swift     # City data service
└── Resources/
    ├── us-cities-cached.json     # US city coordinates cache
    └── international-cities-cached.json  # International city cache
```

## Data Sources

- **Weather Data**: [Open-Meteo API](https://open-meteo.com) - Free weather API with no authentication required
- **City Coordinates**: Pre-geocoded city database with 50+ cities per US state and major international cities

## Privacy

This app does not collect or transmit any personal data. Weather data is fetched directly from Open-Meteo API. City preferences are stored locally on device using UserDefaults.

## License

See LICENSE file in the repository root.

## Version

1.0.0 - Initial release
