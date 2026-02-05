# Daily Forecast Settings Fix

## Issue
Daily forecast was showing all 19 fields by default in VoiceOver, making it overwhelming and appearing to ignore settings customization.

## Root Cause
All 19 daily fields were set to `isEnabled: true` by default in Settings.swift, which was inconsistent with the city list settings where we use intelligent defaults (only 8/22 fields enabled).

## Solution
Applied intelligent defaults to daily forecast fields, enabling only 6 essential fields:

### Enabled by Default (6/19)
1. **temperatureMax** - High temperature
2. **temperatureMin** - Low temperature  
3. **conditions** - Weather description (Clear, Rainy, Cloudy, etc.)
4. **sunrise** - Sunrise time
5. **sunset** - Sunset time
6. **precipitationProbability** - Chance of precipitation (e.g., "30 percent chance")

### Disabled by Default (13/19)
- feelsLikeMax
- feelsLikeMin
- precipitationSum (total amount)
- precipitationHours
- rainSum
- showersSum
- snowfallSum
- windSpeedMax
- windGustsMax
- windDirectionDominant
- uvIndexMax
- daylightDuration
- sunshineDuration

## VoiceOver Impact
**Before:** VoiceOver announced 19 fields per day × 16 days = overwhelming
**After:** VoiceOver announces 6 essential fields per day, matching user expectations

## User Customization
All fields remain available in Settings for users who want more details. This change only affects the **default state** for new installations or settings resets.

## Files Modified
- `iOS/FastWeather/Models/Settings.swift` (lines 376-394, 495-513, 679-697)
  - Updated property defaults
  - Updated init() defaults
  - Updated migration/decode defaults

## Testing
✅ Build succeeded
✅ 6 essential fields enabled by default
✅ 13 optional fields disabled by default
✅ All fields remain customizable in settings

## Consistency
This change brings daily forecast defaults in line with:
- City list weather fields: 8/22 enabled by default
- Design philosophy: Essential information first, details on demand
