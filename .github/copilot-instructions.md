# FastWeather AI Agent Instructions

## Project Overview

FastWeather is a **multi-platform weather application** with implementations for:
- **Python/wxPython** (Windows desktop): [fastweather.py](../fastweather.py)
- **SwiftUI macOS**: [FastWeatherMac/](../FastWeatherMac/)
- **SwiftUI iOS**: [iOS/](../iOS/)
- **Web/PWA** (JavaScript): [webapp/](../webapp/)

All platforms share a common architecture: Open-Meteo API for weather, OpenStreetMap Nominatim for geocoding, local storage for city lists, and **accessibility-first design** (WCAG 2.2 AA compliant).

## Critical Architectural Patterns

### Shared Weather/Geocoding Services
All platforms implement the same API integration pattern:
- **Weather**: `https://api.open-meteo.com/v1/forecast` - No API key required
- **Geocoding**: OpenStreetMap Nominatim with User-Agent header (e.g., `FastWeather/1.0`)
- **WMO Weather Codes**: Standard mapping (0=clear, 1=mainly clear, 61=slight rain, etc.)
- **Unit conversions**: KMH_TO_MPH=0.621371, MM_TO_INCHES=0.0393701, HPA_TO_INHG=0.02953

Examples: [fastweather.py#L25-L26](../fastweather.py#L25-L26), [WeatherService.swift](../FastWeatherMac/FastWeatherMac/Services/WeatherService.swift#L14-L15), [app.js#L11-L13](../webapp/app.js#L11-L13)

### City Data Cache System
**Web/iOS** use pre-geocoded city coordinate caches to avoid slow Nominatim API calls:
- `us-cities-cached.json` / `international-cities-cached.json` contain lat/lon for 50 cities per US state + international cities
- Cache built via Python scripts: [build-city-cache.py](../webapp/build-city-cache.py), [build-international-cache.py](../webapp/build-international-cache.py)
- Without cache: ~22 seconds load time (rate limits). With cache: ~5 seconds
- When adding new locations, check if coordinates exist in cache first before geocoding

### Platform-Specific Data Models

**Swift platforms** use nearly identical models:
```swift
struct City: Identifiable, Codable { id: UUID, name, displayName, latitude, longitude, state?, country? }
struct WeatherResponse: Codable { current, hourly?, daily? }
enum WeatherCode: Int { case clear = 0, rainSlight = 61, ... }
```
See: [FastWeatherMac/Models/WeatherModels.swift](../FastWeatherMac/FastWeatherMac/Models/WeatherModels.swift#L11-L29)

**Web** uses plain JavaScript objects with identical structure stored in `localStorage` as JSON.

**Python** uses dictionaries with wx threading pattern: separate threads for API calls, posting events to main UI thread.

## Accessibility Requirements (NON-NEGOTIABLE)

All platforms are **WCAG 2.2 AA compliant**. When modifying or creating UI:

### VoiceOver/Screen Reader Support
- **Descriptive labels**: "Temperature: 72 degrees Fahrenheit" not just "72"
- **Semantic HTML/ARIA**: `role="alert"`, `aria-live="polite"`, `aria-describedby`
- **Status announcements**: Announce weather updates, errors, city additions
- Examples: [index.html#L14-L37](../webapp/index.html#L14-L37), [ACCESSIBILITY.md](../iOS/ACCESSIBILITY.md#L13-L29)

### Keyboard Navigation
- **Tab order**: Logical flow, visible focus indicators (6.1:1 contrast ratio minimum)
- **Keyboard shortcuts**: ⌘N (new city), ⌘R (refresh), Delete (remove city) on Mac/iOS
- **Arrow keys**: Navigate lists (web uses custom `aria-activedescendant` pattern)
- See: [app.js#L483-L517](../webapp/app.js#L483-L517) for web list navigation

### Visual Design
- **Contrast ratios**: Text 4.5:1 minimum (7.2:1 actual), large text 3:1, UI 3:1
- **No color-only info**: Use icons + text for weather conditions
- **Dynamic Type**: SwiftUI `.dynamicTypeSize` support, web respects system font size

## Build & Development Workflows

### Python Desktop
```bash
pip install -r requirements.txt
python fastweather.py              # Run from source
python build.py                     # Build .exe with PyInstaller
```

### macOS
```bash
cd FastWeatherMac
open FastWeatherMac.xcodeproj      # Or use .command scripts
# Build and Launch FastWeather.command - automated build/run script
```

### iOS
```bash
cd iOS
open FastWeather.xcodeproj
# Build in Xcode (⌘B), requires iOS 17.0+
```

### Web/PWA
```bash
cd webapp
python -m http.server 8000          # Or use start-server.bat on Windows
# Open http://localhost:8000
python build-city-cache.py          # Build city coordinate cache (run once)
```

## Key Conventions & Patterns

### Three View Modes (Web/iOS/Mac)
All visual platforms support **Flat** (cards), **Table** (compact), and **List** (minimal) views:
- User preference stored in `localStorage` (web) or `UserDefaults` (Swift)
- Each view mode must maintain accessibility (different markup/labels per mode)
- Example: [ContentView.swift](../FastWeatherMac/FastWeatherMac/Views/ContentView.swift), [app.js#L365-L390](../webapp/app.js#L365-L390)

### City Management
- **Add**: Search geocoder → display results → user selects → add to persistent list
- **Remove**: Swipe-to-delete (iOS), Delete key (Mac), button (web)
- **Reorder**: Drag-and-drop in Table/List views (not Flat)
- **Storage**: `localStorage.getItem('cities')` (web), `UserDefaults.standard` (Swift), JSON file (Python)

### Error Handling
- **Network failures**: Show user-friendly messages, don't crash
- **Geocoding no results**: "No cities found" with retry option
- **Weather API errors**: Display last known data if available, show refresh button
- All errors announced to screen readers via `role="alert"` or announcements

### Testing Accessibility
- **macOS/iOS**: Use Xcode Accessibility Inspector, enable VoiceOver
- **Web**: Test with NVDA/JAWS/VoiceOver, keyboard-only navigation, axe DevTools
- **Check**: Focus indicators visible, proper ARIA attributes, logical tab order
- See: [iOS/ACCESSIBILITY.md#L114-L137](../iOS/ACCESSIBILITY.md#L114-L137)

## Documentation Structure
- Platform-specific READMEs in each directory with setup instructions
- ACCESSIBILITY.md files document compliance features
- PROJECT_SUMMARY.md files contain detailed implementation notes
- BUILD.md / build scripts for automated builds

## Common Gotchas
- **Nominatim rate limits**: 1 request/second. Use cached coordinates when possible.
- **Weather API params**: `forecast_days` defaults vary; specify explicitly for consistency
- **Swift async/await**: All network calls use `async throws`, handle in Task blocks
- **Web ARIA**: Don't mix `<select>` semantics with custom `role="listbox"` - use one pattern
- **Python threading**: wx UI updates must happen on main thread via `wx.PostEvent()`
