# WeatherFast iOS — Localization Plan

## Overview

This document covers the technical infrastructure work required to make WeatherFast ready for translation into other languages. Finding and working with translators is a separate effort; this plan covers everything that must be done in the codebase first.

The app is currently English-only with all user-facing strings hardcoded directly in Swift source files. There is no localization infrastructure in place. The good news: the app uses pure SwiftUI (no storyboards or XIBs), has centralized formatting utilities, and Xcode's `SWIFT_EMIT_LOC_STRINGS` build setting is already enabled — meaning the foundation is clean and the work is well-scoped.

---

## Current State

| Area | Status |
|---|---|
| Localizable.strings / .xcstrings files | None |
| Language folders (.lproj) | None |
| Hardcoded UI strings in Views | ~350+ across 19 view files |
| Enum raw value labels (settings fields) | 80+ cases |
| Info.plist permission strings | 2 strings, not localized |
| Date/time formatting | Centralized but hardcoded to 12-hour AM/PM |
| Unit symbol labels | Hardcoded in 5 unit enums |
| Accessibility labels | Present but hardcoded |
| Country names utility | English-only mapping |
| Images with embedded text | None (clean) |
| Storyboards / XIBs | None (pure SwiftUI — easier to localize) |

---

## Step 1: Choose a String Catalog Strategy

Apple offers two mechanisms for localization. Choose one before starting any extraction work.

**Option A — Xcode String Catalogs (.xcstrings)** *(recommended)*
Introduced in Xcode 15. A single `.xcstrings` file per target replaces all `.strings` files. Xcode manages it through a GUI, tracks which strings are untranslated, and auto-extracts strings from `Text("...")` calls at build time (because `SWIFT_EMIT_LOC_STRINGS` is already on). This is the modern Apple-preferred path and requires the least manual file management.

**Option B — Traditional Localizable.strings files**
One `.strings` file per language in separate `.lproj` folders. More portable, easier to send to external translators as plain text. More manual to manage.

The rest of this plan assumes Option A (String Catalogs), but the extraction work in Steps 2–5 is identical either way.

---

## Step 2: Extract Hardcoded Strings from Views

This is the largest body of work. Every `Text("...")` call and string literal used for user-visible content must be replaced with a localizable call.

**SwiftUI pattern — before:**
```swift
Text("Add City")
```

**SwiftUI pattern — after:**
```swift
Text("add_city_button", bundle: .main)
// or simply:
Text("Add City")  // Xcode auto-extracts this if SWIFT_EMIT_LOC_STRINGS = YES
```

With String Catalogs and `SWIFT_EMIT_LOC_STRINGS = YES`, Xcode can auto-extract bare `Text("literal")` calls, so many strings in the Views may require little or no source change — they just need entries added to the catalog. However, any string built with interpolation or constructed programmatically requires explicit `String(localized:)` calls.

**Strings that need manual `String(localized:)` wrapping:**
- Formatted strings: `"Wind: \(speed) mph"` — split into a format key: `String(localized: "wind_label \(speed) mph")`
- Strings passed as arguments: `Label(title, systemImage: icon)` where `title` is a computed string
- Strings in `accessibilityLabel()` and `accessibilityHint()` modifiers
- Alert titles and messages
- Error message strings in Services and ViewModels

**Files with the most hardcoded strings (prioritize these):**
- `SettingsView.swift` — section headers, picker labels, toggle labels
- `CitySearchView.swift` — search prompts, placeholder text, error messages
- `WeatherDetailView.swift` — field labels, category headers
- `MainWeatherView.swift` — all primary weather display labels
- `WeatherAlertView.swift` — alert UI labels

---

## Step 3: Localize Enum Raw Values (Settings Field Labels)

The app defines ~80 user-facing field names as Swift enum `rawValue` strings. These power the settings screens where users choose which weather fields to display.

**Examples:**
```swift
enum WeatherFieldType: String {
    case temperature = "Temperature"
    case windSpeed   = "Wind Speed"
    case humidity    = "Humidity"
    // ... 24+ more
}
```

Because raw values are baked into the binary as Swift constants, they cannot be looked up in a string catalog at runtime. Each enum must be extended with a computed `localizedLabel` property:

```swift
var localizedLabel: String {
    String(localized: "field_\(rawValue.lowercased().replacingOccurrences(of: " ", with: "_"))")
}
```

Every call site that currently uses `.rawValue` for display must switch to `.localizedLabel`. The raw values themselves should stay as-is — they serve as stable keys for stored user preferences and should never change.

**Enums to update:**
- `WeatherFieldType` (~27 cases)
- `HourlyFieldType` (~17 cases)
- `DailyFieldType` (~19 cases)
- `MarineFieldType` (~14 cases)
- `DetailCategory` (~10 cases)

---

## Step 4: Localize Info.plist Permission Strings

iOS displays these strings in the system permission dialogs. They must be translated or users in other locales will see English text in an otherwise-localized app.

**Strings to localize:**
- `NSLocationWhenInUseUsageDescription` — "Weather Fast uses your location to show weather for your current area."
- `NSLocationAlwaysUsageDescription` — similar
- `CFBundleDisplayName` — "Weather Fast" (may need translation in some markets)

**How:** Create a `InfoPlist.xcstrings` file (or `InfoPlist.strings` in each `.lproj` folder) and add entries for each key. Xcode will pick these up automatically at build time.

---

## Step 5: Localize Date, Time, and Unit Formatting

### Date and Time

The `FormatHelper` struct in `SettingsManager.swift` currently hardcodes 12-hour AM/PM formatting:

```swift
// Current — always 12-hour
formatter.dateFormat = "h:mm a"
```

**Fix:** Replace with locale-aware formatting using `DateFormatter` with a locale:

```swift
formatter.locale = Locale.current
formatter.dateStyle = .none
formatter.timeStyle = .short   // respects 12h/24h user preference
```

Similarly, the date format `"MMMM d, yyyy"` in `HistoricalWeather.swift` should use `DateFormatter.dateStyle = .long` instead so it formats correctly per locale (e.g., "28 May 2026" in UK English).

### Unit Symbols

Unit symbol strings like `"°F"`, `"mph"`, `"in"`, `"mi"` are generally universal, but display names like `"Fahrenheit"` and `"Celsius"` in the settings pickers need to go through the string catalog.

The unit enums already default based on `Locale.current.measurementSystem`, which is good — this behavior should be preserved and tested across locales.

### Cardinal Directions

Wind direction labels like `"North"`, `"Northeast"`, `"SSW"` are currently hardcoded strings. These need localization entries. Abbreviated directions (N, NE, S) may be universal, but full names must be translated.

### Category Labels

UV Index categories (`"Low"`, `"Moderate"`, `"High"`, etc.) and dew point comfort levels (`"Dry"`, `"Comfortable"`, `"Muggy/Uncomfortable"`) are computed strings that need to go through `String(localized:)`.

---

## Step 6: Country Names Utility

`Utilities/CountryNames.swift` contains a hardcoded dictionary mapping ISO country codes to English names. It also maps alternate native-language names (e.g., `"Deutschland"`) back to English.

For localized country display, Apple's `Locale` API can handle this without a custom dictionary:

```swift
Locale.current.localizedString(forRegionCode: "DE") // → "Germany" in en, "Allemagne" in fr
```

The custom mapping can largely be replaced with this built-in API. The reverse-lookup (native names → ISO code) used for search normalization can remain in English since it is used for API queries, not display.

---

## Step 7: Add Language Support in Xcode Project

Once strings are extracted, language support must be explicitly added in Xcode:

1. Open `FastWeather.xcodeproj`
2. Select the project in the navigator → Info tab
3. Under "Localizations," click `+` to add each target language
4. Xcode will create the necessary `.lproj` folders and populate the String Catalog with untranslated entries

Languages should be added one at a time after the string catalog is stable, not before.

---

## Step 8: Update Tests

All tests in `FastWeatherTests/` that assert on formatted output use hardcoded English expectations. These will need updating once formatting is locale-aware:

- `FormatHelperTests.swift` — 48 test cases asserting AM/PM time strings
- `DateParserTests.swift`
- `HistoricalDateParsingTests.swift`
- `UnitConversionTests.swift`

**Strategy:** Pin tests to `Locale(identifier: "en_US")` explicitly so they continue to test English formatting correctly, rather than depending on the machine's locale. Add separate test cases for a second locale (e.g., `"de_DE"`) to verify locale-aware behavior.

---

## Step 9: Prepare Translation Export

Once the String Catalog is populated with all keys and English values, Xcode can export an `.xcloc` package (File → Export Localizations). This is the standard format for sending to translation vendors or working with professional translators. Each language gets its own `.xcloc` file containing the strings and context.

When translations are returned, they are imported back via File → Import Localizations.

---

## Scope Summary

| Task | Effort Estimate |
|---|---|
| Choose string catalog strategy | Trivial |
| Extract ~350 hardcoded strings from Views | Large |
| Add `localizedLabel` to ~80 enum cases | Medium |
| Localize Info.plist permission strings | Small |
| Fix date/time formatting to be locale-aware | Small–Medium |
| Localize category/direction label strings | Small |
| Replace CountryNames utility with Locale API | Small |
| Add language support in Xcode project | Trivial |
| Update test suite for locale-pinning | Medium |
| Export .xcloc for translators | Trivial (after above) |

---

## What This Plan Does Not Cover

- **Finding and paying translators.** Once the `.xcloc` export is ready, you will need translators for each target language. Translation vendors (e.g., Lokalise, Phrase, Crowdin) can manage this workflow. Freelancers on platforms like Upwork or Gengo are another option.
- **App Store listing translations.** The App Store description, keywords, and screenshots are localized separately through App Store Connect and are not part of the Xcode project.
- **Right-to-left language support (Arabic, Hebrew).** SwiftUI handles RTL layout automatically in most cases, but some custom layout code may need review.
- **Language-specific weather terminology.** Some weather terms (e.g., wind direction names, cloud cover descriptions) may not have obvious direct translations and will need translator judgment.
