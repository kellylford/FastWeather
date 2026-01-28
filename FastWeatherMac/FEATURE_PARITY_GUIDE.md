# macOS Feature Parity Implementation Guide

This guide documents the changes needed to bring FastWeatherMac to feature parity with the iOS app.

## ✅ Completed Tasks

1. **FeatureFlags.swift** - Created in Services/ folder
2. **SettingsManager.swift** - Created with DateParser and FormatHelper utilities
3. **HistoricalWeather.swift** - Created in Models/ folder

## 📝 Remaining Implementation Tasks

### Models to Create

#### Settings.swift (Models/)
Port from iOS with these key types:
- `DisplayMode` enum (condensed/details)
- `ViewMode` enum (list/flat/**table** - add table for macOS)
- `WeatherFieldType` enum
- `DetailCategory` enum
- `TemperatureUnit`, `WindSpeedUnit`, `PrecipitationUnit`, `PressureUnit`, `DistanceUnit` enums
- `AppSettings` struct with all weather display preferences
- See: iOS/FastWeather/Models/Settings.swift (lines 1-262)

### Services to Create

#### RadarService.swift (Services/)
Precipitation nowcasting service:
```swift
// Key methods:
func fetchPrecipitationNowcast(for city: City) async throws -> RadarData
```
- Fetches minutely_15 precipitation data from Open-Meteo
- Processes timeline of precipitation forecast
- Creates directional sectors for radar-like view
- See: iOS/FastWeather/Services/RadarService.swift

#### RegionalWeatherService.swift (Services/)
Weather Around Me feature:
```swift
// Key methods:
func fetchRegionalWeather(for city: City, distanceMiles: Double) async throws -> RegionalWeatherData
```
- Fetches weather for 8 cardinal directions + center
- Uses reverse geocoding for location names
- Caches location names to avoid rate limits
- See: iOS/FastWeather/Services/RegionalWeatherService.swift

#### DirectionalCityService.swift (Services/)
Find cities along a bearing:
```swift
// Key methods:
func findCities(from: City, direction: CardinalDirection, maxDistance: Double) async -> [DirectionalCityInfo]
```
- Uses CLGeocoder for reverse geocoding
- Calculates destination coordinates at intervals
- Returns cities along specified direction
- See: iOS/FastWeather/Services/DirectionalCityService.swift

#### HistoricalWeatherCache.swift (Services/)
Cache for historical weather data:
```swift
// Key methods:
func getCached(for city: City, monthDay: String) -> [HistoricalDay]?
func cache(_ data: [HistoricalDay], for city: City, monthDay: String)
```
- Stores historical data by city and month-day key
- Uses Documents directory for persistent storage
- Reduces API calls for frequently viewed dates
- See: iOS/FastWeather/Services/HistoricalWeatherCache.swift

### Views to Create

#### RadarView.swift (Views/)
Expected Precipitation feature:
- Shows minute-by-minute precipitation forecast
- Timeline view with next 2 hours
- Directional sectors showing precipitation movement
- Accessible text description of radar data
- See: iOS/FastWeather/Views/RadarView.swift (392 lines)

**Key Components:**
- Loading/error states
- Timeline chart showing precipitation intensity
- Direction sectors (N, NE, E, SE, S, SW, W, NW)
- Text interpretation for screen readers

#### WeatherAroundMeView.swift (Views/)
Regional weather comparison:
- Distance picker (50-350 mi or 80-560 km)
- Shows weather in 8 directions + center
- Directional City Explorer (browse cities in each direction)
- Temperature delta compass view
- See: iOS/FastWeather/Views/WeatherAroundMeView.swift (694 lines)

**Key Components:**
- Distance selector with options based on unit preference
- 8-direction weather grid
- City explorer with navigation through cities along a bearing
- Weather data fetching for multiple locations

#### HistoricalWeatherView.swift (Views/)
View History feature:
- Three view modes: Single Day, Multi-Year, Daily Browse
- Date picker with navigation
- Shows historical weather for selected date(s)
- Caches data to reduce API calls
- See: iOS/FastWeather/Views/HistoricalWeatherView.swift (641 lines)

**Key Components:**
- View mode selector (single day/multi-year/daily browse)
- Date navigation (next/prev)
- Historical data list with weather details
- Load History button with proper accessibility

#### DeveloperSettingsView.swift (Views/)
Feature flag controls:
- Toggles for radar, weather around me, user guide
- Quick actions (enable all, disable all, reset)
- Alert source information
- See: iOS/FastWeather/Views/DeveloperSettingsView.swift (89 lines) - **already exists in iOS**, can reference it

### Update Existing Views

#### WeatherDetailView.swift
Add feature-flagged buttons:
```swift
if featureFlags.radarEnabled {
    NavigationLink(destination: RadarView(city: city)) {
        Label("Expected Precipitation", systemImage: "cloud.rain")
    }
}

if featureFlags.weatherAroundMeEnabled {
    NavigationLink(destination: WeatherAroundMeView(city: city, defaultDistance: settingsManager.settings.weatherAroundMeDistance)) {
        Label("Weather Around Me", systemImage: "location.circle")
    }
}

// Add HistoricalWeatherView as inline component or sheet
```

#### ContentView.swift 
Add view mode switching:
```swift
enum CityListViewMode {
    case table
    case list
    case flat
}

@State private var viewMode: CityListViewMode = .table

// Toolbar buttons to switch modes
.toolbar {
    ToolbarItem {
        Picker("View Mode", selection: $viewMode) {
            Label("Table", systemImage: "tablecells").tag(CityListViewMode.table)
            Label("List", systemImage: "list.bullet").tag(CityListViewMode.list)
            Label("Flat", systemImage: "square.grid.2x2").tag(CityListViewMode.flat)
        }
        .pickerStyle(.segmented)
    }
}

// Conditional views based on viewMode
switch viewMode {
case .table:
    TableView(cities: cityManager.cities, selectedCity: $selectedCity)
case .list:
    ListView(cities: cityManager.cities, selectedCity: $selectedCity)
case .flat:
    FlatView(cities: cityManager.cities, selectedCity: $selectedCity)
}
```

Create these view components:
- **TableView.swift** - macOS Table with columns for city, temp, conditions, etc.
- **ListView.swift** - Compact list (like current implementation)
- **FlatView.swift** - Card-based grid layout

#### SettingsView.swift
Add Developer Settings navigation:
```swift
NavigationLink(destination: DeveloperSettingsView()) {
    Label("Developer Settings", systemImage: "wrench.and.screwdriver")
}
```

## 🎨 macOS-Specific Considerations

### View Modes
Unlike iOS which only has List and Flat, macOS should support **all three**:
1. **Table** - Native NSTableView-style with sortable columns
2. **List** - Compact row-based list (current implementation)
3. **Flat** - Card/grid layout for visual overview

### Keyboard Shortcuts
Add these to ContentView:
- `Cmd+R`: Refresh weather
- `Cmd+1/2/3`: Switch between Table/List/Flat views
- `Cmd+D`: Open Developer Settings

### Accessibility
- Use `.help()` modifier for toolbar items
- Provide proper `.accessibilityLabel()` and `.accessibilityHint()` for all controls
- Ensure VoiceOver announces view mode changes

## 📋 Data Models Needed

Add these to the existing WeatherModels.swift or create separate files:

```swift
// Radar data models
struct RadarData {
    let currentStatus: String
    let nearestPrecipitation: NearestPrecipitation?
    let directionalSectors: [DirectionalSector]
    let timeline: [TimelinePoint]
}

struct NearestPrecipitation {
    let distanceMiles: Int
    let direction: String
    let type: String
    let intensity: String
    let movementDirection: String
    let speedMph: Int
    let arrivalEstimate: String?
}

struct DirectionalSector: Equatable {
    let direction: String
    let status: String
}

struct TimelinePoint: Equatable {
    let time: String
    let condition: String
}

// Regional weather models
struct RegionalWeatherData {
    let center: DirectionalLocation
    let directions: [DirectionalLocation]
}

struct DirectionalLocation {
    let direction: String
    let latitude: Double
    let longitude: Double
    let temperature: Double?
    let condition: String?
    let locationName: String?
}

// Directional city models
enum CardinalDirection: String, CaseIterable {
    case north = "North"
    case northeast = "Northeast"
    case east = "East"
    case southeast = "Southeast"
    case south = "South"
    case southwest = "Southwest"
    case west = "West"
    case northwest = "Northwest"
    
    var bearing: Double {
        switch self {
        case .north: return 0
        case .northeast: return 45
        case .east: return 90
        case .southeast: return 135
        case .south: return 180
        case .southwest: return 225
        case .west: return 270
        case .northwest: return 315
        }
    }
}

struct DirectionalCityInfo: Identifiable {
    let id: UUID = UUID()
    let name: String
    let state: String?
    let country: String
    let latitude: Double
    let longitude: Double
    let distanceMiles: Double
    let bearing: Double
    
    var displayName: String {
        if let state = state {
            return "\(name), \(state)"
        }
        return name
    }
}
```

## 🔧 Environment Objects Setup

In FastWeatherMacApp.swift (or main app file), inject these:
```swift
@main
struct FastWeatherMacApp: App {
    @StateObject private var cityManager = CityManager()
    @StateObject private var settingsManager = SettingsManager()
    @StateObject private var featureFlags = FeatureFlags.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(cityManager)
                .environmentObject(settingsManager)
                .environmentObject(featureFlags)
                .frame(minWidth: 900, minHeight: 600)
        }
    }
}
```

## 🧪 Testing Checklist

After implementation, verify:
- [ ] Feature flags toggle correctly and persist
- [ ] All three view modes (Table/List/Flat) work
- [ ] Radar view loads precipitation data
- [ ] Weather Around Me shows 8 directions
- [ ] Historical weather supports all 3 modes (single/multi-year/daily)
- [ ] Date parsing works for Open-Meteo format ("2026-01-18T06:50")
- [ ] Settings persist across app launches
- [ ] VoiceOver announces all features properly
- [ ] Keyboard shortcuts work as expected

## 📚 Reference Files

All implementation details can be found in these iOS files:
- Services: iOS/FastWeather/Services/*.swift
- Views: iOS/FastWeather/Views/*.swift
- Models: iOS/FastWeather/Models/*.swift

Port these to macOS with AppKit-specific adjustments where needed (e.g., NSTableView vs UITableView, NSColor vs UIColor).
