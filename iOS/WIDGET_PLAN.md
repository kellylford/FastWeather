# FastWeather iOS Widget — Implementation Plan

**Status:** Draft / Future Consideration  
**Date:** April 14, 2026  
**Scope:** Add a WidgetKit extension to the iOS FastWeather app showing current weather for saved cities.

---

## Overview

The widget would show current weather conditions for one or more of the user's saved cities directly on the iOS home screen or Lock Screen. No significant changes to existing app logic are required — the main work is enabling App Group data sharing and building a self-contained widget extension.

---

## Phase 1 — Foundation: App Group + Shared Data

The widget runs in a separate process and cannot access the main app's `UserDefaults.standard`. Migrating persistent storage to a shared App Group suite is the prerequisite for everything else.

**Steps:**

1. **Add App Group capability** to the `FastWeather` app target in Xcode (e.g., `group.com.fastweather.app`). This also requires registering the App Group in the Apple Developer Portal.
2. **Migrate city list storage** from `UserDefaults.standard` → `UserDefaults(suiteName: "group.com.fastweather.app")`. The `"SavedCities"` key and `[City]` JSON format stay identical. A one-time migration on first launch copies existing data over.
3. **Migrate settings storage** (`"AppSettings"` key) to the same shared suite so the widget can respect user unit preferences (°F/°C, km/h vs mph, etc.).

**Files to change:**
- `FastWeather/Services/WeatherService.swift` — city list load/save
- `FastWeather/Services/SettingsManager.swift` — settings load/save

---

## Phase 2 — New Widget Extension Target

4. **Add Xcode target:** File → New → Target → Widget Extension.
   - Name: `FastWeatherWidget`
   - iOS deployment target: 17.0
   - "Include Configuration Intent" = **NO** for MVP (static config — shows first city in list)
5. **Add App Group capability** to the new widget target (same group identifier as step 1).
6. **Add shared source files** to the widget target's compile membership (no copy needed):
   - `Models/City.swift`
   - `Models/Weather.swift` (WeatherData, WeatherCode)
   - `Models/Settings.swift` (unit enums)
   - `Services/SettingsManager.swift` (for `DateParser` and `FormatHelper` only)

   All of these are pure `Codable` value types — safe to compile into both targets.

---

## Phase 3 — Lightweight Fetch Layer

7. **Create `WidgetWeatherFetcher.swift`** — a simple `async` function (not `@MainActor`, no `ObservableObject`) that fetches current + today's forecast for one city. Mirrors the `fetchWeatherBasic` pattern in `WeatherService.swift`. Same Open-Meteo URL construction, query parameters, and `User-Agent` header (`FastWeather/1.5 (weatherfast.online)`).
8. **Create `FastWeatherEntry`** — a `TimelineEntry` struct containing:
   - `city: City`
   - `weather: WeatherData?`
   - `date: Date`
   - `isError: Bool`

---

## Phase 4 — Timeline Provider

9. **`FastWeatherTimelineProvider`** conforming to `TimelineProvider`:
   - `placeholder()` → hardcoded static entry (no network call)
   - `getSnapshot()` → reads first city from shared `UserDefaults`, fetches weather, returns entry
   - `getTimeline()` → fetches weather, returns single entry + `TimelineReloadPolicy.after(Date().addingTimeInterval(30 * 60))` (30-minute refresh)

---

## Phase 5 — Widget Views

10. **Small widget** (`systemSmall`):
    - City display name
    - Temperature (in user's preferred unit)
    - WMO condition as SF Symbol icon + short text label
    - Accessibility: `.accessibilityElement(children: .ignore)` with label like "San Diego, 72°F, Clear"

11. **Medium widget** (`systemMedium`):
    - Everything in small, plus: today's high/low, precipitation chance, wind speed — or a 4-hour forecast strip
    - TBD based on preference

All widget views must use `.accessibilityElement(children: .ignore)` with explicit `.accessibilityLabel` — do NOT use `.combine`.

---

## Phase 6 — Per-Widget City Picker (Future, NOT MVP)

12. Upgrade to `AppIntentConfiguration` + an `AppIntent` city-selector Intent. This lets users pick which city to display per widget instance from the widget edit screen. Clearly a separate phase — addable after MVP ships without rearchitecting anything.

---

## New Files Required

| File | Target |
|------|--------|
| `FastWeatherWidget/FastWeatherWidget.swift` | Widget extension |
| `FastWeatherWidget/WidgetWeatherFetcher.swift` | Widget extension |
| `FastWeatherWidget/WidgetViews.swift` | Widget extension |
| `FastWeatherWidget/FastWeatherWidget.entitlements` | Widget extension |

---

## Verification Checklist

- [ ] Both targets have matching App Group entitlement
- [ ] Cities saved in main app appear correctly in widget
- [ ] Unit preferences (°F/°C, etc.) are respected in widget display
- [ ] Timeline refreshes approximately every 30 minutes
- [ ] VoiceOver reads small widget as "City, temperature, condition" — verify with Accessibility Inspector
- [ ] `xcodebuild` produces `** BUILD SUCCEEDED **` for both the app and widget targets

---

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| MVP city selection | First city in saved list | Simple. City-picker is Phase 6. |
| Widget sizes for MVP | Small + Medium | Large is optional later |
| Weather fetch strategy | Widget fetches directly via `URLSession` | Simpler than app-pushed cache via App Group storage |
| Shared code strategy | File target membership | Simpler than a shared Swift Package for MVP |
| API endpoint | Free Open-Meteo endpoint | Widget won't share `Secrets.swift` by default |

---

## Open Questions

1. **Per-widget city picker:** Should the MVP support picking which city shows per widget, or is "first city in your list" acceptable to start?
2. **Paid API key:** If `Secrets.swift` needs to be shared with the widget to use the paid Open-Meteo endpoint, that's a small extra step. Free endpoint is fine for MVP.
3. **Lock Screen widget:** Should a small Lock Screen widget (`accessoryRectangular`, `accessoryCircular`) be in scope for MVP or a follow-up?
