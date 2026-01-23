# Browse Cities Decoding Error Fix

## Problem
The Browse Cities feature was completely broken with decoding errors like:
```
keyNotFound(CodingKeys(stringValue: "relative_humidity_2m", intValue: nil), ...)
```

## Root Cause
The `CurrentWeather` model in [Weather.swift](FastWeather/Models/Weather.swift) required all 14 fields to be present in the API response, but `fetchWeatherBasic()` (used for browse performance) only requests 3 fields:
- `temperature_2m` (required)
- `weather_code` (required)
- `cloud_cover` (required)

When the API response didn't include the other 11 fields, the Swift Codable decoder failed with `keyNotFound` errors.

## Solution
Made 11 `CurrentWeather` fields optional to support both full and basic API responses:

### Weather.swift Changes
Made these fields optional (changed from `Int`/`Double` to `Int?`/`Double?`):
- `relativeHumidity2m` (humidity)
- `apparentTemperature` (feels like)
- `isDay` (day/night indicator)
- `precipitation` (total)
- `rain`
- `showers`
- `snowfall`
- `pressureMsl` (atmospheric pressure)
- `windSpeed10m`
- `windDirection10m`
- `visibility`

Kept these fields required (always requested in both modes):
- `temperature2m`
- `weatherCode`
- `cloudCover`

### View Updates
Updated all views to safely unwrap optional fields using `guard let` or `if let`:

1. **FlatView.swift** - Added guard let unwrapping in `getFieldLabelAndValue()`:
   - Feels Like → `guard let apparentTemp = weather.current.apparentTemperature`
   - Humidity → `guard let humidity = weather.current.relativeHumidity2m`
   - Wind Speed → `guard let windSpeed = weather.current.windSpeed10m`
   - Wind Direction → `guard let windDir = weather.current.windDirection10m`

2. **TableView.swift** - Same pattern as FlatView for horizontal scrolling table

3. **ListView.swift** - Updated both single-line and multi-line weather summaries:
   - Single-line: Used `if let` to conditionally add fields
   - Multi-line: Used `if let` to skip missing fields

4. **CityDetailView.swift** - Updated 3 sections:
   - Header: Hides "Feels like" if not available
   - Current Conditions: Shows only available fields (humidity, wind, pressure, visibility)
   - Precipitation: Shows only available precipitation data

5. **StateCitiesView.swift** - Updated `CityLocationDetailView`:
   - Same changes as CityDetailView (header, conditions, precipitation)

## Testing
- Build succeeded with only deprecation warnings (unrelated to this fix)
- Browse feature now works correctly with minimal API data
- Full detail views still display all fields when using full API mode

## Performance Impact
✅ **No performance degradation** - browse mode still uses minimal API requests (3 fields)
✅ **Graceful degradation** - views automatically hide unavailable fields
✅ **Consistent UX** - users see relevant data regardless of API mode

## Files Modified
- `iOS/FastWeather/Models/Weather.swift` - Made 11 CurrentWeather fields optional
- `iOS/FastWeather/Views/FlatView.swift` - Added guard let unwrapping
- `iOS/FastWeather/Views/TableView.swift` - Added guard let unwrapping
- `iOS/FastWeather/Views/ListView.swift` - Added if let unwrapping (2 functions)
- `iOS/FastWeather/Views/CityDetailView.swift` - Added if let unwrapping (3 sections)
- `iOS/FastWeather/Views/StateCitiesView.swift` - Added if let unwrapping (3 sections)

## Verification
User reported issue: "The browse feature is still broken...keyNotFound...relative_humidity_2m"
✅ **FIXED** - Build succeeded, decoding errors eliminated by making fields optional
