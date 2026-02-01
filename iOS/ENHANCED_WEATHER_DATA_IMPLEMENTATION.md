# Enhanced Weather Data Implementation Guide for iOS

**Target Platform:** FastWeather iOS (SwiftUI)  
**Implementation Status:** NOT YET IMPLEMENTED - AI Agent Instructions  
**Related Web Implementation:** Completed in webapp/ (Phases 1 & 2)

## Overview

This document provides AI agent-readable instructions for implementing enhanced weather data features in the FastWeather iOS application. These features match the Phase 1 and 2 enhancements already implemented in the web application.

## Prerequisites

**CRITICAL - Read First:**
- Review [.github/copilot-instructions.md](../.github/copilot-instructions.md) for development philosophy
- All iOS code changes MUST build successfully: `cd iOS && xcodebuild -project FastWeather.xcodeproj -scheme FastWeather -configuration Debug build`
- Must see `** BUILD SUCCEEDED **` before considering work complete
- Follow accessibility patterns in [iOS/ACCESSIBILITY.md](ACCESSIBILITY.md)
- Use centralized `DateParser.parse()` and `FormatHelper` utilities in [Services/SettingsManager.swift](FastWeather/Services/SettingsManager.swift)

## Phase 1: Quick Wins (Priority Features)

### 1. UV Index Badge Display

**Objective:** Add color-coded UV Index badges to city views with accessibility support

**Implementation Location:**
- **City List Views:** Add UV badge to [Views/ListView.swift](FastWeather/Views/ListView.swift) and [Views/FlatView.swift](FastWeather/Views/FlatView.swift)
- **Detail View:** Add UV information to [Views/CityDetailView.swift](FastWeather/Views/CityDetailView.swift)

**Data Model Changes:**
File: [Models/WeatherModels.swift](FastWeather/Models/WeatherModels.swift)

```swift
// Add to CurrentWeather struct
struct CurrentWeather: Codable {
    // ... existing fields ...
    let windGusts10m: Double?
    let uvIndex: Double?
    let dewpoint2m: Double?
    
    enum CodingKeys: String, CodingKey {
        // ... existing cases ...
        case windGusts10m = "wind_gusts_10m"
        case uvIndex = "uv_index"
        case dewpoint2m = "dewpoint_2m"
    }
}

// Add to HourlyWeather struct
struct HourlyWeather: Codable {
    // ... existing fields ...
    let precipitationProbability: [Int]?
    let uvIndex: [Double]?
    let windgusts10m: [Double]?
    let dewpoint2m: [Double]?
    
    enum CodingKeys: String, CodingKey {
        // ... existing cases ...
        case precipitationProbability = "precipitation_probability"
        case uvIndex = "uv_index"
        case windgusts10m = "windgusts_10m"
        case dewpoint2m = "dewpoint_2m"
    }
}

// Add to DailyWeather struct
struct DailyWeather: Codable {
    // ... existing fields ...
    let precipitationProbabilityMax: [Int]?
    let uvIndexMax: [Double]?
    let daylightDuration: [Double]?
    let sunshineDuration: [Double]?
    
    enum CodingKeys: String, CodingKey {
        // ... existing cases ...
        case precipitationProbabilityMax = "precipitation_probability_max"
        case uvIndexMax = "uv_index_max"
        case daylightDuration = "daylight_duration"
        case sunshineDuration = "sunshine_duration"
    }
}
```

**Helper Functions:**
Create new file: [Utilities/WeatherHelpers.swift](FastWeather/Utilities/WeatherHelpers.swift)

```swift
import SwiftUI

// MARK: - UV Index Helpers
struct UVIndexCategory {
    let category: String
    let color: Color
    let textColor: Color
    
    init(uvIndex: Double?) {
        guard let uv = uvIndex else {
            category = "Unknown"
            color = Color.gray
            textColor = Color.white
            return
        }
        
        switch uv {
        case 0...2:
            category = "Low"
            color = Color(red: 0.16, green: 0.58, blue: 0)
            textColor = Color.white
        case 2...5:
            category = "Moderate"
            color = Color(red: 0.97, green: 0.89, blue: 0)
            textColor = Color.black
        case 5...7:
            category = "High"
            color = Color(red: 0.97, green: 0.35, blue: 0)
            textColor = Color.white
        case 7...10:
            category = "Very High"
            color = Color(red: 0.85, green: 0, blue: 0.11)
            textColor = Color.white
        default:
            category = "Extreme"
            color = Color(red: 0.42, green: 0.29, blue: 0.78)
            textColor = Color.white
        }
    }
}

func getUVIndexDescription(_ uvIndex: Double?) -> String {
    guard let uv = uvIndex else { return "UV data unavailable" }
    let category = UVIndexCategory(uvIndex: uv)
    var description = "UV Index: \(Int(uv.rounded())) (\(category.category))"
    
    switch uv {
    case 0...2:
        description += " - Minimal protection needed"
    case 2...5:
        description += " - Use SPF 30+ sunscreen"
    case 5...7:
        description += " - Use SPF 30+ sunscreen, seek shade"
    case 7...10:
        description += " - Use SPF 50+ sunscreen, avoid midday sun"
    default:
        description += " - Take all precautions, stay indoors if possible"
    }
    
    return description
}

// MARK: - Dew Point Helpers
func getDewPointComfort(_ dewPointF: Double?) -> String {
    guard let dp = dewPointF else { return "Unknown" }
    
    switch dp {
    case ..<50:
        return "Dry"
    case 50..<60:
        return "Comfortable"
    case 60..<65:
        return "Slightly humid"
    case 65..<70:
        return "Muggy/Uncomfortable"
    default:
        return "Oppressive"
    }
}

func formatDewPoint(_ dewPointC: Double?, isFahrenheit: Bool) -> String {
    guard let dp = dewPointC else { return "N/A" }
    
    let temp: Double
    if isFahrenheit {
        temp = (dp * 9/5) + 32
    } else {
        temp = dp
    }
    
    let comfort = getDewPointComfort(isFahrenheit ? temp : (dp * 9/5) + 32)
    let unit = isFahrenheit ? "°F" : "°C"
    
    return "\(Int(temp.rounded()))\(unit) (\(comfort))"
}

// MARK: - Duration Helpers
func formatDuration(_ seconds: Double?) -> String {
    guard let secs = seconds else { return "N/A" }
    
    let hours = Int(secs / 3600)
    let minutes = Int((secs.truncatingRemainder(dividingBy: 3600)) / 60)
    
    return "\(hours)h \(minutes)m"
}
```

**UI Component - UV Badge:**
Add to relevant view files:

```swift
// UV Index Badge View Component
struct UVBadge: View {
    let uvIndex: Double?
    
    var body: some View {
        if let uv = uvIndex {
            let category = UVIndexCategory(uvIndex: uv)
            Text("UV: \(Int(uv.rounded())) (\(category.category))")
                .font(.caption)
                .fontWeight(.semibold)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(category.color)
                .foregroundColor(category.textColor)
                .cornerRadius(12)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(getUVIndexDescription(uv))
        }
    }
}
```

### 2. Wind Gusts Integration

**Objective:** Show wind gusts alongside wind speed throughout the app

**Implementation Pattern:**
Wherever wind speed is currently displayed, enhance to show gusts:

**Current:**
```swift
Text("Wind: \(windSpeed) mph NE")
```

**Enhanced:**
```swift
func formatWind(speed: Double, direction: Int, gusts: Double? = nil, unit: String = "mph") -> String {
    let cardinal = degreesToCardinal(direction)
    var text = "\(Int(speed.rounded())) \(unit) \(cardinal)"
    if let gustSpeed = gusts {
        text += ", gusts \(Int(gustSpeed.rounded())) \(unit)"
    }
    return text
}

// Usage:
Text("Wind: \(formatWind(speed: current.windSpeed10m, direction: current.windDirection10m, gusts: current.windGusts10m))")
```

**Accessibility Note:**
```swift
.accessibilityLabel("Wind: \(formatWind(...)) - Screen reader hears full description")
```

### 3. Precipitation Probability

**Objective:** Show rain chance percentage in hourly and daily forecasts

**Hourly Forecast Enhancement:**
```swift
// In hourly forecast item
VStack(alignment: .leading, spacing: 4) {
    Text(hourTime)
    Text(condition)
    Text("\(temperature)°")
    
    // NEW: Precipitation probability
    if let precipProb = hourly.precipitationProbability?[index], precipProb > 0 {
        HStack(spacing: 2) {
            Image(systemName: "drop.fill")
                .font(.caption2)
            Text("\(precipProb)%")
                .font(.caption)
        }
        .foregroundColor(.blue)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(precipProb)% chance of rain")
    }
}
```

**Daily Forecast Enhancement:**
```swift
// In daily forecast item
if let precipProb = daily.precipitationProbabilityMax?[index], precipProb > 0 {
    Text("Rain Chance: \(precipProb)%")
        .font(.caption)
        .accessibilityLabel("\(precipProb) percent chance of rain")
}
```

## Phase 2: Moderate Effort (Enhanced Details)

### 4. Dew Point in Detail View

**Location:** [Views/CityDetailView.swift](FastWeather/Views/CityDetailView.swift)

Add to current conditions section:
```swift
if let dewPoint = weather.current.dewpoint2m {
    LabeledContent("Dew Point", value: formatDewPoint(dewPoint, isFahrenheit: settingsManager.settings.temperatureUnit == .fahrenheit))
        .accessibilityElement(children: .combine)
}
```

### 5. Daylight & Sunshine Duration

**Location:** Daily forecast section in [Views/CityDetailView.swift](FastWeather/Views/CityDetailView.swift)

```swift
// Add to each daily forecast item
if let daylightDuration = weather.daily.daylightDuration?[index] {
    Text("☀️ \(formatDuration(daylightDuration)) daylight")
        .font(.caption2)
        .accessibilityLabel("\(formatDuration(daylightDuration)) of daylight")
}

if let sunshineDuration = weather.daily.sunshineDuration?[index] {
    Text("☀️ \(formatDuration(sunshineDuration)) sunshine")
        .font(.caption2)
        .accessibilityLabel("\(formatDuration(sunshineDuration)) of sunshine")
}
```

## API Fetch Parameter Updates

**File:** [Services/WeatherService.swift](FastWeather/Services/WeatherService.swift)

**Current parameters need enhancement:**

```swift
func fetchWeather(for city: City, includeHourly: Bool = true, includeDaily: Bool = true) async throws -> WeatherResponse {
    var params: [String: String] = [
        "latitude": "\(city.latitude)",
        "longitude": "\(city.longitude)",
        "current": "temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,rain,showers,snowfall,weather_code,cloud_cover,pressure_msl,wind_speed_10m,wind_direction_10m,wind_gusts_10m,visibility,uv_index,dewpoint_2m",
        "timezone": "auto"
    ]
    
    if includeHourly {
        params["hourly"] = "temperature_2m,apparent_temperature,relative_humidity_2m,dewpoint_2m,precipitation,precipitation_probability,weathercode,cloudcover,windspeed_10m,windgusts_10m,uv_index"
    }
    
    if includeDaily {
        params["daily"] = "weathercode,temperature_2m_max,temperature_2m_min,sunrise,sunset,precipitation_sum,precipitation_probability_max,windspeed_10m_max,uv_index_max,daylight_duration,sunshine_duration"
        params["forecast_days"] = "16"
    }
    
    // ... rest of function
}
```

## Settings/Configuration Updates

**File:** [Models/AppSettings.swift](FastWeather/Models/AppSettings.swift)

Add toggles for new features:

```swift
struct AppSettings: Codable {
    // ... existing settings ...
    
    // NEW: Enhanced data display options
    var showUVIndex: Bool = true
    var showWindGusts: Bool = true
    var showPrecipitationProbability: Bool = true
    var showDewPoint: Bool = false  // Off by default (advanced)
    var showDaylightDuration: Bool = true
    var showSunshineDuration: Bool = false  // Off by default
}
```

## Accessibility Requirements (NON-NEGOTIABLE)

### VoiceOver Labels Pattern:

**UV Index Badge:**
```swift
.accessibilityElement(children: .ignore)
.accessibilityLabel(getUVIndexDescription(uvIndex))
// Screen reader announces: "UV Index: 8 (Very High) - Use SPF 50+ sunscreen, avoid midday sun"
```

**Wind with Gusts:**
```swift
.accessibilityLabel("Wind: 15 miles per hour east, gusts to 25 miles per hour")
// NOT: "Wind: 15 mph E, gusts 25 mph" - spell out units and directions
```

**Precipitation Probability:**
```swift
.accessibilityLabel("\(precipProb) percent chance of rain")
// NOT: "40% rain" - be explicit
```

### Focus Order:
- UV badges should NOT disrupt existing focus order
- New data should be announced AFTER primary data (temp, conditions)
- Use `.accessibilityElement(children: .combine)` to group related info

### Color Contrast:
- UV badge background colors MUST meet WCAG AA (4.5:1 for text)
- Current implementation provides correct text color (black/white) per background
- Test with Xcode Accessibility Inspector

## Testing Checklist

Before marking implementation complete:

1. **Build Verification:**
   ```bash
   cd iOS
   xcodebuild -project FastWeather.xcodeproj -scheme FastWeather -configuration Debug build
   ```
   - MUST see `** BUILD SUCCEEDED **`
   - Fix ALL compilation errors

2. **VoiceOver Testing:**
   - Enable VoiceOver in iOS Settings
   - Navigate through city list - verify UV badge is announced clearly
   - Navigate through detail view - verify all new fields are announced
   - Verify announcement order makes sense

3. **Visual Testing:**
   - UV badges display with correct colors
   - Wind gusts appear inline with wind speed
   - Precipitation probability icons/text are visible
   - All views work in both light and dark mode

4. **Data Validation:**
   - UV Index: Values 0-11+, displays "Unknown" if null
   - Wind Gusts: Only shows if data available
   - Precip Probability: 0-100%, only shows if > 0
   - Dew Point: Comfort level matches temperature
   - Durations: Format as "Xh Ym"

## Implementation Order

1. **Start with data models** - Update WeatherModels.swift
2. **Create helper utilities** - WeatherHelpers.swift
3. **Update API fetch** - WeatherService.swift
4. **Test API response** - Verify new fields populate
5. **Add UV badges** - List views first, then detail
6. **Add wind gusts** - Simple text enhancement
7. **Add precip probability** - Hourly/daily forecasts
8. **Add advanced features** - Dew point, durations
9. **Update settings** - AppSettings.swift toggles
10. **Accessibility audit** - VoiceOver, focus order, contrast
11. **Build verification** - xcodebuild success required

## Common Pitfalls to Avoid

❌ **DON'T** use `ISO8601DateFormatter` for Open-Meteo timestamps - use `DateParser.parse()`  
❌ **DON'T** show UV badges at night (is_day == 0)  
❌ **DON'T** duplicate formatting logic - use centralized helpers  
❌ **DON'T** break existing accessibility - test with VoiceOver  
❌ **DON'T** use color alone - always include text labels  
❌ **DON'T** assume data is always present - use optional binding  
❌ **DON'T** forget to update AppSettings for user control

## Success Criteria

✅ All Phase 1 and 2 features from web app implemented  
✅ xcodebuild completes with `** BUILD SUCCEEDED **`  
✅ VoiceOver announces all new data clearly and correctly  
✅ UV badges color-coded and accessible  
✅ Wind gusts shown inline with wind speed  
✅ Precipitation probability in hourly/daily forecasts  
✅ Dew point with comfort level in detail view  
✅ Daylight/sunshine duration in daily forecasts  
✅ All features toggle-able in settings  
✅ WCAG 2.2 AA accessibility maintained  
✅ Works in light and dark mode  
✅ Handles missing/null data gracefully

## Reference Implementation

See completed web app implementation:
- [webapp/app.js](../webapp/app.js) - Lines 3700-3900 (helper functions)
- [webapp/app.js](../webapp/app.js) - Lines 2260-2450 (city card rendering)
- [webapp/app.js](../webapp/app.js) - Lines 3320-3550 (full weather details)
- [webapp/styles.css](../webapp/styles.css) - Lines 750-760 (UV badge styles)
- [webapp/index.html](../webapp/index.html) - Lines 255-300 (configuration options)
