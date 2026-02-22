# Weather Around Me: Show water body names for ocean/sea coordinates

## Description
When using the Weather Around Me feature for coastal cities at large distances (e.g., Orange Beach, AL at 350 miles), directions that point into bodies of water currently show no location name because there are no cities/states/countries at those coordinates.

## Current Behavior
For Orange Beach, AL at 350 miles radius:
- **North**: Shows city name (e.g., "Birmingham, Alabama")
- **South/Southeast/Southwest**: Show blank (no location name) because these directions point into the Gulf of Mexico

## Expected Behavior
Water body names should be displayed when coordinates are over water:
- **South**: "Gulf of Mexico"
- **Southeast**: "Gulf of Mexico"
- **East**: "Atlantic Ocean" (for east coast cities)
- etc.

## Technical Details
The `reverseGeocode()` function in `RegionalWeatherService.swift` currently only extracts:
- `city` / `town` / `village`
- `state`
- `country`

OpenStreetMap Nominatim API returns additional fields for water coordinates:
- `display_name`: Full human-readable location (e.g., "Gulf of Mexico")
- `type`: Could be "water", "sea", "ocean", "bay"
- `class`: Typically "natural" for water bodies
- `addresstype`: Could indicate water feature

## Proposed Solution
Enhance the `NominatimReverseResponse` model to include:
```swift
struct NominatimReverseResponse: Codable {
    let address: NominatimAddress
    let displayName: String?  // Add this
    let type: String?         // Add this
    let addresstype: String?  // Add this
    
    enum CodingKeys: String, CodingKey {
        case address
        case displayName = "display_name"
        case type
        case addresstype
    }
}
```

Update the location name logic to:
1. Try city/state/country extraction (current behavior)
2. If all are null, check if `type` indicates water ("water", "sea", "ocean", "bay")
3. Use `display_name` or construct from water body type
4. Fallback to "Open water" if nothing else available

## Example Output After Fix
Orange Beach, AL at 350 miles:
- **North**: Birmingham, Alabama - 68°F
- **South**: Gulf of Mexico - 72°F
- **Southeast**: Gulf of Mexico - 73°F

## Benefits
- **Accessibility**: Provides geographic context for blind/low-vision users
- **Educational**: Users learn what water bodies surround coastal cities
- **Completeness**: All 8 directions show meaningful location information
- **Global**: Works for any coastal city worldwide (Mediterranean Sea, Pacific Ocean, etc.)

## Files to Modify
- `iOS/FastWeather/Services/RegionalWeatherService.swift` - Update models and reverse geocoding logic
- `iOS/WEATHER_AROUND_ME.md` - Update documentation

## Priority
Enhancement - improves user experience for coastal cities but not blocking

## Labels
- enhancement
- accessibility
- weather-around-me

## Related
This feature was added in build 13 as part of the "Weather Around Me" accessibility feature.
