# FastWeather iOS — Comprehensive Review
**Date:** April 15, 2026  
**Conducted by:** GitHub Copilot (Claude Sonnet 4.6)  
**Scope:** Full audit of the iOS app's Open-Meteo API integration and accessibility implementation  
**Files reviewed:** All Swift source files under `iOS/FastWeather/`

---

## How This Review Was Produced

This document consolidates the independent findings of three reviewers:

1. **Open-Meteo Expert** — Reviewed all API integration, URL construction, date parsing, response decoding, WMO codes, missing variables, caching, error handling, and performance. Primary references: https://open-meteo.com/en/docs and https://open-meteo.com/en/docs/historical-weather-api.
2. **Apple Accessibility Expert** — Reviewed all SwiftUI views for VoiceOver correctness, focus management, Dynamic Type, keyboard/switch control, live regions, and WCAG 2.2 AA compliance. Primary reference: https://developer.apple.com/documentation/accessibility.
3. **Coordinating Engineer** — Reviewed cross-cutting concerns, architectural patterns, and cross-team findings for consistency. Produced this consolidated document.

Each section retains attribution so findings can be traced back to the responsible domain expert.

---

## Executive Summary

The FastWeather iOS app is architecturally sound with strong accessibility foundations and a correct Open-Meteo integration structure. However, the audit uncovered **five confirmed API parameter name bugs** that silently produce nil data today, a **timezone parsing bug** that corrupts timestamps for international cities, **widespread VoiceOver double-reading** on every weather data field due to a single modifier pattern, and a set of inaccessible UI regions where VoiceOver users cannot reach content.

The most critical fixes are:

| Priority | Issue | Impact |
|----------|-------|--------|
| P0 | Deprecated API parameter names (`windgusts_10m`, `dewpoint_2m`, `cloudcover`, `windspeed_10m_max`, `winddirection_10m_dominant`, `weathercode`) | Silent nil data across wind, dew point, cloud cover fields |
| P0 | `.accessibilityElement(children: .combine)` + custom `.accessibilityLabel` on `DetailRow` and widespread views | Every weather data field on every screen reads twice |
| P1 | `WeatherResponse` missing `utc_offset_seconds` — timezone parsing wrong for international cities | Hour offsets wrong; "next hour" logic broken for foreign cities |
| P1 | Horizontal ScrollView hourly forecast cards inaccessible to VoiceOver | 24 hours of forecast data unreachable |
| P1 | Free tier capped at 7-day forecast; API supports 16 days free | Unnecessary data loss for all non-paying users |
| P2 | Alert buttons swallowed by `.ignore` container in FlatView/ListView | No way to activate alerts via VoiceOver |
| P2 | Synthetic `apparentTemperature` for future days set to mean temp (incorrect) | "Feels Like" shows mean temperature, not feels-like |

---

# Part 1 — Open-Meteo API Integration Review

*Reviewer: Open-Meteo Expert*  
*Files: WeatherService.swift, SettingsManager.swift, WeatherHelpers.swift, RegionalWeatherService.swift, HistoricalWeatherCache.swift, Weather.swift, HistoricalWeather.swift, WeatherAlert.swift, all View files*

---

## 1.1 CRITICAL — Deprecated API Parameter Names ✅ **FIXED**

**Files:** `Services/WeatherService.swift`, `Models/Weather.swift`, `Models/HistoricalWeather.swift`  
**Fixed in:** Commit 1d63d2b (April 17, 2026)  
**Tests:** `FastWeatherTests/OpenMeteoAPIParameterTests.swift` (9 tests, all passing)

~~The Open-Meteo API transitioned from concatenated names to underscore-separated names. The app uses the old aliases in multiple locations. While backward-compatible aliases exist today, Open-Meteo has stated intent to remove them. When they are removed, the affected fields silently return `nil` (Swift's `decodeIfPresent` returns nil for missing keys, no error thrown).~~

**RESOLUTION:** All API parameter names and CodingKeys updated to use correct underscore-separated format:
- ✅ `windgusts_10m` → `wind_gusts_10m`
- ✅ `dewpoint_2m` → `dew_point_2m`
- ✅ `cloudcover` → `cloud_cover`
- ✅ `windspeed_10m_max` → `wind_speed_10m_max`
- ✅ `winddirection_10m_dominant` → `wind_direction_10m_dominant`
- ✅ `weathercode` → `weather_code` (historical)

All struct properties renamed to match CodingKeys, all references updated throughout codebase, comprehensive test suite added with live API integration test. Verified working with paid API tier.

---

## 1.2 CRITICAL — Free Tier Unnecessarily Capped at 7-Day Forecast ✅ **FIXED**

**File:** `Services/WeatherService.swift` (line ~331)  
**Fixed in:** Commit 68b7677 (April 17, 2026)  
**Tests:** `FastWeatherTests/OpenMeteoAPIParameterTests.swift::testForecastDaysUsesCorrectValues`

~~According to the current Open-Meteo documentation, **up to 16 forecast days are available on the free tier**. There is no paid-only restriction on `forecast_days`. The code mistakenly limits free users to 7 days. Notably, `fetchWeatherFull` (used by the city browse view) already correctly hardcodes `"16"` without a key check — this inconsistency shows the intent is 16 days.~~

**RESOLUTION:** Removed incorrect API key check from `forecast_days` parameter:
- ❌ **Before:** `value: includeHourly ? (Secrets.openMeteoAPIKey != nil ? "16" : "7") : "3"`
- ✅ **After:** `value: includeHourly ? "16" : "3"`

Free tier users now correctly receive up to 16 days of forecast data. Test validates API returns >7 days (up to 16) without requiring paid API key.

---

## 1.3 HIGH — Timezone Parsing Bug for International Cities ✅ **FIXED**

**Files:** `Models/Weather.swift`, `Services/WeatherService.swift`, `Services/SettingsManager.swift`, `Views/ListView.swift`, `Views/CityDetailView.swift`  
**Fixed in:** April 24, 2026

~~All API calls use `timezone=auto`. When fetching Tokyo weather, Open-Meteo returns timestamps in JST (e.g., `"2026-04-15T15:00"` = 3 PM local). `DateParser.parse()` creates a `DateFormatter` with no timezone set, so it uses the device's local timezone. A user in New York (UTC-4) would parse `"2026-04-15T15:00"` as 3 PM EDT — a 13-hour error.~~

**Pre-fix analysis clarified the actual impact:**
- **Display of times** (sunrise/sunset, hourly labels via `FormatHelper.formatTime`) — actually correct due to cancelling errors: the timestamp is parsed in device timezone and formatted back in device timezone, so the raw string's hour is always displayed correctly. No change needed here.
- **`glanceAheadSummary`** and **`findCurrentHourIndex`** — genuinely broken: comparing device-timezone current hour against city-local timestamp hours puts the hourly window at the wrong position for international cities.

**RESOLUTION:**

1. **`WeatherResponse`** (`Models/Weather.swift`): Added `utcOffsetSeconds: Int?` with `CodingKey "utc_offset_seconds"`. Only `utcOffsetSeconds` is decoded — it's sufficient for constructing a `TimeZone`. `timezone` (IANA string) was not added; `TimeZone(secondsFromGMT:)` is more reliable than `TimeZone(identifier:)` for IANA names.

2. **`WeatherData`** (`Models/Weather.swift`): Added `utcOffsetSeconds: Int?` stored field and a computed `timeZone: TimeZone` property (`TimeZone(secondsFromGMT: utcOffsetSeconds ?? 0)`). Defaults to UTC when offset is unavailable (historical path, which has no hourly data anyway).

3. **`WeatherService`** (`Services/WeatherService.swift`): All 7 `WeatherData(current:daily:hourly:)` call sites updated to pass `utcOffsetSeconds`. Primary fetch paths pass `response.utcOffsetSeconds`; the historical archive path passes `nil`; the My Data merge and WeatherKit snow overlay paths propagate `weatherData.utcOffsetSeconds`.

4. **`DateParser`** (`Services/SettingsManager.swift`): Added `static func parse(_ isoString: String, in timeZone: TimeZone) -> Date?` overload. Creates a one-off formatter with the given timezone so the returned `Date` represents the correct absolute UTC moment for the city's local time string.

5. **`glanceAheadSummary`** (`Views/ListView.swift`): Replaced hour-component comparison (`calendar.component(.hour, from:) >= currentHour`) with absolute date comparison (`date >= now`), using `DateParser.parse(_:in: weather.timeZone)`. Works correctly for any city regardless of timezone offset.

6. **`findCurrentHourIndex`** (`Views/CityDetailView.swift`): Both instances (in `CityDetailView` and `MarineForecastSection`) updated with the same absolute date comparison. `CityDetailView` uses `weather?.timeZone`; `MarineForecastSection` looks up the timezone from `weatherService.weatherCache`.

`** BUILD SUCCEEDED **`

---

## 1.4 HIGH — `DateParser.parse()` Missing POSIX Locale ✅ **FIXED**

**File:** `Services/SettingsManager.swift`  
**Fixed in:** April 24, 2026 (combined with 1.5)

~~On devices with a non-Gregorian calendar locale (Arabic, Hebrew, Thai Buddhist, Ethiopian Ge'ez), `DateFormatter` may use the locale's calendar system when parsing numeric year/month/day fields, causing silent parse failures. Setting `Locale(identifier: "en_US_POSIX")` is the Apple-documented standard safeguard when parsing fixed-format date strings.~~

**RESOLUTION:** Fixed as part of 1.5 — see below.

---

## 1.5 HIGH — `DateParser.parse()` Allocates New Formatters Per Call ✅ **FIXED**

**File:** `Services/SettingsManager.swift`  
**Fixed in:** April 24, 2026

~~`DateParser.parse()` creates two `DateFormatter` instances on every invocation. A full 16-day hourly fetch returns 384 time strings. That's 768 `DateFormatter` allocations — an expensive operation — per single fetch.~~

**RESOLUTION:** 1.4 and 1.5 fixed together. All four formatters (`DateFormatter` primary + three `ISO8601DateFormatter` fallbacks) are now static lazy-initialized constants. The primary formatter also received `locale = Locale(identifier: "en_US_POSIX")`. Thread-safety is not a concern here — `WeatherService` is `@MainActor` and all `FormatHelper` calls in views run on the main thread, so there is no concurrent access to the shared instances. `** BUILD SUCCEEDED **`

---

## 1.6 HIGH — Synthetic `apparentTemperature` for Future Days is Wrong ✅ **FIXED**

**Files:** `Services/WeatherService.swift`, `Models/Weather.swift`  
**Fixed in:** April 24, 2026

~~When `dateOffset > 0`, a synthetic `CurrentWeather` is built from daily data:~~

~~```swift~~
~~let avgTemp = ((daily.temperature2mMax[dateOffset] ?? 0) + (daily.temperature2mMin[dateOffset] ?? 0)) / 2~~
~~let current = WeatherData.CurrentWeather(~~
~~    ...~~
~~    apparentTemperature: avgTemp,   // ← WRONG: this is mean temp, not feels-like~~
~~    ...~~
~~)~~
~~```~~

~~This sets "Feels Like" to the mean of max/min temperature. For a cold windy day, real feels-like might be 45°F while the mean is 55°F. The UI would display "Feels Like: 55°F" — meaningfully incorrect.~~

~~**Immediate fix:** Set `apparentTemperature: nil` and guard against nil in the display.~~  
~~**Complete fix:** Add `apparent_temperature_max` and `apparent_temperature_min` to the daily request and compute a proper average.~~

**RESOLUTION:** Complete fix implemented. The immediate/nil approach was rejected — hiding "Feels Like" entirely is worse UX than showing a slightly wrong number.

- ✅ Added `apparentTemperatureMax`/`apparentTemperatureMin` as optional fields to `WeatherData.DailyWeather` in `Weather.swift` with correct `CodingKeys` (`"apparent_temperature_max"`, `"apparent_temperature_min"`)
- ✅ Added `apparent_temperature_max,apparent_temperature_min` to the full daily parameter string in `fetchWeatherForDate`
- ✅ Replaced `apparentTemperature: avgTemp` with a proper average of the new fields, returning `nil` (not a wrong value) only if the API omits both fields
- ✅ Forwarded the new fields through `singleDayDaily` and the WeatherKit snow overlay `DailyWeather` reconstruction
- ✅ `BUILD SUCCEEDED`

---

## 1.7 HIGH — Forecast API Fetches Don't Decode Open-Meteo Error Responses ✅ **FIXED**

**Files:** `Services/WeatherService.swift` — `fetchWeatherForDate`, `fetchWeatherBasic`, `fetchWeatherFull`, `fetchMarineData`, `fetchMyDataMarineValues`, `fetchMyDataAirQualityValues`  
**Fixed in:** April 24, 2026

~~When the API returns a 400 error (e.g., invalid parameter name such as `windgusts_10m`), the body is:~~

~~```json~~
~~{"error": true, "reason": "Cannot initialize WeatherVariable from invalid String value windgusts_10m for key hourly"}~~
~~```~~

~~Attempting to decode this as `WeatherResponse` throws a generic `DecodingError`. The user sees "The data couldn't be read because it isn't in the correct format" instead of the actual API error reason. This makes diagnosing the deprecated parameter name issues (§1.1) much harder.~~

~~`fetchHistoricalWeather` already handles this correctly and its pattern should be applied to all forecast API calls.~~

**RESOLUTION:** Added a private `apiData(for:timeout:)` helper to `WeatherService` that wraps `apiRequest(for:)`, checks the HTTP status, decodes the Open-Meteo error body on non-200 responses, and throws a descriptive `NSError` before any attempt to decode `WeatherResponse`. All six call sites that previously used `let (data, _) = try await URLSession.shared.data(for: apiRequest(for: url))` now use `let data = try await apiData(for: url)`:

- ✅ `fetchWeatherForDate`
- ✅ `fetchWeatherBasic`
- ✅ `fetchWeatherFull`
- ✅ `fetchMarineData`
- ✅ `fetchMyDataMarineValues`
- ✅ `fetchMyDataAirQualityValues`

The existing `fetchHistoricalWeather` was left unchanged (it builds its own `URLRequest` directly, bypasses `apiRequest`, and already had the check). `** BUILD SUCCEEDED **`

---

## 1.8 MEDIUM — `past_days` Not Used; Archive API Called for Recent Past Dates ✅ **FIXED**

**Files:** `Services/WeatherService.swift`  
**Fixed in:** April 24, 2026

~~For `dateOffset = -1` (yesterday), the app uses the archive API, which has a ~5-day data lag. The forecast API supports `past_days=1` through `past_days=92` with **no data lag** and returns full hourly data. The archive API path only returns daily data, so past-day detail views have no hourly charts.~~

**RESOLUTION:**

- ✅ The `dateOffset < 0` branch now checks the range: for `dateOffset >= -92`, it calls the new `fetchPastWeatherForCity`; for `dateOffset < -92`, it continues to call `fetchHistoricalWeatherForCity` (archive API)
- ✅ Added `fetchPastWeatherForCity(city:dateOffset:cacheKey:)` — always requests full hourly (`temperature_2m,weather_code,precipitation,precipitation_probability,relative_humidity_2m,wind_speed_10m,wind_gusts_10m,uv_index,dew_point_2m,snowfall,cloud_cover`) and full daily params with `past_days=abs(dateOffset)` and `forecast_days=1`
- ✅ With `past_days=N, forecast_days=1`, the response arrays start from the target past day (index 0). The target daily row and the first 24 hourly entries are extracted using `targetIndex = 0` — the same day-extraction logic as the `dateOffset > 0` path
- ✅ Synthetic `current` built from daily max/min (same pattern as the future-date path); `utcOffsetSeconds` passed through so `timeZone` works correctly
- ✅ On failure, falls back to `fetchHistoricalWeatherForCity` (archive API) so the user still sees daily data if the forecast API is unavailable
- ✅ `** BUILD SUCCEEDED **`

---

## 1.9 MEDIUM — `RegionalWeatherService` Bypasses Centralized URL Builder ✅ **PARTIALLY FIXED**

**Files:** `Services/RegionalWeatherService.swift`  
**Fixed in:** April 24, 2026

~~`RegionalWeatherService` manually builds URLs, duplicates the User-Agent header, and issues 9 concurrent requests simultaneously — bypassing `WeatherService.apiRequest(for:)` and the `maxConcurrentRequests` limit. On the free tier, 9 simultaneous requests will trigger HTTP 429 (rate limit) responses. Additionally, the service hardcodes `"temperature_unit": "celsius"` regardless of user preference.~~

**Pre-fix analysis clarified which claims were accurate:**

- **Concurrent 429 risk** — overstated. Open-Meteo free tier enforces a daily request quota (10,000 req/day), not a concurrent connection limit. 9 simultaneous forecast requests are unlikely to cause 429 in practice.
- **User-Agent duplication** — `RegionalWeatherService` already used `"FastWeather/1.5 (weatherfast.online)"`, which matches `WeatherService` exactly. No change needed.
- **Cross-service routing** — introducing a dependency on `WeatherService.apiRequest(for:)` from `RegionalWeatherService` would create a circular or tight coupling between two services that currently have no relationship. Deferred.
- **Hardcoded `"temperature_unit": "celsius"`** — this is the one real issue. `BasicWeatherResponse` only decodes `temperature_2m`, used for a relative regional comparison — not user-facing unit display. But the parameter is unnecessary: the API default is already Celsius and client-side conversion is not applied here anyway.

**RESOLUTION:** Removed `"temperature_unit": "celsius"` from the `params` dict in `fetchWeatherForLocation`. The API returns Celsius by default; the temperature value is used only internally for regional comparison and is not converted or displayed with units. `** BUILD SUCCEEDED **`

---

## 1.10 MEDIUM — `fetchWeatherBasic` Requests Unused Hourly Data ✅ **FIXED**

**File:** `Services/WeatherService.swift`  
**Fixed in:** April 24, 2026

~~The basic/browse fetch is used in city-list views that display no hourly charts. Requesting hourly data here wastes bandwidth and compounds the deprecated name issue. Removing `hourly` from the basic fetch reduces payload size.~~

**RESOLUTION:** Removed `"hourly": "cloud_cover"` from `fetchWeatherBasic`. Browse and Weather Around Me views display only current conditions; no caller ever reads `weather.hourly` from a basic-fetch result. The deprecated-name note in the original report was already stale (item 1.1 had corrected `cloudcover` → `cloud_cover`). `** BUILD SUCCEEDED **`

---

## 1.11 MEDIUM — `fetchWeatherFull` Bypasses Cache ✅ **FIXED**

**File:** `Services/WeatherService.swift`  
**Fixed in:** April 24, 2026

~~`fetchWeatherFull` never reads or writes `weatherCache`. Any caller always makes a live network request even if the same city was recently cached by `fetchWeatherForDate`. Consider routing through the cache layer.~~

**RESOLUTION:** Added a dedicated `browseWeatherFullCache: [String: WeatherData]` and `browseFullCacheTimestamps: [String: Date]` to `WeatherService`. `fetchWeatherFull` now checks the cache first (same `isCacheValid` TTL check as `fetchWeatherBasic`) and writes through on a miss. A companion `trimBrowseFullCacheIfNeeded()` evicts the oldest entries when the dict exceeds `maxBrowseCacheEntries` (100). A separate cache is used rather than sharing `browseWeatherCache` because the two fetches return different payload shapes (1-day current-only vs. 16-day full hourly+daily) and merging them would create stale-data risks when a basic entry is served where full data is expected. `** BUILD SUCCEEDED **`

---

## 1.12 MEDIUM — Marine Fetch Missing `current` Section for Standard Users

**File:** `Services/WeatherService.swift` (line ~766)

The primary `fetchMarineData` only requests `hourly` marine data. `MarineData.current` is only populated via the My Data path. Standard users who haven't configured My Data have no marine current conditions.

**Fix:** Add `"current": "wave_height,wave_direction,wave_period,sea_surface_temperature"` to the main marine fetch.

---

## 1.13 MEDIUM — `appendMyDataParameters` Decodes `AppSettings` on Every Fetch

**File:** `Services/WeatherService.swift` (line ~104)

This static method reads `UserDefaults` and decodes the entire `AppSettings` JSON on every invocation of `fetchWeatherForDate`. With 10 saved cities, that's 10 full JSON decodes per refresh cycle. The already-decoded settings object should be passed in instead.

---

## 1.14 LOW — Missing High-Value Variables

The following API variables are available at no extra cost but are not currently requested:

| Variable | Type | Benefit |
|----------|------|---------|
| `apparent_temperature` | Hourly | Hourly feels-like chart in DayDetailView |
| `wind_direction_10m` | Hourly | Per-hour wind direction |
| `wind_gusts_10m_max` | Daily | Daily peak gusts in multi-day forecast |
| `apparent_temperature_max/min` | Daily | Daily feels-like range (also fixes §1.6) |
| `snow_depth` | Hourly | Current snow on ground vs. new snowfall |
| `precipitation_probability_max` | Light fetch daily | Immediate display in list views |
| `cloud_cover` | Full hourly fetch | Currently only in basic fetch; hourly cloud cover chart broken |
| `visibility` | Hourly | Visibility trend in fog/storm conditions |
| `freezing_level_height` | Hourly | Snow/elevation forecasting |

Note: `cloud_cover` is a fix (the full hourly fetch currently omits it, so `DayDetailView.hourlySlice?.cloudcover` is always nil for city detail views), not just an enhancement.

---

## 1.15 LOW — `WeatherCache.swift` is Dead Code

**File:** `Services/WeatherCache.swift`

This `UserDefaults`-backed persistent cache class is entirely unused. A comment in `WeatherService` explains it was disabled due to 8.9-second load times. The dead code adds maintenance confusion. Either delete it or replace the storage backend (file-based JSON is orders of magnitude faster than UserDefaults for large blobs) and re-enable it.

---

## 1.16 LOW — Historical Cache "Current Year" Stale Data Risk

**File:** `Services/HistoricalWeatherCache.swift`

Historical data is cached indefinitely by month-day key. If a same-day history entry was cached before the archive's 5-day lag resolved, it may contain incomplete "current year" data. The existing check `if cached.count >= yearsBack { return cached }` helps, but consider a timestamp-based re-fetch policy for the current year.

---

## 1.17 INFORMATIONAL — WMO Weather Codes: Complete and Correct

`Models/Weather.swift` `WeatherCode` enum covers all 30 standard WMO interpretation codes (0–99) with correct descriptions and SF Symbol names. No issues.

---

## 1.18 INFORMATIONAL — Items Working Correctly

- Paid/free tier URL switching for all API endpoints
- Historical archive URL (`archive-api.open-meteo.com`) vs forecast URL separation
- Marine API `cell_selection=sea` parameter
- Unit conversion constants (0.621371 MPH, 0.0393701 in, 0.02953 inHg)
- Snowfall unit conversion: cm → inches (`× 0.393701`) correct
- `pressure_msl` (sea level) over `surface_pressure` — meteorologically correct choice
- Cache durations (10 min current, 1 hr forecast, 5 min alerts) appropriately tuned to API update frequency
- `HistoricalWeatherCache` perpetual cache policy correct (historical data doesn't change)
- `FormatHelper.formatTime()` and `formatTimeCompact()` routing through `DateParser` — correct
- `DailyForecastSummaryView` natural-language summary is a strength

---

## 1.19 — Expected Precipitation: WeatherKit Integration ✅ **FIXED**

**Files:** `Services/RadarService.swift`, `Views/RadarView.swift`  
**Fixed in:** April 24, 2026  
**Context:** Observed failure: app showed "clear, nearest precip 105 miles away" during an active thunderstorm (Madison, WI, ~1 AM). Root cause: Open-Meteo `minutely_15` is NWP model output — cannot detect storms that formed after the last model initialization run.

### What changed

`RadarService` now uses WeatherKit's `.minute` forecast (radar-blended, 1-minute resolution, 60-minute window) as the primary data source for "Expected Precipitation" in supported countries, with Open-Meteo NWP as the fallback.

**Supported WeatherKit countries:** United States, Canada, United Kingdom, Ireland, Australia, New Zealand.

For these cities:
- `fetchPrecipitationNowcast(for:)` calls `WeatherKit.WeatherService.shared.weather(for:including:.current,.minute)`
- `currentWeather.precipitationIntensity` (radar-derived) is used for the "at your location" status — directly fixes the "clear during storm" problem
- `Forecast<MinuteWeather>` (60 entries × 1 minute) replaces `minutely_15` (4 entries × 15 minutes) for the timeline and chart
- If WeatherKit returns `nil` for `.minute` (location outside WK coverage) or throws, the fallback to Open-Meteo NWP runs automatically

For all other countries: Open-Meteo NWP path unchanged.

**`RadarView` changes:**
- Timeline label: "1-Hour Forecast" (WeatherKit) vs "2-Hour Forecast" (Open-Meteo)
- Timeline intervals: Now, 5, 10, 15, 20, 30, 45, 60 min (WeatherKit) vs 15-min intervals (Open-Meteo)
- Precipitation chart: New smooth area + line chart using actual `precipitationMmPerHr` values from `ChartPoint`. WeatherKit shows 60 1-minute bars; Open-Meteo maps its 7 coarse intervals. Y-axis hidden to avoid false precision; x-axis shows 0/15/30/45/60 markers.
- Audio graph: VoiceOver `.accessibilityRepresentation` now uses sparse points (0, 5, 10, 15, 20, 30, 45, 60 min) for manageable exploration
- Attribution: Apple Weather mark (light/dark variant) with link to legal attribution page when WeatherKit is active; "Precipitation nowcast data by Open-Meteo.com" otherwise. Required by WeatherKit terms.

**New data model additions (RadarService.swift):**
- `ChartPoint` — per-minute chart entry with `minute: Int`, `precipitationMmPerHr: Double`, `condition: String`
- `RadarData.chartData: [ChartPoint]?` — nil for Open-Meteo, 60-entry array for WeatherKit
- `RadarData.dataSource: RadarDataSource` — `.weatherKit` or `.openMeteo`
- `TimelinePoint.precipitationMmPerHr: Double` — now stored on timeline points for chart fallback

**Data models moved:** `RadarData`, `NearestPrecipitation`, `DirectionalSector`, `TimelinePoint` were defined in `RadarView.swift`; moved to `RadarService.swift` where they originate.

`** BUILD SUCCEEDED **`

### Previous code bugs fixed (also this session)

1. **Paid-tier API endpoint ignored.** `RadarService` hardcoded the free-tier URL, bypassing `Secrets.openMeteoAPIKey`. Fixed.
2. **Fixed 15 mph storm speed assumption.** Added `wind_speed_10m` to hourly request; `findNearestPrecipitation` now uses actual wind speed (km/h → mph, 5 mph floor).
3. **Inline `DateFormatter` without POSIX locale.** Replaced both inline formatters with `DateParser.parse()`.

---

# Part 2 — Accessibility Review

*Reviewer: Apple Accessibility Expert*  
*Files: All Views, Services/SettingsManager.swift, iOS/ACCESSIBILITY.md*

---

## 2.1 CRITICAL — `.accessibilityElement(children: .combine)` + Custom Label: Widespread Double-Reading

**Severity:** Every weather data screen reads every field twice  
**Files:** `CityDetailView.swift` (`DetailRow`), `FlatView.swift`, `StateCitiesView.swift`, `MyCitiesView.swift`, `RadarView.swift`, `WeatherAroundMeView.swift`, `SettingsView.swift`

The pattern used throughout the app is:

```swift
.accessibilityElement(children: .combine)
.accessibilityLabel("Humidity: 65%")
```

`.combine` merges children into one element using their synthesized text. Adding a custom `.accessibilityLabel` on top appends a second label. VoiceOver speaks both — producing readings like "Humidity 65% Humidity: 65%".

`DetailRow` is the highest-priority fix: it's used on every weather data field in `CityDetailView`, `DayDetailView`, `DailyHeadingBlock`, and `HourlyHeadingRow`.

**Fix everywhere:**

```swift
// WRONG
.accessibilityElement(children: .combine)
.accessibilityLabel("Humidity: 65%")

// CORRECT
.accessibilityElement(children: .ignore)
.accessibilityLabel("Humidity: 65%")
```

Only use `.combine` when you want VoiceOver to collect children's individual labels without overriding them — and never pair it with a custom `.accessibilityLabel` on the same element.

---

## 2.2 CRITICAL — Alert Buttons Swallowed by `.ignore` Container

**Severity:** VoiceOver users cannot activate weather alert badges  
**Files:** `FlatView.swift` (`CitySectionHeader`), `ListView.swift` (`ListRowView`)

Both views wrap an HStack containing an interactive alert `Button` under `.accessibilityElement(children: .ignore)`. The `.ignore` collapses all children into one element. The alert button becomes unreachable even though `buildAccessibilityLabel()` includes alert text in the description.

**Fix:** Add a named custom accessibility action on the container:

```swift
.accessibilityElement(children: .ignore)
.accessibilityLabel(buildAccessibilityLabel())
.accessibilityAction(named: "View Alert Details") {
    if let alert = highestSeverityAlert {
        onAlertTap(alert)
    }
}
```

---

## 2.3 CRITICAL — Horizontal ScrollView Hourly Forecast Cards Inaccessible

**Severity:** 24 hours of forecast data unreachable via VoiceOver swipe  
**Files:** `CityDetailView.swift` (hourly cards section), `DayDetailView.swift`, `MarineForecastSection`

VoiceOver swipe navigation cannot scroll horizontal `ScrollView` content. Off-screen cards are simply unreachable. Each `HourlyForecastCard` has correct `.accessibilityElement(children: .ignore)` and a complete custom label — the accessibility work is there, but VoiceOver cannot navigate to cards that require scrolling.

**Fix:** Add `.accessibilityScrollAction` to the inner `HStack`:

```swift
ScrollView(.horizontal, showsIndicators: false) {
    HStack(spacing: 16) {
        ForEach(...) { HourlyForecastCard(...) }
    }
    .accessibilityScrollAction { edge in
        // Programmatic scroll based on edge (.leading / .trailing)
    }
}
```

Or provide an `.accessibilityRepresentation` that exposes a flat vertical list of the same data. The headings layout already solves this correctly — the cards layout needs parity.

---

## 2.4 HIGH — `ISO8601DateFormatter` Dead Code in `HourlyForecastCard`

**Severity:** Latent correctness bug; high future regression risk  
**File:** `CityDetailView.swift` (line ~1233)

```swift
let formatter = ISO8601DateFormatter()
formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
var hourDescription = formattedTime       // from FormatHelper.formatTimeCompact — CORRECT
if let date = formatter.date(from: time) { // ALWAYS FAILS for "2026-01-18T06:50"
    // manual hour formatting — NEVER REACHED
}
```

Open-Meteo timestamps have no timezone suffix and no fractional seconds. `ISO8601DateFormatter` with `.withInternetDateTime` requires a timezone (`Z` or `+HH:mm`), so this branch never executes. The fallback `formattedTime` from `FormatHelper` is correct, but the dead code creates a false impression of a fallback chain. Remove the `ISO8601DateFormatter` block entirely:

```swift
private func createAccessibilityLabel() -> String {
    guard let time = time else { return "No data" }
    var label = formattedTime  // FormatHelper.formatTimeCompact — sufficient
    for field in settingsManager.settings.hourlyFields.filter({ $0.isEnabled }) {
        if let fieldText = getFieldAccessibilityText(for: field.type) {
            label += ", \(fieldText)"
        }
    }
    return label
}
```

---

## 2.5 HIGH — Radar Timeline Entirely Accessibility-Hidden

**File:** `RadarView.swift`

The entire `radarTimelineView` GroupBox has `.accessibilityHidden(true)`. The `radarSummaryCard` and Swift Charts audio graph provide overview data, but timestamped detail for each point in the 2-hour timeline is unavailable. Users cannot determine whether precipitation starts at 4:15 PM vs 5:30 PM.

**Fix:** Replace `.accessibilityHidden(true)` on the timeline container with `.accessibilityElement(children: .contain)` and ensure each timeline entry has a label like "4:15 PM, Light Rain". The audio graph pattern already in `radarMapView` provides the model.

---

## 2.6 HIGH — Historical Weather View Mode Buttons Have No Selected State

**File:** `HistoricalWeatherView.swift`

The three view mode buttons (Single Day, Browse Days, History) distinguish active state visually via `borderedProminent` vs `bordered` — color/weight only. No accessibility trait indicates which is currently selected.

**Fix:**

```swift
Button("Single Day") { viewMode = .singleDay }
    .buttonStyle(viewMode == .singleDay ? .borderedProminent : .bordered)
    .accessibilityAddTraits(viewMode == .singleDay ? .isSelected : [])
```

Apply the same pattern to all three mode buttons.

---

## 2.7 HIGH — Missing Announcements in Key Async Operations

**File:** `AddCitySearchView.swift`

Three missing VoiceOver notifications:

**a. Search results arrive silently:**
```swift
UIAccessibility.post(notification: .announcement,
    argument: searchResults.count > 0 ? "\(searchResults.count) results found" : "No cities found")
```

**b. Search error arrives silently:**
```swift
UIAccessibility.post(notification: .announcement, argument: errorMessage)
```

**c. No `.screenChanged` after city add:**
```swift
UIAccessibility.post(notification: .screenChanged, argument: nil)
dismiss()
```

**File:** `CityDetailView.swift` — `WeatherAlertsSection`

After alerts finish loading, no announcement is posted:
```swift
let msg = alerts.isEmpty ? "No active weather alerts" : "\(alerts.count) active weather alert\(alerts.count == 1 ? "" : "s")"
UIAccessibility.post(notification: .announcement, argument: msg)
```

**File:** `MyCitiesView.swift` / `ContentView.swift` — Weather refresh completion has no announcement. Add "Weather updated" on success, error message on failure.

---

## 2.8 HIGH — Coordinates in Search Result Labels

**File:** `AddCitySearchView.swift`

```swift
.accessibilityLabel("\(result.displayName), coordinates \(String(format: "%.4f, %.4f", result.latitude, result.longitude))")
```

VoiceOver reads "37.7749, minus 117.1611" verbatim. The `displayName` already includes city, state/region, and country. Coordinates add cognitive load with no disambiguation benefit.

**Fix:** Remove the coordinates from the accessibility label.

---

## 2.9 MEDIUM — Tab Items Carry Wrong Trait

**File:** `ContentView.swift`

```swift
.accessibilityAddTraits(.isButton)  // ← Wrong
```

Tab items have radio-button semantics, not plain button semantics. Adding `.isButton` overrides the correct system-provided semantics. Remove it.

---

## 2.10 MEDIUM — Date Display Has Conflicting Traits

**File:** `MyCitiesView.swift`

```swift
Text(dateDisplayString)
    .accessibilityAddTraits(.isButton)    // ← Conflicting
    .accessibilityAdjustableAction { ... }
```

`.accessibilityAdjustableAction` correctly marks this as adjustable (swipe up/down for increment/decrement). Adding `.isButton` alongside creates ambiguity — VoiceOver announces "button" when it should say "adjustable". Remove `.isButton`.

---

## 2.11 MEDIUM — Pressure Hardcoded to hPa in `StateCitiesView`

**File:** `StateCitiesView.swift`

```swift
Text(String(format: "%.1f hPa", pressure))  // ignores user unit preference
```

If the user has selected inHg, VoiceOver reads an unconverted hPa value with the wrong unit label.

**Fix:**
```swift
let converted = settingsManager.settings.pressureUnit.convert(pressure)
let unitLabel = settingsManager.settings.pressureUnit.rawValue
Text(String(format: settingsManager.settings.pressureUnit == .hPa ? "%.0f %@" : "%.2f %@", converted, unitLabel))
```

---

## 2.12 MEDIUM — Picker Accessibility Value in Label (Wrong Semantic Slot)

**File:** `HistoricalWeatherView.swift`

```swift
.accessibilityLabel("Year, \(tempYear)")  // value embedded in label — doesn't update dynamically
```

The current value belongs in `.accessibilityValue`, not `.accessibilityLabel`. VoiceOver reads label once on focus; value updates as the element changes.

**Fix:**
```swift
.accessibilityLabel("Year")
.accessibilityValue(String(tempYear))
```

Apply the same fix to month and day pickers in `DatePickerSheet`.

---

## 2.13 MEDIUM — Toggle Container Has `.isButton` Trait

**File:** `SettingsView.swift` (line ~245)

```swift
.accessibilityElement(children: .combine)
.accessibilityAddTraits(.isButton)
```

The Toggle already carries switch/toggle semantics. Wrapping with `.combine` + `.isButton` makes VoiceOver call it a "button" rather than a "switch". Remove `.isButton`.

---

## 2.14 MEDIUM — Chevron Not Hidden in `DailyHeadingBlock`

**File:** `CityDetailView.swift` (line ~2049)

```swift
HStack {
    Text(dayName)
    Image(systemName: "chevron.right")  // no .accessibilityHidden(true)
}
.accessibilityAddTraits(.isHeader)
```

VoiceOver announces "chevron right" as part of the day name heading.

**Fix:** Add `.accessibilityHidden(true)` to the chevron image.

---

## 2.15 MEDIUM — `DayDetailView.navigationTitle` Uses Sunrise to Infer Date (Fragile)

**File:** `DayDetailView.swift` (lines ~54–60)

The navigation title is derived by parsing the sunrise timestamp. If sunrise is nil (possible if the API returns nil or parsing fails), the title falls back to "Day 3" — generic and unhelpful.

**Fix:** Compute the title date directly from `dayIndex` and today:
```swift
let date = Calendar.current.date(byAdding: .day, value: dayIndex, to: Date()) ?? Date()
let df = DateFormatter()
df.dateFormat = "EEEE, MMMM d"
df.locale = Locale(identifier: "en_US_POSIX")
return df.string(from: date)
```

---

## 2.16 MEDIUM — `TableView.swift` Has Local `formatTime` That Diverges from `FormatHelper`

**File:** `TableView.swift`

```swift
private func formatTime(_ isoString: String) -> String {
    guard let date = DateParser.parse(isoString) else { return isoString }
    let formatter = DateFormatter()
    formatter.timeStyle = .short  // respects 12/24-hour system setting
    return formatter.string(from: date)
}
```

`FormatHelper.formatTime()` hardcodes `"h:mm a"` (always 12-hour). Users with 24-hour time enabled see different formatting in Table view vs all other views. Replace with `FormatHelper.formatTime(isoString)` for consistency, or update `FormatHelper` to respect the system 12/24-hour preference.

---

## 2.17 MINOR — "Double Tap" in Accessibility Hints (Deprecated Phrasing)

VoiceOver appends "double tap to activate" automatically for buttons since iOS 14. Explicitly saying "Double tap to..." in hints creates redundant announcements.

**Affected files:** `BrowseCitiesView.swift`, `CityDetailView.swift`, `DayDetailView.swift`, `WeatherAroundMeView.swift`

**Fix:** Remove the "Double tap" prefix from all hints:
- `"Double tap to browse cities in \(state)"` → `"Browse cities in \(state)"`

---

## 2.18 MINOR — Error State SF Symbol Images Not Hidden

`Image(systemName: "exclamationmark.triangle")` in error states lacks `.accessibilityHidden(true)`. VoiceOver announces the SF Symbol name literally.

**Affected files:** `AddCitySearchView.swift`, `RadarView.swift`, `CityDetailView.swift` `MarineForecastSection`

---

## 2.19 MINOR — `FormatHelper.formatTime` Returns Raw ISO String on Parse Failure

```swift
guard let date = DateParser.parse(isoString) else { return isoString }
```

A failed parse returns the raw `"2026-01-18T06:50"` string, which VoiceOver speaks verbatim as a timestamp literal. Should return `"Unknown time"` or `"--"` instead.

---

## 2.20 MINOR — `WeatherAroundMeView` No Announcement When Direction Has No Cities

When `citiesInDirection` is empty after a direction change, the "No cities found" text appears silently.

```swift
.onChange(of: citiesInDirection) { _, newValue in
    if newValue.isEmpty {
        UIAccessibility.post(notification: .announcement,
            argument: "No cities found in this direction")
    }
}
```

---

## 2.21 MINOR — `DailyHeadingBlock` — `.isHeader` on a NavigationLink is Semantically Inconsistent

The NavigationLink is both a heading and an activatable button. VoiceOver announces it as a heading, which users associate with static section titles, not interactive navigations. Consider separating the heading `Text` (with `.isHeader`) from the tappable `NavigationLink`.

---

## 2.22 INFORMATIONAL — What's Done Well

The following accessibility implementations are correct and should be preserved as reference patterns:

- **`AccessibleTableBridge.swift`**: Full `UIAccessibilityContainerDataTable` implementation with correct column/row header semantics, `accessibilityContainerType = .dataTable`, and intentional `.staticText` (not `.header`) for row-header cells.
- **`DateParser` + `FormatHelper`**: Centralized utilities handle Open-Meteo's non-standard format. Parse failure logging is present.
- **`DailyForecastRow`**: Correctly uses `.ignore` with `createAccessibilityLabel()`. All children are `.accessibilityHidden(true)`. Uses `FormatHelper` for sunrise/sunset.
- **`MyCitiesView` date navigation**: Separate `accessibilityDateString` vs visual `dateDisplayString`, `.accessibilityAdjustableAction`, directional announcements on day change — all correct.
- **`ListView` custom actions**: Remove, Move Up, Move Down, Move to Top, Move to Bottom, View Historical, Glance Ahead — comprehensive and consistently applied.
- **`RadarView` audio graph**: `.accessibilityRepresentation { Chart(...) }` is the correct pattern.
- **`DailyForecastSummaryView`**: Natural-language weather summary is a genuine accessibility strength.
- **`AlertDetailView`**: No raw ISO strings, correct `.isHeader` traits, hidden decorative images.
- **`WeatherAlertsSection`**: `.accessibilityElement(children: .contain)` allows VoiceOver to navigate into alert buttons.

---

# Part 3 — Cross-Cutting Observations

*Reviewer: Coordinating Engineer*

---

## 3.1 The `.combine` + Custom Label Bug is Caused by a Single Shared Component

The most widespread accessibility issue (§2.1) traces to `DetailRow` — one component used throughout the entire app. Fixing `DetailRow` to use `.ignore` instead of `.combine` will resolve double-reading on the majority of affected screens in a single change. All other instances of the pattern should be audited after `DetailRow` is fixed, but `DetailRow` is the force multiplier.

---

## 3.2 API and Accessibility Bugs Share a Root Cause Pattern

Both the deprecated API parameter names (§1.1) and the dead ISO8601 code in `createAccessibilityLabel` (§2.4) share the same root cause: **implicit reliance on backward-compatible aliases without validation**. Both bugs produce silent failures — nil data and wrong VoiceOver output respectively — with no error messages to diagnose them. The fix for both is the same: validate at system boundaries, log all failures, and use canonical APIs.

The absence of HTTP status code checking in forecast API fetches (§1.7) means that when §1.1's deprecated names eventually break, the error will manifest as a cryptic decode failure rather than the API's actual reason string. Fixing §1.7 before §1.1's aliases are removed would make the transition significantly easier to diagnose.

---

## 3.3 `RegionalWeatherService` Needs a Structural Fix

`RegionalWeatherService` is architecturally isolated from `WeatherService` in ways that cause three separate issues: duplicate URL construction (§1.9), bypassed concurrency limits (§1.9), and hardcoded units (§1.9). These are symptoms of the same root cause: the service was written independently rather than as an extension of the existing API layer. A refactor that gives `RegionalWeatherService` access to `WeatherService.apiRequest(for:)` and `maxConcurrentRequests` would resolve all three.

---

## 3.4 Timezone Correctness Requires Coordinated Changes

The timezone bug (§1.3) requires changes across three layers simultaneously:
1. `WeatherResponse` model (add `utc_offset_seconds`)
2. `DateParser.parse()` (accept optional `TimeZone` parameter)
3. All call sites that use `DateParser.parse()` (pass the timezone from the response)

These changes should be made in one coordinated commit. A partial fix (e.g., only adding the model field without threading the timezone through to `DateParser`) will not improve behavior and may introduce confusion.

---

## 3.5 Suggested Fix Priority Order

| Phase | Fixes | Rationale |
|-------|-------|-----------|
| **Phase 1 (Data correctness)** | §1.1 (deprecated parameter names) + §1.7 (HTTP error decoding) | Fix data before fixing display. Do together so errors are diagnosable. |
| **Phase 2 (Accessibility P0)** | §2.1 (`DetailRow` .combine → .ignore) | Single change; highest user impact. |
| **Phase 3 (Accessibility P1)** | §2.2 (alert buttons), §2.3 (horizontal ScrollView) | Critical unreachable UI elements. |
| **Phase 4 (Data completeness)** | §1.2 (free 16-day forecast), §1.6 (apparentTemperature fix), §1.14 (cloud_cover in full hourly fetch) | Correct existing display bugs. |
| **Phase 5 (Timezone fix)** | §1.3 + §1.4 + §1.5 (coordinated timezone/DateParser fixes) | Requires coordinated multi-file change. |
| **Phase 6 (Accessibility P2)** | §2.5–§2.21 | Medium/minor accessibility polish. |
| **Phase 7 (Enhancements)** | §1.8 (past_days), §1.9 (RegionalWeatherService), §1.14 (new variables) | New functionality. |

---

*End of review. Total issues identified: 18 Open-Meteo findings, 22 accessibility findings, 3 architectural findings.*
