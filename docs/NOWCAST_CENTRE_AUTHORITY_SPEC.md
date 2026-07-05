# Spec: Single centre authority + intensity floor for the nowcast seam

**Status:** Specified and harness-verified 2026-07-05. Not yet implemented in Swift.
**Branch:** `nowcast-port`
**Verification:** tools/datatesting runs 20260705-113125Z (storm), -115037Z (baseline),
-115956Z and -120250Z (fix simulation, storm + baseline). Analyses in the run folders.

## Problem

The Next Hour narration reads WeatherKit's minute nowcast (radar-informed);
Storm Approach's centre state reads Open-Meteo model data. On one screen, two
authorities answer "is it raining on me" — and they disagree often enough to
matter:

- 19.4% of WeatherKit-sampled cities during active weather (7 of 36)
- 11.6% on an ordinary day (8 of 69); 9.5% among genuinely quiet cities
- Observed live 2026-07-04 at east Madison: narration "rain for 48 minutes,"
  Storm Approach "not raining," NWS station confirmed no rain fell.

Failure fingerprints from the instrumented runs:

- WeatherKit phantoms are LOW intensity: 0.05–0.07 mm/h, typically at
  stations reporting Fog/Mist. Real storms measured 3.6–10.4 mm/h.
- Open-Meteo misses storm spin-up and overpersists after decay.
- NWS-station referee on "raining now" disputes: WeatherKit 5, Open-Meteo 2
  across all refereed rows — WeatherKit is the better, not perfect, authority.

## The fix (two parts, one dev flag)

New feature flag `nowcastCentreAuthorityEnabled` (default ON on this branch,
toggle in Developer Settings → Nowcasting). One flag gates both parts — they
ship together or not at all, because part B without part A recreates the
contradiction in mirror image.

### Part A — intensity floor at the shared source (RadarService)

In `RadarService.fetchWeatherKitNowcast`:

- New constant `wkIntensityFloorMmPerHr = 0.2`. Chosen from measured data:
  phantoms 0.05–0.07 mm/h, real storms 3.6–10.4 mm/h; the floor sits an
  order of magnitude below real rain.
- A minute counts as active iff `precipitationIntensity >= 0.2` (replaces
  `minute.precipitation != .none`).
- `currentIsPrecip` (the condition-based "sole authority") additionally
  requires current `precipitationIntensity >= 0.2` when an intensity value is
  present; if WeatherKit supplies no intensity, trust the condition as today.
- Applies to the narration samples, the timeline "active" states, and the
  fields Part B consumes — one floored view for every consumer.

### Part B — Storm Approach centre reads the same nowcast

In `StormApproachService.fetchStormApproach`, when the flag is on and the
city's country is in `weatherKitMinuteForecastCountries`:

- Call `RadarService.shared.fetchPrecipitationNowcast(for: city)` — the
  3-minute TTL cache means zero net new API calls (CityDetail or the Next
  Hour card usually fetched it moments earlier).
- If `dataSource == .weatherKit`, override the CENTRE state only:
  - `rainingHere` := floored WeatherKit now-state
  - `hereIntensity` := `PrecipIntensity(mmPerHour: current WK intensity)`
  - `arrivalMinutes` (0–60 min) := first floored-active WeatherKit minute
  - 60–120 min window: WeatherKit's horizon ends (~60–80 min), so if WK shows
    nothing, keep the Open-Meteo centre series for steps 5–8 (75–120 min) —
    preserves the 2-hour promise with the best source for each window.
  - `situation` derives from the overridden values as today.
- Everything spatial stays Open-Meteo: ring sampling, nearest bearing and
  distance, steering/centroid motion, town impacts, saved-city impacts.
  (Only Open-Meteo can sample a field; the referee data never impeached it
  on direction.)
- If the RadarService fetch fails or returns the Open-Meteo path, behavior
  is exactly today's (single source already — no seam outside WK coverage).

### Not changed

- The dry-convection reconciliation gate (displayedConditionCode) — untouched.
- Ring geometry, confidence/hedging rules, narration phrasing (locked by
  NextHourSummaryTests — the summarizer is untouched; only the ACTIVE flags
  feeding it change).
- Non-WeatherKit countries: no behavior change at all.

## Why not other designs (considered, rejected)

- Floor only, no centre authority: cards still disagree whenever radar and
  model differ above the floor (spin-up, decay) — measured 11–19%.
- Centre authority only, no floor: both cards would have confidently repeated
  the east-Madison phantom for 48 minutes. Consistent but wrong; the floor
  kills that class (all measured phantoms sit far below 0.2).
- Hedged dual-source wording ("radar says X, model says Y"): violates the
  no-decoder-ring principle.

## Harness verification (2026-07-05 runs)

Simulation: `intensity_floor_fix_sim` rows in the harness apply the exact
fix logic (floor at shared source, WK centre authority, OM 60–120 min
fallback) and classify every WeatherKit-sampled city against the NWS referee.

- 102 cities simulated across storm-chasing and baseline runs:
  - Oversuppression (floor removes rain a station confirms): **0**
  - Real precipitation preserved above floor: **9 of 9**
  - Phantom/low-intensity claims suppressed: 1 live (no-referee city) plus
    all 5 retro-verified phantom cases from the morning runs (analysis-seam.md)
  - Everything else: dry, unchanged
- Seam closure: by construction, narration and Storm Approach centre cannot
  contradict where WeatherKit is available (one source, one floor).
- Residual known imperfection: transient edge cases where BOTH sources are
  wrong together (e.g. Rockville RI — rain 21 min prior, both forecast dry);
  ~5–7% estimated, out of scope for this fix.
- Honest cost: the referee backed Open-Meteo in 2 of ~133 refereed
  now-disputes (~1.5%); in those cases the fixed app is wrong at the centre
  where today's Storm Approach happened to be right — accepted in exchange
  for eliminating self-contradiction and the phantom class.

## Implementation checklist (when approved)

1. `FeatureFlags.swift`: add `nowcastCentreAuthorityEnabled` (default ON) +
   DeveloperSettingsView toggle in the Nowcasting section.
2. `RadarService.swift`: floor constant + Part A logic; expose the floored
   now-state/arrival on `RadarData` (`wkNowActive: Bool?`,
   `wkArrivalMinutes: Int?`) for Part B.
3. `StormApproachService.swift`: Part B centre override (new optional
   parameter or direct RadarService call; keep `displayedConditionCode`
   plumbing as is).
4. Unit tests: floor classification fixtures (0.05 → dry, 0.2 → wet edge,
   3.6 → wet); centre-override behavior with a stubbed RadarData; existing
   NextHourSummaryTests must pass unchanged.
5. Re-run the harness before/after on the same day; expect
   `centre_precip_source_seam` mismatches ≈ 0 for WK cities and no
   oversuppression rows.
6. In-app spot checks per NOWCAST_TESTING_GUIDE.md, plus a fog-night check
   at a Fog/Mist station city if one exists that day.
