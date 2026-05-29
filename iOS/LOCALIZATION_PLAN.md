# WeatherFast iOS — Localization Plan

## Overview

This document covers the technical infrastructure work required to make WeatherFast ready for translation into other languages. Finding and working with translators is a separate effort; this plan covers everything that must be done in the codebase first.

The app is currently English-only with all user-facing strings hardcoded directly in Swift source files. There is no localization infrastructure in place. The good news: the app uses pure SwiftUI (no storyboards or XIBs), has centralized formatting utilities, and Xcode's `SWIFT_EMIT_LOC_STRINGS` build setting is already enabled — meaning the foundation is clean and the work is well-scoped.

**Decision: Do it right.** Rather than patching localization on top of the existing structure, this plan takes a clean approach — migrating the settings enums to `Int` raw values, removing the storage/display coupling that caused the problem in the first place, and building with `String(localized:)` as the standard going forward. The user base is small enough that the one-time migration cost is low and the payoff compounds with every future feature.

---

## Current State

| Area | Status |
|---|---|
| Localizable.strings / .xcstrings files | None |
| Language folders (.lproj) | None |
| Hardcoded UI strings in Views | ~350+ across 19 view files |
| Enum raw value labels (settings fields) | 80+ cases, `String` raw values used for both storage and display |
| Info.plist permission strings | 2 strings, not localized |
| Date/time formatting | Centralized but hardcoded to 12-hour AM/PM |
| Unit symbol labels | Hardcoded in 5 unit enums |
| Accessibility labels | Present but hardcoded |
| Country names utility | English-only mapping |
| Images with embedded text | None (clean) |
| Storyboards / XIBs | None (pure SwiftUI — easier to localize) |

---

## Step 1: Set Up the String Catalog

Before touching any source code, create the localization infrastructure that everything else will feed into.

Use **Xcode String Catalogs (.xcstrings)** — the modern Apple standard introduced in Xcode 15. A single `Localizable.xcstrings` file lives in the project and Xcode manages it through a GUI. It tracks which strings are translated, which are stale, and which are missing. Because `SWIFT_EMIT_LOC_STRINGS` is already enabled in the build settings, Xcode will auto-detect bare `Text("literal")` calls and offer to add them to the catalog.

**To create it:** In Xcode, File → New → File → String Catalog. Name it `Localizable`. Add it to the FastWeather target.

At this point the catalog is empty. The following steps populate it.

Also enable the **"Use Compiler to Extract Swift Strings"** build warning (in Build Settings, search "localization"). This flags any new `Text("literal")` or `String(...)` that bypasses the localization system, so the problem doesn't re-accumulate over time.

---

## Step 2: Migrate Settings Enums from String to Int Raw Values

This is the most structurally important change and should be done before any string extraction, because it changes how display labels are generated throughout the app.

**The problem with the current design:**

The five settings enums use `String` raw values that serve double duty — they're both the storage key (saved to `UserDefaults`) and the display label shown in the UI. This meant the English label and the storage key were the same thing, making it impossible to translate the label without breaking saved preferences.

```swift
// Current — storage key and display label are the same string
enum WeatherFieldType: String {
    case temperature = "Temperature"
    case windSpeed   = "Wind Speed"
}

// Saved to UserDefaults as the string "Wind Speed"
// Displayed in UI via .rawValue → "Wind Speed"
```

**The fix — separate storage from display:**

Switch to `Int` raw values (stable, never user-visible) and add a `localizedLabel` computed property that looks up the translated string at runtime:

```swift
enum WeatherFieldType: Int, Codable {
    case temperature = 1
    case windSpeed   = 2
    case dewPoint    = 3
    // ... assign a stable Int to every case

    var localizedLabel: String {
        switch self {
        case .temperature: String(localized: "field.temperature")
        case .windSpeed:   String(localized: "field.wind_speed")
        case .dewPoint:    String(localized: "field.dew_point")
        }
    }
}
```

The `Int` is what gets saved to `UserDefaults`. It never changes. The `localizedLabel` returns whatever the string catalog says for the current language. Adding a new language in the future requires no code changes to the enum.

**Enums to migrate:**
- `WeatherFieldType` (~27 cases)
- `HourlyFieldType` (~17 cases)
- `DailyFieldType` (~19 cases)
- `MarineFieldType` (~14 cases)
- `DetailCategory` (~10 cases)

**UserDefaults migration — the one tricky part:**

Existing users have their field selections saved as English strings (`"Wind Speed"`, `"Temperature"`, etc.). When the app updates and the enum switches to `Int` raw values, those saved strings will fail to decode.

A one-time migration must run at first launch after the update:

```swift
// Run once on first launch after update
func migrateSettingsIfNeeded() {
    guard !UserDefaults.standard.bool(forKey: "didMigrateEnumsToInt") else { return }

    // Read old string-keyed values, map to new Int-keyed equivalents, re-save
    // Mark migration complete
    UserDefaults.standard.set(true, forKey: "didMigrateEnumsToInt")
}
```

This migration needs to be written and tested before the update ships. It is the highest-risk piece of this entire plan — if it's wrong, users lose their saved field configurations. Test it thoroughly with a device that has real saved settings.

**After migration:** Every call site that used `.rawValue` for display switches to `.localizedLabel`. Every call site that used `.rawValue` for storage (encoding/decoding) switches to the `Int` value automatically via `Codable`.

---

## Step 3: Extract Hardcoded Strings from Views

With the enum work done, this is the largest remaining body of work — extracting ~350 hardcoded English strings from 19 view files into the string catalog.

**Simple `Text()` calls** — Xcode auto-extracts these when `SWIFT_EMIT_LOC_STRINGS` is on. Many view strings may require no source change, just adding them to the catalog and providing translations.

**Strings requiring manual `String(localized:)` wrapping:**

Any string that is constructed programmatically rather than written as a bare literal needs explicit wrapping:

```swift
// Interpolated strings
// Before:
Text("Wind: \(speed) mph")

// After — use a format specifier so translators can reorder words:
Text("wind_with_speed \(speed)", tableName: nil)
// Catalog entry: "wind_with_speed %@" → "Wind: %@ mph" (en) / "Vent : %@ km/h" (fr)
```

```swift
// Strings passed as arguments
// Before:
.accessibilityLabel("Location unit, currently \(settingsManager.settings.distanceUnit.rawValue)")

// After:
.accessibilityLabel(String(localized: "accessibility.distance_unit \(unit.localizedLabel)"))
```

**Files with the most hardcoded strings (tackle these first):**
- `SettingsView.swift` — section headers, picker labels, toggle labels
- `CitySearchView.swift` — search prompts, placeholder text, error messages
- `WeatherDetailView.swift` — field labels, category headers
- `MainWeatherView.swift` — primary weather display labels
- `WeatherAlertView.swift` — alert UI labels

---

## Step 4: Localize Info.plist Permission Strings

iOS shows these strings in the system permission dialogs before the user has even opened the app fully. If untranslated, users in other locales see English text at a critical trust moment.

**Strings to localize:**
- `NSLocationWhenInUseUsageDescription` — "Weather Fast uses your location to show weather for your current area."
- `NSLocationAlwaysUsageDescription` — similar
- `CFBundleDisplayName` — "Weather Fast" (may need adaptation in some markets)

**How:** Create an `InfoPlist.xcstrings` file (separate from `Localizable.xcstrings`) and add entries for each key. Xcode picks these up automatically at build time.

---

## Step 5: Fix Date, Time, and Unit Formatting

### Date and Time

`FormatHelper` in `SettingsManager.swift` hardcodes 12-hour AM/PM:

```swift
// Current — always 12-hour regardless of locale
formatter.dateFormat = "h:mm a"
```

Replace with locale-aware formatting:

```swift
formatter.locale = Locale.current
formatter.dateStyle = .none
formatter.timeStyle = .short   // automatically 12h or 24h per user's system setting
```

The date format `"MMMM d, yyyy"` in `HistoricalWeather.swift` should similarly use `DateFormatter.dateStyle = .long` so it produces "28 May 2026" in UK English, "28. Mai 2026" in German, etc.

### Unit Display Names

Unit symbol abbreviations (`"°F"`, `"mph"`, `"in"`, `"mi"`) are internationally understood and do not need translation. However, full display names shown in the settings pickers (`"Fahrenheit"`, `"Celsius"`, `"Miles per hour"`) do need to go through the string catalog.

The unit enums already default to the appropriate system based on `Locale.current.measurementSystem` — that behavior is correct and should be preserved.

### Cardinal Directions and Weather Categories

These are computed strings currently returned as hardcoded English:

- Wind directions: `"North"`, `"Northeast"`, `"SSW"`, etc.
- UV Index categories: `"Low"`, `"Moderate"`, `"High"`, `"Very High"`, `"Extreme"`
- Dew point comfort levels: `"Dry"`, `"Comfortable"`, `"Muggy/Uncomfortable"`, `"Oppressive"`

Each needs a `String(localized:)` call with a stable key. Abbreviated directions (`N`, `NE`, `S`) are universal and can remain as-is.

---

## Step 6: Replace Country Names Utility with Apple's Locale API

`Utilities/CountryNames.swift` is a large hardcoded dictionary mapping ISO country codes to English names. Apple's `Locale` API does this natively and in the user's language:

```swift
// Before — always English
CountryNames.name(for: "DE")  // → "Germany"

// After — respects current locale
Locale.current.localizedString(forRegionCode: "DE")  // → "Germany" / "Allemagne" / "Deutschland"
```

The reverse-lookup portion (mapping native-language city/country names back to an ISO code for API queries) is an internal operation the user never sees — that can stay in English.

---

## Step 7: UI Layout and Text Clipping

This is the most under-appreciated part of localization and a known risk given that the app already experienced screen clipping on different iPhone sizes in English. Some languages — German especially, but also Finnish, Dutch, and Russian — produce strings 30–50% longer than their English equivalents on average. A label that fits neatly in English can overflow or clip badly in another language.

**The additional challenge here:** Visual layout issues cannot be caught by VoiceOver or by building and running the app normally. They require someone to look at the screen. The strategy below is designed to catch as many problems as possible through code and automated tooling, minimizing the need for constant visual checks.

### Design defensively in SwiftUI (do this during Step 3)

As strings are extracted from views, simultaneously audit each label for layout assumptions that will break with longer text. Look for and fix:

```swift
// Fragile — fixed width will clip German strings
Text(field.localizedLabel)
    .frame(width: 120)

// Better — let it grow, truncate gracefully
Text(field.localizedLabel)
    .lineLimit(1)
    .minimumScaleFactor(0.8)   // shrinks font up to 20% before truncating

// Or allow wrapping where layout permits
Text(field.localizedLabel)
    .lineLimit(nil)
    .fixedSize(horizontal: false, vertical: true)
```

For weather field labels in lists and grids, prefer flexible layouts (`HStack` with `Spacer()`) over any hardcoded widths. This can be verified in code without visual inspection.

### Pseudo-localization testing (catch problems without real translations)

Xcode has a built-in pseudo-localization feature that replaces all localized strings with longer, accented versions — for example, "Wind Speed" becomes `[Ŵîñð Šþééð~~]`. The bracketing and extra characters simulate longer strings and make truncation immediately obvious.

To enable it: In Xcode, Edit Scheme → Run → Options → App Language → set to "Double-Length Pseudolanguage."

Running the simulator in this mode and taking screenshots is something AI can assist with directly — screenshots can be reviewed to spot clipping without requiring visual inspection on your part. This should be done after Step 3 (string extraction) and repeated after any significant UI change.

### Real-language visual sign-off

Pseudo-localization catches structural problems, but a real language needs a real visual check before shipping. Options:

- **Ask your translator to do a visual review.** Most professional translators or localization vendors will do a basic UI check as part of their work if you ask. Send them a TestFlight build.
- **Beta testers in the target language.** A native speaker who can look at the screen is the best possible test. Even one person is enough to catch obvious clipping.
- **AI-assisted simulator screenshots.** For languages you want to verify before finding a translator, I can help run the simulator with a specific locale and review screenshots for obvious layout issues.

The goal is to not ship a language to the App Store without at least one human looking at the actual screen. This is the one part of the process that genuinely cannot be automated away.

---

## Step 8: Add Language Support in Xcode

Once the string catalog is stable and fully populated with English values:

1. Open `FastWeather.xcodeproj`
2. Select the project in the navigator → Info tab
3. Under "Localizations," click `+` and add each target language
4. Xcode populates the catalog with untranslated entries for that language

Add languages only after the catalog is stable. Adding a language before all strings are extracted means the catalog will need re-exporting after each new string is added.

---

## Step 8: Update the Test Suite

All formatting tests currently assert hardcoded English output. Once formatting is locale-aware, tests must be pinned to an explicit locale so they don't behave differently on different machines:

```swift
// Before — depends on whatever locale the machine has
XCTAssertEqual(FormatHelper.formatTime("2026-05-28T06:50"), "6:50 AM")

// After — pinned to en_US, always predictable
let result = FormatHelper.formatTime("2026-05-28T06:50", locale: Locale(identifier: "en_US"))
XCTAssertEqual(result, "6:50 AM")
```

Add a second locale (e.g., `"de_DE"`) test pass to verify that locale-aware formatting actually changes output as expected.

**Test files to update:**
- `FormatHelperTests.swift` — 48 test cases
- `DateParserTests.swift`
- `HistoricalDateParsingTests.swift`
- `UnitConversionTests.swift`

---

## Step 9: Export for Translators

Once the catalog is complete and all English values are confirmed correct, Xcode can export `.xcloc` packages — one per language — via File → Export Localizations. This is the standard format for translation vendors and freelance translators. When translations come back, they are imported via File → Import Localizations and Xcode merges them into the catalog.

---

## Recommended Order of Work

The steps above are listed by topic, but the recommended execution order is:

1. **Step 1** — Create the string catalog first so there's somewhere to put strings as you go
2. **Step 2** — Migrate enums to `Int` raw values, including the `UserDefaults` migration; test thoroughly on a device with real saved settings before proceeding
3. **Step 5** — Fix date/time formatting (touches centralized code, easier to do before view extraction)
4. **Step 6** — Replace CountryNames utility
5. **Step 3** — Extract view strings; simultaneously audit each view for fixed-width layout assumptions (Step 7 defensive coding)
6. **Step 4** — Add InfoPlist.xcstrings
7. **Step 9** — Update tests
8. **Step 7 (pseudo-localization)** — Run simulator in Double-Length Pseudolanguage mode, review screenshots for clipping
9. **Step 8** — Add language support in Xcode
10. **Step 10** — Export for translators; request visual sign-off from translator or beta tester

---

## Scope Summary

| Task | Effort |
|---|---|
| Create string catalog | Trivial |
| Migrate 5 enums to `Int` raw values + `localizedLabel` | Medium |
| Write and test UserDefaults migration | Medium–Large (high risk, must be thorough) |
| Extract ~350 hardcoded strings from Views + layout audit | Large |
| Fix date/time formatting to be locale-aware | Small–Medium |
| Localize direction/category computed strings | Small |
| Replace CountryNames with Locale API | Small |
| Localize Info.plist permission strings | Small |
| Update test suite for locale-pinning | Medium |
| Pseudo-localization testing + screenshot review | Medium |
| Add language support in Xcode | Trivial |
| Export .xcloc for translators | Trivial |
| Sighted visual sign-off per language (requires human) | External |

---

## What This Plan Does Not Cover

- **Finding and paying translators.** Once the `.xcloc` export is ready, you will need translators for each target language. Translation vendors (Lokalise, Phrase, Crowdin) can manage this workflow end-to-end. Freelancers on Upwork or Gengo are a lower-cost option.
- **App Store listing translations.** The App Store description, keywords, and screenshots are localized separately through App Store Connect and are not part of the Xcode project.
- **Right-to-left language support (Arabic, Hebrew).** SwiftUI handles RTL layout automatically in most cases, but some custom layout code may need review if those languages are targeted.
- **Language-specific weather terminology.** Some weather terms (dew point comfort levels, UV index descriptions) don't have universally agreed translations and will need translator judgment.
