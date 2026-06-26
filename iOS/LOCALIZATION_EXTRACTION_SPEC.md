# Localization Extraction Spec — WeatherFast iOS (working doc)

Make all user-facing English strings localizable through the String Catalog, **without** changing
English behavior and **without** changing anything persisted to storage.

## Golden rules (do not violate)

1. **Never change an enum's `String` raw value.** Raw values are stable storage keys
   (UserDefaults/Codable/struct `id`s/dictionary keys/API params). To *display* an enum, the enums
   already have a `.localizedLabel` property — at display sites, replace `.rawValue` with
   `.localizedLabel`. Do **not** touch `.rawValue` used for storage, ids, keys, comparisons, or API.

2. **Unit SYMBOLS stay raw — do NOT localize:** `°F °C mph km/h m/s in mm hPa inHg mmHg mi km`.
   These are the unit enums' raw values (`temperatureUnit.rawValue`, `windSpeedUnit.rawValue`,
   `precipitationUnit.rawValue`, `pressureUnit.rawValue`, `distanceUnit.rawValue`). Leave every one
   of these `.rawValue` uses exactly as-is (project policy: internationally understood + screen-reader
   pronunciation). This is the ONE kind of `.rawValue` display you must NOT change.

3. **Do not touch date PARSING** (`en_US_POSIX` formatters in DateParser). Out of scope here.

4. Do **not** run `xcodebuild`, edit `.xcstrings`, edit the `.xcodeproj`, or touch files outside your
   assigned list. Do not reformat or refactor unrelated code. The lead does the integration build.

## How SwiftUI auto-localization works here

- A **string literal** passed to `Text(...)`, `Label(...)`, `Button("...")`, `Toggle("...", ...)`,
  `Section("...")`, `.navigationTitle("...")`, `.accessibilityLabel("...")`, `.accessibilityHint("...")`,
  `.accessibilityValue("...")`, `.alert("...", ...)` is automatically a `LocalizedStringKey` and is
  auto-extracted to the catalog. **LEAVE THESE LITERALS AS-IS — do not wrap them.**
  - This includes literals with interpolation: `Text("Wind: \(speed)")`,
    `.accessibilityLabel("Unit, currently \(x)")` — still auto-localized.
  - **EXCEPTION:** if such a literal interpolates an enum `.rawValue` **that we localized**
    (field `type.rawValue`, `category.rawValue`, `direction.rawValue`/`selectedDirection.rawValue`,
    `position.rawValue`, exploration `mode.rawValue`, `layout.rawValue`, sort-order `rawValue`),
    change that **interpolated** `.rawValue` → `.localizedLabel` so the inserted text is translated too.
    (But unit-symbol `.rawValue` stays raw — rule 2.)

- A **non-literal String** — a variable, a `func`/computed-property `return`, a `let x = "..."` that is
  later displayed — is **NOT** auto-localized. Wrap these explicitly (next section).

## Wrapping a non-literal string

```swift
// before
return "High Temperature"
// after
return String(localized: "field.high_temperature", defaultValue: "High Temperature",
              comment: "Short context for the translator")
```

- `defaultValue:` must be **byte-for-byte** the original English (same punctuation, casing, symbols).
- Key: lowercase, dot-namespaced, stable, descriptive — e.g. `uv.category.high`,
  `mydata.temperature2m.name`, `around_me.cities_to`.
- **Interpolated** non-literal strings: keep the interpolation in `defaultValue`, never in the key
  (the key must be a static literal). Placeholders (`%@`, `%lld`) are derived from `defaultValue`:
  ```swift
  alertTitle = String(localized: "around_me.cities_to",
                      defaultValue: "Cities to the \(direction.localizedLabel)",
                      comment: "Header for the list of cities in a compass direction")
  ```
- Use **shared keys** when the same English text appears for the same concept (the catalog de-dupes).
  Reuse existing keys already defined in `Settings.swift` / `BrowseModels.swift` /
  `DirectionalCityService.swift` where the concept matches (e.g. `field.*`, `direction.*`).

## Custom view components with `String` parameters

If a custom SwiftUI view stores `let title: String` (or `label`/`name`/`text`) and renders it via
`Text(title)`, then literals passed at call sites will NOT localize. **Check the call sites first:**
- If **all** call sites pass string literals (or already-localized values) → change the property type
  to `LocalizedStringKey`. All literal call sites then auto-localize, no further change.
- If any call site passes runtime data (a city name, a formatted value, an enum `.localizedLabel`
  result) → leave the property as `String`, and make sure the *source* of that string is localized.

## UV index / comfort categories (shared keys — use these exact keys)

`uv.category.low` "Low", `uv.category.moderate` "Moderate", `uv.category.high` "High",
`uv.category.very_high` "Very High", `uv.category.extreme` "Extreme".
High/Low temp short labels: `field.high_short` "High", `field.low_short` "Low".

When done, list every file you changed and a one-line summary of what kinds of changes you made.
