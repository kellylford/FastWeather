# My Data Feature — Implementation Plan (iOS)

## Overview

Add a user-configurable "My Data" section to the city detail view that displays **current-condition** data points the user picks from the full Open-Meteo API catalog. The feature is gated behind Developer Settings via a new feature flag. Users configure it through a dedicated sheet accessed from a "My Data" button in Developer Settings. The configuration screen organizes ~50 API parameters into meaningful categories, lets users browse with a category picker, shows live data from a selectable preview city, and supports add/remove toggling. Once created, the My Data section appears as a new `DetailCategory` in the city detail view and is treated like any other section in Settings (toggle on/off, reorder, configure individual fields). All UI is VoiceOver-accessible.

## Key Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Data scope | Current conditions only | Simple label-value pairs; avoids complex hourly/daily scroll UIs for v1 |
| API fetching | Dynamic — selected params appended to API call | Exposes full Open-Meteo parameter catalog (~50 current params) |
| Section count | One global section across all cities | Per the requirement: users can have just one |
| Section name | Hardcoded to "My Data" | Avoids naming/editing complexity |
| Preview city | Defaults to first city | User can switch via picker in config screen |
| Storage for dynamic values | `[String: Double]` dictionary on `CurrentWeather` | Avoids adding 50+ optional properties |
| Settings version | Bumped to 3 | Migration appends `.myData` to existing `detailCategories` |

## Implementation Steps

### Step 1: Feature Flag

**File:** `iOS/FastWeather/Services/FeatureFlags.swift`

- Add `myDataEnabled` property (Bool, `@Published`, persisted to `UserDefaults` key `feature_my_data_enabled`, default `true`).
- Update `resetToDefaults()`, `enableAll()`, `disableAll()` methods to include it.

### Step 2: Data Catalog Model

**New file:** `iOS/FastWeather/Models/MyDataCatalog.swift`

- **`MyDataCategory`** enum (String, CaseIterable): `.temperature`, `.humidity`, `.wind`, `.precipitation`, `.pressure`, `.clouds`, `.solar`, `.soil`, `.atmosphere`, `.marine`, `.airQuality` — each with a `displayName`.
- **`MyDataParameter`** enum (String, Codable, CaseIterable) — ~100 cases covering current conditions from three Open-Meteo API endpoints.
  - Computed properties: `displayName`, `explanation` (one-sentence), `apiKey` (Open-Meteo query string name), `unit` (raw unit), `category: MyDataCategory`.
  - Parameters grouped into 11 categories:
    - **Temperature**: temperature_2m, apparent_temperature, temperature_80m/120m/180m
    - **Humidity**: relative_humidity_2m, dew_point_2m, vapour_pressure_deficit
    - **Wind**: wind_speed_10m/80m/120m/180m, wind_direction_10m/80m/120m/180m, wind_gusts_10m
    - **Precipitation**: precipitation, rain, showers, snowfall, snow_depth, freezing_level_height
    - **Pressure**: pressure_msl, surface_pressure
    - **Clouds**: cloud_cover, cloud_cover_low/mid/high, visibility, weather_code, is_day
    - **Solar**: shortwave_radiation, direct_radiation, direct_normal_irradiance, diffuse_radiation, uv_index, sunshine_duration
    - **Soil**: soil_temperature_0cm/6cm/18cm/54cm, soil_moisture at 5 depths
    - **Atmosphere**: cape, evapotranspiration, et0_fao_evapotranspiration
    - **Marine & Ocean**: wave_height, wave_direction/period/peak_period for mean/wind/swell/secondary/tertiary waves, ocean_current_velocity/direction, sea_surface_temperature, sea_level_height_msl
    - **Air Quality**: pm10, pm2_5, carbon_monoxide, nitrogen_dioxide, sulphur_dioxide, ozone, aerosol_optical_depth, dust, uv_index, ammonia, carbon_dioxide, methane, european_aqi, us_aqi, alder/birch/grass/mugwort/olive/ragweed_pollen

### Step 3: Settings Model Updates

**File:** `iOS/FastWeather/Models/Settings.swift`

- **`MyDataField`** struct (Identifiable, Codable, Equatable): `id: String`, `parameter: MyDataParameter`, `isEnabled: Bool`.
- Add `.myData` case to `DetailCategory` enum with raw value `"My Data"`.
- Add to `AppSettings`: `myDataFields: [MyDataField]` (default empty).
- Add `.myData` to default `detailCategories` array (at end, `isEnabled: false`).
- Bump `settingsVersion` to `3`.
- Add migration logic: merge `.myData` into existing saved `detailCategories`.
- Update `CodingKeys`, `init(from:)`, and `encode(to:)`.

### Step 4: WeatherService Dynamic Parameters

**File:** `iOS/FastWeather/Services/WeatherService.swift`

- In `fetchWeather(for:)`, compute the set of My Data `apiKey`s that are enabled and not already in the base parameter list.
- Append them to the `current=` query parameter.
- **File:** `iOS/FastWeather/Models/Weather.swift`
  - Add `myDataValues: [String: Double]?` to `CurrentWeather`.
  - Custom `init(from decoder:)` that decodes known fields normally, then sweeps remaining numeric keys into `myDataValues`.

### Step 5: My Data Configuration View

**New file:** `iOS/FastWeather/Views/MyDataConfigView.swift`

- Presented as `.sheet` from "My Data" button in DeveloperSettingsView.
- **City picker** at top: `Picker` over `cityManager.cities`, defaults to first. Changing fetches weather.
- **Category picker**: `Picker` with `.menu` style for 11 categories (temperature, humidity, wind, precipitation, pressure, clouds, solar, soil, atmosphere, marine, air quality).
- **Parameter list**: For each `MyDataParameter` in selected category:
  - `displayName` (bold)
  - `explanation` (secondary text, `.font(.caption)`)
  - Live value from preview city weather data (formatted with unit conversion)
  - Add / Remove button (SF Symbol `plus.circle` / `minus.circle`)
- **Selected count** shown at bottom.
- **Accessibility**: Each row gets `.accessibilityElement(children: .ignore)` with combined label: "{name}: {explanation}. Current value: {value}. {Added/Not added}". Buttons have `.accessibilityHint`.
- **Visual safety**: Fixed-width layout for buttons, `.lineLimit(nil)` on explanation text, no truncation risks.

### Step 6: CityDetailView — Render My Data Section

**File:** `iOS/FastWeather/Views/CityDetailView.swift`

- Add `.myData` case in `detailSection(for:weather:)`.
- Guard on `featureFlags.myDataEnabled` and non-empty enabled fields.
- Render `GroupBox` with label "My Data" and `chart.bar.doc.horizontal` icon.
- `ForEach` over enabled `myDataFields` → `DetailRow` per field.
- Value lookups: first check named `CurrentWeather` properties (for params the app already decodes), then fall back to `myDataValues[apiKey]`.
- Format with unit conversion via `MyDataFormatHelper.format(parameter:value:settings:)`.
- Empty state: "No data points selected. Configure in Settings > Developer Settings > My Data."
- Accessibility: `.accessibilityElement(children: .contain)` on the GroupBox.

### Step 7: SettingsView Integration

**File:** `iOS/FastWeather/Views/SettingsView.swift`

- In `categoryDataItems(for:)`, add `.myData` case.
- Iterate `settingsManager.settings.myDataFields` with Toggle per field + Move Up/Move Down/Move to Top/Move to Bottom VoiceOver accessibility actions.
- If no fields configured, show text: "No data points configured. Use Developer Settings > My Data to add data points."
- The `.myData` category in `detailCategories` already gets section-level toggle and reorder via existing `ForEach`.

### Step 8: DeveloperSettingsView Updates

**File:** `iOS/FastWeather/Views/DeveloperSettingsView.swift`

- Add "My Data" toggle in Feature Flags section.
- Add "My Data" `NavigationLink` or button that opens `MyDataConfigView` as a sheet (only shown when flag is enabled).

### Step 9: Value Formatting

**In `MyDataCatalog.swift`** (or separate helper):

- `MyDataFormatHelper.format(parameter:value:settings:) -> String`
  - Switches on parameter to apply correct unit conversion:
    - Temperature params → `settings.temperatureUnit.convert()`
    - Wind params → `settings.windSpeedUnit.convert()`
    - Precipitation params → `settings.precipitationUnit.convert()`
    - Pressure params → `settings.pressureUnit.convert()`
    - Distance/visibility → `settings.distanceUnit`
    - Percentages, indices, raw values → formatted as-is with unit suffix
  - Appropriate decimal places per type.

### Step 10: Error/Empty States

- Config screen: loading indicator while fetching preview city weather.
- If API returns `nil` for a selected parameter → show "N/A".
- If no cities exist → config screen shows message instead of picker.
- If feature flag disabled → `.myData` section hidden even if configured.

### Step 11: Build Verification

- `cd iOS && xcodebuild -project FastWeather.xcodeproj -scheme FastWeather -configuration Debug build`
- Must see `** BUILD SUCCEEDED **`.

## Visual Safety Checklist

- [ ] All text uses `.lineLimit(nil)` or adequate limits — no clipping
- [ ] `DetailRow` pattern reused for consistent layout
- [ ] Buttons use SF Symbols with adequate tap targets (44pt minimum)
- [ ] GroupBox styling matches existing sections
- [ ] Dynamic Type respected — no fixed font sizes
- [ ] No horizontal overflow in parameter list rows
- [ ] Category picker does not truncate long names

## Accessibility Checklist

- [ ] All interactive elements have accessibility labels and hints
- [ ] Add/Remove state announced with context
- [ ] Category and city pickers are VoiceOver-operable
- [ ] Reorder actions (Move Up/Down/Top/Bottom) in Settings with announcements
- [ ] Data rows read as "Label: value"
- [ ] Empty states are announced
- [ ] Feature flag toggle has descriptive label

## Files Modified

| File | Change |
|---|---|
| `Services/FeatureFlags.swift` | Add `myDataEnabled` flag |
| `Models/Settings.swift` | Add `MyDataField`, `.myData` category, version bump |
| `Models/Weather.swift` | Add `myDataValues` to `CurrentWeather` |
| `Services/WeatherService.swift` | Append dynamic params to API call |
| `Views/CityDetailView.swift` | Render `.myData` section |
| `Views/SettingsView.swift` | Add `.myData` case to `categoryDataItems` |
| `Views/DeveloperSettingsView.swift` | Add toggle and config button |

## Files Created

| File | Purpose |
|---|---|
| `Models/MyDataCatalog.swift` | Parameter catalog, categories, format helper |
| `Views/MyDataConfigView.swift` | Configuration sheet UI |
