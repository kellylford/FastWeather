# My Location Feature — Implementation Plan

## Goal

Add a persistent "My Location" section to the city list (MyCitiesView) that shows live weather for the user's current device location. The section is separate from the saved city list, refreshes on demand, and offers an "Add to My City List" action without cluttering the city list by default.

---

## Settings Changes (First, Since They Drive Everything)

### New Section in SettingsView — "My Location" (first group)

Two controls, appearing before the existing "Units" section:

| Control          | Type               | Default          |
| ---------------- | ------------------ | ---------------- |
| Show My Location | Toggle             | On               |
| Position         | Picker (2 choices) | Before City List |

Position choices: **Before City List** / **After City List**

### New Fields in `AppSettings` (`Models/Settings.swift`)

```swift
var myLocationEnabled: Bool = true
var myLocationPosition: MyLocationPosition = .beforeCityList
```

### New Enum (`Models/Settings.swift`)

```swift
enum MyLocationPosition: String, Codable, CaseIterable {
    case beforeCityList = "Before City List"
    case afterCityList  = "After City List"
}
```

`AppSettings.currentVersion` must be bumped (4) and the schema note updated. No migration needed since new fields have defaults.

---

## New Service: `MyLocationService.swift`

A new `@MainActor ObservableObject` singleton (following the pattern of `LocationService.shared`). It owns the current-location city state so any view can observe it.

**Published properties:**
- `@Published var locationCity: City?` — the resolved City for the current device position; `nil` until first successful fetch
- `@Published var isLoading: Bool` — true while GPS + reverse-geocode is in flight
- `@Published var permissionStatus: CLAuthorizationStatus` — mirrors `LocationService.authorizationStatus`
- `@Published var error: String?` — human-readable error string; cleared on next successful fetch

**Key methods:**
- `refresh() async` — requests location via `LocationService.shared.getCurrentLocation()`, reverse-geocodes (see accuracy note below), updates `locationCity`. Called on app foreground, pull-to-refresh, and on first enable.
- `addToMyCityList()` — appends `locationCity` (if non-nil) to `WeatherService.savedCities`. Guard against duplicates by lat/lon proximity (\~1 km).
- `requestPermissionIfNeeded()` — called on first view appearance when `authorizationStatus == .notDetermined`.

**Persistence:** Store the last-known `locationCity` in `UserDefaults` (same app group) under key `"MyLocationCity"` so the row shows a cached name immediately on relaunch while a fresh fetch is in flight.

**Inject** `MyLocationService.shared` as an `@EnvironmentObject` in `WeatherFastApp.swift`, alongside `WeatherService` and `SettingsManager`.

---

## Location Accuracy & Display Name

### Your Question
You asked whether we can use more detailed location names like we recently improved city search.

### Recommendation

Yes — and it's independent of weather accuracy. Open-Meteo always receives exact GPS coordinates regardless of display name. The display name question is purely about what label the user sees.

**Proposed approach: sub-locality when available, city otherwise.**

In `LocationService.reverseGeocode()`, change the city name resolution from:

```swift
// Current
let cityName = placemark.locality ?? placemark.name ?? "Current Location"
```

to:

```swift
// Proposed — for My Location only (new parameter or separate method)
let subLocality = placemark.subLocality   // e.g. "Mission District", "Midtown"
let locality    = placemark.locality      // e.g. "San Francisco"
let cityName    = subLocality.map { "\($0), \(locality ?? "")" } ?? locality ?? "Current Location"
```

This gives names like *"Midtown, New York"* or *"Fisherman's Wharf, San Francisco"* when sub-locality data is available from the geocoder, and falls back cleanly to city name otherwise.

**GPS accuracy:** Bump `kCLLocationAccuracyKilometer` to `kCLLocationAccuracyHundredMeters` inside `MyLocationService` (not in the base `LocationService`, to avoid affecting Weather Around Me). This gives a meaningful sub-locality from the geocoder without draining battery significantly more.

**Open question for you:** Do you want the sub-locality name shown, or would you prefer plain city name for consistency with the rest of the list? Either works; we can make this a setting later.

KF: I want the more specific name to make this feature more engaging.
---

## UI — My Location Section

### `MyLocationSectionView.swift` (new view)

A self-contained section that renders in all three city-list view modes (Flat, List, Table). It is passed to each sub-view as an optional header or footer section.

**States to handle:**

| State                                      | Display                                                                          |
| ------------------------------------------ | -------------------------------------------------------------------------------- |
| `myLocationEnabled == false`               | Section hidden entirely                                                          |
| `permissionStatus == .notDetermined`       | Row with "Enable Location" button that calls `requestPermissionIfNeeded()`       |
| `permissionStatus == .denied`              | Row with "Open Settings" button linking to `UIApplication.openSettingsURLString` |
| `isLoading == true`, `locationCity == nil` | Row showing a progress indicator with label "Locating…"                          |
| `locationCity != nil`                      | Full weather row (same appearance as a saved city row)                           |

### Section Header

Plain `"My Location"` text header, matching the style of other section headers in each view mode. No additional subtitle.

### Weather Row

Reuse the same row view that saved cities use (`ListRowView`, or the FlatView card). The row is tappable and navigates to `CityDetailView` exactly like a saved city.

The row displays the sub-locality+city name (e.g., "Midtown, New York") with a `location.fill` SF Symbol badge next to the name to differentiate it visually.

---

## Context Menu & VoiceOver — My Location Row

The My Location row has a **reduced** context menu vs saved cities (no Move Up/Down/Remove, since it is not in the list). Add one new action:

### Context Menu

```
[location.fill]  Add to My City List
[arrow.clockwise]  Refresh My Location
```

No "Remove" — the section is toggled via Settings only.

### Accessibility Actions (`.accessibilityAction`)

- `"Add to My City List"` — calls `MyLocationService.addToMyCityList()`, posts announcement "Added [city name] to your city list"
- `"Refresh My Location"` — calls `MyLocationService.refresh()`, posts announcement "Refreshing location"
- `"View Historical Weather"` — same as saved cities (navigates to `HistoricalWeatherView`)
- `"Glance Ahead"` — same as saved cities (reads out forecast summary)

Accessibility label: `"My Location: [city name]. [weather summary]"` (matching the pattern used for saved cities).

---

## Pull-to-Refresh

Extend `MyCitiesView.refreshAllCities()` to also call `MyLocationService.shared.refresh()` when `myLocationEnabled` is true.

---

## Changes to Existing Views

### `MyCitiesView.swift`
- Add `@EnvironmentObject var myLocationService: MyLocationService`
- In `mainContent`, wrap each sub-view call to pass a `myLocationSection` block (the `MyLocationSectionView`)
- Call `myLocationService.requestPermissionIfNeeded()` in `.onAppear`
- Add My Location refresh to `refreshAllCities()`
- Update `EmptyStateView` condition: show empty state only when `savedCities.isEmpty && !myLocationEnabled` (or when enabled but permission denied)

### `ListView.swift`
- Accept an optional `myLocationSection: AnyView?` parameter
- Render it above or below the `ForEach` based on `settingsManager.settings.myLocationPosition`
- Keep all existing city-row logic unchanged

### `FlatView.swift`
- Same parameter + position logic as ListView
- Flat mode renders cards; My Location card uses the same card style

### `TableView.swift`
- Same parameter + position logic
- If TableView is complex to integrate, we can defer it (My Location would simply not appear in table mode until a follow-up)
KF: This is fine. Honestly defer this because it doesn’t make a lot of sense in table view.


### `SettingsView.swift`
- Add a new `Section(header: Text("My Location"))` as the **first** section of the form, above "Units"
- Contains the `Toggle` and `Picker` for the two new settings

### `WeatherFastApp.swift`
- Inject `MyLocationService.shared` as an `.environmentObject`

---

## Files Created / Modified

| Action | File                                                                                           |
| ------ | ---------------------------------------------------------------------------------------------- |
| Create | `iOS/FastWeather/Services/MyLocationService.swift`                                             |
| Create | `iOS/FastWeather/Views/MyLocationSectionView.swift`                                            |
| Modify | `iOS/FastWeather/Models/Settings.swift` (new enum + fields, bump version)                      |
| Modify | `iOS/FastWeather/Services/LocationService.swift` (new reverse-geocode method for sub-locality) |
| Modify | `iOS/FastWeather/Views/SettingsView.swift` (new first settings section)                        |
| Modify | `iOS/FastWeather/Views/MyCitiesView.swift` (inject service, pass section, refresh)             |
| Modify | `iOS/FastWeather/Views/ListView.swift` (accept + render My Location section)                   |
| Modify | `iOS/FastWeather/Views/FlatView.swift` (accept + render My Location section)                   |
| Modify | `iOS/FastWeather/Views/TableView.swift` (accept + render My Location section — or defer)       |
| Modify | `iOS/FastWeather/WeatherFastApp.swift` (add EnvironmentObject)                                 |

---

## Open Questions Before Implementation

1. **Display name granularity:** Sub-locality+city (e.g. "Midtown, New York") or just city (e.g. "New York")? Or do you want both but let the user choose in Settings?
  
KF: More specific to make the feature feel engaging.  

2. **Auto-refresh on foreground:** Should the location silently refresh every time the app returns to foreground, or only on explicit pull-to-refresh? (Battery/UX trade-off.)
  
KF: I think we already have logic to refresh after a certain amount of time if the app comes back into the foreground. We should follow that logic so we are not hammering the battery.  

3. **TableView mode:** Include My Location section in TableView from the start, or defer it?
  
KF: Defer. It honestly doesn’t make a lot of sense in table mode.  
  

4. **Feature flag:** Gate behind a `FeatureFlags` toggle during development (so it can be turned off if something breaks), or ship directly?
  
Put behind our developer settings feature but on by default.  
  

5. **"Add to My City List" deduplication:** If the user's current city is already in their saved list, should the action be disabled/hidden, or should it silently skip adding?
  
KF: If it is truly a duplicate for now silently fail. If it offers more specificity than something already there, add.