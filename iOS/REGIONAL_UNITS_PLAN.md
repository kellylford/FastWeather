# Regional Units Plan

## Background

User feedback from Norway: wind speed should be in meters per second (m/s), not km/h.
This document answers the broader questions that feedback raises and proposes a plan.

---

## Q1: Which countries/regions prefer m/s for wind speed?

m/s is the official meteorological standard in a significant portion of the world, not just
Norway. The common thread is countries that adopted SI units fully for meteorology, especially
across northern/eastern Europe and East Asia.

**Nordic & Baltic**
- Norway, Sweden, Finland, Iceland — all official weather services report in m/s
- Denmark is the outlier in Scandinavia; it uses m/s in technical contexts but km/h is common

**Eastern Europe & CIS**
- Russia, Ukraine, Belarus, Kazakhstan, and most former Soviet states — m/s is the standard
  carried over from Soviet meteorological conventions
- Estonia, Latvia, Lithuania follow m/s

**East Asia**
- Japan — the Japan Meteorological Agency (JMA) uses m/s officially
- South Korea — Korean Meteorological Administration uses m/s
- China — China Meteorological Administration uses m/s

**Other**
- Israel uses m/s in official forecasts

**Knots** are used globally in maritime and aviation contexts. Not covered in this plan since
FastWeather is a consumer app rather than a nautical/aviation tool, but worth keeping in mind
for a future Marine Forecast enhancement.

The Beaufort scale sees niche use in parts of Europe (Netherlands, Germany) for communicating
wind to general audiences but is unusual in consumer weather apps.

---

## Q2: Other measurements that differ by region (that we're not yet handling)

### Wind speed in m/s — the new gap (covered in this plan)

### Atmospheric pressure: mmHg
The app already supports hPa and inHg. Russia and CIS countries often show pressure in
millimeters of mercury (mmHg), not hPa. `PressureUnit` already exists; adding `.mmHg`
is a small addition and would benefit the same CIS user base as m/s wind.

Current state: `PressureUnit` has `.hPa` and `.inHg` but no `.mmHg`.
Conversion: 1 hPa × 0.750062 = mmHg (this constant is already in the code but the case
is missing from the enum).

Actually — looking at the code again, `.mmHg` *is* already defined in `PressureUnit`
(Settings.swift:335). The conversion is there. It may simply not be surfaced properly
in the UI picker. Worth verifying whether it appears in Settings.

### Snow depth
The app displays snowfall in mm or inches. Some regions (Scandinavia, Canada, Russia)
care specifically about accumulated *snow depth* as a separate measurement from snowfall.
Open-Meteo provides `snow_depth` (in meters). Currently not exposed in the UI at all.
This is out of scope for this plan but worth a future issue.

### Visibility: already handled
`DistanceUnit` covers km vs miles, and visibility uses it. No gap here.

### Wave height
The Marine Forecast section shows wave height. It follows `DistanceUnit` (miles vs km),
which maps to feet vs meters implicitly, but the labels show "m" or "ft" based on the
unit setting. This appears correct.

### Temperature, precipitation, distance
All already unit-aware with locale-based defaults. No gap.

---

## Plan: Adding m/s (and surfacing mmHg) in the iOS app

### Step 1 — Extend `WindSpeedUnit` enum

**File:** `iOS/FastWeather/Models/Settings.swift` (line 285)

Add a `.ms` case:

```swift
enum WindSpeedUnit: String, CaseIterable, Codable {
    case mph    = "mph"
    case kmh    = "km/h"
    case ms     = "m/s"

    func convert(_ kmh: Double) -> Double {
        switch self {
        case .mph: return kmh * 0.621371
        case .kmh: return kmh
        case .ms:  return kmh / 3.6
        }
    }

    static var defaultUnit: WindSpeedUnit {
        guard let region = Locale.current.region?.identifier else {
            return .kmh
        }
        let msRegions: Set<String> = [
            "NO", "SE", "FI", "IS",            // Nordic
            "RU", "UA", "BY", "KZ",            // Russia / CIS core
            "EE", "LV", "LT",                  // Baltic
            "JP", "KR", "CN",                  // East Asia
            "IL"                               // Israel
        ]
        if msRegions.contains(region) {
            return .ms
        }
        if Locale.current.measurementSystem == .us {
            return .mph
        }
        return .kmh
    }
}
```

**Why `Locale.current.region`:** `measurementSystem` can't distinguish km/h countries from
m/s countries — both are `.metric`. We need the country code. `Locale.current.region` is
available on iOS 16+ (which we already target at iOS 17+).

**Migration:** Adding a new enum case with a new raw value (`"m/s"`) is fully backward-
compatible. Existing stored values `"mph"` and `"km/h"` still decode correctly. No
`settingsVersion` bump needed.

### Step 2 — No changes needed to the Settings UI picker

`SettingsView` already uses `ForEach(WindSpeedUnit.allCases, id: \.self)`, so the new
`.ms` case will appear automatically in the wind speed picker.

### Step 3 — No changes needed to wind display formatting

`formatWind()` in `WeatherHelpers.swift` (line 121) takes `unit: String` — it just
embeds the raw value of the enum as the label. Since `.ms.rawValue == "m/s"`, the
formatted string will read `"5 m/s NW"` automatically once the enum is updated.

Verify all call sites that pass `windSpeedUnit.rawValue` — a quick grep shows they all
flow through `formatWind()` or inline the rawValue directly. No custom string paths.

### Step 4 — Verify Open-Meteo API request parameters

Open-Meteo accepts a `wind_speed_unit` query parameter: `"kmh"`, `"mph"`, `"ms"`, or
`"kn"`. Currently the app requests in km/h and converts client-side. This is fine and
should remain as-is — client-side conversion means one API URL pattern for caching, and
the conversion math is trivial. No API change needed.

### Step 5 — Surface mmHg in the Settings UI (quick win)

The `PressureUnit.mmHg` case already exists in the model with the correct conversion
factor. Confirm it appears in the SettingsView pressure picker (same `allCases` pattern).
If it does, it's already done. If not, check whether the raw value or UI label is
incorrect.

### Step 6 — Update `defaultUnit` for `PressureUnit`

**File:** `iOS/FastWeather/Models/Settings.swift` (line 347)

Currently defaults to `inHg` for US, `hPa` everywhere else. Russia/CIS users expect
mmHg. Apply the same region-based check:

```swift
static var defaultUnit: PressureUnit {
    guard let region = Locale.current.region?.identifier else {
        return .hPa
    }
    let mmHgRegions: Set<String> = [
        "RU", "UA", "BY", "KZ", "EE", "LV", "LT"
    ]
    if mmHgRegions.contains(region) {
        return .mmHg
    }
    if Locale.current.measurementSystem == .us {
        return .inHg
    }
    return .hPa
}
```

### Step 7 — Accessibility labels

`SettingsView` accessibility label for the wind speed picker reads:
`"Wind speed unit, currently \(settingsManager.settings.windSpeedUnit.rawValue)"`

`"m/s"` is readable by VoiceOver but will be announced as letters ("m slash s").
Consider adding a `var accessibilityLabel: String` property to `WindSpeedUnit`:

```swift
var accessibilityLabel: String {
    switch self {
    case .mph: return "miles per hour"
    case .kmh: return "kilometers per hour"
    case .ms:  return "meters per second"
    }
}
```

Then update the SettingsView picker accessibility label accordingly.

### Step 8 — User Guide

`USER_GUIDE.md` mentions the wind speed setting. Update to mention m/s as an option.
The in-app `UserGuideView.swift` should reflect the same.

---

## Out of scope for this plan

- Knots — valuable for maritime contexts but the Marine Forecast section is the right
  place to consider it, not as a global wind setting
- Snow depth as a separate measurement
- Beaufort scale

---

## Implementation order

1. `Settings.swift` — add `.ms` to `WindSpeedUnit`, update `defaultUnit` with region check
2. `Settings.swift` — update `PressureUnit.defaultUnit` with region check (verify mmHg is
   already in the UI picker)
3. `WeatherHelpers.swift` — add `accessibilityLabel` to `WindSpeedUnit` if doing the
   accessibility label improvement
4. `SettingsView.swift` — update wind speed picker accessibility label
5. User Guide update
6. Test on device/simulator with Norwegian locale (`Settings → General → Language & Region`)
