# Nowcasting & Short-Term Forecast Improvement Proposal

**Status:** Functional portions re-ported to branch `nowcast-port` (2026-07-03) on top of main's WeatherKit conditions work. The radar map and AI radar description described below were **not** ported (deliberately excluded); the dry-convection reconciliation now keys off the condition the app displays (post-WeatherKit-overlay) instead of the raw Open-Meteo code, and the nowcast fetch is TTL-cached. See `iOS/NOWCAST_TESTING_GUIDE.md`. Original implementation was on branch `docs/nowcasting-proposal`.
**Date:** 2026-06-17 (implemented 2026-06-18; ported 2026-07-03)
**Author:** Research synthesis (deep web research + codebase audit)
**Scope:** iOS (`iOS/`) primarily, since WeatherKit is iOS-only. Concepts (ring sampling, narration) port to web/Windows where data allows.

## Implementation status (iOS)

All four shipping items are behind feature flags (Settings → Developer Settings), both **on by default** so they're visible for testing. Sonification (Part D) was intentionally **not** built — keeping the app blind-*friendly*, not blind-*only*; every new output is plain text/standard SwiftUI that sighted users see too.

| Item | Status | Key files |
|---|---|---|
| Gap 2 — "Next Hour" narration | ✅ Implemented | `Services/RadarService.swift` (`buildNextHourSummary`), surfaced in `Views/RadarView.swift` (`nextHourCard`). Flag: `nextHourNarrationEnabled` |
| Gap 1 / B1 — real ring sampling | ✅ Implemented | `Services/StormApproachService.swift` (multi-coordinate Open-Meteo call). Flag: `stormApproachEnabled` |
| Gap 1 / B2 — true storm motion | ✅ Implemented | `StormApproachService.estimateMotion` (centroid tracking across forecast frames) — replaces wind-direction guess |
| Gap 1 / Part C — saved-city impact | ✅ Implemented | `StormApproachService.classifyCity`; `RadarView.stormApproachCard` |
| Gap 1 — nearby-town layer (radar-like) | ✅ Implemented | `StormApproachService.nearbyPlaces` / `classifyPlace` — names bundled towns the storm is over/heading for (no reverse geocoding), within ~50 mi, in addition to saved cities |
| Part D — sonification | ⛔ Deferred by design | — |

Notes: a new multi-coordinate Open-Meteo call (one request, `timeformat=unixtime`, `timezone=GMT`) samples 8 bearings × 2 radii (30/60 km) + nearby saved cities + nearby bundled towns. Distances/speeds respect the user's unit settings. Builds clean for the iOS Simulator; XCTest suite not yet run.

**Home of Storm Approach:** merged into the **Weather Around Me** feature (top section), not Expected Precipitation — one unified "around me" surface. The `stormApproachEnabled` flag gates the whole section; turned off, Weather Around Me reverts to exactly its prior temperature/condition comparison. The Next Hour narration remains in Expected Precipitation (gated by `nextHourNarrationEnabled`).

**Convective awareness:** when the location's Open-Meteo `weather_code` reports a thunderstorm (95/96/99) but quantitative precipitation is 0 (scattered/dry convection — e.g. Aventura FL), Storm Approach surfaces a reconciling note instead of a flat "no precipitation", so it agrees with the main screen's condition rather than contradicting it.

**Nowcast IA refinements** (flag `nowcastRefinementsEnabled`, **default OFF** — with it off the app is byte-for-byte the prior behavior): (1) the precipitation feature is renamed **"Next Hour"** (Actions-menu button + screen title) to signal *timing* vs. Weather Around Me's *spatial* picture; (2) that screen becomes purely temporal — the older wind-inferred "nearest precipitation" block is hidden, since Storm Approach does direction better; (3) a tappable **Next Hour one-liner** appears on the main city detail screen (today only), opening the full timing screen. The main Settings toggle and User Guide text keep the "Expected Precipitation" wording for now.

---

## Weather Around Me — accuracy roadmap & radar integration

### What is already trustworthy vs. shaky
- **Arrival time ("reaching you in ~20 min") is the strongest number** — it comes from *your own point's* `minutely_15` forecast onset (native NOAA HRRR in the US). Keep relying on this for "when".
- **Direction/motion is the shaky part.** Two weak methods existed: the original Weather Around Me inferred approach/recession from **surface wind** at remote cities (storms don't move with surface wind); the first Storm Approach used **precipitation-weighted centroid tracking** across two forecast frames (better, but conflates storm *growth/decay* with *motion*).

### Accuracy improvements (flag `weatherAroundMeImprovementsEnabled`, default ON)
1. **Steering-wind storm motion (primary fix).** Estimate motion from the **mid-level steering flow** — the vector mean of the 850/700/500 hPa winds at the location (Open-Meteo pressure-level wind variables, paid tier) — which is how storm motion is actually estimated. Use the centroid drift only as a **cross-check**.
2. **Confidence + honest hedging.** Compare the steering vector against the centroid drift: close agreement → high confidence, state it plainly; disagreement or sparse field → lower confidence, hedge ("generally from the southwest", "roughly 20–30 minutes", "track is unclear"). Never state a crisp vector the data can't support — over-precision destroys trust for a user who can't glance at radar to cross-check.
3. **Denser sampling grid** — 16 bearings × 3 radii instead of 8 × 2, so a lone cell between spokes isn't missed or mislocated. Just more coordinates in the same single multi-coordinate call (cheap on paid tier).
4. **Precipitation type per town** — use each sampled point's `weather_code` to say "**snow** over Springfield" vs. rain, and extend the thunderstorm-with-zero-rain reconciliation to towns, not just the centre.

### Radar integration (flag `weatherRadarMapEnabled`, default ON)
- **Free, public-domain NWS NEXRAD radar tiles on a MapKit overlay.** NOAA/NWS NEXRAD base-reflectivity composite (N0Q) served as web-mercator XYZ tiles by the Iowa Environmental Mesonet (`mesonet.agron.iastate.edu/cache/tile.py/1.0.0/nexrad-n0q-900913/{z}/{x}/{y}.png`) → `MKTileOverlay` over an `MKMapView` centred on the location, pin at the city, attribution shown. **US (CONUS) coverage only**; outside the US the overlay is empty and a note says so.
- **Why NEXRAD/IEM and not RainViewer:** RainViewer's free public API is **personal/educational use only** — not licensed for a published app — so it was swapped out. NOAA NEXRAD is public domain. (RainViewer max zoom was 7, requiring a zoom cap; IEM serves higher zooms.)
- **Why it matters for a blind developer/user:** it puts a *real radar image* in the app that **VoiceOver image recognition / on-device AI (iOS 26/27 image descriptions)** can describe in ~2 seconds — and it doubles as the **ground-truth check** for our text narration (does "moving northeast" match what the image shows?). We don't build the AI; we just present an image the OS can read.

### Still open / future
- **Observed-radar nowcast** (NOAA MRMS, or RainViewer's nowcast frames) as a data source rather than only model fields, to validate/replace the steering-wind motion estimate.
- Decide whether the older Weather Around Me machinery (regional summary, 8-direction cards, directional explorer + pressure trends) stays, gets demoted, or is retired now that Storm Approach is the primary "around me" content.

---

## Why this document exists

FastWeather is excellent at accessibility and solid at the basics ("what's happening today and over the next several days"). Two gaps remain:

- **Gap 1 — "What's around me / what's coming at me right now"** (the radar-replacement problem). When a storm is outside the window, sighted users glance at animated radar and instantly know: is precipitation approaching or leaving, from which direction, how intense, how soon. The current **Weather Around Me** feature (compare nearby cities) feels clunky, and **direction-of-approach is inferred from surface wind**, which is meteorologically unreliable.
- **Gap 2 — Short-term / immediate-area forecasting** (next hour, next few hours). Currently below average; no concise "rain starting in ~11 minutes, lasting ~35" narration.

Everything below is grounded in two things: (1) a deep, fact-checked research pass on the weather/nowcasting/accessibility landscape, and (2) an audit of the existing iOS code.

---

## The single most important finding

The two things that *seem* like the hard parts — getting a real per-minute precipitation nowcast, and knowing how to present spatial/radar info non-visually — are **both already solved and reachable today** with the developer's current entitlements (paid Open-Meteo + WeatherKit). No new science, no model training.

- **Nowcast data is already in hand:** Apple **WeatherKit `NextHourForecast`** returns a minute-by-minute array where each `ForecastMinute` carries `precipitationIntensity` (mm/hr), `precipitationChance`, and `startTime`. `RadarService` already fetches `.minute` — but only renders it as a timeline list.
- **The non-visual design pattern is documented prior art:** a granted patent (US11501660B2, "Spatial weather map for the visually impaired," The Weather Company) plus peer-reviewed studies establish exactly how blind users want spatial weather conveyed (user-at-center, pitch = intensity, stereo/spatial = direction, plain-language ETA).

**The work is integration and presentation, not research.**

---

## What's weak in FastWeather today (from the code audit)

Three concrete issues undercut "what's around me":

1. **The 8 "directional sectors" in `RadarView` are placeholders.** They're labeled North/NE/E/… but each is backed by the *same single-point* data for the user's location. They cannot actually say "precip is to your southwest."
   - File: `iOS/FastWeather/Views/RadarView.swift`, `iOS/FastWeather/Services/RadarService.swift` (`directionalSectors`)

2. **Direction-of-approach is guessed from surface wind** ("opposite of wind direction"). Storm cells routinely move 20–40° off the surface wind, sometimes a wholly different direction. This is the root of the "clunky / not-quite-right" feeling — the app states a direction derived from the wrong variable.
   - File: `iOS/FastWeather/Services/RadarService.swift` (lines ~509–513, ~463–467)

3. **Weather Around Me samples 9 points but only `temperature_2m` + `weather_code`** — no precipitation intensity, no time evolution. It's a snapshot table comparison, not a sense of an approaching storm.
   - File: `iOS/FastWeather/Services/RegionalWeatherService.swift`

---

## Data-source reality check (fact-checked)

| Need | Best source | Reality check |
|---|---|---|
| Per-minute rain timing | **WeatherKit NextHour** | US + select regions only; already fetched in `RadarService` |
| 15-min sub-hourly fallback | **Open-Meteo `minutely_15`** (paid) | Native resolution only in North America (NOAA HRRR 1 km) & Central Europe (DWD ICON-D2, Météo-France AROME); **interpolated from hourly elsewhere** |
| Radar tiles / reflectivity | **Open-Meteo: none** | ⚠️ Open-Meteo exposes **no** radar/reflectivity/nowcast product |
| Raw radar (if ever needed) | RainViewer | **Image tiles only**, not numeric values; some free-tier claims were *refuted* in research — re-verify before relying |
| International nowcast | Rainbow Weather | Single vendor source; "global" is marketing; **pricing unknown** — investigate, don't assume |
| Storm bearing / ETA | **Compute in-app** | Ring-sample Open-Meteo, or estimate motion from 2 frames; fully under our control |

**Implication:** True radar replacement must come from WeatherKit (timing) + in-app computation (direction). Open-Meteo is a data feed, not a radar service.

---

## GAP 2 — Short-term forecasting (do this first)

Highest value, lowest risk, data already fetched.

### Feature: "Next Hour" precipitation narration

One concise spoken summary at the top of the detail view:

> *"Rain starting in about 11 minutes, light at first, heaviest around 8:40, tapering off by 9:05. No rain after that for the next hour."*

- **Data:** WeatherKit `NextHourForecast` → fall back to Open-Meteo `minutely_15` → fall back to `hourly`. All three already plumbed in the app.
- **Difficulty:** **Low.** The per-minute data is already in `RadarService` (`chartData` / WeatherKit `minuteByMinute`). The new work is a *summarizer*: scan the per-minute array for onset, peak, end, and gaps; emit one sentence.
- **Accessibility pattern:** This is the legendary Dark Sky feature, done better for VoiceOver — one sentence beats a chart or a 60-row table. Make it the first element VoiceOver reads in `CityDetailView`. Keep the existing timeline/graph below for drill-down.
- **Key research caveat:** blind study participants often **preferred plain numbers/words to tones** for precise info. Narration is the hero; sonification is an optional layer (see Gap 1, Part D).

---

## GAP 1 — The radar replacement

A radar glance answers two different questions that need different data:

### Part A — "When will it hit *me*?" (timing)

This is Gap 2 applied to the current location. NextHour / `minutely_15` at the user's point already gives onset + intensity. **Solved by the Gap 2 feature.**

### Part B — "From which direction is it coming?" (the real gap)

Two buildable approaches, in order of effort:

#### B1 — Ring sampling (recommended starting point)

Sample Open-Meteo **precipitation** (not just temp) at a ring of points around the user — e.g. 8–16 bearings × 2–3 radii (~15 / 35 / 60 km). This yields a coarse but *real* precipitation field. Find active precip, get its bearing + distance, combine with the forecast at the user's point to state arrival:

> *"Rain to the southwest, about 18 miles out, reaching you in roughly 25 minutes. Clear in every other direction."*

- **Data:** Open-Meteo paid (exactly the call-volume the $30/mo buys). ~16–24 coordinates per refresh.
- **Difficulty:** **Medium.** This is an *upgrade to the existing `RegionalWeatherService` ring logic* — it already computes the coordinate ring; add `precipitation` to the request fields plus a "find precip → report bearing + distance" reducer.
- **Payoff:** Replaces the fake `directionalSectors` with real ones.

#### B2 — True storm motion (meteorologically correct)

Instead of guessing direction from wind, compute it from **two consecutive precipitation frames** (two `minutely_15` snapshots ~15 min apart, or two ring samples). The shift of the precip pattern *is* the storm motion vector — exactly what real nowcasting does (optical-flow methods: pysteps Lucas-Kanade / variational / DARTS). We don't need pysteps (Python); a simple in-app cross-correlation of two grids yields a motion vector good enough for "moving northeast at ~25 mph."

- **Difficulty:** **Medium-high**, but fixes the wind-direction correctness bug — the difference between "clunky" and "trustworthy."
- **Don't:** try to run the big ML nowcasters in-app. DeepMind DGMR and NowcastNet prove the science is solid but are **research models, not APIs**. WeatherKit NextHour already delivers their output-quality for timing.

### Part C — Standout innovation: tie storm motion to saved cities

The most actionable accessibility finding (ACM W4A 2026): blind users want storm motion described **relative to places that matter to them** — "moving toward or away from your points of interest." **The app already has saved cities and current location.**

> *"The storm line is moving toward your home in Lincoln — arriving in about 40 minutes. It's moving away from your saved city, Omaha."*

- **Difficulty:** Low–medium on top of B1/B2.
- **Why it matters:** Genuinely differentiating, maps perfectly onto the existing data model, and no mainstream app does it.

### Part D — Sonification (optional, advanced)

The audio layer that gives the *gestalt* of a radar sweep. Validated mapping: **user at center, pitch = intensity** (high pitch = heavy), **stereo/spatial pan = direction**, tempo = activity, plus a spoken summary. A clockwise "audio scan" (N→E→S→W) panning + pitching as it goes lets someone *hear* "heavy stuff to my southwest" in ~2 seconds.

- **Difficulty:** **High** (AVAudioEngine / PHASE 3D audio). **Opt-in extra, never the primary output** — always keep text narration.
- ⚠️ **IP caveat:** The Weather Company holds granted patents (US11501660B2, US11830376) on spatialized weather audio for the visually impaired. Do an IP review before shipping something that closely mirrors "user-at-center, outward-emanating spatialized audio." Plain narration + simple stereo panning are far less likely to be encumbered.

---

## Recommended sequencing

1. **"Next Hour" narration** (Gap 2) — low effort, data already fetched, immediate impact. Ship first.
2. **Real ring sampling for direction** (Gap 1 / B1) — upgrade `RegionalWeatherService` to pull precipitation; retire the fake sectors. Core fix for "clunky."
3. **Storm-relative-to-my-cities narration** (Gap 1 / Part C) — small add on top of #2, genuinely novel.
4. **True 2-frame motion** (Gap 1 / B2) — replaces the wind-direction guess; makes it trustworthy.
5. **Sonification** (Part D) — only if #1–4 land well, and after an IP check.

---

## Honest caveats

- **Coverage geography is the recurring asterisk.** WeatherKit NextHour and Open-Meteo native 15-minutely are strong in the US, degrade or vanish elsewhere. Build the **NextHour → minutely_15 → hourly** fallback chain deliberately and detect coverage.
- **Sonification UX evidence is thin** — leans on one small formative study (n=5) plus patents describing *systems*, not shipped products. Treat specific pitch/pan choices as **hypotheses to test with VoiceOver users**, not settled fact. Always provide a plain-text fallback (some participants preferred numbers to tones).
- **RainViewer / Rainbow Weather need re-verification** before any integration — RainViewer free-tier nowcast claims were refuted in research; Rainbow Weather's coverage/pricing is unconfirmed.
- **API drift:** verify WeatherKit / Open-Meteo field names and coverage at build time.

---

## Sources (fact-checked, high-confidence unless noted)

- WeatherKit REST API (NextHourForecast, ForecastMinute fields) — https://developer.apple.com/documentation/weatherkitrestapi
- Open-Meteo docs (minutely_15, coverage, no radar product) — https://open-meteo.com/en/docs
- Open-Meteo sub-hourly explainer — https://openmeteo.substack.com/p/sub-hourly-15-minutely-weather-forecasts
- DeepMind DGMR (Nature) — https://www.nature.com/articles/s41586-021-03854-z
- NowcastNet (Nature) — https://www.nature.com/articles/s41586-023-06184-4
- DeepMind "Nowcasting the next hour of rain" — https://deepmind.google/blog/nowcasting-the-next-hour-of-rain/
- pysteps optical-flow motion estimation (GMD) — https://gmd.copernicus.org/articles/12/4185/2019/
- "Spatial weather map for the visually impaired" patent US11501660B2 — https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/11501660
- Sonification prototypes for blind users (UXPA Journal) — https://uxpajournal.org/development-and-evaluation-of-two-prototypes-for-providing-weather-map-data-to-blind-users-through-sonification/
- Inclusive climate communications / accessible storm narration (ACM W4A 2026) — https://dl.acm.org/doi/10.1145/3800424.3800436
- RainViewer API (image tiles only; some claims refuted) — https://www.rainviewer.com/api.html
- Rainbow Weather nowcast API (vendor source; pricing unverified) — https://developer.rainbow.ai/
