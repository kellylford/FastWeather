# datatesting — nowcast data validation outside the app

`nowcast_data_test.py` validates the `nowcast-port` branch's data layer against
the same live APIs the app uses, with line-for-line Python ports of the Swift
algorithms (each function cites its Swift source). The idea: prove the data is
good before spending time exploring it in the app.

**This copy (in the repo) is canonical.** A runnable copy plus a Finder
double-clickable wrapper (`Test Nowcast Data.command`) lives in
`~/Library/CloudStorage/OneDrive-Personal/RadarData/`; if you change the
script, update both (or re-copy).

## What it does

1. **Finds interesting weather automatically** (the successor to quickradar's
   hand-curated storm-chase list): NWS active alerts (severe thunderstorm,
   tornado, flood, winter events) mapped to the nearest bundled city, plus an
   Open-Meteo current-precipitation scan across ~190 candidate cities
   worldwide. ~60% of the run is active-weather cities, the rest a fixed
   baseline spread (including international, which exercises the 2-hour
   narration phrasing).
2. **Per city, replicates both the NEW and OLD data paths:**
   - Storm Approach improved (steering winds, 16×3 ring, confidence) and
     legacy (centroid, 8×2 ring) — `weatherAroundMeImprovementsEnabled` on/off
   - The OLD wind-inferred "nearest precipitation" block
     (`RadarService.findNearestPrecipitation`) that Storm Approach replaces
   - The Next Hour narration (Open-Meteo `minutely_15` path — the same
     summarizer function the WeatherKit path feeds)
3. **Cross-checks them:** new-vs-old direction delta, steering-vs-centroid
   delta (the confidence input), arrival agreement, narration-vs-Storm-Approach
   same-city agreement, phantom-thunderstorm candidates (raw Open-Meteo storm
   code with zero measurable rain — the cases the port's re-pointed
   reconciliation exists for).

## Output (per run)

`<output-root>/run-YYYYMMDD-HHMMSSZ/`
- `results.csv` — long format: `data_name`, `app_location`, `new_value`
  (feature on), `old_value` (feature off), plus flags compared, the check
  applied, `check_result` (`ok` / `review` / `mismatch` / `n_a`), details.
- `cities.csv` — one wide row per city with every numeric metric
  (bearings, deltas, mm rates, confidence, phantom flag, both headlines).
- `summary.json` — run metadata, API-call count, check-result tallies.
- `run.log` — per-city progress and errors.

## Usage

```bash
python3 datatesting/nowcast_data_test.py                 # 100 cities
python3 datatesting/nowcast_data_test.py --cities 20     # quicker pass
python3 datatesting/nowcast_data_test.py --output-root ~/somewhere
```

No dependencies beyond Python 3 stdlib. Uses the paid Open-Meteo key from
`iOS/FastWeather/Services/Secrets.swift` automatically (or
`OPEN_METEO_API_KEY` env var); falls back to the free tier. A 100-city run is
~310 API calls.

## Known deviations from the app (documented in the script header)

1. Legacy-path time indexing uses `timeformat=unixtime` instead of local ISO +
   `DateParser` — index selection is mathematically identical; every other
   query parameter matches the app.
2. WeatherKit paths can't run outside an entitled app bundle. The narration
   tested is the Open-Meteo `minutely_15` path; the summarizer function itself
   is shared and separately locked by `FastWeatherTests/NextHourSummaryTests`.
3. "Saved cities" are stand-ins: the 3 nearest bundled cities 40–250 km away
   (app filter is >1 km, ≤250 km, nearest 5 of the user's real list).

## Reading the results

- `check_result=mismatch` rows are the ones to investigate first —
  especially `next_hour_summary` (same-city surfaces must agree) and
  `arrival_at_location` (same source data, so >30 min apart is a bug smell).
- `precip_direction` mismatches are usually the *old* method being wrong
  (surface-wind guessing) — that's the justification for Storm Approach, not
  a bug in it. Confirm by comparing against any radar source.
- `phantom_thunderstorm=True` cities in `cities.csv` are where the old
  reconciliation gate would have contradicted the WeatherKit-informed main
  screen — spot-check those in the app.
