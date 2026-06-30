# FastWeather iOS — Comprehensive Code Review

**Date:** 2026-06-30
**Scope:** `iOS/` — 48 Swift files, ~20,846 LOC
**Method:** Five parallel domain reviews (services/networking, SwiftUI views, accessibility, models/persistence, project hygiene), de-duplicated and prioritized here.

---

## Status (updated 2026-06-30)

All work is on branch **`code-review-fixes`** — `main` is untouched and shippable.

**Fixed + tested (commit on branch):**
- ✅ **CR-1** — `settingsVersion` now encoded/decoded; version-reset gate is live again. Tests added.
- ✅ **CR-2** — My Data reads now use the App Group suite (with `.standard` fallback).
- ✅ **CR-3** — bounds-safe `Array.value(at:)` applied to daily/past extraction + `DayDetailView`. Tests added.
- ✅ **HI-6** — offset-aware cache validity for future-day + marine fetches.
- Build succeeds; all 101 unit tests pass (incl. 8 new).

**Withdrawn after verification (do NOT change):**
- ❌ **CR-5** — radar timeline "hidden from VoiceOver" — intentional; data is exposed via the accessible chart. Confirmed by VoiceOver testing.
- ❌ **HI-2** — dew point CodingKey "mismatch" — reviewer was backwards; the API is asked for `dew_point_2m` and it decodes correctly.

**Deferred — needs on-device testing or your VoiceOver confirmation (not yet touched):**
- ⏸️ All accessibility items (CR-4 and every Medium/Low a11y item) — **awaiting your VoiceOver verification** (see `VOICEOVER_VERIFICATION.md`).
- ⏸️ **HI-1** (WeatherKit coordinate cache), **HI-3** (alert error surfacing), **HI-4** (iCloud conflict/quota), **HI-5** (My Data refresh coalescing), **HI-7** (cache key on coords), **HI-8** (hour-index fallback), **HI-10** (duplicate WeatherService) — behavioral/architectural; warrant app testing before changing.

---

## Executive Summary

The codebase is in good overall shape: secrets are properly gitignored, required Info.plist usage strings and entitlements are present, force-unwraps/`try!` are nearly absent, the accessibility layer is genuinely strong (correct UIKit data-table bridge, Charts `accessibilityRepresentation`, consistent decorative-image hiding), and `AppSettings` decoding is defensively written with `decodeIfPresent ... ?? default` throughout.

The real risks cluster in five places:

1. **Two latent crash classes** from force-subscripting independently-optional API arrays at a shared index (daily forecast extraction, `DayDetailView`).
2. **A dead settings version-gate** — `settingsVersion` is never encoded/decoded, so the documented "force-wipe incompatible data" safety net does nothing, and the incompatible-data case it guards throws an *uncatchable* `NSException`.
3. **An App Group suite mismatch** — settings are written to the shared suite but read from `UserDefaults.standard` in three `WeatherService` paths, silently dropping a user's "My Data" parameters from API requests.
4. **Paid-API cost amplification** — redundant WeatherKit calls on the browse/regional fan-out, over-aggressive cache re-fetching, and a per-parameter full-city refresh loop, all against a paid Open-Meteo + metered WeatherKit budget.
5. **One VoiceOver state blocker** — a settings toggle collapsed into a button, which loses its on/off switch state — in an app whose core promise is accessibility parity. (A second radar finding, CR-5, was withdrawn after VoiceOver testing — see below.)

Recommended sequence: fix the Critical correctness/crash bugs and the accessibility blocker first (small, high-impact), then the High cost/data-integrity items, then tackle the one large structural refactor (shared weather formatter + decomposing `CityDetailView`) opportunistically.

> **Note on verification:** Findings here come from static review. Where they touch VoiceOver behavior, trust on-device VoiceOver testing over the static inference — CR-5 below is a worked example of a static "violation" that VoiceOver testing proved was correct, intentional design.

---

## Priority Action List (do these first)

| # | Severity | Area | Item |
|---|----------|------|------|
| 1 ✅ | Critical | Models | **DONE.** Encode/decode `settingsVersion` — the version-reset safety net is inert; incompatible data throws an uncatchable `NSException` on launch |
| 2 ✅ | Critical | Services | **DONE.** App Group suite mismatch: 3 `WeatherService` reads hit `.standard` not the shared suite → My Data params silently dropped |
| 3 ✅ | Critical | Services/Views | **DONE.** Array-index crash on partial API responses (daily extraction + `DayDetailView` subscripts) |
| 4 | Critical | A11y | Settings toggle collapsed via `.combine`+`.isButton` loses switch semantics/state |
| ~~5~~ | ~~Critical~~ | A11y | ~~RadarView text timeline hidden from VoiceOver~~ — **WITHDRAWN** after VoiceOver testing; the data is exposed via the accessible chart and the hidden list is an intentional duplicate. Do not change. |
| 6 ✅ | High | Services | **DONE (HI-6).** Offset-aware cache validity for future-day + marine fetches (was always 10 min). *(Separate from the WeatherKit-overlay cost item, which is deferred — see HI-1.)* |
| 7 ❌ | High | Models | ~~`dewpoint_2m` vs `dew_point_2m` mismatch~~ **WITHDRAWN** — verified the request asks for `dew_point_2m` and it decodes correctly. Do not change. |
| 8 | High | Services | Severe-weather alert fetch errors silently swallowed → "no alerts" indistinguishable from "fetch failed" |
| 9 | High | Models | iCloud sync: no quota handling + last-writer-wins overwrites cities (data loss) |
| 10 | High | Views | `MyDataConfigView.addParameter` refreshes every saved city per parameter (API amplification) |

---

## CRITICAL

### CR-1 · `settingsVersion` is never encoded — version-gate is dead, incompatible data crashes on launch
**`Models/Settings.swift:441, 646, 784–1140`, `Services/SettingsManager.swift:43–67`**
`settingsVersion` has a stored property and a `CodingKeys` entry, but the custom `encode(to:)` never writes it and `init(from:)` never reads it. Every saved blob lacks the key, so `SettingsManager`'s `savedVersion != currentVersion` reset branch is never taken. The mechanism's purpose is to force-wipe structurally-incompatible older data — and the code comment notes that incompatible (v2) data caused an **`NSException`** (a type mismatch), which is *not* a Swift `Error` and will **not** be caught by the surrounding `try/catch`. Result: a future format change can crash on launch with no recovery.
**Fix:**
```swift
// encode(to:)
try container.encode(settingsVersion, forKey: .settingsVersion)
// init(from:)
settingsVersion = try container.decodeIfPresent(Int.self, forKey: .settingsVersion) ?? 1
```
Then verify the reset branch fires for a mismatched version.

### CR-2 · Settings read from `UserDefaults.standard` instead of the App Group suite — My Data params silently dropped
**`Services/WeatherService.swift:132, 152, 191` vs `Services/SettingsManager.swift:24–26, 79`**
`SettingsManager` writes settings to the App Group suite, but `appendMyDataParameters`, `fetchMyDataMarineValues`, and `fetchMyDataAirQualityValues` read `"AppSettings"` from `UserDefaults.standard`. After `migrateToAppGroupIfNeeded` runs, the canonical copy lives only in the suite; `.standard` is stale or empty. A user's configured "My Data" parameters never get appended to requests, so those fields silently never populate.
**Fix:** Route all three reads through `UserDefaults(suiteName: AppGroup.suiteName) ?? .standard`, via a shared helper so the suite/key pairing can't drift again.

### CR-3 · Array-index crash on partial daily / past API responses
**`Services/WeatherService.swift:444–461, 605–647`; `Views/DayDetailView.swift:142, 192–197, 298–301, 355–357, 407–410`**
Future-date and past-date extraction guard only the master array (`temperature2mMax.count`), then force-subscript independently-optional companion arrays at the same index — `daily.sunrise.map { [$0[dateOffset]] }`, `precipitationSum[dateOffset]`, `apparent_temperature_max[targetIndex]`, etc. Each companion is a separate `[T?]?` (`Weather.swift:331–346`). `DayDetailView` reaches `dayIndex` up to 15 and never re-validates against array length. Open-Meteo normally returns equal-length arrays, but any partial/omitted-field response traps instead of degrading. (The hourly path at `WeatherService.swift:470` is already safe — it clamps with `min(...)`.)
**Fix:** Add a safe-subscript helper `func safeElement<T>(_ arr: [T?]?, _ i: Int) -> T? { guard let arr, i < arr.count else { return nil }; return arr[i] }` and use it everywhere a companion array is indexed. In `DayDetailView`, early-return on `guard dayIndex < (daily?.temperature2mMax.count ?? 0)`.

### CR-4 · Settings toggle collapsed into a button — loses VoiceOver switch state
**`Views/SettingsView.swift:328–342`**
Weather-field reorder rows wrap a native `Toggle` in an HStack with `.accessibilityElement(children: .combine)` + `.accessibilityAddTraits(.isButton)`. This strips the switch trait and on/off value; VoiceOver announces a "button" and the state is conveyed only via hint text (which many users disable). Violates the project's `.ignore`-not-`.combine` rule and hides toggle state. `DeveloperSettingsView.swift:22–60` shows the correct pattern (plain `Toggle` + label + hint).
**Fix:** Remove `.combine` and `.isButton`; keep the native `Toggle` with its label; attach the reorder `.accessibilityAction(named:)` actions directly to the `Toggle`. Drop the state-in-hint workaround.

### CR-5 · ~~RadarView text timeline hidden from VoiceOver~~ — WITHDRAWN (not a defect; intentional, verified by VoiceOver testing)
**`Views/RadarView.swift:199`**
**Status: not a bug — do not "fix."** The static review flagged `radarTimelineView` as `.accessibilityHidden(true)` and assumed VoiceOver users lose the per-interval forecast. VoiceOver testing on Madison disproves this: the same time-point data (now, 5, 10, 15 … 60 min, each with its precipitation/condition) **is** exposed — more richly — through the Precipitation Graph's `.accessibilityRepresentation` (`RadarView.swift:271–284`), where each curated point (`[0,5,10,15,20,30,45,60]`) is a labeled element with the condition as its value, plus an audio graph. The hidden `radarTimelineView` is the *visual* duplicate of that same data; it is hidden **on purpose** so VoiceOver doesn't read the identical time points twice. This is correct accessibility design. The unused `timelineAccessibilityLabel()` at `:354` is genuinely dead code, but wiring it up would *regress* the experience by double-reading the timeline — leave the timeline hidden. (Lesson: this is exactly why the project rule mandates VoiceOver testing over static inference.)

---

## HIGH

### HI-1 · WeatherKit condition overlay is uncached — re-bills on every view (cost only; overlay itself is intentional and must stay)
**`Services/WeatherService.swift:806–811`; `Services/RegionalWeatherService.swift:187–197, 236–247`**
**Context — do not undo:** The per-location WeatherKit overlay (commit `f7cf43d`, "WeatherKit-backed current conditions") is a deliberate accuracy fix. Open-Meteo sometimes reports the wrong condition (e.g. "thunderstorm in Madison" when Apple's observation-informed data says clear), so the app intentionally replaces Open-Meteo's condition with WeatherKit's so the directional tiles match the rest of the app. **The overlay is correct and should not be removed or scoped to fewer tiles — doing so re-introduces the mismatch.**

The only real issue is **cost-efficiency, not correctness**: the WeatherKit condition is fetched *fresh on every appearance* and never cached, even though the location *name* right below it (`getCachedLocationName`, RegionalWeatherService:202–214) is cached by coordinate. So one "Weather Around Me" open ≈ 9 WeatherKit calls, and re-opening the same screen re-bills all 9. WeatherKit is metered (500k/mo free, then per-call). At a small user base this is well within the free quota — it's a tuning opportunity, not a bug.
**Fix (preserves the overlay fully):** Cache the WeatherKit condition by rounded coordinate, exactly like `getCachedLocationName` already does — same accurate Apple condition, just not re-fetched on every view. Do **not** remove the overlay or limit it to the selected city.

### HI-2 · ~~`dewpoint_2m` vs `dew_point_2m` CodingKey mismatch~~ — WITHDRAWN (reviewer had it backwards; verified against the actual request)
**`Models/Weather.swift:192, 212`; `Services/WeatherService.swift:367, 570, 837`**
**Status: not a bug — do not change the CodingKey.** Trust-but-verify caught this one. The base current request string explicitly asks Open-Meteo for **`dew_point_2m`** (with the underscore — `WeatherService.swift:367, 570, 837`), Open-Meteo echoes back the same key, and `CurrentWeather.CodingKeys` correctly maps `dewPoint2m = "dew_point_2m"`. Current-conditions dew point **does** populate. Changing the CodingKey to `dewpoint_2m` (the reviewer's suggested fix) would *break* a working feature.
**Two minor, non-urgent inconsistencies remain — verify against a live API response before touching:**
1. `knownKeys` (`Weather.swift:192`) lists `"dewpoint_2m"` instead of `"dew_point_2m"`, so the dynamic My Data sweep doesn't treat `dew_point_2m` as a known/named key. Harmless today (still decoded into the named property), but `dew_point_2m` could also land in `myDataValues`.
2. `MyDataCatalog.swift:354` returns `apiKey == "dewpoint_2m"` (the *legacy* spelling) for the Dew Point My Data parameter. If a user adds Dew Point via My Data, the request uses `dewpoint_2m`; whether Open-Meteo still honors that legacy alias needs a live check. The normal (non-My-Data) dew point is unaffected.

### HI-3 · Severe-weather alert fetch errors silently swallowed
**`Services/WeatherService.swift:1389–1391, 1448–1450`**
`fetchNWSAlertsDirectly` catches all errors and returns `[]`, and non-200 statuses also return `[]`. A connectivity drop or transient NWS 500 reads to the user as "no active alerts" — indistinguishable from genuinely clear. For a safety-critical feature, a missed warning presenting as "all clear" is dangerous.
**Fix:** Distinguish "no alerts" (empty 200) from "fetch failed" (network/HTTP error); throw on failure so the view can show "Unable to check alerts." Apply the same distinction to the WeatherKit alert path.

### HI-4 · iCloud sync: no quota handling, last-writer-wins clobbers cities (data loss)
**`Services/iCloudSyncService.swift:58–99`; `Services/SettingsManager.swift:103–114`; `Services/WeatherService.swift:1586–1596`**
`NSUbiquitousKeyValueStore` has a hard 1 MB total / 1 MB-per-key limit; `set(_:forKey:)` returns no success flag, so an oversized `savedCities`/settings blob is silently dropped. On remote change, `applyRemoteSettings`/`applyRemoteCities` replace local state wholesale with no timestamp or merge — two devices editing offline means the last to sync clobbers the other, and for `savedCities` that is data loss. `try?` on encode also swallows failures with no log.
**Fix:** Merge cities by `id` union (or apply a `lastModified` newer-wins check) instead of replacing; observe `didChangeExternallyNotification` for `QuotaViolationChange`; log encode failures via `AppLogger.persistence.error`; trim synced city payload to just identity + coordinates.

### HI-5 · `MyDataConfigView.addParameter` refreshes every saved city per parameter
**`Views/MyDataConfigView.swift:317–323`**
`addParameter` loops `for savedCity in weatherService.savedCities { await weatherService.fetchWeather(...) }`. Adding several data points in a row triggers N×M live fetches against the paid tier.
**Fix:** Coalesce into a single batched refresh on sheet dismiss (`Done`), or mark cache stale and let normal lazy fetch repopulate.

### HI-6 · Over-aggressive cache re-fetching costs paid calls
**`Services/WeatherService.swift:333, 948`**
`fetchWeatherForDate` and `fetchMarineData` validate cache with `isCacheValid(timestamp:)`, which always uses the 10-minute current-weather duration regardless of `dateOffset`. The offset-aware `isCacheValid(for:)` (1-hour for future days) exists but isn't used here, so future-day and marine forecasts re-fetch every 10 minutes instead of hourly.
**Fix:** Call `isCacheValid(for: cacheKey)` in both sites.

### HI-7 · `City.id` random per-install UUID keys the weather cache — can't survive iCloud city-list replacement
**`Models/City.swift:10–40`; `Services/WeatherCache.swift:49`; `Services/iCloudSyncService.swift:65–82`**
The in-memory/disk weather cache is keyed by `City.id`, a `UUID()` minted per install. The same place on two devices has different UUIDs, so when device B pulls device A's list (wholesale replace), every cached entry is orphaned. `HistoricalWeatherCache` avoids this by keying on rounded lat/lon.
**Fix:** Key the weather cache on a stable natural key (rounded `"\(lat),\(lon)"`, matching `HistoricalWeatherCache`), or derive `City.id` deterministically from coordinates.

### HI-8 · `findCurrentHourIndex` falls back to 0 — shows stale/past hours
**`Views/CityDetailView.swift:1096–1107` (+ duplicates at `2397–2410`, `311–318`)**
When no hourly timestamp is `>= now`, the function returns index 0 — the *start* of a possibly-overnight cached payload, i.e. hours in the past. The hourly forecast then silently shows old data.
**Fix:** Fall back to `times.count - 1`, or return a sentinel and skip the section.

### HI-9 · Untested critical surfaces; App Group migration untested
**`iOS/FastWeatherTests/`**
Tests cover only pure functions. Zero coverage on `WeatherService` networking/URL-building, the disk caches, `LocationService`/`RadarService`/`RegionalWeatherService`, `MyDataCatalog` `apiKey` mapping (a typo silently drops a field), and the one-shot App Group settings migration (a regression silently wipes user settings on upgrade). The two "live API" tests `XCTSkip` without a paid key, so CI never runs them.
**Fix:** Extract URL-building into a pure function and assert query strings; inject a `URLProtocol` stub to test fetch/error/cache paths offline; add a `MyDataCatalog` round-trip test (every `apiKey` non-empty and unique); add a migration test (seed legacy `.standard`, run a fresh `SettingsManager`, assert values land in the suite and the flag is set).

### HI-10 · `WeatherAroundMeView` constructs a second `WeatherService()` in view state
**`Views/WeatherAroundMeView.swift:34`**
`@State private var directionalWeatherService = WeatherService()` creates a parallel service (separate cache, separate config, no guaranteed `Secrets` wiring), bypassing the injected `@EnvironmentObject`. Duplicates network/cache infrastructure and can double API cost.
**Fix:** Move directional batch-fetch into the shared `WeatherService`/`RegionalWeatherService` and inject it; don't construct services in view state.

---

## MEDIUM

### Accessibility
- **`.combine` used where `.ignore` is mandated (23 sites).** Most also set an explicit label so user impact is small, but it violates the stated rule and is fragile. Highest-impact: `DayDetailView.swift:347, 389, 448` — GroupBox sections with **no** explicit label, concatenating every row into one element and losing per-row navigation. Other sites: `CityDetailView:656, 1140`, `FlatView:263`, `StateCitiesView:405, 496`, `WeatherAroundMeView:148,180,197,246,528`, `RadarView:77,109,126,172`, `HistoricalWeatherView:534`, `MyCitiesView:283`, `SettingsView:537`, `ListView:105,394`. **Fix:** replace with `.ignore` + explicit label; for the multi-row `DayDetailView` GroupBoxes use `.contain` so rows stay navigable.
- **Buttons missing `.accessibilityHint()` (rule is unconditional).** `CityDetailView:689`; `MyCitiesView:212,239,249`; `RadarView:55,395`; `AddCitySearchView:129–144,177`; `StateCitiesView:135,170,295,330`; `FlatView:178,339`; `MyDataConfigView:159`; `SettingsView:546`; WeatherAroundMe direction buttons.
- **Sort-menu selected state is icon-only** (`StateCitiesView:163` + country menu ~`323`) — VoiceOver doesn't announce the selected option. **Fix:** `.accessibilityAddTraits(selected ? .isSelected : [])` per item.
- **`.accessibilityLabel` on a `.contain` container is ignored** (`WeatherAroundMeView:264–265`) — render an `.isHeader` Text inside instead.
- **Silent async content changes** — `AddCitySearchView:219–242` doesn't announce when results/errors arrive; post a `.announcement`.
- **Hardcoded `.system(size:)` on real content text** (hero temperatures) won't scale with Dynamic Type: `CityDetailView:558,664`, `WeatherAroundMeView:240`, `DayDetailView:131`, `HistoricalWeatherView:48,59`, `StateCitiesView:588`. Use relative font styles. (The same-size *icons* are correctly hidden.)

### Views / architecture
- **Raw `DateFormatter` used for time display instead of `FormatHelper`** (project rule): `TableView:442`, `StateCitiesView:774`, `CityDetailView:582` (also a per-render allocation in body). **And** `HourlyForecastCard.createAccessibilityLabel` parses Open-Meteo timestamps with a **banned `ISO8601DateFormatter`** (`CityDetailView:1315–1326`) — the no-suffix timestamps fail to parse and silently fall back. Route through `FormatHelper` / `DateParser.parse()`.
- **Drifted duplicate `formatX` helpers** produce inconsistent precision for the same datum across screens: `formatPrecipitation` `%.2f` vs `%.1f`, `formatWindSpeed` `%.1f` vs `%.0f`, `formatWindDirection` `(deg/45).rounded()` vs `(deg+22.5)/45`. Resolved by the shared-formatter refactor below.
- **Redundant refresh storms** — `ContentView:53–61` (every foreground) + `MyCitiesView:133–137` (every date change) + per-row `.task(id:)` fetches in ListView/FlatView all trigger overlapping full-city fetches. Centralize date-offset fetching; have rows read cache only.
- **`WeatherAlertsSection` never refreshes on `alertsRefreshID`** (`CityDetailView:2295–2371`, `hasLoaded` blocks re-fetch) — pull-to-refresh leaves detail-screen alerts stale. Add `.task(id: weatherService.alertsRefreshID)`.
- **`TableView` rebuilds the entire accessibility tree every scroll frame** (`TableView:248–257`, `AccessibleTableBridge:261–267`) — O(cities×columns) string formatting per tick. Batch into one `apply(headers:rows:handlers:)` that rebuilds once; only rebuild when data actually changes. (Flag is off by default.)
- **`MyDataConfigView` keys preview on a mutable array index** (`:23–29`) — store the selected `City.id` instead, to survive removal while the sheet is open.
- **`removeCity` uses a hardcoded 0.5s `asyncAfter`** (`CityDetailView:843–849`) to dodge a `UICollectionView` crash — fragile timing race. Remove in a dismiss-completion callback instead.

### Models / persistence
- **`WeatherCache` is backed by `UserDefaults`, not files** (`WeatherCache.swift:51,129,162`) — full multi-city weather blobs (16-day daily + hourly + dynamic My Data) can reach low-MB, loaded wholesale into memory, encoded+written synchronously on `@MainActor`. Move to a file in Caches, write off the main actor, cap entries.
- **`HistoricalWeatherCache` has no expiry/size cap and lives in Documents** (`:38–74`) — unbounded growth, included in device backups. Move to `.cachesDirectory`, add LRU/size eviction (or at least `isExcludedFromBackup`).
- **`detailCategories` defaults duplicated 5× and already drifted** — the stored-property default (`Settings.swift:617`) omits `astronomy`/`myData` while `init()`/`init(from:)` include them. Extract a single `static let defaultDetailCategories` referenced everywhere.
- **`WeatherData.timeZone` falls back to `.current`** (`Weather.swift:161–163`) — collapses "UTC offset missing" and "device-local" into one expression, risking a remote city showing device-local times. Make the nil-offset case explicitly UTC.

### Services
- **`RegionalWeatherService` encodes + writes UserDefaults while holding the lock** (`:56–62`) on the 9-way concurrent fan-out — move encode/write outside the lock (or use an actor).
- **Marine cache never independently trimmed** (`WeatherService:282–294,1030`) — `trimWeatherCacheIfNeeded` checks `weatherCache.count`/`cacheTimestamps`, never `marineCache`/`marineCacheTimestamps`, so marine entries leak. `removeCity` also doesn't clear marine entries (`:241–248`). Give marine its own trim and clear it in `removeCity`.
- **`LocationService.getCurrentLocation` permission race** (`:53–64`) — a fixed 500ms sleep then re-read of auth status spuriously throws `.permissionDenied` while the user is still responding to the dialog. Await the `$authorizationStatus` publisher with a timeout instead.
- **WeatherKit alert `expires` hardcoded to now+24h** (`WeatherService:1490`) — a cleared alert can show as active up to 24h. Shorten the synthetic expiry and rely on the 5-min refresh to drop cleared alerts.

---

## LOW (selected)

- **Dead/committed cruft:** `Views/DeveloperSettingsView.swift.bak` is tracked (`git rm` it, add `*.bak` to `.gitignore`); `iOS/TestApp/` and `iOS/TestWeatherFastApp/` are tracked but not referenced by the project (delete or move out of `iOS/`); `WeatherCache.swift` appears unused by `WeatherService` (the disk cache was disabled as too slow) — confirm and delete if dead; `RadarView.timelineAccessibilityLabel` unused (wire it up per CR-5); `CityDetailView:485` dead `.historicalWeather` enum case.
- **Doc drift:** `CLAUDE.md` lists 8 feature flags; `FeatureFlags.swift` has 11 (missing `weatherKitConditionsEnabled`, `specificPlaceNamesEnabled`, `myLocationEnabled`). Update the table.
- **Negative-modulo trap:** `MyDataCatalog:640` and `Models/Settings` cardinal-direction `% 8` can produce a negative index on negative input — use `((x % 8) + 8) % 8`.
- **Three force-unwrapped static URLs:** `AlertDetailView:89`, `SettingsView:540`, `CityDetailView:778` — constants are valid, but prefer guard-let or `encodingInvalidCharacters:`.
- **Code duplication:** single-day extraction (`WeatherService:417–491` vs `605–671`) and `baseCurrentParams` (`:367, 570`) duplicated; cardinal-direction helper duplicated in ≥4 files; `@StateObject private var featureFlags = FeatureFlags.shared` wraps a singleton per-view in 6 views (use `@ObservedObject` or inject once).
- **Assertion-free "documentation" tests** in `DateParserTests` (`testParseMalformedTimestamp`, non-leap branch) give false coverage signal — add real assertions.
- **`AddCitySearchView` debounce leaks overlapping tasks** (`:198–215`) — use `.task(id: searchText)` for automatic cancellation.
- **Icon-only buttons below 44×44pt** — `MyDataConfigView:119,231`, ListView/FlatView alert badges — add `.frame(minWidth:44,minHeight:44)`.
- **Persistence errors logged via Release-stripped `debugLog`** (`WeatherCache`, `HistoricalWeatherCache`) — route actual failures through `AppLogger.persistence.error` so they're visible in Release.

---

## The one large refactor worth scheduling

**Extract a shared `WeatherFormatter` + field renderer, and decompose `CityDetailView`.**

The `formatTemperature/WindSpeed/WindDirection/Precipitation/Snowfall/Pressure/Visibility` family is copy-pasted into ~11 structs across 6 files, and the `getFieldLabelAndValue` switch is duplicated nearly verbatim in `FlatView` (`342–448`), `TableView` (`289–398`), and reimplemented again in `ListView.buildWeatherSummary/buildAccessibilityLabel` (`571–919`). They have already drifted (the MEDIUM precision inconsistencies above are the symptom). A units bug or new field currently must be fixed in 4+ places.

`CityDetailView.swift` (2,707 lines) holds 11 `View` structs and a ~570-line `@ViewBuilder detailSection`.

**Plan:** introduce a `WeatherFormatter` value type seeded from `AppSettings` exposing all `formatX` methods, plus a single `WeatherFieldRenderer` (`label(for:)`/`value(for:)`/`accessibilityText(for:)`). Have ListView/FlatView/TableView consume it. Then split each `detailSection` case (`todaysForecast`, `currentConditions`, `astronomy`, `location`, `myData`) into its own small `View` struct (the forecast rows were already extracted — finish the job). This removes the dominant maintainability debt and resolves the precision-drift and duplicate-parsing findings as a side effect.

---

## Confirmed clean (don't "fix" these)

- Secrets: `Secrets.swift` gitignored and confirmed; no hardcoded keys/tokens/`customer-*` hosts anywhere; only `Secrets.swift.example` tracked.
- No `try!` / `as!` force casts in `FastWeather/`.
- Info.plist usage descriptions present (`NSLocationWhenInUseUsageDescription`, `NSLocationUsageDescription`); ATS locked down with a forward-secrecy-compliant open-meteo exception; WeatherKit + App Group + ubiquity-kvstore entitlements correct on both targets.
- `DateParser.parse()` used correctly for Open-Meteo timestamps in services (the lone `ISO8601DateFormatter` in `WeatherService:1402` is the NWS path, which legitimately sends ISO8601). The one banned use is in a *view* (CityDetailView:1315, MEDIUM above).
- `LocationService` continuation handling, `[weak self]` in NotificationCenter observers, and `refreshAllWeather`'s manual task-group concurrency limiter are all correct.
- Accessibility done right: `AccessibleTableBridge` is a correct `UIAccessibilityContainerDataTable` (exposes both column *and* row header hooks); RadarView chart has a real `.accessibilityRepresentation`; decorative SF Symbols consistently hidden; raw unit strings passed through without pronunciation overrides (per the user's standing feedback — leave as-is).

---

## Notes on build configuration

- Deployment target iOS 17.0, Swift 5, `MARKETING_VERSION 1.5.7 (2)` — consistent across configs.
- `SWIFT_STRICT_CONCURRENCY` unset (defaults to `minimal`) — fine under Swift 5, but consider `targeted` before any Swift 6 migration to surface the data-race notes above.
- Warnings-as-errors unset — consider enabling for CI to prevent warning rot in a 20k-LOC codebase. `ENABLE_USER_SCRIPT_SANDBOXING = YES` is already set.
- No UI/accessibility test target despite the accessibility-first mandate — consider an `XCUIApplication` smoke test running `performAccessibilityAudit()` over the main tabs (iOS 17+).
