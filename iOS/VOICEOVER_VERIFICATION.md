# VoiceOver Verification Guide

> **RESOLVED 2026-06-30 (user-tested).** Outcome: **VO-4 fixed** (sort selected-state now announced). **VO-6** confirmed *deliberate* (no per-keystroke announcement — results are swipe-discoverable). **VO-1, VO-2, VO-3, VO-5, VO-8** all confirmed working as intended / deliberate. **VO-7** (Dynamic Type) split out to issue #76 for deeper review. VoiceOver is considered good to go for now. Details below kept for reference.

**Purpose:** The code review flagged a set of accessibility concerns by *static analysis*. As the radar timeline showed, static analysis can misread deliberate design. **No VoiceOver/accessibility code has been changed.** This guide gives you the exact path to reach each flagged spot with VoiceOver so you can decide, per item, whether it's a real problem or working as intended.

For each item, mark a verdict at the bottom:
- ✅ **Working as intended** — leave it; I'll record it as withdrawn.
- 🔧 **Real problem, fix it** — I'll implement the fix on the `code-review-fixes` branch.
- 🤔 **Needs discussion** — we'll talk it through.

Turn VoiceOver on (triple-click side button, or Settings → Accessibility → VoiceOver). Swipe right/left to move between elements; double-tap to activate.

---

## VO-1 — Settings: weather-field rows announced as "button", not "switch" *(review: CR-4)*

**Where:**
1. **Settings** tab.
2. Scroll to the **"City List View"** section.
3. Swipe through the weather-field rows (Temperature, Wind, Humidity, etc.) — each has a toggle and a reorder grip.

**What to check:** Focus one of these rows. Does VoiceOver announce it as a **switch** with an on/off **state** ("Temperature, switch, on")? Or does it say **"button"** and put the state only in the spoken hint ("…enabled, double tap to disable")?

**Why it's flagged:** The row wraps a native `Toggle` but applies `.accessibilityElement(children: .combine)` + `.accessibilityAddTraits(.isButton)` ([SettingsView.swift:341–342](FastWeather/Views/SettingsView.swift:341)), which collapses the switch into a button and drops the native on/off value. Users who turn hints off wouldn't hear the state. `DeveloperSettingsView` uses a plain `Toggle` (the "correct" pattern) for contrast.

**Might be intentional?** Possibly — the row also exposes **"Move Up"/"Move Down"** VoiceOver actions for reordering, and combining may have been done so those actions attach cleanly. The proposed fix keeps the reorder actions but restores native switch semantics. **You'll know in 2 seconds of swiping whether the state is announced.**

**Your verdict:** ☐ Working as intended ☐ Fix it ☐ Discuss

---

## VO-2 — Day Detail: each section read as one combined blob *(review: H1 / `.combine`)*

**Where:**
1. **My Cities** → tap a **city**.
2. In City Detail, find the **16-Day Forecast**, and **tap a day** (e.g. tomorrow) to open **Day Detail**.
3. Swipe through the **"Wind & UV"**, precipitation, and astronomy sections.

**What to check:** When you focus a section like "Wind & UV", does VoiceOver read the **whole section as a single element** ("Wind & UV, Max Wind, 12 mph NW, Max UV Index, 5, Moderate")? Or can you swipe to each row individually? Is the combined reading helpful (a quick summary) or too much in one breath / hard to navigate?

**Why it's flagged:** These GroupBoxes use `.accessibilityElement(children: .combine)` ([DayDetailView.swift:347, 389](FastWeather/Views/DayDetailView.swift:347) and the astronomy section), merging all rows. The project rule prefers `.ignore` + an explicit label, or `.contain` to keep rows individually navigable.

**Might be intentional?** Very possibly — combining gives a one-swipe summary per section, which some VoiceOver users prefer over swiping every row. This is a genuine UX judgment call, which is why I'm asking rather than changing it.

**Your verdict:** ☐ Working as intended ☐ Fix it ☐ Discuss

---

## VO-3 — Buttons missing spoken hints *(review: H2)*

**Where (several spots):**
- **My Cities** → the date controls: **Previous day / Next day / Go to today** buttons.
- **My Cities** → tap a city → the big **"Actions"** button and the **"Add to My Cities"** button.
- **Browse Cities** → drill into a state/country → the **"Sort"** button (toolbar).
- **Add City** search → **Cancel** and the search-result rows.

**What to check:** Focus each button. After the label and "button", does VoiceOver speak a **hint** ("…goes to the previous day")? The project rule says all buttons should have an `.accessibilityHint()`.

**Why it's flagged:** These buttons have labels but no `.accessibilityHint()` (e.g. [MyCitiesView.swift:212, 239, 249](FastWeather/Views/MyCitiesView.swift:212)).

**Might be intentional?** Partly — for buttons whose label is already unambiguous ("Cancel", "Go to today"), a hint can be redundant noise, and some designers deliberately omit it. You decide which actually need a hint vs. which are self-evident. Tell me which ones bug you and I'll add hints only to those.

**Your verdict:** ☐ All fine as-is ☐ Add hints to all ☐ Add to specific ones (note which) ☐ Discuss

---

## VO-4 — Sort menu: selected option not announced as "selected" *(review: H3)*

**Where:**
1. **Browse Cities** → drill into a state or country list.
2. Activate the **"Sort"** button → the sort menu opens.
3. Swipe through the options (Name A–Z, Temperature High–Low, etc.).

**What to check:** On the option that is **currently active**, does VoiceOver say **"selected"**? Or does it read the option name with no indication of which one is chosen? (The currently-selected one shows a checkmark icon visually.)

**Why it's flagged:** The selected option is conveyed only by swapping the icon to a checkmark ([StateCitiesView.swift:163](FastWeather/Views/StateCitiesView.swift:163)); there's no `.isSelected` trait or ", selected" in the label. The menu's *outer* button does say the current sort ([:170](FastWeather/Views/StateCitiesView.swift:170)), so the info exists — just not on the individual rows.

**Might be intentional?** Less likely — this looks like a genuine gap, but the outer-button announcement partly mitigates it. Confirm whether you can tell which option is active while inside the menu.

**Your verdict:** ☐ Working as intended ☐ Fix it ☐ Discuss

---

## VO-5 — "Weather in surrounding areas" group label may be dropped *(review: M1)*

**Where:**
1. **My Cities** → tap a city → **Actions** → **Weather Around Me**.
2. Swipe to the grouped surrounding-areas region.

**What to check:** Is the group introduced/labeled as **"Weather in surrounding areas"** by VoiceOver, or does that label never get spoken (you just land directly on the first direction tile)?

**Why it's flagged:** A `.accessibilityLabel` is set on a container that uses `.accessibilityElement(children: .contain)` ([WeatherAroundMeView.swift:264–265](FastWeather/Views/WeatherAroundMeView.swift:264)). A label on a `.contain` element is generally ignored by VoiceOver, so the heading may simply not be announced.

**Might be intentional?** No — if the label isn't read, it's just dead code; if you never expected a spoken group heading there, then nothing's lost. Tell me whether you hear "Weather in surrounding areas".

**Your verdict:** ☐ Heading is read (fine) ☐ Heading missing, add it properly ☐ Don't need a heading ☐ Discuss

---

## VO-6 — Search results / errors arrive silently *(review: M2)*

**Where:**
1. **My Cities** → **Add City** (the add/search flow).
2. Type a city name and **stop typing** (results load after ~0.5s).

**What to check:** When results appear (or "No cities found" / an error appears), does VoiceOver **announce** anything ("5 results found")? Or does focus stay silently in the text field with no signal that results are ready?

**Why it's flagged:** `performSearch` populates results/errors with no `UIAccessibility.post(.announcement, …)` ([AddCitySearchView.swift:219–243](FastWeather/Views/AddCitySearchView.swift:219)), so a VoiceOver user may not realize results arrived.

**Might be intentional?** Unlikely intentional, but worth confirming your real workflow — if you naturally swipe down to the results after typing, you'll find them; an announcement is a convenience. Your call on whether it's worth adding.

**Your verdict:** ☐ Fine as-is ☐ Add announcement ☐ Discuss

---

## VO-7 — Large temperature text doesn't scale with Dynamic Type *(review: M3)*

**Note:** This affects **low-vision sighted** users (large text sizes), **not** VoiceOver speech. You may want a sighted helper, or skip this one.

**Where:** City Detail (big current temperature), Weather Around Me (48pt temps), Day Detail (44pt), Historical (32pt), Browse city detail (72pt).

**What to check:** With **Settings → Accessibility → Display & Text Size → Larger Text** cranked up, do these big temperatures grow? Or stay fixed?

**Why it's flagged:** They use hardcoded `.font(.system(size:))` ([CityDetailView.swift:664](FastWeather/Views/CityDetailView.swift:664) etc.), which ignores Dynamic Type. (The decorative *icons* at the same sizes are correctly hidden from VoiceOver.)

**Might be intentional?** Often a deliberate layout choice (giant hero number). Fix would use scalable relative fonts. Low priority unless you care about large-text users.

**Your verdict:** ☐ Fine as-is ☐ Make scalable ☐ Discuss

---

## VO-8 — Smaller catch-all items (quick checks)

These are low-severity; check only if convenient:

- **VO-8a — Hit targets** *(L1)*: the **+ / –** stepper buttons in **My Data Config** (Settings → My Data configuration) and the small **alert badge** icons on city rows — are they easy to land on / activate, or fiddly? Concern: they may be smaller than the 44×44pt minimum.
- **VO-8b — Historical "tap" rows** *(L3)*: in **Historical Weather**, tappable rows use a tap gesture + manual button trait rather than a real button. Do they behave like proper buttons under VoiceOver (and Full Keyboard Access)?
- **VO-8c — Alert sheet focus** *(L4)*: when a **weather alert** detail sheet opens, where does VoiceOver focus land — on the alert headline, or on the nav bar? Concern: it may not jump to the alert title.

**Your verdict:** ☐ All fine ☐ Issues (note which) ☐ Discuss

---

## Summary table (fill in and send back)

| ID | Area | Verdict |
|----|------|---------|
| VO-1 | Settings field toggles = button not switch | |
| VO-2 | Day Detail sections combined | |
| VO-3 | Buttons missing hints | |
| VO-4 | Sort menu selected state | |
| VO-5 | "Surrounding areas" group label | |
| VO-6 | Search results announced | |
| VO-7 | Large temp Dynamic Type (sighted) | |
| VO-8 | Hit targets / tap rows / sheet focus | |

Send this back however's easiest and I'll implement only the ones you mark "Fix it."
