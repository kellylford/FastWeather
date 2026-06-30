# Current Conditions Accuracy Plan — WeatherKit-backed "now" conditions

**Status:** Phase 1+2 implemented 2026-06-30 (Paths A/B/C, behind `weatherKitConditionsEnabled`, default ON). Builds clean for iOS Simulator. Pending on-device + VoiceOver validation. Deferred: widgets (Path D), attribution surfacing, reconciling-note fallback, richer vocabulary → tracked in #74.
**Author:** Planning session 2026-06-30
**Tracking issue:** #73 (see GitHub)
**Related:** #72 (Glance Ahead), `WEATHER_AROUND_ME.md`, `ARCHITECTURE.md`

---

## 1. Problem statement

The city list (and many other surfaces) can show a condition like **"Thunderstorm"
for a city where it is currently dry**. This is not a bug in our code — it is a
property of the data source:

- Every "current conditions" label in the app is derived from Open-Meteo's
  `current.weather_code`.
- Open-Meteo's `current` block is **numerical-model output, not an observation**.
  It is effectively the model's value for the current hour in that grid cell.
- WMO thunderstorm codes (95/96/99) are assigned by the model from convective
  signals, not measured precipitation — so `current.precipitation` can be `0`
  while the code says thunderstorm.

The **paid Open-Meteo tier ($30/mo) does not fix this** — it buys dedicated
servers, higher rate limits, and a commercial license, but the **same models,
grid, and `weather_code` derivation** as the free tier.

Competing apps (Apple Weather, AccuWeather, Weather Channel) feel more accurate
"right now" because their current conditions **blend real observations + radar
nowcast**. We already pay for a source that does this: **WeatherKit** (Apple
Developer membership, 500k calls/mo free), and we already use it for snow totals,
precipitation nowcast, and international alerts — **but not for the current
conditions label.**

### Goal

Make "current conditions" observation/nowcast-informed via WeatherKit, **and do
it consistently across every surface in the app**, so we are never wrong in
*different* ways on different screens (which is worse than being uniformly
imperfect).

---

## 2. The consistency problem (why this needs a plan, not a one-line change)

A full audit found **41 distinct condition-display surfaces** across the app,
fed by **four independent data paths**, plus an **already-shipping inconsistency**.

### 2.1 The four independent data paths

| Path | Entry point | What it fetches | Surfaces fed |
|------|-------------|-----------------|--------------|
| **A. Main WeatherData** | `WeatherService.fetchWeatherForDate` | Full Open-Meteo `current`+`daily`+`hourly` | My Cities list, City Detail, Table, Flat, Day Detail, Weather Around Me (prefetch) |
| **B. Regional** | `RegionalWeatherService.fetchWeatherForLocation` | Minimal Open-Meteo (`temperature_2m,weather_code` only) via its own `BasicWeatherResponse` | Weather Around Me directional tiles |
| **C. Browse basic** | `WeatherService.fetchWeatherBasic` | Lightweight Open-Meteo current | Browse Cities / State Cities rows (3 row styles) |
| **D. Widget** | `FastWeatherWidget` timeline provider | Its own fetch → pre-mapped `entry.condition` / `entry.sfSymbol` | All home-screen + lock-screen widgets |

**Any fix applied only to Path A leaves B, C, and D showing Open-Meteo** — which
*is* the "wrong in different ways" failure mode.

### 2.2 Pre-existing inconsistency (independent of this work)

Within **City Detail**, two condition values are shown:
- The large **current conditions card** reads `current.weatherCodeEnum` (CURRENT).
- **"Today's Forecast"** directly above reads `daily.weatherCode[0]` (DAILY, the
  whole-day summary code).

These can already disagree today. The plan should decide the intended
relationship (see §6).

---

## 3. Source-of-truth strategy by time horizon

The accuracy problem is **specific to "now."** Forecasts are model output
everywhere, for every provider — so future hours/days are *expected* to be
forecasts and are internally consistent as-is. We therefore scope the change
tightly:

| Horizon | Surfaces | Source decision | Rationale |
|---------|----------|-----------------|-----------|
| **CURRENT ("now")** | list, browse, detail current card, table, flat, Weather Around Me, widgets | **WeatherKit `currentWeather.condition`** → translated to WMO; fall back to Open-Meteo | This is the only place observations beat models |
| **HOURLY forecast** | detail hourly cards/rows, Glance Ahead | **Keep Open-Meteo** | Forecast; WeatherKit hourly capped ~240h and adds horizon gaps |
| **DAILY forecast** | detail 16-day rows, Day Detail, "Today's Forecast", share | **Keep Open-Meteo** | Forecast; WeatherKit daily capped at 10 days vs our 16 |
| **HISTORICAL** | Historical Weather | **Keep Open-Meteo archive** | WeatherKit has no comparable 1940→ archive |

**Net:** only the **CURRENT** column changes. That keeps the blast radius
contained while directly fixing the reported problem, and avoids introducing a
provider that can't cover our forecast/historical horizons.

---

## 4. Recommended architecture — single translation point ("WMO as common currency")

Every one of the 41 surfaces ultimately renders from our `WeatherCode` (WMO)
enum — its `.description` and `.systemImageName(isDay:)`. The cleanest,
lowest-risk way to stay consistent is to **keep WMO as the internal currency**
and translate WeatherKit's condition *into* a WMO code at the data layer. Then
**no UI surface changes at all** — they keep reading `weatherCodeEnum`.

### 4.1 New translation helper (one definition, used by all paths)

```swift
// Weather.swift (or a new ConditionMapping.swift)
extension WeatherCode {
    /// Best-effort map from WeatherKit's WeatherCondition to a WMO code.
    /// Returns nil for conditions with no reasonable WMO equivalent
    /// (caller then keeps the Open-Meteo code).
    init?(weatherKitCondition: WeatherCondition, isDaylight: Bool) { ... }
}
```

This is the **linchpin**: define the mapping **once**, reuse everywhere. We
already handle the `WeatherCondition` enum in `RadarService.isWKConditionPrecipitating`
(RadarService.swift:205), so there is precedent.

### 4.2 Overlay in Path A (mirror the snow overlay)

`applyWeatherKitSnowOverlay` (WeatherService.swift:1203) is the exact template:
guarded by `#if canImport(WeatherKit)` + `@available(iOS 16.0, *)` + feature
flag, applied at WeatherService.swift:540–545, silent fallback on any error.

**Optimization (quota-friendly):** the snow overlay *already* calls
`weather(for:including: .daily)`. Change it to
`weather(for:including: .daily, .current)` and read the current condition from
the **same call** — **zero additional WeatherKit requests** for saved cities.
A combined `applyWeatherKitOverlay` would set both snow totals and the current
condition code.

### 4.3 Bring Paths B, C, D onto the same helper

- **Path B (Regional / Weather Around Me):** add the same `.current` overlay (or
  call the shared translation helper) so directional tiles match the list.
- **Path C (Browse basic):** same overlay applied to `fetchWeatherBasic`.
- **Path D (Widgets):** **decision required** (see §6) — widgets are a separate
  target with a tight refresh/runtime budget; calling WeatherKit per timeline
  refresh has cost and quota implications. Option: upgrade widgets too (full
  consistency) vs. document widgets as an accepted Open-Meteo boundary.

### 4.4 Alternative considered (rejected for v1)

A **unified internal `Condition` type** that both providers map into, with the UI
rendering from it. Cleaner long-term, but touches the `WeatherCode` enum and all
41 surfaces — a large refactor with high regression risk. **Recommend deferring**;
the WMO-translation approach gets the same user-visible consistency with overlay-
point-only changes. Revisit if we ever add a third current-conditions provider.

---

## 5. Where WeatherKit lacks detail — gaps & fallback plan

| Gap | Detail | Fallback |
|-----|--------|----------|
| **Taxonomy mismatch** | WeatherKit `WeatherCondition` (~40 cases incl. `.hot`, `.breezy`, `.windy`, `.haze`, `.smoky`, `.blowingDust`) has **no clean WMO equivalent** for several values; WMO has intensity buckets (slight/moderate/dense) WeatherKit lumps together | Mapping returns `nil` for unmappable cases → **keep the Open-Meteo `weather_code`** for that city. Never show a worse label than today. |
| **Forecast horizon** | WeatherKit daily ≤10 days, hourly ≤~240h vs our 16-day Open-Meteo | N/A — we deliberately keep forecasts on Open-Meteo (§3) |
| **No historical** | No 1940→ archive equivalent | Keep Open-Meteo archive |
| **Region coverage / auth** | WeatherKit can return HTTP 400 (unsupported region), JWT/entitlement errors, WeatherDaemon errors — already observed in alert code (WeatherService.swift:1455–1485) | Silent fallback to Open-Meteo current (existing pattern); cache empty result to avoid retry storms |
| **`.minute` nowcast limited** | Minute precip only ~6 countries — **but `.current` condition is global**, so the condition overlay works worldwide (subject to WeatherKit coverage) | Condition overlay uses `.current`, not `.minute`; no extra restriction |
| **iOS version** | WeatherKit needs iOS 16+ (we target iOS 17+) | `#if canImport` + `@available` guards retained |
| **Latency** | WeatherKit adds a network round-trip; list shows many cities | Overlay is async in the fetch path (snow-overlay precedent); consider show-Open-Meteo-then-upgrade if perceptible |

**Fallback principle:** WeatherKit is an *enhancement overlay*. On any
gap/error/unmappable condition, we **silently retain the current Open-Meteo
behavior** — the app never regresses below today.

---

## 6. Open design decisions (need your call)

1. **Widget scope (Path D).** Upgrade widgets to WeatherKit current conditions
   (full consistency, but added WeatherKit calls on the OS refresh budget), or
   document widgets as an accepted Open-Meteo boundary? *Recommendation: phase 2
   — ship app surfaces first, evaluate widget quota impact, then decide.*

2. **City Detail current-card vs "Today's Forecast."** After the overlay, the
   current card = WeatherKit "now"; "Today's Forecast" = Open-Meteo daily[0]
   (whole-day). Keep both (they answer different questions: now vs today overall)
   with clearer labels, or align them? *Recommendation: keep both, relabel for
   clarity.*

3. **Feature flag + default.** Per project convention, gate behind
   `weatherKitConditionsEnabled` in `FeatureFlags` + `DeveloperSettingsView`.
   Default on or off for first TestFlight? *Recommendation: default ON in dev,
   ship to TestFlight behind the flag for A/B against Open-Meteo.*

4. **Scope of "current."** Saved cities only first, or saved + browse + Weather
   Around Me together? *Recommendation: do A+B+C together — partial rollout
   re-creates the exact inconsistency we're trying to remove.*

---

## 7. What else we should consider (cross-cutting)

- **Attribution (legal requirement).** Apple requires the Apple Weather mark + a
  link to the WeatherKit legal/data-sources page **wherever WeatherKit data is
  shown.** We already have the pattern (`WeatherAttributionData` /
  `legalPageURL`, RadarView.swift:295–312) but only on the Radar screen.
  Surfacing WeatherKit conditions broadly means attribution must appear on (or
  be reachable from) the list, detail, browse, Weather Around Me — and widgets if
  upgraded. **This is mandatory, not optional.**

- **Quota / cost.** WeatherKit free tier = 500k calls/mo. Combining the current
  read into the existing snow `.daily` call (§4.2) means **no new calls for saved
  cities**. Browse + Weather Around Me + widgets are the volume risk — estimate
  call counts before enabling those paths. (Cost sensitivity noted in project
  infrastructure memory.)

- **Caching coherence.** Current conditions cache TTL is 10 min
  (`currentWeatherCacheDuration`). WeatherKit current has its own freshness; the
  10-min cache is acceptable. Ensure the overlaid code is what gets cached (apply
  overlay *before* `weatherCache[key] = …`, like snow).

- **VoiceOver (non-negotiable per CLAUDE.md / ACCESSIBILITY.md).** Because all
  surfaces read the same `weatherCodeEnum`, the overlay flows to VoiceOver labels
  automatically — but every changed surface must be re-tested with VoiceOver
  before sign-off. Watch the "Conditions: …" labels in list, detail, browse,
  table, flat, Day Detail.

- **My Data "condition as numeric field"** (MyDataConfigView.swift:295) reads the
  raw `current.weatherCode` as a number — it will reflect the overlaid value too.
  Confirm that's desirable (it should be).

- **Share text** (CityDetailView.swift:900) uses `current.weatherCode` — will
  reflect WeatherKit. Good (stays consistent with the on-screen card).

- **Testing strategy.** Add a dev/debug comparison (log or hidden view) showing
  Open-Meteo code vs WeatherKit-translated code side by side for spot-checking
  during TestFlight. Unit-test the `WeatherCondition → WMO` mapping table.

- **Rollback.** Feature flag gives instant rollback. Because it's an overlay with
  silent fallback, disabling the flag returns the app to exactly today's behavior.

---

## 8. Proposed phasing

- **Phase 0 (this doc):** agree strategy, decisions in §6.
- **Phase 1:** translation helper + combined WeatherKit overlay on Path A (saved
  cities), behind `weatherKitConditionsEnabled`. Attribution on detail/list.
  VoiceOver pass. TestFlight A/B.
- **Phase 2:** extend overlay to Path B (Weather Around Me) and Path C (Browse)
  using the same helper. Attribution on those surfaces.
- **Phase 3:** decide + (optionally) implement widgets (Path D), with quota
  estimate.
- **Phase 4:** revisit the §6.2 current-vs-today labeling; consider the unified
  `Condition` refactor only if a third provider appears.

---

## 9. Fix vs. enhancement — condition vocabulary (dust, hot, haze, …)

**Can this ship as both a fix and an enhancement?** Yes, but only with a small,
explicit, separable addition. Two distinct value levels:

| Level | What the user gets | Scope |
|-------|--------------------|-------|
| **A. Accuracy fix (this plan, as written)** | The conditions we *already* show become observation/nowcast-informed — "Thunderstorm" stops appearing when it's dry | Overlay + translation only; no UI/vocabulary change |
| **B. Richer vocabulary (optional enhancement)** | *New* condition types Open-Meteo can't express — **Haze, Blowing dust, Smoke, Hot, Windy, Frigid, Tropical storm, Hurricane** | Extend our condition representation: new cases + `.description` + SF Symbol + VoiceOver label |

**Why we don't get B for free today or under the minimal plan:** Open-Meteo's
`weather_code` is a *subset* of WMO with no entry for haze/dust/smoke/hot/windy,
and §4's architecture maps unmappable WeatherKit conditions to `nil` → falls back
to Open-Meteo → those richer conditions are never surfaced.

**To unlock B**, we stop forcing everything through the WMO subset and let the
condition layer carry WeatherKit-only values (e.g. a small superset enum, or
`WeatherCode` gains synthetic cases for the non-WMO conditions). This touches the
rendering surfaces (each new case needs an icon + label), so it is *additive
scope*, not part of the accuracy fix.

**Recommendation:** ship **A** first (the fix). Treat **B** as a clearly-separable
fast-follow that can be marketed as the enhancement ("FastWeather now recognizes
haze, blowing dust, smoke, and extreme heat"). Decide B's scope after A is
validated. *This is a billing/marketing decision, not a technical dependency — A
does not require B.*

---

## 10. Relationship to the `docs/nowcasting-proposal` branch

A prior exploration branch (`docs/nowcasting-proposal`, **ignoring its AI radar
description feature per direction**) already touched this exact problem and the
same data paths. It informs — but does **not** expand — the current scope.

### 10.1 The "thunderstorm with 0mm" problem was already solved a different way

Commit `9e24732` ("Storm Approach: reconcile thunderstorm code with zero
precipitation") handled the **identical** symptom (Aventura FL: condition says
storm, precipitation 0mm) inside `StormApproachService` by **keeping the
Open-Meteo code and adding a reconciling note**:

> *"Thunderstorms are in your area's forecast, but no measurable rain is reaching
> your location or nearby towns right now."*

**Two strategies for one problem:**

| | Branch (`9e24732`) | This plan (§4) |
|---|---|---|
| Approach | Keep Open-Meteo code, **explain** the gap (cross-check `weather_code` vs `precipitation`) | **Replace** the code with WeatherKit's observation-informed condition |
| Result when dry | Still shows "Thunderstorm" + a note | Likely shows "Cloudy/Partly Cloudy" — discrepancy disappears |
| Coverage | Works everywhere Open-Meteo does | Best where WeatherKit has coverage; falls back to Open-Meteo |

**They are complementary, not competing:** WeatherKit conditions fix the main
surfaces; the **reconciling-note becomes the natural fallback messaging** for the
cases where we stay on Open-Meteo (WeatherKit unavailable/errored, or an
unmappable condition). Worth reusing the existing wording rather than inventing
new copy.

### 10.2 Coordination risk — overlapping files

That branch already modifies several files this plan's Path B/C would touch:
`RegionalWeatherService`, `WeatherAroundMeView`, `ListView`, `CityDetailView`,
`FlatView`, plus a large `FeatureFlags` expansion (`stormApproachEnabled`,
`nextHourNarrationEnabled`, `nowcastRefinementsEnabled`,
`weatherAroundMeImprovementsEnabled`, `weatherRadarMapEnabled`). **Action:** before
implementing Path B (Weather Around Me) here, check whether any of that branch is
landing first, to avoid conflicting edits and duplicate feature flags. Phase 1
(saved-cities, Path A) has the least overlap and is safe to do independently.

### 10.3 Other branch enhancements to carry forward later (out of scope now)

Noted for future work, not this issue: "Next Hour" precipitation narration
(WeatherKit `NextHourForecast` summarizer), real ring-sampling for storm
direction (upgrade `RegionalWeatherService` to fetch `precipitation`),
storm-motion-relative-to-saved-cities narration, and the NWS NEXRAD radar map.
These are tracked conceptually by the branch's proposal doc; surface them as
their own issues when we pick them up.

### 10.4 Net effect on this plan

- **No scope change.** Implementation stays scoped to the current
  current-conditions issue (#73).
- **One reuse:** adopt the branch's reconciling-note wording as the Open-Meteo
  fallback message (ties into §5's fallback principle).
- **One guardrail:** coordinate Path B edits with the branch to avoid collisions.
- **One link:** the §9-B vocabulary enhancement connects to the branch's
  "precipitation type per town" ambition (both want richer per-point condition
  detail).

---

## 11. Appendix — full surface inventory

41 surfaces across: My Cities list (ListView), Browse/State Cities (3 row
styles), City Detail (current card, Today's Forecast, hourly cards/rows, 16-day
rows, share), Day Detail, Table, Flat, Historical, Weather Around Me, and 6
widget variants (small, medium, circular, rectangular, large + 5-day). CURRENT-
horizon surfaces (the ones this plan changes) are: My Cities list (587, 757),
Browse rows (StateCitiesView 364/371/415, 463/470/506, 576/582/584), City Detail
current card (669/674/676) + share (877/900), Table (298), Flat (352), Weather
Around Me (634/692), and the widget current entries. Full file:line table held in
the planning session audit.
