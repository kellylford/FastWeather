# Nowcast data-quality analyses

Preserved findings from the tools/datatesting harness runs (analysis only —
raw per-run CSV/JSON data stays in the OneDrive RadarData folder, in the run
directory named in each document). All three were produced against live
weather with line-for-line ports of the app's Swift algorithms, adjudicated
where possible by NWS station observations.

Reading order:

1. `2026-07-04-first-validation-run.md` — first 100-city validation of the
   ported nowcast features (run-20260704-102618Z). Established that the Next
   Hour narration and Storm Approach agree when reading the same source, that
   the old wind-inferred direction method was measurably wrong (5 mismatches,
   all old-method errors), and that the confidence ladder works.
2. `2026-07-05-seam-instrumented-run.md` — first run with WeatherKit sampled
   via REST (run-20260705-113125Z). Measured the two-source seam: 19% of
   WeatherKit-covered cities had the Next Hour card and Storm Approach
   contradicting each other during active weather; characterized the failure
   modes (WeatherKit low-intensity radar phantoms vs Open-Meteo spin-up
   lag/decay persistence).
3. `2026-07-05-baseline-with-nws-referee.md` — quiet-day baseline with the
   NWS-station referee (run-20260705-115037Z). Background seam rate ~11.6%
   (9.5% among truly quiet cities); referee sided with WeatherKit 2-0 when
   the sources disputed "raining now"; concluded the data sufficed to spec
   the fix.

Outcome: docs/NOWCAST_CENTRE_AUTHORITY_SPEC.md (single centre authority +
0.2 mm/h intensity floor), harness-verified across 102 simulated cities
(zero oversuppression, 9/9 real-rain preserved) and implemented behind
nowcastCentreAuthorityEnabled.
