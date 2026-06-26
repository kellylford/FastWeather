# Localization in WeatherFast — Start Here (for someone new to it)

This explains, from zero, how localization actually works in iOS/Xcode and with translators.
If you've never localized an app before, read this first. The other docs are references:

- **This file** — the mental model and the click-by-click workflow.
- [`TRANSLATOR_GUIDE.md`](TRANSLATOR_GUIDE.md) — what you hand to translators and the exact commands.
- [`LOCALIZATION_EXTRACTION_SPEC.md`](LOCALIZATION_EXTRACTION_SPEC.md) — coding rules for adding new strings later.

---

## 1. The mental model

You already have the right intuition: localization is "show different text depending on the language."
Here's how iOS actually does it.

Every piece of user-facing text in the app is an **entry** in a central file called a **String Catalog**.
Each entry has:

- a **key** (an identifier),
- the **English source text**,
- a slot for **each language's translation**,
- a **comment** (a note telling the translator what the string means / where it appears).

At runtime, when the app is about to show a string, iOS looks at the **device's language setting**,
finds that string's entry, and uses the matching translation. **If there's no translation for the
current language, it falls back to the English source.** That fallback is why the app works perfectly
in English today even though no translations exist yet — and why it won't crash or show blanks when you
add a half-finished language later.

That's the whole idea. Everything below is just *how the text gets into that catalog* and *how
translations get back in*.

> One subtlety about "keys": in our code there are two styles, and both end up as catalog entries.
> - A plain SwiftUI literal like `Text("Settings")` — here the English text **is** the key.
> - An explicit key like `String(localized: "field.wind_speed", defaultValue: "Wind Speed")` — here
>   `field.wind_speed` is the key and "Wind Speed" is the English. We used explicit keys for anything
>   that isn't a simple on-screen literal (enum labels, programmatic sentences) so translators get a
>   stable identifier and a comment. You don't need to think about which is which day to day.

---

## 2. The pieces (where things physically live)

| Thing | What it is | Where |
|---|---|---|
| `Localizable.xcstrings` | The String Catalog — the table of every UI string and its translations | `iOS/FastWeather/Resources/` |
| `InfoPlist.xcstrings` | A second, small catalog for text that lives in `Info.plist` (the app name + the two location-permission prompts) | `iOS/FastWeather/Resources/` |
| `.xcloc` package | The hand-off bundle you give a translator — **one per language** | you generate these on demand |
| `.xliff` file | The actual translation file *inside* an `.xcloc`. XLIFF is the universal format every translation tool understands | inside each `.xcloc` |

A `.xcstrings` file is technically JSON, but **you never edit it by hand** — Xcode shows it as a
spreadsheet-like editor. Click `Localizable.xcstrings` in Xcode's left sidebar and you'll see a table:
strings down the side, a column per language, a status dot per cell (translated / new / needs review).

---

## 3. The lifecycle of one string (concrete example)

Follow the word "Wind Speed" from code to a German screen:

1. **In code** it's written once: `String(localized: "field.wind_speed", defaultValue: "Wind Speed", …)`.
2. **You build the app in Xcode.** Xcode scans the code and makes sure `field.wind_speed` exists in
   `Localizable.xcstrings` with English = "Wind Speed". (New strings get added automatically.)
3. **You export** (one menu command). Xcode writes a `de.xcloc` file containing "Wind Speed" with an
   empty German slot and the comment "Weather data field name."
4. **The translator** opens `de.xcloc`, types `Windgeschwindigkeit` into the German slot, sends it back.
5. **You import** that `de.xcloc` (one menu command). Xcode writes `Windgeschwindigkeit` into the
   catalog's German column.
6. **You build and run** on a device set to German → the app shows `Windgeschwindigkeit`. Set the device
   back to English → it shows "Wind Speed". No code changed in steps 3–6.

That round trip — **export → translate → import** — is the entire job. You'll repeat it whenever you
add strings or languages.

---

## 4. What *you* (the developer) actually do in Xcode

All of these are normal menu commands — no scripting required (though there are command-line equivalents
in `TRANSLATOR_GUIDE.md` if you prefer).

**See/edit the catalog:** Click `Localizable.xcstrings` in the file navigator. You can read every
string, see translation progress, and even type translations yourself if you ever want to.

**Add a language:** Click the blue project icon at the top of the navigator → select the **project**
(not a target) → **Info** tab → **Localizations** section → click **+** → choose the language.
*(Italian, Spanish, and German are already added.)*

**Send work to a translator (Export):** **Product** menu → **Export Localizations…** → choose a folder →
Xcode writes one `.xcloc` folder per language. Zip and send them.

**Bring translations back (Import):** **Product** menu → **Import Localizations…** → pick the `.xcloc`
the translator returned. Repeat per language. Commit the updated `.xcstrings` files.

**Preview a language yourself (no translator needed):** **Product** → **Scheme** → **Edit Scheme** →
**Run** → **Options** tab → **App Language** → pick a language (or a *pseudolanguage*, see §6).
Run the app and it launches in that language. This changes only your test runs, not the real app.

That's it. Five menu commands cover the entire developer side.

---

## 5. What the *translator* does (so you know what you're asking for)

You send them an `.xcloc` per language. They open it in either:

- **Xcode** (free) — double-clicking an `.xcloc` opens a side-by-side source→target editor with the
  comments visible, or
- **a professional translation tool** (Lokalise, Phrase, Crowdin, Trados, Poedit, …) — these import the
  `.xliff` inside the package and give the translator translation memory, glossaries, and QA checks.
  This is what a vendor or freelancer will normally use.

They fill in every target slot and send the `.xcloc`/`.xliff` back. The rules they must follow (don't
break `%@`/`%lld` placeholders, keep them but reorder for grammar, don't translate unit symbols or place
names, mind length) are spelled out in `TRANSLATOR_GUIDE.md` — send that file along with the packages.

---

## 6. Testing it before you have translations

You don't need a translator to find layout problems. Two tools:

- **Pseudolanguages.** In Edit Scheme → App Language, pick **"Double-Length Pseudolanguage."** The app
  runs with every string artificially lengthened and bracketed, e.g. `[Ŵîñð Šþééð~~]`. Anything that
  clips or overflows jumps out immediately. This is the cheapest way to catch the German-is-longer
  problem — German averages 30–50% longer than English. Run it, screenshot the main screens, look for
  cut-off text.
- **Run in a real language.** Set App Language to Italian/Spanish/German. Even with no translations yet,
  you'll see localized **dates, times, and numbers** (and any strings already translated). Useful to
  confirm the formatting work is correct.

The one thing that genuinely can't be automated: a human eyeballing each shipping language's screens
once for clipping. Even one native speaker with a TestFlight build is enough.

---

## 7. About German and right-to-left (RTL) languages

**German** is handled the normal way — it's just longer, so the risk is *visual clipping*, caught with
the pseudolanguage test in §6 and a real-language screen review. No special code.

**RTL (Arabic, Hebrew)** is **not in scope yet** — Italian, Spanish, and German all read left-to-right.
When/if you add an RTL language later: because this app is built in standard SwiftUI (which lays out by
"leading/trailing" rather than "left/right"), iOS **mirrors the entire interface automatically** —
text aligns right, navigation flips, etc. So RTL is mostly free here. The only work would be reviewing
any custom layout that hardcodes left/right and giving the screens a visual pass. Nothing to do now;
just know it's a small, contained effort rather than a rewrite.

---

## 8. Glossary

- **Localization (l10n)** — translating/adapting the app for a specific language/region.
- **Internationalization (i18n)** — the engineering that *makes* an app localizable (what was just done).
- **Locale** — a language+region setting, e.g. `it` (Italian), `de_DE` (German/Germany), `en_US`. Decides
  not just words but date order, 12h vs 24h time, decimal separators, etc.
- **String Catalog (`.xcstrings`)** — the modern Xcode file holding all strings + translations.
- **`.xcloc`** — the per-language package you exchange with translators.
- **XLIFF (`.xliff`)** — the standard translation file format inside an `.xcloc`; every translation tool reads it.
- **Key** — the identifier for a string in the catalog.
- **Placeholder** — `%@`, `%lld`, `%1$@` etc.: a slot where a runtime value (name, number) is inserted.
- **Pseudolanguage** — a fake language Xcode generates to stress-test layout without real translations.
- **Fallback** — when a translation is missing, iOS shows the English source instead.

---

## 9. FAQ

**Do I have to do anything special to build the English app now?** No. Build and run exactly as before;
English is the fallback for every string. Nothing in the daily workflow changes.

**If I switch the scheme to Italian today, why is most text still English?** Because translations aren't
in yet — you'll see English (the fallback) plus localized dates/numbers. That's expected. It becomes
Italian once you import a translated `.xcloc`.

**Where do new strings go when I add a feature later?** Mostly automatically: a SwiftUI `Text("…")`
literal is picked up on the next build/export. For non-UI strings, wrap them with `String(localized:)` —
see `LOCALIZATION_EXTRACTION_SPEC.md`. Then re-export.

**Can I translate a little at a time?** Yes. Untranslated strings fall back to English, so you can ship a
partially translated language. Suggested order is in `TRANSLATOR_GUIDE.md` (permission prompts first,
the long User Guide last).

**Is the App Store listing (description, screenshots) localized by this?** No — that's separate, done in
App Store Connect, not in the Xcode project.
