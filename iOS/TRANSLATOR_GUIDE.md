# WeatherFast iOS — Translator Guide

This document tells a professional translator (or localization vendor) exactly how to translate
WeatherFast, and tells **you** (the developer) how to hand work off and merge it back.

The app's code is fully internationalized: every user-facing string is in Xcode **String Catalogs**
(`.xcstrings`). Translators never touch source code. They work in the industry-standard **XLIFF**
format, which Xcode exports and re-imports.

First three target languages: **Italian (it)** — highest priority, there is a specific request —
plus **Spanish (es)** and **German (de)**.

> ## ⚠️ A machine-translated draft already exists — REVIEW it, don't retranslate from scratch
>
> All 1,536 strings in **it / es / de** have already been filled in with a **machine-generated draft**
> and are marked **"Needs Review"** in the catalog (the yellow flag in Xcode; `state="needs-review"` in
> the XLIFF). When you open a `.xcloc`, the target column is **pre-filled**.
>
> **Your job is to review and correct, not to translate from a blank slate.** Read each draft, fix what's
> wrong or stiff, and once you're satisfied mark it reviewed/approved (in Xcode, the status changes to a
> green "Reviewed"/translated checkmark). Pay closest attention to: weather terminology, the long
> **User Guide** prose, and the scientific **"My Data"** explanations — that's where machine output is
> most likely to need fixing. Short UI labels are usually fine but still worth a glance.
>
> The draft was produced by an AI, not a human translator, so treat it as a strong first pass only. **Do
> not ship any language to the App Store until a native speaker has reviewed it** (see §6).

---

## 1. What the developer sends the translator

You send **one `.xcloc` package per language** (a folder, zip it). Generate them from the project root
(`iOS/`):

```bash
xcodebuild -exportLocalizations \
  -project FastWeather.xcodeproj \
  -localizationPath ./loc-export \
  -exportLanguage it -exportLanguage es -exportLanguage de
```

This produces `loc-export/it.xcloc`, `loc-export/es.xcloc`, `loc-export/de.xcloc`. Zip each and send.

> You can also do this in Xcode: **Product → Export Localizations…** — pick the languages, choose a
> folder. Same result, with a GUI.

Each `.xcloc` contains, under `Localized Contents/<lang>.xliff`, every translatable string with:
- the **source** English text,
- an empty **target** for the translator to fill,
- a **note** (the developer comment) giving context for that string.

There are roughly **1,500 strings**. See §5 for prioritization — you do not have to do all of them
at once, and the User Guide alone is about a third of the volume.

---

## 2. What the translator does

The translator opens the `.xcloc` in whichever tool they prefer:

- **Xcode** (free, Mac) — double-click the `.xcloc`; it opens an editor showing source → target side by
  side, grouped by file, with the developer notes visible. Type translations in the target column.
- **A CAT tool / TMS** — Lokalise, Phrase, Crowdin, memoQ, Trados, Poedit, etc. all import the
  `<lang>.xliff` inside the package directly. This is the normal path for a vendor; it gives them
  translation memory, glossaries, and QA checks.

They translate every `target`, then send back the **same `.xcloc`** (or the edited `.xliff`).

### Rules the translator must follow (include this list when you send the files)

1. **Never alter placeholders.** Tokens like `%@`, `%lld`, `%1$@`, `%2$@`, `%.0f` are runtime values
   (a temperature, a city name, a count). Keep them exactly, but **move them** to wherever the target
   language's grammar needs them. Example (German reorders):
   - Source: `Moved %1$@ above %2$@`
   - German: `%1$@ über %2$@ verschoben`
2. **Keep numbered placeholders in sync.** If the source has `%1$@` and `%2$@`, the translation must use
   both, with the same numbers (the number identifies *which* value goes there, regardless of order).
3. **Do not translate unit symbols** if any slip through: `°F`, `°C`, `mph`, `km/h`, `m/s`, `mm`, `in`,
   `hPa`, `mi`, `km`. These are international. (Most are not in the catalog at all, by design.)
4. **Do not translate place names.** City, state, and country *data* is not in the catalog. Country
   names shown in the UI are localized automatically by iOS — translators never see them.
5. **Read the note.** Many short strings ("High", "Low", "Showers") are weather-domain terms; the note
   says where each appears and what it means. Translate for the weather context.
6. **Mind length.** This is a VoiceOver-first, layout-sensitive app. Prefer concise translations,
   especially for button titles, settings rows, and table column headers. German in particular runs
   long — if a natural translation is very long, flag it rather than guessing.
7. **Markdown is meaningful.** Some User Guide strings contain `**bold**` markers — keep them around the
   equivalent words.
8. **Plurals:** see §4.

---

## 3. What the developer does when translations come back

From `iOS/`:

```bash
xcodebuild -importLocalizations \
  -project FastWeather.xcodeproj \
  -localizationPath ./loc-import/it.xcloc
```

(or **Product → Import Localizations…** in Xcode, once per file). Xcode merges the targets into
`Localizable.xcstrings` / `InfoPlist.xcstrings`. Commit the updated `.xcstrings` files.

Then build and run in the target language to sanity-check (see §6).

---

## 4. Plurals (important)

A few strings vary with a number — e.g. `hour` vs `hours`, `1 minute ago` vs `5 minutes ago`. English
only has two forms; some languages have more (and Italian/Spanish/German use one/other like English).

For these, the **String Catalog supports per-plural variations**. In Xcode's catalog editor, right-click
the string → **Vary by Plural**, and the translator fills the `one` / `other` (and any `few`/`many`)
forms their language needs. The relevant keys are namespaced `time.*` and the "… ago" strings under
`radar.*` / `historical.*` / `date.*`. If you're sending raw XLIFF to a vendor, tell them which strings
are countable so they can request the plural treatment.

This is the one area that benefits from a quick conversation with the translator rather than a
fire-and-forget handoff.

---

## 5. Scope & suggested priority

Translate in this order so the app is usable in a new language as early as possible:

1. **InfoPlist.xcstrings** (3 strings) — the App Store name and the two location-permission prompts.
   These are the very first text a user sees. Tiny, high-impact.
2. **Core UI** — Settings, city list, city detail, search, alerts. The `field.*`, `category.*`,
   `setting.*`, `sort.*`, `direction.*`, `alert.*`, `around_me.*`, `announce.*` keys. This is the app's
   day-to-day surface.
3. **My Data** (`mydata.*`) — ~180 strings (parameter names + scientific explanations). Only matters if
   the user opens the optional "My Data" feature. Can be deferred.
4. **User Guide** (the long prose in the Help screen) — about a third of all words. High value but
   self-contained; ship it last or in its own pass.

`extractionState` in the catalog and the "stale"/"needs review" flags in Xcode track what's done.

---

## 6. Visual / layout sign-off (cannot be skipped, cannot be fully automated)

Translating the strings is necessary but not sufficient — someone has to **look at the screen** in each
language to catch truncation and clipping (this app has hit layout clipping before, and German/Finnish
strings run 30–50% longer than English).

Before testing real translations, you can stress-test layout for free with **pseudo-localization**:

- Xcode → **Edit Scheme → Run → Options → App Language → "Double-Length Pseudolanguage"** (or
  "Accented Pseudolanguage"). Run in the simulator. Strings become e.g. `[Ŵîñð Šþééð~~]`, making
  overflow obvious. Screenshot the main screens and review.

For real languages, run the simulator in that language (Edit Scheme → App Language → Italian/Spanish/
German) and walk the key screens, or hand a TestFlight build to a native speaker. The goal: at least one
human looks at the actual screens before that language ships to the App Store.

---

## 7. Adding a fourth language later

1. Open the project → select the **project** → **Info** tab → **Localizations** → **+** → pick the
   language. (Italian, Spanish, German are already added.)
2. Re-run the export command in §1 with `-exportLanguage <new>`.
3. Send, translate, import (§2–§3).

No source-code changes are ever required to add a language.

---

## 8. For maintainers: keeping it clean going forward

- New user-facing text in **SwiftUI** can usually just be a literal — `Text("…")`, `Button("…")`,
  `.navigationTitle("…")`, `.accessibilityLabel("…")` auto-extract to the catalog.
- New text in **plain `String`** (a `var`, a `func` return, a `switch`) must be wrapped:
  `String(localized: "dot.key", defaultValue: "English", comment: "context")`.
- **Never display an enum's `rawValue`.** Raw values are storage keys. Add/extend a `localizedLabel`
  (see `Settings.swift`, `BrowseModels.swift`, `DirectionalCityService.swift`, `WeatherAlert.swift`).
- After adding strings, re-run **Export Localizations** to refresh the catalogs and the translator
  packages.

The working spec used during the initial localization pass is in
[`LOCALIZATION_EXTRACTION_SPEC.md`](LOCALIZATION_EXTRACTION_SPEC.md).
