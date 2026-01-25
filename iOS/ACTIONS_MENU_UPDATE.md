# City Detail Actions Menu Update

## Summary
Replaced four separate action buttons in CityDetailView with a single consolidated actions menu, added a "Remove City" option, and added a setting for default Weather Around Me distance.

## Changes Made

### 1. CityDetailView.swift
**Changed:** Replaced four individual action buttons with a single `Menu`:
- Before: Four separate buttons (View Historical Weather, Expected Precipitation, Weather Around Me, Refresh)
- After: One "Actions" menu button containing all options plus "Remove City"

**Features:**
- Historical Weather (always available)
- Expected Precipitation (shown only if `radarEnabled` feature flag is on)
- Weather Around Me (shown only if `weatherAroundMeEnabled` feature flag is on)
- Remove City (destructive action, shows confirmation dialog)

**Navigation:**
- Remove City action uses `dismiss()` to return to city list
- Confirmation dialog prevents accidental deletion
- Uses `weatherService.removeCity(city)` to actually remove the city

**Accessibility:**
- Menu button has clear label: "Actions menu"
- Hint explains available options
- All menu items use proper `Label` with SF Symbols
- Remove City uses destructive role for clear indication

### 2. Settings.swift (AppSettings)
**Added:** `weatherAroundMeDistance: Double = 150`
- Default distance in miles for Weather Around Me feature
- Persists across app sessions
- Used as initial value when opening Weather Around Me view

### 3. SettingsView.swift
**Added:** New "Weather Around Me" section before the Units section
- Picker with distance options: 50, 100, 150, 200, 250, 300, 350 miles
- Default: 150 miles
- Auto-saves when changed
- Accessibility label includes current value
- Hint explains what the setting controls

### 4. WeatherAroundMeView.swift
**Changed:** Added `defaultDistance` parameter and custom initializer
- View now accepts a default distance from settings
- `distanceMiles` state is initialized with the default value
- Fallback default of 150 miles if not specified
- Example usage: `WeatherAroundMeView(city: city, defaultDistance: settingsManager.settings.weatherAroundMeDistance)`

## User Experience Improvements

### Space Savings
- Before: 4 large buttons taking up significant vertical space
- After: 1 menu button, same size as before but only one item
- More room for weather data and other content

### Organization
- All actions logically grouped in one place
- Destructive action (Remove City) clearly separated with a divider
- Consistent with iOS design patterns (Menu for multiple options)

### Feature Flags Respected
- Expected Precipitation only appears in menu if developer setting is enabled
- Weather Around Me only appears in menu if developer setting is enabled
- No visual clutter from disabled features

### Remove City Workflow
1. Tap "Actions" menu
2. Tap "Remove City" (shows in red as destructive)
3. Confirmation dialog appears: "Remove [City Name]?"
4. Tap "Remove" to confirm or "Cancel" to abort
5. If removed, user returns to city list automatically

## Technical Details

### Feature Flag Integration
```swift
if featureFlags.radarEnabled {
    Button(action: { showingRadar = true }) {
        Label("Expected Precipitation", systemImage: "cloud.rain")
    }
}
```

### Confirmation Dialog
```swift
.confirmationDialog(
    "Remove \(city.name)?",
    isPresented: $showingRemoveConfirmation,
    titleVisibility: .visible
) {
    Button("Remove", role: .destructive) {
        weatherService.removeCity(city)
        dismiss()
    }
    Button("Cancel", role: .cancel) { }
} message: {
    Text("This city will be removed from your list.")
}
```

### Settings Persistence
- `weatherAroundMeDistance` is part of `AppSettings` struct
- Auto-saved via `settingsManager.saveSettings()` when changed
- Loaded from `UserDefaults` on app launch
- Uses `@Published` to update UI reactively

## Testing Checklist
- [x] Build succeeds on iOS Simulator
- [ ] Menu button appears in city detail view
- [ ] Historical Weather option works (always visible)
- [ ] Expected Precipitation option appears only when dev setting enabled
- [ ] Weather Around Me option appears only when dev setting enabled
- [ ] Weather Around Me uses default distance from settings
- [ ] Remove City shows confirmation dialog
- [ ] Confirming removal navigates back to city list
- [ ] City is actually removed from list
- [ ] Settings page shows Weather Around Me distance picker
- [ ] Changing distance setting persists across app restarts

## Files Modified
1. `/iOS/FastWeather/Views/CityDetailView.swift` - Actions menu, remove city
2. `/iOS/FastWeather/Models/Settings.swift` - weatherAroundMeDistance property
3. `/iOS/FastWeather/Views/SettingsView.swift` - Distance picker UI
4. `/iOS/FastWeather/Views/WeatherAroundMeView.swift` - Default distance parameter

## Build Status
✅ **BUILD SUCCEEDED** - All changes compile successfully
