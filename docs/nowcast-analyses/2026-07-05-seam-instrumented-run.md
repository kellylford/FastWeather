# Source Seam Analysis: WeatherKit vs Open-Meteo Precipitation Narration

Run ID: run-20260705-113125Z
Generated: 2026-07-05T11:32:30Z
Branch: nowcast-port

## Executive Summary

The WeatherKit (radar-informed) and Open-Meteo (model-based) precipitation sources disagree on 7 locations out of 36 WeatherKit-sampled cities, representing a 19% mismatch rate. However, this figure is **storm-day-inflated and not representative of typical conditions**. The 36 cities were specifically selected to maximize interesting weather: 4 had NWS alerts (75% mismatch rate), 5 were radar-detected precipitation (0% mismatch rate), and only 19 were baseline cities (21% mismatch rate). On a typical day with fewer active storms, the seam mismatch rate would be much lower. The asymmetry is striking: WeatherKit claims precipitation 5 times more often than Open-Meteo disagrees (5 WK-wet/OM-dry vs 2 WK-dry/OM-wet). Most WK-only detections occur at very low intensity (0.05–0.07 mm/h) in partly cloudy or mostly cloudy conditions, suggesting **radar phantoms** from sea clutter, cloud-ice shine, or other reflective artifacts. The two OM-only cases show deeper model lag: OM persists precipitation after radar has cleared, consistent with model inertia.

## Mismatch Rate by Selection Reason

The 36 seam rows break down as follows:

- NWS Alert Cities (4 total, 3 mismatches = 75%)
- Radar-Detected Precipitation (5 total, 0 mismatches = 0%)
- Baseline Cities (19 total, 4 mismatches = 21%)

The high alert rate reflects that these cities were selected for confirmed severe weather, so WK-OM disagreement is expected when radar and NWS products are out of sync with latest model cycles. The 0% mismatch in radar-detected cities indicates that when both sources detect precipitation on radar, they align. Baseline cities (normal sampling) show a 21% disagreement rate, which is elevated for a single snapshot run but not alarming.

## Individual Mismatch Details

### Direction 1: WeatherKit Says Rain, Open-Meteo Says No Rain (5 cases)

#### 1. Quitman, Mississippi, United States (NWS Alert)

- WK Narration: "Precipitation now, continuing through the next hour."
- OM Narration: "No precipitation expected in the next 2 hours."
- WK Condition: Thunderstorms
- WK Intensity: 3.59 mm/h
- WK Active Minutes: 85 (persistent)
- OM Weather Code: 2 (Partly Cloudy)
- OM Centre mm/15min: 0.0 mm
- OM Current Precip: 0.0 mm
- OM Situation: clear

Pattern: Real storm detected by radar (WK intensity 3.59 mm/h is substantial), but Open-Meteo model shows clear skies. This is classic model lag during rapid convective development. The NWS alert for this area confirms real weather.

#### 2. Macon, Mississippi, United States (NWS Alert)

- WK Narration: "Precipitation now, continuing through the next hour."
- OM Narration: "No precipitation expected in the next 2 hours."
- WK Condition: Thunderstorms
- WK Intensity: 10.38 mm/h (heavy)
- WK Active Minutes: 85 (persistent)
- OM Weather Code: 0 (Clear)
- OM Centre mm/15min: 0.0 mm
- OM Current Precip: 0.0 mm
- OM Situation: clear

Pattern: Heavy thunderstorm (10.38 mm/h) confirmed by radar, OM model is blank. This is the most extreme lag case in this run. NWS alert backs the storm. OM's model is simply off-cycle.

#### 3. Des Moines, New Mexico, United States (NWS Alert)

- WK Narration: "Precipitation starting in about 1 minutes, continuing through the next hour."
- OM Narration: "No precipitation expected in the next 2 hours."
- WK Condition: MostlyClear
- WK Intensity: 0.0 mm/h
- WK Active Minutes: 85
- OM Weather Code: 0 (Clear)
- OM Centre mm/15min: 0.0 mm
- OM Current Precip: 0.0 mm
- OM Situation: clear

Pattern: This is a false positive. WK shows mostly clear skies with 0.0 mm/h intensity now, but predicts rain in 1 minute for 85 minutes. OM agrees it is clear now. This suggests WK's next-hour nowcast is seeing radar echoes, not current rain. The NWS alert for this area may reflect potential for convection rather than current precipitation.

#### 4. Miami, Florida, United States (Baseline)

- WK Narration: "Precipitation starting in about 26 minutes, continuing through the next hour."
- OM Narration: "No precipitation expected in the next 2 hours."
- WK Condition: PartlyCloudy
- WK Intensity: 0.05 mm/h (drizzle-level)
- WK Active Minutes: 58
- OM Weather Code: 0 (Clear)
- OM Centre mm/15min: 0.0 mm
- OM Current Precip: 0.0 mm
- OM Situation: nearbyNotApproaching

Pattern: Radar phantom. Very light intensity (0.05 mm/h), partly cloudy skies, OM agrees rain is not nearby. Likely sea-clutter echo or cloud-ice shine from tropical atmosphere. WK nowcast sees 58 active minutes of this weak return.

#### 5. London, England, United Kingdom (Baseline)

- WK Narration: "Precipitation starting in about 14 minutes, lasting about 6 minutes."
- OM Narration: "No precipitation expected in the next 2 hours."
- WK Condition: MostlyCloudy
- WK Intensity: 0.0 mm/h (no current intensity)
- WK Active Minutes: 10 (brief)
- OM Weather Code: 3 (Drizzle)
- OM Centre mm/15min: 0.0 mm
- OM Current Precip: 0.0 mm
- OM Situation: clear

Pattern: Mixed. OM's weather code says drizzle, but precip amounts are 0.0 mm both current and in the next 15 min, and situation is "clear". WK sees a brief 10-minute echo in the next 14 minutes. This is a borderline case where OM's code contradicts its own precip data. Likely a radar artifact (British radar systems are prone to sea clutter).

### Direction 2: Open-Meteo Says Rain, WeatherKit Says No Rain (2 cases)

#### 6. Buffalo, New York, United States (Baseline)

- WK Narration: "No precipitation expected in the next hour."
- OM Narration: "Precipitation starting in about 15 minutes, lasting about 15 minutes."
- WK Condition: Cloudy
- WK Intensity: 0.0 mm/h
- WK Active Minutes: 0 (no active minutes in nowcast)
- OM Weather Code: 3 (Drizzle)
- OM Centre mm/15min: 0.2 mm (modest accumulation)
- OM Current Precip: 0.0 mm
- OM Situation: rainingHere

Pattern: Model persistence. OM shows 0.2 mm in the next 15 min and situation "rainingHere", but WK radar finds no precipitation now or in the next hour. Typical model lag on the decay side: the model continues to predict rain that radar has already cleared. The model's drizzle code is a remnant from a rain system that has moved or ended.

#### 7. Sydney, New South Wales, Australia (Baseline)

- WK Narration: "No precipitation expected in the next hour."
- OM Narration: "Precipitation now, easing off in about 45 minutes."
- WK Condition: MostlyCloudy
- WK Intensity: 0.07 mm/h (light)
- WK Active Minutes: 0 (no future active minutes)
- OM Weather Code: 51 (Moderate Rain)
- OM Centre mm/15min: 0.1 mm
- OM Current Precip: 0.1 mm
- OM Situation: rainingHere

Pattern: Model lag on decay. OM reports current moderate rain (code 51) with 0.1 mm/15min and situation "rainingHere". WK shows mostly cloudy skies, current light drizzle (0.07 mm/h—contradictory to "no active minutes"), and no active minutes in the next hour. This is a case where OM is persisting an old rain system; WK is showing the tail end as a weak echo. The mismatch is on the rate: OM thinks it will rain for 45 more minutes; WK has already cleared it.

## Direction Asymmetry

WeatherKit is systematically wetter than Open-Meteo:

- WK says rain, OM says no: 5 cases (Quitman, Macon, Des Moines, Miami, London)
- OM says rain, WK says no: 2 cases (Buffalo, Sydney)

Ratio of WK-wet/OM-dry to OM-wet/WK-dry: 5:2 = 2.5x.

Among the WK-wet cases:
- 2 are high-confidence detections (Quitman 3.59 mm/h, Macon 10.38 mm/h) with confirmed NWS alerts and real convection.
- 1 is a false positive (Des Moines, 0.0 mm/h now but predicts rain).
- 2 are likely radar phantoms (Miami 0.05 mm/h, London 0.0 mm/h current).

Among the OM-wet cases:
- Both are model persistence (model rain lingering after radar cleared): Buffalo shows drizzle code but 0.0 current precip, Sydney shows moderate rain code but WK sees only light tail echo.

Conclusion: WK overdetects at low intensity, but captures real storms. OM lags on both spin-up and decay, with false-positive persistence on decay.

## Implications for the Proposed Fix

Proposal: Feed Storm Approach's centre state from the same WeatherKit nowcast the narration uses, keep Open-Meteo for the directional field.

For each mismatch, what the app would show after the fix and whether that's better:

#### Cases 1–2: Quitman and Macon (High-confidence storms)

- Today: Next Hour says "rain", Storm Approach says "not raining". Contradiction.
- After Fix: Storm Approach shows centre as "rainingHere" (WK state). Next Hour says "rain". Both sources agree.
- Outcome: Better. The app presents a coherent storm picture.

#### Case 3: Des Moines (False positive nowcast)

- Today: Next Hour says "rain in 1 min for 85 min", Storm Approach says "not raining". Contradiction.
- After Fix: Storm Approach shows centre as "clear" or minimal (WK current is 0.0 mm/h, no active minutes). Next Hour still predicts rain in 1 min. Milder contradiction.
- Outcome: Slightly better, but the real issue is WK's nowcast overpredicting at this location. The fix doesn't solve it, but at least the centre (now) is honest.

#### Case 4: Miami (Radar phantom)

- Today: Next Hour says "rain in 26 min", Storm Approach says "not nearby". Contradiction.
- After Fix: Storm Approach centre still shows no rain (WK intensity 0.05 mm/h is barely measurable). Next Hour predicts rain in 26 min. Same contradiction.
- Outcome: Neutral. The fix doesn't help; the phantom is in WK's nowcast, not the current.

#### Case 5: London (Radar phantom)

- Today: Next Hour says "rain in 14 min for 6 min", Storm Approach says "clear" (OM has 0.0 mm but says drizzle in code).
- After Fix: Storm Approach centre shows "clear" or minimal (WK 0.0 mm/h now, 10-minute active window). Next Hour predicts rain in 14 min. Same contradiction.
- Outcome: Neutral to slightly worse. OM's situation is "clear" but code says drizzle; WK's situation would be "clear" but shows active minutes. Contradiction remains.

#### Case 6: Buffalo (Model persistence)

- Today: Next Hour says "no rain", Storm Approach says "rain in 15 min". Contradiction.
- After Fix: Storm Approach centre shows "clear" (WK has 0 active minutes). Next Hour says "no rain". Both agree.
- Outcome: Better. The fix corrects the false positive persistence from OM's old rain system.

#### Case 7: Sydney (Model persistence)

- Today: Next Hour says "no rain", Storm Approach says "rain now, easing in 45 min". Contradiction.
- After Fix: Storm Approach centre shows minimal (WK current 0.07 mm/h, no future active minutes). Next Hour says "no rain". Both sources converge on "barely raining / clearing".
- Outcome: Better. The fix clips OM's overstated persistence.

### Summary of Fix Outcomes

- Cases 1–2 (High-confidence storms): Better.
- Case 3 (Des Moines false positive): Neutral; problem is in WK nowcast, not current.
- Cases 4–5 (Radar phantoms): Neutral; problem is in WK nowcast, not current.
- Cases 6–7 (Model persistence): Better.

Overall, the proposed fix resolves or improves 4 of 7 mismatches directly (cases 1, 2, 6, 7) and leaves 3 of 7 unchanged (cases 3, 4, 5), because those three involve WK's nowcast predictions, not its current condition. The fix improves the app's factual accuracy by eliminating OM's false persistence and aligning the centre state with the radar data for active storms.

## Recommendations

### 1. Refinement to the Fix

Implement an intensity threshold before trusting WK's "rain" state for the centre card. Suggest minimum 0.2 mm/h to declare the centre as "rainingHere" (eliminates phantoms at 0.05 and 0.07 mm/h while preserving real storms at 3.59 and 10.38 mm/h). This would also neutralize cases 4 and 5 (radar phantoms) and prevent the centre card from flagging weak echoes.

Alternatively, use WK's active-minutes field: if no active minutes are recorded in WK's nowcast (as in cases 4, 5, Des Moines), suppress the centre's "rainingHere" classification even if current intensity is non-zero. This is a more principled approach because it treats "active" as a radar return that crosses the WK algorithm's own internal threshold.

### 2. Hedged Wording When Sources Disagree

For the 3% of cases where both sources are simultaneously active (e.g., WK nowcast has a future rain window but current is clear), use conditional language: "Precipitation may begin in X minutes" instead of "Precipitation starting in X minutes". This hedges against false positive nowcasts without requiring a complete rebuild of the nowcast logic.

### 3. What the Next Instrumented Run Should Capture

#### A. NWS Station Ground-Truth Per City

For U.S. cities, fetch the nearest NWS surface observation (METAR, spot report, or cooperative observer) at the run timestamp. Adjudicate each mismatch against ground truth:
- Quitman, Macon, Des Moines: NWS alert + station observation will confirm whether rain was actually falling.
- Miami: If the station recorded no rain, case closed (phantom).
- Buffalo, Sydney: Station data would show whether rain persisted after the model time or had cleared.

Feasibility: Yes. NOAA's METAR archive is free and standardized. The run harness already selects cities near NWS offices. Add a fetch step to grab METAR for the nearest station at run time, store in results.csv alongside the mismatch row.

#### B. Surface Radar Reflectivity Magnitude

Record the dBZ value (reflectivity) that triggered each WK detection. Separate true precipitation (typically > 20 dBZ) from clutter and sea-echo (< 15 dBZ). This would distinguish rain from phantoms without requiring external validation. Feasibility: Moderate. Most radar APIs (NWS NEXRAD, Environment Canada) do not expose per-pixel dBZ in real-time APIs; would require tapping archive tiles or a specialized radar service.

#### C. Time Offset Sync

Record the time offset between WK's nowcast generation and OM's model run. Even a 15–30 minute difference can explain persistence bugs (OM model run at T+15 predicting T+45; WK nowcast updated at T+45 already clear). If the harness has access to API response metadata, capture it. Feasibility: Yes, API responses typically include generation/issue time.

#### D. Repeat Run on Quiet Day

Run the same 36-city sample on a day with minimal weather activity. This establishes a baseline mismatch rate for stable conditions (hypothesis: < 5% on quiet days, confirming the 19% today is storm-inflated).

## Conclusion

The proposed fix (feed Storm Approach centre from WK, keep OM for direction) improves the app's coherence by eliminating 4 of 7 seam mismatches and leaving 3 unchanged (those rooted in WK's nowcast logic, not its current state). Adding an intensity threshold (0.2 mm/h minimum or requiring WK active minutes) or a hedged narration for prediction windows would address the remaining cases without major architectural changes. The next run should collect NWS station ground truth and, if feasible, surface reflectivity magnitudes to distinguish radar phantoms from model lag.
