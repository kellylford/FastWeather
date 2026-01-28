# macOS View Modes - Correct Implementation Plan

## Understanding the iOS/Web View Structure

### View Modes (Top Level)
- **List View** - Compact list with weather summary per city
  - Has **Display Mode** setting: Condensed vs. Details
  - **Condensed**: Shows data values only (e.g., "72°F • Clear • 45%")
  - **Details**: Shows field labels + values (e.g., "Temperature: 72°F • Conditions: Clear • Humidity: 45%")
  - Navigation link to full detail view per city
  
- **Flat View** - Linear sectioned list (like a long web page)
  - Always shows field labels (always in "details" mode)
  - Each city is a separate section with header
  - All weather fields shown as rows within the section
  - No navigation - all data visible inline
  
- **Table View** (Web/macOS only) - Proper tabular layout
  - Rows = Cities
  - Columns = Configured weather fields (temp, conditions, wind, etc.)
  - Column headers show field names
  - Compact data display in cells
  
### Current macOS Implementation (WRONG)

The current macOS app has these files but they're not implemented correctly:

1. **TableView.swift** - Currently a simplified List, should be an actual Table component
2. **ListView.swift** - Incorrectly treats state/country as data to display
3. **FlatView.swift** - Incorrectly treats state/country as data to display
4. **ContentView.swift** - Has wrong view mode picker (Table/List/Flat instead of List/Flat, with List having display mode toggle)

### Required Changes

#### 1. Settings Model (Create new AppSettings if needed)
```swift
// In Models/Settings.swift or new file
enum DisplayMode: String, CaseIterable, Codable {
    case condensed = "Condensed"
    case details = "Details"
}

enum ViewMode: String, CaseIterable, Codable {
    case list = "List"
    case flat = "Flat"
}

struct AppSettings: Codable {
    var viewMode: ViewMode = .list
    var displayMode: DisplayMode = .condensed
    var temperatureUnit: TemperatureUnit = .fahrenheit
    // ... other settings
    
    var weatherFields: [WeatherField] = [
        WeatherField(type: .temperature, isEnabled: true),
        WeatherField(type: .conditions, isEnabled: true),
        // ... etc
    ]
}
```

#### 2. ContentView.swift Changes
- Remove Table from view mode picker
- Add List and Flat only
- When List is selected, show **Display Mode** toggle (Condensed/Details)
- Toolbar should have:
  - View Mode picker (List/Flat)
  - Display Mode toggle (only visible when List view active)
  - Add City button
  - Refresh button

#### 3. ListView.swift - Complete Rewrite
Should be compact list like iOS:
- Each row shows city name + weather summary
- Summary built from enabled weather fields in settings
- Condensed mode: "72°F • Clear • 45% • 15 mph"
- Details mode: "Temperature: 72°F • Conditions: Clear • Humidity: 45% • Wind Speed: 15 mph"
- Navigation link to CityDetailView for full weather
- Context menu for actions (remove, refresh, etc.)
- VoiceOver: Proper accessibility labels with all data

#### 4. FlatView.swift - Verify Implementation
Should show all cities as sections:
- Section header: City name + current temp
- Section content: All enabled weather fields as rows
- Always shows field labels (always "details" mode)
- Actions menu at bottom of each section
- No navigation links - everything visible inline

#### 5. TableView.swift - Completely New (macOS Exclusive)
Use SwiftUI Table component:
```swift
Table(selection: $selectedCity) {
    TableColumn("City") { city in
        Text(city.displayName)
    }
    
    // Dynamic columns based on enabled weather fields
    if settingsManager.settings.weatherFields.first(where: { $0.type == .temperature && $0.isEnabled }) != nil {
        TableColumn("Temperature") { city in
            if let weather = getWeather(for: city) {
                Text(formatTemperature(weather.current.temperature2m))
            } else {
                Text("Loading...")
            }
        }
    }
    
    // ... more columns for enabled fields
} rows: {
    ForEach(cityManager.cities) { city in
        TableRow(city)
    }
}
```

#### 6. Create Settings View
Need a settings panel to:
- Configure which weather fields are shown/hidden
- Reorder weather fields (drag and drop)
- Set units (temp, wind, precipitation)
- Set view mode and display mode preferences

### Testing Plan
1. Test List View - Condensed mode
2. Test List View - Details mode  
3. Test Flat View (always detailed)
4. Test Table View with all columns
5. Test Table View with some fields disabled
6. Verify VoiceOver reads everything correctly in all modes
7. Test field reordering in settings

### References
- iOS ListView.swift: Lines 1-431
- iOS FlatView.swift: Lines 1-273
- iOS Settings.swift: Lines 1-262
- Web app table view: webapp/app.js lines 2250-2300
