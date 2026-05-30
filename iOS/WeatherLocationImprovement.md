# Weather Location Improvement — AI Handoff Brief

**Status:** Design complete, ready to build. No code written yet.  
**Context:** This document was created mid-conversation on Windows to allow the work to continue on Mac. Read the entire thing before writing a line of code.

---

## What We're Building (and Why)

Users report that weather feels imprecise — "I searched for Madison but I don't know where exactly." The real ask is hyper-local weather: Willy Street, the airport, UW campus, a specific ZIP code.

The good news: **the infrastructure already works.** `CLGeocoder` already returns precise coordinates and specific place names for everything the user could type. The app just throws the place name away. This feature is mostly a naming/labeling fix.

---

## The Core Bug (Discovered in This Session)

In `iOS/FastWeather/Views/AddCitySearchView.swift`, `searchCity()` (around line 241):

```swift
// CURRENT — builds display name from locality only, ignores place name
var displayParts: [String] = []
if let locality = placemark.locality { displayParts.append(locality) }
if let administrativeArea = placemark.administrativeArea { displayParts.append(administrativeArea) }
if let country = normalizedCountry { displayParts.append(country) }

let displayName = displayParts.isEmpty ? "Unknown Location" : displayParts.joined(separator: ", ")
let cityName = placemark.locality ?? placemark.name ?? ...
```

CLGeocoder returns `placemark.name` with the specific place name, but the code always prefers `placemark.locality`. So:

| User types | `placemark.name` Apple returns | `placemark.locality` | What gets stored |
|---|---|---|---|
| "Dane County Airport" | "Dane County Regional Airport" | "Madison" | **"Madison"** ← wrong |
| "1025 Williamson St Madison WI" | "1025 Williamson St" | "Madison" | **"Madison"** ← wrong |
| "UW Madison campus" | "University of Wisconsin-Madison" | "Madison" | **"Madison"** ← wrong |
| "Willy Street Madison" | "Williamson St" | "Madison" | **"Madison"** ← wrong |
| "Madison, Wisconsin" | "Madison" | "Madison" | "Madison" ← correct |
| "53703" | "53703" | "Madison" | "Madison" ← handled separately |

Addresses DO geocode to correct coordinates (weather is fetched for the right spot) but the label is wrong. A user adding "Dane County Airport" and "UW Campus" gets two identical entries both labeled "Madison, WI."

---

## The Fix: Naming Logic

The rule is: if `placemark.name` is meaningfully more specific than `placemark.locality`, use it.

```swift
private func searchCity(query: String) async throws -> [GeocodingResult] {
    let geocoder = CLGeocoder()
    let placemarks = try await geocoder.geocodeAddressString(query)
    
    return placemarks.compactMap { placemark -> GeocodingResult? in
        guard let location = placemark.location else { return nil }
        
        let nativeCountry = placemark.country
        let normalizedCountry = CountryNames.normalize(nativeCountry, isoCode: placemark.isoCountryCode)
        
        let locality = placemark.locality
        let adminArea = placemark.administrativeArea
        let placemarkName = placemark.name         // specific place name
        let thoroughfare = placemark.thoroughfare  // street name only
        
        // Determine the primary name to show and store
        let specificName: String?
        
        if let name = placemarkName, let city = locality, name != city {
            // placemark.name is more specific than the city
            if name == thoroughfare {
                // It's just a street name — combine with city for clarity
                specificName = "\(name), \(city)"
            } else if name.range(of: "^\\d", options: .regularExpression) != nil {
                // Starts with a number — it's a full address like "1025 Williamson St"
                // Use street name only (drop the house number), combined with city
                specificName = thoroughfare.map { "\($0), \(city)" } ?? "\(name), \(city)"
            } else {
                // Named place (airport, university, landmark, neighborhood)
                specificName = name
            }
        } else {
            specificName = nil // Normal city search — use locality as before
        }
        
        let primaryName = specificName ?? locality ?? placemarkName ?? "Unknown"
        
        // Build display name for the search results list
        var displayParts: [String] = []
        displayParts.append(primaryName)
        if specificName != nil, let city = locality { displayParts.append(city) }
        if let area = adminArea { displayParts.append(area) }
        if let country = normalizedCountry { displayParts.append(country) }
        
        let displayName = displayParts.joined(separator: ", ")
        
        return GeocodingResult(
            id: UUID(),
            displayName: displayName,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            name: primaryName
        )
    }
}
```

Expected results after this change:

| User types | Search result shows | Stored city name | City list label |
|---|---|---|---|
| "Dane County Airport" | "Dane County Regional Airport, Madison, WI, United States" | "Dane County Regional Airport" | "Dane County Regional Airport, WI" |
| "UW Madison campus" | "University of Wisconsin-Madison, Madison, WI, United States" | "University of Wisconsin-Madison" | "University of Wisconsin-Madison, WI" |
| "1025 Williamson St Madison WI" | "Williamson St, Madison, WI, United States" | "Williamson St, Madison" | "Williamson St, Madison, WI" |
| "Willy Street Madison" | "Williamson St, Madison, WI, United States" | "Williamson St, Madison" | "Williamson St, Madison, WI" |
| "Madison, Wisconsin" | "Madison, WI, United States" (unchanged) | "Madison" | "Madison, WI" (unchanged) |

**Note:** `addCity()` (below `searchCity()`) also needs review — it does its own name cleaning including ZIP code detection. Make sure it doesn't accidentally strip or transform the specific place name. The ZIP regex `^\\d{5}$` is fine (won't match place names). The county suffix removal (`hasSuffix(" County")`) is fine. The US state detection loop may need a check to not apply when the name is already a specific place — test carefully.

---

## The UI Fix (Must Do Before or Alongside)

**This is not optional.** Long place names will clip hard without this change.

### Problem

Both list views use `.lineLimit(1)` on city names. The right side of the row (temperature + optional alert icon) consumes 90–120pt. On a standard iPhone (~393pt wide minus list insets), the city name gets ~200–240pt. 

- "Dane County Regional Airport, WI" needs ~285pt → **clips on every iPhone**
- "University of Wisconsin-Madison, WI" needs ~310pt → **clips on every iPhone**
- "Williamson St, Madison, WI" needs ~200pt → marginal

### File 1: `iOS/FastWeather/Views/ListView.swift` — `ListRowView`, around line 275

```swift
// CHANGE THIS:
Text(city.displayName)
    .font(.body)
    .fontWeight(.medium)
    .lineLimit(1)           // ← change to 2
    .truncationMode(.tail)

// TO THIS:
Text(city.displayName)
    .font(.body)
    .fontWeight(.medium)
    .lineLimit(2)
    .truncationMode(.tail)
```

### File 2: `iOS/FastWeather/Views/FlatView.swift` — `CitySectionHeader`, around line 375

```swift
// CHANGE THIS:
Text(city.displayName)
    .font(.headline)
    .lineLimit(1)           // ← change to 2
    .truncationMode(.tail)

// TO THIS:
Text(city.displayName)
    .font(.headline)
    .lineLimit(2)
    .truncationMode(.tail)
```

Normal city names ("Madison, WI", "San Diego, CA") still fit on one line — no visual change for existing users. Long names wrap to a second line instead of clipping.

### Also check: glance ahead preview

`ListView.swift`, around line 179 (inside `glanceAheadPreview`):
```swift
Text(city.displayName)
    .font(.headline)
    .lineLimit(1)    // context menu preview — consider lineLimit(2) here too
```
Lower priority since it's a context menu, but should be consistent.

---

## The City Model (Discussed, Not Decided)

Current `City` struct (`iOS/FastWeather/Models/City.swift`) has:
```swift
struct City: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String      // e.g. "Dane County Regional Airport"
    let state: String?    // e.g. "WI"
    let country: String
    let latitude: Double
    let longitude: Double
    
    var displayName: String {
        // US: "name, state" → "Dane County Regional Airport, WI"
        // International: "name, country"
    }
}
```

With the naming fix above, `name` holds the specific place name and `displayName` = "Dane County Regional Airport, WI". This works fine and requires **no model changes**.

A future improvement discussed but explicitly deferred: add `subLabel: String?` to render a two-level display (iOS Maps style):
```
Dane County Airport          72°F
Madison, WI
```
Where the primary label is just the place name and the secondary is city/state. This would require adding `subLabel` to `City`, storing it during `addCity()`, and updating `ListRowView` and `CitySectionHeader` to use a two-line VStack layout. **Do not implement this now** — `lineLimit(2)` is sufficient for the first version.

---

## ZIP Code Behavior (Confirmed Working, No Change Needed)

ZIP codes already work correctly for coordinates — CLGeocoder returns the ZIP code area centroid. The `addCity()` function already handles the case where `placemark.name` is just a ZIP code (regex `^\\d{5}$`) and extracts the city name from `displayName` instead. This existing logic is correct and should be preserved.

53703 (downtown Madison) and 53718 (east Madison near airport) return different coordinates and therefore different weather from Open-Meteo. The labels both say "Madison, WI" which is a separate future issue — out of scope for this feature.

---

## Nearby Locations Feature (Future — Do Not Build Now)

A separate larger feature was discussed extensively. Summary for future reference:

**The concept:** From a saved city, show a list of nearby specific locations the user can add. "Browsing around Madison" feels like: Middleton, Fitchburg, Sun Prairie, and eventually named sub-city locations.

**What already exists:**  
`WeatherAroundMeView` + `RegionalWeatherService` + `DirectionalCityService` do most of this already. The "Explore Direction" section lets you step through real cities in any compass direction. Tapping a location opens `AroundMeCityDetailView` → `CityDetailView` and the Add button is confirmed to work (user has used it).

**The gap:** The existing feature is framed as regional weather context (default 150 miles radius, 8 compass directions). The user want is smaller radius (5–15 miles), purpose-built for "find a more local spot to add." Also: within large city limits, reverse geocoding mostly returns the same city name, so sub-city resolution requires either NWS observation stations (US only) or Nominatim neighborhood data.

**NWS stations:** For US cities, `api.weather.gov/points/{lat},{lon}` returns nearby physical weather observation stations. These are real measured data, not model output, and already have proper names (KMSN = Dane County Regional Airport). FastWeather already calls NWS for alerts, so this would be a natural extension for US users.

**Naming quality without NWS:**  
`DirectionalCityService` uses the pre-geocoded city cache (50 cities/state) + CLGeocoder reverse geocoding for gaps. For suburban rings around a city (Middleton at ~7mi, Fitchburg at ~6mi) the names are good. Within city limits everything comes back as the same city name. This is acceptable for the "find a suburb" use case but not for intra-city granularity.

---

## Files Changed / To Change Summary

| File | Status | What |
|---|---|---|
| `iOS/FastWeather/Views/AddCitySearchView.swift` | **TO DO** | `searchCity()` naming logic |
| `iOS/FastWeather/Views/ListView.swift` | **TO DO** | `lineLimit(1)` → `lineLimit(2)` in `ListRowView` |
| `iOS/FastWeather/Views/FlatView.swift` | **TO DO** | `lineLimit(1)` → `lineLimit(2)` in `CitySectionHeader` |
| `iOS/FastWeather/Models/City.swift` | No change needed | Model works as-is |

---

## Testing Checklist (On Mac/Xcode/Simulator)

- [ ] Search "Dane County Airport" → result shows full airport name, not just "Madison"
- [ ] Add it → city list shows "Dane County Regional Airport, WI" on two lines, not clipped
- [ ] Search "1025 Williamson St Madison WI" → result shows "Williamson St, Madison, WI, United States"
- [ ] Add it → city list shows "Williamson St, Madison, WI"
- [ ] Search "UW Madison campus" → result shows university name
- [ ] Search "Madison, Wisconsin" → unchanged, still shows "Madison, WI, United States"
- [ ] Search "53703" → unchanged, still extracts "Madison" from display name
- [ ] Add two different Madison ZIP codes → both show as "Madison, WI" (known limitation, not a regression)
- [ ] VoiceOver: read city list with long name → full name announced, not truncated version
- [ ] FlatView (flat layout): long name wraps to two lines, does not clip
- [ ] ListView (list layout): long name wraps to two lines, does not clip
- [ ] Existing cities with short names: no visual change, still one line

---

## Important Project Context

- **Kelly is visually impaired** and uses VoiceOver on iPhone. Cannot visually verify UI clipping. Any UI changes need to be reasoned about structurally, not just "looks fine in preview."
- **Accessibility pattern:** `.accessibilityElement(children: .ignore)` with explicit `.accessibilityLabel()`. The full `city.displayName` is already in the accessibility label in `ListRowView.buildAccessibilityLabel()` — VoiceOver already reads the full name even when the visual text clips. The visual fix (lineLimit 2) is for sighted users.
- **No bare `print()`** — use `AppLogger.service`, `.network`, `.persistence`, or `.location`.
- **Open-Meteo timestamps** always parse via `DateParser.parse()`, never `ISO8601DateFormatter`.
