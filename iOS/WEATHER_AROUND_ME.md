# Weather Around Me Feature

## Overview
The "Weather Around Me" feature provides an accessible alternative to visual weather maps by showing current weather conditions in all 8 cardinal directions around a selected city.

## Purpose
- **Accessibility-First Design**: Non-visual users cannot effectively use weather radar maps
- **Regional Context**: Understand "big picture" weather patterns without visual interpretation
- **Weather Movement Detection**: Identify temperature gradients and approaching precipitation

## Implementation Details

### Architecture
- **Feature Flag**: `weatherAroundMeEnabled` in `FeatureFlags.swift`
- **Service**: `RegionalWeatherService.swift` - Fetches weather for 9 locations (center + 8 directions)
- **View**: `WeatherAroundMeView.swift` - Displays directional weather comparison
- **Integration**: Button in `CityDetailView.swift` (purple button below Expected Precipitation)

### How It Works
1. **Sampling Distance**: ~50 miles (~0.7 degrees lat/lon) from center city
2. **API Calls**: Uses Open-Meteo free API (9 concurrent calls per city)
3. **Data Points**: Temperature and weather condition for each direction
4. **Analysis**: Generates regional summary identifying patterns:
   - "Warmer to the south" (temperature difference > 5°F)
   - "Colder to the north"
   - "Precipitation to the west"

### User Experience
- **Navigation**: Purple "Weather Around Me" button in city detail view
- **Display**: Grouped cards showing:
  - Your Location (current city)
  - Surrounding Areas (8 directions with icons/temps)
  - Regional Summary (auto-generated weather trends)
- **Refresh**: Pull-to-refresh or toolbar refresh button
- **Accessibility**: Full VoiceOver support with descriptive labels

### Example Output
```
Your Location
Madison, Wisconsin - 72°F, Clear

Surrounding Areas
↑ North - 68°F, Partly cloudy
↗ Northeast - 69°F, Mostly clear
→ East - 70°F, Clear
... (8 total)

Regional Summary
Warmer to the south. Precipitation to the west.
```

## Files Added/Modified

### New Files
- `iOS/FastWeather/Views/WeatherAroundMeView.swift` - Main view
- `iOS/FastWeather/Services/RegionalWeatherService.swift` - API service
- `iOS/add_weather_around_me_files.py` - Xcode project integration script

### Modified Files
- `iOS/FastWeather/Services/FeatureFlags.swift` - Added `weatherAroundMeEnabled` flag
- `iOS/FastWeather/Views/CityDetailView.swift` - Added button and sheet
- `iOS/FastWeather/Views/DeveloperSettingsView.swift` - Added toggle
- `iOS/FastWeather.xcodeproj/project.pbxproj` - Added files to build

## Feature Flag Control
By default, this feature is **disabled**. Enable it in:
**Settings → Developer Settings → Weather Around Me**

## Performance Considerations
- **API Calls**: 9 requests per city (respectful of Open-Meteo free tier)
- **Concurrency**: Uses Swift's async/await for parallel fetching
- **Cache**: Consider adding caching if performance issues arise (10-minute TTL similar to main weather)

## Future Enhancements
- [ ] Add distance radius selector (25, 50, 100 miles)
- [ ] Show wind direction arrows to visualize flow
- [ ] Historical comparison ("Warmer than yesterday")
- [ ] Severe weather detection in surrounding areas
- [ ] Cache results for 10 minutes
- [ ] Add movement animations (e.g., "Precipitation approaching from west at 15 mph")

## Testing Notes
- Tested with build 12 on iPhone 17 simulator
- Verified VoiceOver labels provide context
- Confirmed API calls complete successfully
- Regional summary logic validated with various weather patterns

## Related Documentation
- Open-Meteo API: https://open-meteo.com/en/docs
- iOS Accessibility Guidelines: [iOS/ACCESSIBILITY.md](ACCESSIBILITY.md)
- Feature Flags System: [FeatureFlags.swift](FastWeather/Services/FeatureFlags.swift)
