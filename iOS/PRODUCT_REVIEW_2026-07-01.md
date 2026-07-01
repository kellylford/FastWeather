# WeatherFast — Engineering & Product Review (2026-07-01)

A leadership-lens review commissioned as a pre-merge gate: is this *good weather software*, not just accessible software? Conducted by an agent playing "head of engineering for an accessibility + weather company." Findings were independently spot-checked against the source (trust-but-verify) before recording here.

## Status of findings (updated 2026-07-01)

**Fixed on branch `code-review-fixes`:**
- ✅ **#1 Alert honesty** — NWS/WeatherKit alert fetch failures now throw and the UI shows a distinct **"Couldn't check for alerts / Try Again"** state instead of a misleading "No active alerts". (WeatherKit 400 = genuine region-unsupported still shows no-alerts.)
- ✅ **#3 Fabricated future "current" data** — for future/past days the hero now shows the real forecast **High/Low** (not the min/max *average* mislabeled "Current temperature"), the averaged "Feels like" is omitted, and the fabricated **"Cloud Cover 0%"** row is suppressed.
- ✅ **#5 Moon timezone** — moon rise/set now render in the city's timezone, matching sunrise/sunset (were device-local → wrong for remote cities).

**Filed as issues (deferred, not fixed here):**
- ⏸️ **#2 Background severe-weather alerting** — no push/BGTask; alerts only load when a city is opened. Needs an external service (under investigation).
- ⏸️ **#4 Directional "nearest precipitation"** — single-point/wind-derived data presented with radar-level confidence. Ideas exist on the nowcast branch.
- ⏸️ **#6 WeatherKit/Open-Meteo consistency** — condition text can contradict Open-Meteo numbers on one screen; `.blizzard`/`.hurricane` condition mapping degrades/drops.
- ⏸️ **Radar text summary** — add a plain-text intensity summary ("peak 3 mm/hr at ~25 min") alongside the audio graph.

**Reviewer finding NOT actioned (verified against reality):**
- ❌ The review flagged the radar text timeline being `accessibilityHidden` as "VoiceOver loses the timeline." This repeats the withdrawn CR-5 finding — on-device VoiceOver testing (Madison) confirmed the per-interval time+condition data *is* conveyed via the chart's `accessibilityRepresentation`. The reviewer's subtler point (a text summary would beat sonification as the primary affordance) is captured under "Radar text summary" above.

---

## The review (as delivered)

### 1. Verdict
Well-built and genuinely thoughtful, but **not yet trustworthy as a serious weather tool** until the honesty/correctness defects are fixed. Engineering craft (caching, timezones, accessibility interactions) is above most shipping weather apps, and the data breadth (marine, air quality, soil, CAPE, historical to 1940, astronomy) is impressive. The gap to "good weather software" is almost entirely **honesty about uncertainty and failure** — presenting modeled/estimated/averaged/failed states as if they were observed and certain.

### 2. What's genuinely strong
- **Timezone discipline** — `WeatherData.timeZone` derives city-local time from the API offset and deliberately falls back to UTC (never device-local), with hourly parsing threading `cityTimeZone`.
- **Historical engine** — `fetchSameDayHistory` pulls the same calendar day across ~85 years, one request/year with concurrency and per-year failure isolation; the recent-past (forecast API `past_days`) vs archive split is correct and subtle.
- **WeatherKit nowcast path** — uses the minute-by-minute feed and treats the `condition` enum as the authority for "is it precipitating," even letting `minute[0]`'s explicit type override a lagging summary.
- **"Weather Around Me"** — the `accessibilityAdjustableAction` that swipes a VoiceOver user through progressively farther cities in a chosen compass direction is a genuinely novel non-visual way to explore regional weather.
- **My Data catalog** — deep (soil layers, CAPE, radiation, pollen, marine, AQI) and correctly routed per endpoint.
- **Cost-aware architecture** — light vs full fetches, LRU eviction, TTL caches, free-vs-paid concurrency gating.

### 3. Where the weather substance is weak or missing
- **(a) Severe-weather alerts fail silently as "all clear."** [FIXED #1] A failed NWS/WeatherKit request rendered identically to genuine calm. For a safety feature, "couldn't check" and "nothing there" must never look the same.
- **(b) No alerting when the app is closed.** [ISSUE #2] No `UNUserNotification`/`BGTaskScheduler`/push. Alerts load only when a user opens a city and scrolls to them. Largest *product* gap.
- **(c) Future/past "current" conditions are a synthesized average mislabeled as current.** [FIXED #3] `(dailyMax+dailyMin)/2` shown at 72pt as "Current temperature," and a fabricated "Cloud Cover 0%" for every future/past day.
- **(d) "Directional" precipitation is single-point data dressed up as spatial.** [ISSUE #4] All 8 directions return the same status; "nearest precipitation" distance/direction is `minutes × windSpeed` (opposite of wind), not radar — presented with radar-level confidence.
- **(e) WeatherKit + Open-Meteo mix is a Frankenstein for internal consistency.** [ISSUE #6] Condition text (WeatherKit) can contradict precip amount / weather_code (Open-Meteo) on one screen; `.blizzard`→moderate snow, `.hurricane`/`.tropicalStorm` dropped.
- **(f) Rich ingredients (CAPE, freezing level, dew point) are never synthesized** into storm/winter insight — raw numbers only.

### 4. Accessibility: real or superficial?
Mostly real and thoughtful (hand-written labels, adjustable actions, custom row actions, announcements) — this is a team that actually uses VoiceOver. Information-conveyance gaps noted: moon timezone [FIXED #5]; and the argument that an audio graph conveys *shape not fact*, so radar would benefit from an explicit text intensity summary [ISSUE — radar text summary]. (The "radar timeline hidden" claim itself was verified as a non-issue; data is conveyed via the accessible chart.)

### 5. Risks that would keep me up at night
- Silent-failure alerts + no background alerting (#1 [fixed], #2 [issue]).
- Fabricated facts for non-today days (#3 [fixed]).
- Moon timezone inconsistency (#5 [fixed]).
- Cost/load of "Weather Around Me" — up to ~9 Open-Meteo + ~9 WeatherKit + geocoding per open; most expensive screen, one tap from every city.
- Persistent cache disabled ("too slow from UserDefaults") → every cold launch is all-network; offline is "spinner then error," not last-known-good.
- `@MainActor` service doing network + large JSON decode → possible scroll hitches on older devices with many cities.

### 6. The hard questions for the team
1. If api.weather.gov is down during a tornado outbreak, what does the user see — and how is that different from a calm day?
2. Plan for alerting a user who isn't looking at the app? If none, is the App Store copy honest that alerts are view-only?
3. Why is a min/max average shown at 72pt as "Current temperature," and why does every future day claim "Cloud Cover 0%"?
4. Is "nearest precipitation, 12 mi west, moving east" an observation or a wind extrapolation? Why radar-level confidence?
5. Why do all 8 directional sectors show the same status?
6. Is an audio graph really a substitute for "rain in 15 minutes" as text?
7. WeatherKit "Rain" over Open-Meteo `precipitation: 0.0` — which wins per field? What happens to `.hurricane`/`.blizzard`?
8. Moon times: device-local or city-local?
9. Real cost per "Weather Around Me" open, and monthly ceiling if it gets popular?
10. Historical archive forced to free tier — documented constraint, and failure mode if it rate-limits mid-sweep?

### 7. Priorities before this is "good" (reviewer's ranking)
1. Make alert failure honest. [FIXED #1] *(reviewer: non-negotiable)*
2. Add background severe-weather notifications. [ISSUE #2]
3. Stop fabricating non-today "current" data. [FIXED #3]
4. Relabel wind-derived "nearest precipitation" as an estimate / make sectors real. [ISSUE #4]
5. Fix moon timezone. [FIXED #5]
6. Un-hide radar timeline for VoiceOver + add a text intensity summary. [radar text summary — timeline itself verified non-issue]
7. Resolve WeatherKit/Open-Meteo consistency; stop degrading `.blizzard`/`.hurricane`. [ISSUE #6]
8. Restore cross-launch caching (small on-disk store) for offline last-known-good.
9. Cost-guard "Weather Around Me."

> "The bones are strong and the accessibility instincts are real. Close the honesty gap and I'd happily put our name on it."
