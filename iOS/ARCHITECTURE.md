# FastWeather iOS - Developer Architecture Guide

**For AI Assistants and Developers**

This document provides a comprehensive overview of the FastWeather iOS app architecture, patterns, and conventions to enable effective code assistance and development.

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [Architecture Patterns](#architecture-patterns)
3. [Project Structure](#project-structure)
4. [Core Services](#core-services)
5. [Data Models](#data-models)
6. [View Architecture](#view-architecture)
7. [Feature Flags System](#feature-flags-system)
8. [Settings Management](#settings-management)
9. [Accessibility Implementation](#accessibility-implementation)
10. [API Integration](#api-integration)
11. [Caching Strategy](#caching-strategy)
12. [Common Patterns](#common-patterns)
13. [Development Guidelines](#development-guidelines)

---

## Project Overview

**App Name:** FastWeather  
**Platform:** iOS 17.0+  
**Framework:** SwiftUI  
**Language:** Swift  
**Architecture:** MVVM with Service Layer  
**Primary Focus:** Accessibility-first weather application

### Key Features
- Multi-city weather tracking
- Historical weather data (1940-present)
- Hourly and daily forecasts
- Weather alerts (U.S. NWS)
- Precipitation forecast (feature-flagged)
- Regional weather comparison (feature-flagged)
- State/country city browser
- Highly customizable settings
- Full VoiceOver support

---

## Architecture Patterns

### MVVM (Model-View-ViewModel)

```
┌─────────────────┐
│     Views       │  SwiftUI Views
│  (UI Layer)     │  - ContentView, CityDetailView, etc.
└────────┬────────┘
         │
         │ Observes
         ▼
┌─────────────────┐
│  ViewModels /   │  ObservableObject classes
│    Services     │  - WeatherService, SettingsManager
└────────┬────────┘
         │
         │ Uses
         ▼
┌─────────────────┐
│     Models      │  Data structures
│  (Data Layer)   │  - City, WeatherData, AppSettings
└─────────────────┘
```

### Service Layer Pattern

Services are singletons or `@EnvironmentObject` instances that manage:
- Data fetching (API calls)
- Data persistence (UserDefaults, cache)
- Business logic
- State management

**Key Services:**
- `WeatherService` - Weather data fetching and caching
- `SettingsManager` - App settings persistence
- `FeatureFlags` - Feature toggle management

---

## Project Structure

```
FastWeather/
├── FastWeatherApp.swift          # App entry point
├── Models/                        # Data models
│   ├── WeatherModels.swift       # Weather API response models
│   ├── Settings.swift            # App settings models
│   ├── City.swift                # City data model
│   └── WeatherAlert.swift        # Alert models
├── Services/                      # Business logic layer
│   ├── WeatherService.swift      # Weather API client
│   ├── SettingsManager.swift     # Settings + DateParser + FormatHelper
│   └── FeatureFlags.swift        # Feature flag management
├── Views/                         # SwiftUI views
│   ├── ContentView.swift         # Main tab container
│   ├── MyCitiesView.swift        # My Cities tab (delegates to List/Table/Flat)
│   ├── ListView.swift            # List view mode
│   ├── TableView.swift           # Table view mode
│   ├── FlatView.swift            # Flat card view mode
│   ├── CityDetailView.swift      # Detailed weather view
│   ├── HistoricalWeatherView.swift  # Historical data
│   ├── RadarView.swift           # Precipitation forecast
│   ├── WeatherAroundMeView.swift # Regional comparison
│   ├── BrowseCitiesView.swift    # City browser
│   ├── StateCitiesView.swift     # State/country drill-down
│   ├── AddCitySearchView.swift   # City search
│   ├── SettingsView.swift        # Settings screen
│   ├── DeveloperSettingsView.swift  # Feature flags
│   ├── UserGuideView.swift       # User documentation
│   └── ...                       # Supporting views
└── Assets.xcassets/               # Images, icons, colors
```

---

## Core Services

### WeatherService

**Purpose:** Centralized weather data management  
**Pattern:** Singleton + `ObservableObject`  
**Responsibilities:**
- Fetch current weather from Open-Meteo API
- Fetch historical weather data
- Fetch NWS weather alerts (U.S. only)
- Cache weather data in memory
- Manage saved cities list
- Persist cities to UserDefaults

**Key Properties:**
```swift
@Published var savedCities: [City]           // User's city list
@Published var weatherCache: [UUID: WeatherData]  // In-memory cache
```

**Key Methods:**
```swift
func fetchWeather(for city: City) async throws -> WeatherData
func fetchHistoricalWeather(for city: City, date: Date) async throws -> HistoricalWeatherData
func fetchNWSAlerts(for city: City) async throws -> [WeatherAlert]
func addCity(_ city: City)
func removeCity(_ city: City)
func saveCities()  // Persist to UserDefaults
```

**Usage:**
```swift
@EnvironmentObject var weatherService: WeatherService

// Fetch weather
Task {
    await weatherService.fetchWeather(for: city)
}

// Access cached weather
if let weather = weatherService.weatherCache[city.id] {
    // Use weather data
}
```

### SettingsManager

**Purpose:** App settings persistence and formatting utilities  
**Pattern:** Singleton + `ObservableObject`  
**Responsibilities:**
- Load/save app settings from UserDefaults
- Provide centralized date/time parsing (`DateParser`)
- Provide centralized formatting utilities (`FormatHelper`)

**Key Properties:**
```swift
@Published var settings: AppSettings  // All app settings
```

**Key Methods:**
```swift
func saveSettings()
func resetToDefaults()
```

**Utilities:**
```swift
// DateParser - Parse Open-Meteo timestamps
DateParser.parse("2026-01-18T06:50") -> Date?

// FormatHelper - Format times for display
FormatHelper.formatTime("2026-01-18T06:50") -> "6:50 AM"
FormatHelper.formatTimeCompact("2026-01-18T15:00") -> "3 PM"
```

### FeatureFlags

**Purpose:** Toggle in-development features without code changes  
**Pattern:** Singleton + `ObservableObject`  
**Responsibilities:**
- Enable/disable experimental features
- Persist flag states to UserDefaults
- Provide bulk toggle methods

**Key Properties:**
```swift
@Published var radarEnabled: Bool              // Expected Precipitation
@Published var weatherAroundMeEnabled: Bool    // Regional weather
@Published var userGuideEnabled: Bool          // User guide link
```

**Usage:**
```swift
@StateObject private var featureFlags = FeatureFlags.shared

if featureFlags.radarEnabled {
    // Show Expected Precipitation button
}
```

---

## Data Models

### City

**File:** `Models/City.swift` (likely, or in `WeatherModels.swift`)  
**Purpose:** Represents a geographic location

```swift
struct City: Identifiable, Codable {
    var id: UUID
    var name: String
    var displayName: String  // "Name, State, Country"
    var latitude: Double
    var longitude: Double
    var state: String?
    var country: String?
}
```

### WeatherData

**File:** `Models/WeatherModels.swift`  
**Purpose:** Current weather snapshot from API

```swift
struct WeatherData: Codable {
    let current: CurrentWeather
    let hourly: HourlyWeather?
    let daily: DailyWeather?
    // ... timezone, elevation
}

struct CurrentWeather: Codable {
    let temperature2m: Double
    let relativeHumidity2m: Int?
    let apparentTemperature: Double?
    let weatherCode: Int
    let windSpeed10m: Double?
    // ... many more fields
}
```

### AppSettings

**File:** `Models/Settings.swift`  
**Purpose:** User preferences

```swift
struct AppSettings: Codable {
    var viewMode: ViewMode = .list
    var displayMode: DisplayMode = .condensed
    var temperatureUnit: TemperatureUnit = .fahrenheit
    var windSpeedUnit: WindSpeedUnit = .mph
    var precipitationUnit: PrecipitationUnit = .inches
    var pressureUnit: PressureUnit = .inHg
    var historicalYearsBack: Int = 20
    var weatherAroundMeDistance: Double = 150  // miles
    
    var weatherFields: [WeatherField]  // Ordered, toggleable
    var detailCategories: [DetailCategoryField]  // Ordered, toggleable
}
```

**Enums:**
```swift
enum ViewMode: String, Codable, CaseIterable {
    case list, table, flat
}

enum TemperatureUnit: String, Codable, CaseIterable {
    case fahrenheit = "°F"
    case celsius = "°C"
    
    func convert(_ celsius: Double) -> Double
}
```

---

## View Architecture

### Tab Structure

```
ContentView (TabView)
├── Tab 1: MyCitiesView
│   └── Delegates to ListView / TableView / FlatView based on settings
├── Tab 2: BrowseCitiesView
│   └── State/Country picker → StateCitiesView
└── Tab 3: SettingsView
```

### Navigation Pattern

- **Tabs:** Top-level navigation via `TabView`
- **Detail views:** `NavigationLink` or `.sheet()` for modals
- **Dismiss:** Use `@Environment(\.dismiss)` for programmatic back navigation

### View Modes (My Cities Tab)

The `MyCitiesView` delegates rendering to one of three view modes:

1. **ListView** - Vertical list with swipe actions
2. **TableView** - Compact table format
3. **FlatView** - Card-based grid layout

**Selection logic:**
```swift
switch settingsManager.settings.viewMode {
case .list: ListView()
case .table: TableView()
case .flat: FlatView()
}
```

### City Detail View

**File:** `Views/CityDetailView.swift`  
**Structure:**
- Header: City name, current temp, conditions
- Actions menu: Historical, Precipitation, Weather Around Me, Remove
- Dynamically rendered sections (based on `detailCategories` in settings):
  - Weather Alerts
  - Today's Forecast
  - Current Conditions
  - Precipitation
  - Hourly Forecast
  - Daily Forecast
  - Location Info

**Section ordering:**
```swift
ForEach(settingsManager.settings.detailCategories) { categoryField in
    if categoryField.isEnabled {
        detailSection(for: categoryField.category, weather: weather)
    }
}
```

---

## Feature Flags System

### Purpose
Control visibility of in-development features without code branches or app store submissions.

### Implementation

**File:** `Services/FeatureFlags.swift`

```swift
class FeatureFlags: ObservableObject {
    static let shared = FeatureFlags()
    
    @Published var radarEnabled: Bool
    @Published var weatherAroundMeEnabled: Bool
    @Published var userGuideEnabled: Bool
    
    // Persists to UserDefaults automatically via didSet
}
```

### Usage in Views

```swift
@StateObject private var featureFlags = FeatureFlags.shared

if featureFlags.radarEnabled {
    Button("Expected Precipitation") { ... }
}
```

### Developer Settings

**File:** `Views/DeveloperSettingsView.swift`  
Access via: Settings → Developer Settings (bottom of screen)

Provides toggles for all feature flags plus quick actions:
- Enable All Features
- Disable All Features
- Reset to Defaults

---

## Settings Management

### Persistence

All settings stored in `UserDefaults` as JSON-encoded `AppSettings` struct.

**Save:**
```swift
settingsManager.saveSettings()
```

**Auto-save on change:**
```swift
Picker(...) { ... }
    .onChange(of: settingsManager.settings.temperatureUnit) {
        settingsManager.saveSettings()
    }
```

### Customizable Elements

1. **Weather Fields** (List/Table/Flat views)
   - Reorderable via drag-and-drop
   - Toggleable (show/hide)
   - Options: Temperature, Conditions, Feels Like, Humidity, Wind Speed, etc.

2. **Detail Categories** (City Detail view)
   - Reorderable via drag-and-drop
   - Toggleable (show/hide)
   - Options: Weather Alerts, Today's Forecast, Current Conditions, etc.

3. **Units**
   - Temperature: °F / °C
   - Wind Speed: mph / km/h / m/s / knots
   - Precipitation: inches / mm
   - Pressure: inHg / hPa / mmHg

4. **Display Options**
   - View Mode: List / Table / Flat
   - Display Mode: Condensed / Expanded
   - Historical Years: 1-50 years back

---

## Accessibility Implementation

### VoiceOver Support

**CRITICAL PATTERNS:**

1. **Custom Labels with `.ignore`:**
   ```swift
   .accessibilityElement(children: .ignore)  // NOT .combine!
   .accessibilityLabel("Custom label text")
   ```

2. **Order matters:**
   ```swift
   // GOOD: "San Diego, California, 72°F, Conditions: Clear"
   // BAD: "Conditions: Clear, San Diego, California, 72°F"
   ```

3. **Time formatting:**
   ```swift
   // Use centralized formatters
   FormatHelper.formatTime(isoString)  // "6:50 AM"
   ```

4. **Silent failures are dangerous:**
   ```swift
   guard let date = DateParser.parse(string) else {
       print("⚠️ Failed to parse: '\(string)'")
       return "Unknown"  // Don't return empty string
   }
   ```

### Accessibility Checklist

- [ ] All interactive elements have `.accessibilityLabel()`
- [ ] Buttons have `.accessibilityHint()` explaining action
- [ ] Use `.accessibilityElement(children: .ignore)` with custom labels
- [ ] Decorative images have `.accessibilityHidden(true)`
- [ ] Headers use `.accessibilityAddTraits(.isHeader)`
- [ ] Date/time uses `FormatHelper.formatTime()` not raw ISO8601
- [ ] Test with VoiceOver (⌘F5 on Mac Catalyst)

### Common Patterns

```swift
// Button with label and hint
Button("Refresh") { ... }
    .accessibilityLabel("Refresh weather")
    .accessibilityHint("Updates weather data for \(city.name)")

// Custom grouped element
HStack {
    Text(city.name)
    Text(temperature)
}
.accessibilityElement(children: .ignore)
.accessibilityLabel("\(city.name), \(temperature), \(conditions)")

// Header
Text("Current Conditions")
    .font(.headline)
    .accessibilityAddTraits(.isHeader)
```

---

## API Integration

### Open-Meteo Weather API

**Base URL:** `https://api.open-meteo.com/v1/forecast`  
**Authentication:** None required  
**Rate Limit:** Generous, no API key needed

**Current Weather Request:**
```swift
let params = [
    "latitude": "\(city.latitude)",
    "longitude": "\(city.longitude)",
    "current": "temperature_2m,relative_humidity_2m,weathercode,...",
    "hourly": "temperature_2m,precipitation,...",
    "daily": "temperature_2m_max,temperature_2m_min,...",
    "timezone": "auto"
]
```

**Date Format:** `"yyyy-MM-dd'T'HH:mm"` (no timezone, no seconds)  
⚠️ **Do NOT use `ISO8601DateFormatter` directly** - use `DateParser.parse()`

### Historical Weather API

**Base URL:** `https://archive-api.open-meteo.com/v1/archive`  
**Date Range:** 1940-01-01 to yesterday  
**Same parameters as forecast API**

### NWS Weather Alerts

**Base URL:** `https://api.weather.gov/alerts/active`  
**Parameters:** `?point=lat,lon`  
**Coverage:** U.S. locations only  
**Format:** JSON-LD with GeoJSON

---

## Caching Strategy

### In-Memory Cache

**WeatherService.weatherCache:**
```swift
@Published var weatherCache: [UUID: WeatherData] = [:]
```

**Pattern:**
1. Check cache first
2. If missing or stale, fetch from API
3. Update cache
4. Publish changes (triggers UI update via `@Published`)

### UserDefaults Storage

**Saved Cities:**
```swift
// Stored as JSON array
UserDefaults.standard.data(forKey: "SavedCities")
```

**Settings:**
```swift
// Stored as JSON object
UserDefaults.standard.data(forKey: "AppSettings")
```

**Feature Flags:**
```swift
// Stored as individual bools
UserDefaults.standard.bool(forKey: "feature_radar_enabled")
```

### Cache Invalidation

- Weather cache: In-memory only (cleared on app restart)
- Historical cache: Separate cache in `WeatherService`
- Manual refresh: Pull-to-refresh or refresh button

---

## Common Patterns

### Async/Await Weather Fetching

```swift
Task {
    do {
        let weather = try await weatherService.fetchWeather(for: city)
        // UI updates automatically via @Published
    } catch {
        print("Error: \(error)")
    }
}
```

### Environment Objects

**Inject at app root:**
```swift
@main
struct FastWeatherApp: App {
    @StateObject private var weatherService = WeatherService()
    @StateObject private var settingsManager = SettingsManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(weatherService)
                .environmentObject(settingsManager)
        }
    }
}
```

**Access in views:**
```swift
@EnvironmentObject var weatherService: WeatherService
@EnvironmentObject var settingsManager: SettingsManager
```

### Conditional Rendering

**Feature-flagged:**
```swift
if featureFlags.radarEnabled {
    Button("Expected Precipitation") { ... }
}
```

**Settings-based:**
```swift
if settingsManager.settings.weatherFields.first(where: { $0.type == .humidity })?.isEnabled == true {
    Text("Humidity: \(humidity)%")
}
```

### Sheet Presentation

```swift
@State private var showingDetail = false

Button("Show Detail") {
    showingDetail = true
}
.sheet(isPresented: $showingDetail) {
    DetailView()
        .environmentObject(weatherService)
}
```

---

## Development Guidelines

### Code Style

1. **Use explicit types when clarity matters:**
   ```swift
   let temperature: Double = 72.5  // Good
   let temp = 72.5  // OK if obvious
   ```

2. **Prefer `guard` for early exits:**
   ```swift
   guard let weather = weatherService.weatherCache[city.id] else {
       return Text("Loading...")
   }
   ```

3. **Use `async/await` for network calls:**
   ```swift
   Task {
       let weather = try await weatherService.fetchWeather(for: city)
   }
   ```

4. **Always provide accessibility labels:**
   ```swift
   Button("Refresh") { ... }
       .accessibilityLabel("Refresh weather for \(city.name)")
   ```

### File Organization

- **Models:** Pure data structures, Codable, no logic
- **Services:** ObservableObject, business logic, API calls
- **Views:** SwiftUI views only, delegate logic to services
- **Extensions:** Use sparingly, prefer utilities in services

### Adding New Features

1. **Add feature flag** (if experimental):
   ```swift
   // FeatureFlags.swift
   @Published var newFeatureEnabled: Bool { didSet { ... } }
   ```

2. **Add to DeveloperSettingsView:**
   ```swift
   Toggle("New Feature", isOn: $featureFlags.newFeatureEnabled)
   ```

3. **Implement feature:**
   ```swift
   if featureFlags.newFeatureEnabled {
       NewFeatureView()
   }
   ```

4. **Test with VoiceOver** before enabling by default

### Testing Checklist

- [ ] Build succeeds on iOS Simulator
- [ ] Build succeeds on Mac Catalyst
- [ ] VoiceOver announces all elements correctly
- [ ] Pull-to-refresh works
- [ ] Settings persist across app restarts
- [ ] API errors are handled gracefully
- [ ] Empty states display properly
- [ ] Large font sizes don't break layout

---

## Common Issues & Solutions

### Issue: Date Parsing Fails

**Problem:** `ISO8601DateFormatter` can't parse Open-Meteo timestamps  
**Solution:** Use `DateParser.parse(isoString)` from SettingsManager.swift

### Issue: VoiceOver Reads Wrong Order

**Problem:** Visual layout != VoiceOver order  
**Solution:** Use `.accessibilityElement(children: .ignore)` + custom label

### Issue: Settings Don't Persist

**Problem:** `settingsManager.saveSettings()` not called  
**Solution:** Add `.onChange()` modifier to settings controls

### Issue: Feature Flag Not Working

**Problem:** Using wrong instance of FeatureFlags  
**Solution:** Always use `FeatureFlags.shared`, not creating new instances

### Issue: Weather Data Missing

**Problem:** Accessing optional fields without nil-check  
**Solution:** Use `if let` or `guard let` before accessing optionals

---

## Quick Reference

### Key Files to Know

| File | Purpose |
|------|---------|
| `FastWeatherApp.swift` | App entry point, environment objects |
| `WeatherService.swift` | Weather API client, city management |
| `SettingsManager.swift` | Settings persistence, date/time utilities |
| `FeatureFlags.swift` | Feature toggles |
| `Settings.swift` | Settings data models |
| `WeatherModels.swift` | API response models |
| `CityDetailView.swift` | Main weather display |
| `HistoricalWeatherView.swift` | Historical weather UI |

### Environment Objects

```swift
@EnvironmentObject var weatherService: WeatherService
@EnvironmentObject var settingsManager: SettingsManager
@StateObject private var featureFlags = FeatureFlags.shared
```

### Common Utilities

```swift
// Date parsing
DateParser.parse("2026-01-18T06:50") -> Date?

// Time formatting
FormatHelper.formatTime("2026-01-18T06:50") -> "6:50 AM"
FormatHelper.formatTimeCompact("2026-01-18T15:00") -> "3 PM"

// Unit conversion
settingsManager.settings.temperatureUnit.convert(celsius)
settingsManager.settings.windSpeedUnit.convert(kmh)
```

---

## For AI Assistants

When helping with this codebase:

1. **Always check feature flags** before adding features to views
2. **Use centralized utilities** (DateParser, FormatHelper) for date/time
3. **Follow accessibility patterns** exactly as documented
4. **Respect settings structure** - changes must persist via `saveSettings()`
5. **Use environment objects** - don't create new service instances
6. **Test assumptions** - search codebase before assuming API exists
7. **Preserve user experience** - don't disable features to "fix" bugs
8. **Consider edge cases** - empty states, errors, loading states
9. **Match existing patterns** - consistency is critical for maintenance
10. **Document significant changes** - update this file when architecture changes

### Before Making Changes

- [ ] Search for similar implementations
- [ ] Check if feature flag is needed
- [ ] Verify environment objects are available
- [ ] Plan accessibility implementation
- [ ] Consider settings persistence

### After Making Changes

- [ ] Build succeeds
- [ ] Accessibility labels are correct
- [ ] Settings persist if applicable
- [ ] No crashes on nil data
- [ ] VoiceOver tested (if UI changes)

---

**Last Updated:** January 24, 2026  
**Version:** 1.0  
**Maintainer:** FastWeather Development Team
