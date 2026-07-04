# Nowcast Port — Testing Guide

**Branch:** `nowcast-port` (based on main after the 1.5.8 WeatherKit conditions work)
**Date:** 2026-07-03
**Build status:** Builds clean (Xcode 27 beta, iPhone 17 / iOS 27.0 simulator). Full XCTest suite passes: 120 tests, 0 failures, including 12 new `NextHourSummaryTests`.

## What this branch adds

Four features from the old `docs/nowcasting-proposal` branch, re-ported on top of main. The radar map and all AI radar-description work were deliberately **not** brought over. Every feature is behind a flag in **Settings → Developer Settings → Nowcasting**, all **on by default** on this branch:

| Toggle | Flag | What it does |
|---|---|---|
| Next Hour Narration | `nextHourNarrationEnabled` | One-sentence precipitation timing summary at the top of the precipitation screen |
| Storm Approach | `stormApproachEnabled` | Directional precipitation card at the top of Weather Around Me |
| Storm Motion Accuracy | `weatherAroundMeImprovementsEnabled` | Steering-wind motion, confidence hedging, denser sampling, rain/snow per town |
| Next Hour Layout | `nowcastRefinementsEnabled` | Renames Expected Precipitation to "Next Hour", hides its wind-inferred block, adds a tappable one-liner to City Detail |

With all four toggles off, the app behaves exactly like main.

## How Apple and Open-Meteo data are divided (the "don't look silly" rules)

- **WeatherKit answers "what is happening at this spot, now and next"**: current/forecast conditions (from main), and the minute-by-minute timing that feeds the Next Hour narration. Timing statements ("starting in about 11 minutes") come from your own location's WeatherKit nowcast — the most trustworthy number we have.
- **Open-Meteo answers "what does the field around me look like"**: Storm Approach's ring sampling (up to ~60 coordinates in one paid-tier request) and the mid-level steering winds. WeatherKit cannot do this without ~60 separately billed calls.
- **Three guardrails against contradicting ourselves:**
  1. The dry-convection note ("thunderstorm in the area") now keys off the condition the app is *displaying* (post-WeatherKit-overlay), not the raw Open-Meteo model code. If the main screen doesn't say thunderstorm, Storm Approach won't claim one. When the displayed condition isn't available to it, the note is suppressed rather than guessed.
  2. Storm Approach's per-town rain/snow labels only appear where measurable precipitation exists in the data (≥0.1 mm per 15 min) — it never labels a dry town.
  3. With Storm Motion Accuracy on, direction wording hedges by confidence: steering wind and centroid drift agreeing → plain statement; disagreeing or sparse → "generally from the southwest", "track is unclear". It never states a crisp vector the data can't support.
- **API cost:** Storm Approach adds one Open-Meteo multi-coordinate call per Weather Around Me open (paid tier, trivial). The nowcast fetch is now cached for 3 minutes, so the new inline card + the full screen + repeated opens share one WeatherKit call instead of billing each time.

## Test plan

Setup: build and run on device or simulator. All four toggles should already be on (first launch of this build sets them). If you've run this branch before and toggled things, check Settings → Developer Settings → Nowcasting.

### 1. Next Hour narration (precipitation screen)

1. Open a saved city's detail screen → Actions → **Next Hour** (renamed from Expected Precipitation; the rename itself confirms the Next Hour Layout flag is on).
2. **Expect:** the first card is "Next Hour" with one plain sentence, e.g. "No precipitation expected in the next hour." or "Precipitation starting in about 25 minutes, lasting about 30 minutes."
3. **VoiceOver:** the Next Hour card should be the first content element read after the updated-timestamp line, as a single utterance.
4. **Consistency check:** the sentence must agree with the timeline list below it (if the sentence says rain in ~25 minutes, the timeline should show rain in that window).
5. For a rainy test case, use a city where it's currently raining (check a national map or pick somewhere notoriously wet today). Expect "Precipitation now, easing off in about N minutes" or "…continuing through the next hour."
6. **International check:** open a non-WeatherKit-coverage city (e.g. Tokyo, Paris). The narration should still appear (Open-Meteo 15-minute data, looking 2 hours out) or be absent — never wrong. Phrasing there says "in the next 2 hours."

### 2. Inline Next Hour card (city detail)

1. Open any saved city's detail screen (today, not a forecast day).
2. **Expect:** below the current-conditions block, a tappable "Next Hour" card with the same one-sentence summary. Tapping it opens the full Next Hour screen.
3. **VoiceOver:** the card reads as one element: "Next Hour. <sentence>", with hint "Opens precipitation timing details."
4. **Consistency check:** the inline sentence and the full screen's sentence must match (they share a 3-minute cache).
5. Navigate to a previous/next day (Glance Ahead / date navigation): the card must **not** appear on non-today screens.
6. Turn off **Next Hour Layout** in Developer Settings: the card disappears, and the Actions menu item reads "Expected Precipitation" again.

### 3. Storm Approach (Weather Around Me)

1. From the city list, press-and-hold a city (or use the VoiceOver custom action) → **Weather Around Me**. Or from city detail → Actions → Weather Around Me.
2. **Expect:** the first card after the distance picker is **Storm Approach** with a headline like:
   - "No precipitation within about 45 miles, and none expected here in the next 2 hours." (clear day), or
   - "Rain about 20 miles to the southwest, moving northeast at about 25 mph, reaching you in about 30 minutes." (active weather)
3. Under the headline, when weather is active: "Nearby towns:" lines ("Rain over Middleton, 8 mi west") and "Your saved cities:" lines ("Rain reaching Milwaukee in about 40 minutes").
4. **VoiceOver:** the whole card reads as one element — headline, then towns, then cities.
5. **The big consistency check (this is the one that used to look silly):**
   - The Storm Approach headline must not contradict the current-conditions label shown for the same city on the main list. In particular, if the main screen says "Thunderstorm", Storm Approach may say "thunderstorm in the area" with no measurable rain — but if the main screen says "Partly Cloudy", Storm Approach must NOT mention a thunderstorm.
   - The directional tiles below (Surrounding Areas) show WeatherKit-informed conditions; Storm Approach talks about precipitation amounts. They can differ in wording ("Cloudy" tile while Storm Approach reports light rain 20 miles out is fine — different questions) but must not flatly contradict ("Heavy rain over Springfield" while Springfield's own tile says "Clear").
6. **Active-weather test:** pick a day/city with a front moving through (or browse to a city that has one — add it temporarily). Verify the reported direction roughly matches reality (compare with any radar source out of band).
7. Turn off **Storm Approach**: the card disappears; Weather Around Me reverts to exactly the old temperature/condition comparison.

### 4. Storm Motion Accuracy (hedging and typing)

1. With Storm Approach on, toggle **Storm Motion Accuracy** off, then refresh Weather Around Me: motion (if any) comes from centroid tracking alone and the wording never hedges. Toggle it back on and refresh: with active weather, the wording may hedge ("generally from the west", "roughly 20 to 30 minutes") when the data is ambiguous.
2. In winter or for a northern city, verify towns get typed correctly: "Snow over…" vs "Rain over…".
3. There is no visible confidence number — the hedging *is* the confidence display. Crisp wording = high confidence. That's deliberate.

### 5. Flag matrix (regression safety)

1. Developer Settings → **Disable All Features**, restart the app: the app must look and behave exactly like main with everything off (no Next Hour card, no Storm Approach, "Expected Precipitation" naming, WAM as before).
2. **Reset to Defaults**: all four nowcast features return, plus the standard defaults.
3. Toggle each of the four flags individually and verify only its own surface changes.

### 6. API sanity (Xcode console, optional)

Filter the console for `RadarService` / `StormApproach` debug lines:
- Opening a city detail then immediately opening the full Next Hour screen should log **one** nowcast fetch, not two (cache hit).
- One Weather Around Me open should log a single multi-coordinate Open-Meteo request for Storm Approach (plus the usual regional fetches).

## Known limits / by design

- Storm Approach arrival times come from each point's own 15-minute forecast; sub-15-minute precision is neither claimed nor displayed.
- The narration and Storm Approach may disagree slightly on onset time (1-minute WeatherKit vs 15-minute Open-Meteo grids). Both say "about" — small deltas are expected; flag anything over ~15 minutes apart.
- The steering-wind fetch uses paid-tier pressure-level variables; if that call fails, motion falls back to centroid with hedged wording (never an error).
- Sonification (Part D of the proposal) remains deliberately unbuilt.
- The `RadarService.buildNextHourSummary` phrasing is locked by 12 unit tests (`FastWeatherTests/NextHourSummaryTests.swift`) — change phrasing there first, then the code.

## What was intentionally NOT ported

Radar map (MapKit/NEXRAD tiles), the "Open Radar Map" entry points on ListView/FlatView, all Foundation Models / AI radar description services, cross-validation, and the quickradar Python lab. If any of those ever come back, they start from a fresh design discussion, not from the old branch.
