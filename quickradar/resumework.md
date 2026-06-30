# Resume Work: WeatherFast Radar AI Description Project

**Purpose:** Load this file into a new Claude Code session to get fully current. Open it, say "read resumework.md and continue."

**Last updated:** 2026-06-24 (annotation dot built and working; CoreGraphics horizontal flip bug found and fixed)

---

## Project Summary

WeatherFast is an accessibility-first weather app. The radar feature uses Apple Foundation Models (iOS/macOS 27) to describe NWS NEXRAD radar images in plain language for blind users. This folder is the Mac-side research toolkit — capturing radar images, testing prompts, and building a dataset of AI vs. VoiceOver vs. NWS ground truth comparisons.

---

## Where We Are (June 24, 2026)

### What's Working

- **Two-frame movement analysis** correctly identifies precipitation over a city and describes what's moving toward/away from it. Tested during an active Madison thunderstorm — correctly reported "Madison WI is under precipitation, expect light rain in the coming hour."
- **Mac prompt testing loop**: `Test Live Radar.command` → Terminal opens → asks for city → runs FM → logs result → asks for another city. Results saved to `RadarData/test_logs/`.
- **Blue color fix**: The original prompts omitted blue entirely from the precipitation color list. Blue is the *most common* color on NWS radar (light rain, 5–35 dBZ) and the model was calling widespread light-rain scenes "clear." All prompt variants in both the iOS app and Mac tools are now fixed.
- **Lake Michigan vs. blue rain distinction**: Added explicit instruction that Lake Michigan is a solid fixed shape on the eastern edge, while blue precipitation patches are irregular and scattered anywhere on the map.
- **Annotation dot (location fix) — BUILT and working**: Red dot is projected from city lat/lon to pixel coordinates using the NEXRAD 248km coverage radius formula and drawn on the image before sending to FM. Verified: Madison dot landed in the storm center; Honolulu dot landed on Oahu's south shore. Both test_prompt.swift and fm_describe.swift generate annotated variants. The test script saves `annotated_current.png` and `annotated_prior.png` alongside raw GIFs in each run folder.
- **41-city archive sweep** with Alaska (PAHG, PAPD, PACG) and Hawaii (PHMO, PHKM).

### What's Still Unknown (Needing Data)

**Does the annotation dot actually improve FM accuracy?** The dot is built and data is being collected, but we don't yet have enough runs to compare annotated vs. unannotated FM accuracy against NWS ground truth. Each archive JSON contains `fm_description` and `fm_description_annotated` so this comparison is ready to make once we have ~20+ runs across varied weather conditions.

**Single-frame vs. two-frame**: Two-frame remains more reliable for location certainty. The annotation dot may close the gap for single-frame — unknown until data is analyzed.

---

## The "Local + Big Picture" Question

Kelly's question on June 24: "It's raining hard here but knowing that is just part of the picture. What's coming is also helpful."

**The answer: both paths are already partially built. They complement each other.**

### What Radar FM Covers
- **Right now, locally**: Single-frame radar image → plain-language description of current precipitation (once the location dot fix is in)
- **Next 30–60 minutes, movement**: Two-frame radar → "precipitation is moving northeast toward Madison at moderate speed, should arrive in about 20 minutes"
- **Storm structure**: Squall lines, cells, warning polygons visible on the map — things that data numbers don't convey

### What Existing Data Already Covers Better Than Radar FM
- **Next hour, minute-by-minute**: WeatherKit nowcast (already in the app, "Expected Precipitation" / "Next Hour" section). More reliable than extrapolating radar images.
- **Next 6–48 hours**: Open-Meteo hourly — precipitation probability, mm/hour, weather code. Already displayed in CityDetailView.
- **Storm motion direction/speed**: `StormApproachService` already samples surrounding lat/lon points every few minutes and computes approach direction. Already built, gated behind `stormApproachEnabled`.
- **Active warnings**: NWS alerts API (already in the app) gives authoritative text for US cities.

### The Ideal Combination (Already Partly Built)
1. **Radar FM single-frame** → "Heavy rain is falling over Madison right now, with a severe cell visible to the southwest"
2. **Radar FM two-frame** → "That cell is moving northeast at moderate speed, approaching Madison from the southwest"
3. **Storm Approach card** → "Storm arriving from 230° (SW), estimated 45 minutes away, moving at 28 mph" (computed from data, not AI)
4. **Next Hour / nowcast** → Minute-by-minute precipitation probability for the next 60 min
5. **Hourly forecast** → After that cell passes, clear by 3pm

The radar FM fills in the *visual/structural* picture that data can't express: squall line shape, storm cell intensity by color, warning polygon location relative to the city. Data fills in the *timeline* picture: when it starts, when it ends, how much. Together they're powerful.

---

## Branch State (docs/nowcasting-proposal)

This branch has 32 files changed, 8056 insertions vs. main. Decision made June 24:

**Strategy: Internal TestFlight only for now, not external.**

External users stay on main (current App Store build). Internal testers get the 1.6 build from this branch.

**New features ON by default (internal testers will see):**
- `nextHourNarrationEnabled` — plain-language "Next Hour" summary in Expected Precipitation
- `stormApproachEnabled` — Storm Approach card in Weather Around Me  
- `nowcastRefinementsEnabled` — renames "Expected Precipitation" → "Next Hour", inline card in CityDetail
- `weatherAroundMeImprovementsEnabled` — improved storm motion algorithm in Storm Approach
- `weatherRadarMapEnabled` — NWS radar map inside Weather Around Me

**New features OFF by default (invisible to external users when eventually shipped):**
- `foundationModelsRadarEnabled` — the FM radar description (iOS 27 only)
- `radarStructuredOutputEnabled`, `radarTwoFrameMovementEnabled` — additional radar modes

**Removed from this build (June 24):**
- `RadarAILogger` class and all in-app logging UI — replaced by Mac-side tooling
- `UIFileSharingEnabled` / `LSSupportsOpeningDocumentsInPlace` from Info.plist

**Version: 1.6 (build 4)**

---

## Prompt Bug History

### Bug 1: City-Anchoring (Fixed June 24)
**Old prompt:** "FIND the [city] label on the map and judge precipitation by what is immediately around that label."  
**Problem:** Model reported precipitation "near Madison" when it was 120 miles north near Sturgeon Bay. The zoom-out ~200km radius meant "immediately around the label" covered a huge area.  
**Fix:** Map-first framing. Describe where precipitation IS by naming cities/counties/features, then state whether the target city is under it.

### Bug 2: Blue = Water (Fixed June 24)
**Old prompt:** Listed precipitation colors as "(green, yellow, red, purple)." Told model "TEAL/CYAN AREAS: Bodies of water. Not precipitation."  
**Problem:** Blue is the most common radar color (light rain, 5–35 dBZ). The model was treating all blue as Lake Michigan and calling widespread light-rain scenes "clear." Confirmed during an active Madison thunderstorm — heavy red/orange cell right over Madison, model said "clear."  
**Fix:**
- Added "BLUE PATCHES scattered across the map: These ARE real precipitation (light rain, 5–35 dBZ). Blue is the most common precipitation color and must not be ignored or mistaken for water."
- Distinguished Lake Michigan as "solid fixed shape on the eastern edge" vs. "irregular scattered patches" for precipitation.
- Added blue to all color lists: "blue=light, green=light-moderate, yellow=moderate, red=heavy, purple=extreme"

### Bug 3: Single-Frame Location (Annotation dot fix BUILT — data collection in progress)
**Problem:** Model cannot reliably read the tiny "Madison" label text inside a colored precipitation echo in a 600×550 GIF. It describes precipitation "near Madison in Dane County" but won't commit to "Madison is under precipitation." Two-frame analysis is more reliable because frame comparison forces spatial reasoning.  
**Fix built June 24:** Red dot projected from city lat/lon onto radar pixel coordinates using NEXRAD 248km radius. Prompt says "the red dot marks [city]'s location — it overrides any city label text." Both test_prompt.swift and fm_describe.swift updated. Still need data to know if it actually improves accuracy.

### Bug 4: CoreGraphics Horizontal Flip in Annotated Images (Fixed June 24)
**Problem:** Annotated PNGs were horizontally mirrored — all map text appeared backwards, islands were flipped left-right. Raw GIFs were correct. Discovered on the Honolulu run (confirmed by reading `annotated_current.png` and comparing to `current.gif`).  
**Root cause:** CGContext y-flip transform (`translateBy(0,h)` + `scaleBy(1,-1)`) combined with `ctx.makeImage()` produced a horizontally mirrored bitmap for some images. Exact CG internal cause unclear; may be an interaction with how GIF palettes are decoded into CGImage on macOS 27 beta.  
**Fix:** Replaced CoreGraphics drawing with `NSBitmapImageRep` + `NSGraphicsContext` (AppKit). AppKit handles the CGImage coordinate flip internally without producing artifacts. Fix applied to both `test_prompt.swift` and `RadarData/fm_describe.swift`.  
**Data impact:**
- `test_logs/20260624_133407_Honolulu_HI/` — annotated PNGs are **FLIPPED** (pre-fix). FM descriptions from this run are still approximately correct (FM described the right conditions) but the dot was on the wrong side of the image.
- Archive run `20260624_132032` — annotated PNGs are **CORRECT**. fm_describe.swift ran after the fix was applied.
- All runs after June 24 session: correct.

---

## Weather Images Lab (new — June 29, expands beyond radar)

`quickradar/weather_lab.py` is a broader experiment: instead of one radar image,
it fetches a **whole suite of free NOAA/NWS weather imagery** for a location,
describes each with a prompt tailored to that image type, sonifies the local
radar into stereo audio, and emits an **accessible `report.html`** you read
top-to-bottom with VoiceOver (semantic headings, AI text as image alt, an
`<audio>` player per description, a skip link).

```bash
cd quickradar
python3 weather_lab.py 53703                  # Foundation Models (default), full suite
python3 weather_lab.py 53703 33101 90210      # multiple locations in one run
python3 weather_lab.py "Madison, WI" --ai both    # FM + Ollama side by side
python3 weather_lab.py 53703 --ai none --no-audio # fast fetch-only smoke test
python3 weather_lab.py 53703 --only radar_local,goes_ir
```

Multiple locations write one run folder each, then a master `runs/index.html`
lists all reports (newest first) with conditions + alerts — open that to scan
many places fast.

**Image suite (13 types, all free, no API key, gracefully skips any 404):**
- `radar_local` — nearest NEXRAD station base reflectivity (also sonified)
- `radar_national` — CONUS radar mosaic
- `goes_geocolor` / `goes_ir` / `goes_wv` / `goes_airmass` — GOES-19 regional
  sector (auto-picked from 9 sectors by nearest center): true color, Band 13
  clean IR (cloud-top height = storm strength), Band 9 water vapor (moisture /
  jet stream), Air Mass RGB (air masses + dry intrusions — reads very well)
- `forecast_qpf` / `forecast_qpf_day2` — WPC day-1 & day-2 precip amounts
- `surface_fronts` — WPC surface analysis (fronts, highs/lows)
- `tropical_atlantic` — NHC 7-day Atlantic tropical outlook (seasonal)
- `drought` — US Drought Monitor
- `snow_depth` — NOHRSC national snow depth (best-effort dated URL; empty in summer)
- `meteogram` — NWS hourly forecast graph for the exact point. URL needs the
  CORRECT forecast office (`wfo`) + zone, fetched per-point from the NWS points
  API; a hardcoded office returns a blank 800×40 strip. Tests AI graph reading.

Dead ends (moved to interactive/layered, dropped): NDFD `graphical.weather.gov`
static maps, SPC `day1otlk.gif` categorical outlook.

**Foundation Models reliability gotchas (June 29):**
- Each `describe_fm` call spins up the model in a fresh `swift` process. ~13
  rapid back-to-back calls hit transient `1001`/`1046` errors that cluster at the
  END of a run. `describe_fm` now retries those with 3s/6s backoff + a 1s settle
  between calls — clears them. Non-transient errors return short clean messages
  (no more giant nested NSError blobs in the report).
- The **US Drought Monitor map intermittently trips Apple's on-device Sensitive
  Content Analysis filter** (error 15) — likely the deep-red D4 areas. It's
  non-deterministic; retry often gets through. Handled as a clean
  "[FM declined this image — on-device sensitive-content filter]" note.
- Accuracy spot-check: FM read `snow_depth` as "snow near Madison (tan/white)"
  when tan/white = NONE — it misreads legend semantics. Reinforces: always pair
  with the ground-truth panel.

**AI backends** (`--ai`): `fm` = Apple Foundation Models via `run_fm_image.sh`
(wraps `fm_image.swift`, a generic image describer — the image-type-agnostic
sibling of test_prompt.swift; MUST run under Xcode-beta + MacOSX27 SDK, the
default toolchain lacks the `Attachment` API). `ollama` = local minicpm-v4.6.
`both` runs them for comparison. `none` skips AI.

**Audio experiment:** the local radar is turned into a 4-second **"audio radar
sweep"** (`*_sweep.wav`): 8 compass sectors clockwise from north, pitch rises
with precipitation intensity, volume with coverage, stereo pan follows E/W
(west = left ear). v1 uses image center ≈ radar station as the reference point.
(Text-to-speech of descriptions was removed June 29 — VoiceOver reads the text;
only this non-speech sonification remains. `--no-audio` skips it.)

**Key early insight (June 29 Madison run):** ground truth was "Mostly Clear,
90°F, Extreme Heat Warning" — but image-based descriptions never mention the
heat warning (it's invisible in imagery) and FM read light radar echoes (likely
hot-day ground clutter) as light rain. Lesson: imagery + AI is great for the
visual/structural picture but blind to non-visual hazards, so the `report.html`
always pairs descriptions with an NWS **ground-truth panel** (obs + alerts) so
you can judge accuracy. Output lands in `quickradar/runs/<timestamp>_<place>/`
(gitignored) with `images/`, `audio/`, per-image `.txt`, `data.json`, `report.html`.

---

## Tools

### Test One City (Mac, ~20-30 seconds)
```bash
cd ~/Documents/GitHub/FastWeather
./quickradar/run_test_prompt.sh "Madison WI"
./quickradar/run_test_prompt.sh Houston
./quickradar/run_test_prompt.sh            # all cities
```
Or double-click **`RadarData/Test Live Radar.command`** in Finder for the interactive loop.

Each run saves to `RadarData/test_logs/TIMESTAMP_CITY/`:
- `current.gif` / `prior.gif` — raw radar frames
- `annotated_current.png` / `annotated_prior.png` — with red dot marking city
- `results.txt` — all four FM descriptions (with/without annotation × single/movement)

Supports 65 cities by name or station ID. Zip codes and commas are stripped automatically.

### Full Archive Run (Mac, ~5 min)
Downloads fresh radar for 20+ cities, runs FM on both unannotated and annotated images,
fetches NWS ground truth data, saves everything to `RadarData/runs/TIMESTAMP/`.
```bash
cd ~/Library/CloudStorage/OneDrive-Personal/RadarData
./run_archive.sh
./run_archive.sh --no-fm      # images + NWS data only, skip Foundation Models
```
Or double-click **`RadarData/Capture Radar Images.command`**.

Each city JSON now includes: `city_lat`, `city_lon`, `station_lat`, `station_lon`,
`fm_description` (unannotated), `fm_description_annotated`, and `annotated_file`.
Annotated PNG saved to `runs/TIMESTAMP/annotated/`.

### Build and Deploy to Phone
```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
xcodebuild -project iOS/FastWeather.xcodeproj -scheme FastWeather \
  -configuration Debug -destination 'id=00008130-000A11502811401C' build \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"

APP=$(find ~/Library/Developer/Xcode/DerivedData/FastWeather-*/Build/Products/Debug-iphoneos/WeatherFast.app -maxdepth 0 | head -1)
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
xcrun devicectl device install app --device "Kelly Ford" "$APP"
```

---

## Prompt File
`~/Library/CloudStorage/OneDrive-Personal/RadarData/prompt.txt`

Edit this to change what the AI is asked. Uses `{CITY}` and `{LOCATION_HINT}` placeholders. The iOS app uses its own built-in prompts in `RadarFoundationModelsService.swift` (same structure, keep in sync).

---

## Data on Disk

```
RadarData/ (OneDrive)
  prompt.txt                 ← EDIT THIS to change the prompt
  fm_describe.swift          ← Foundation Models runner (batch mode)
  run_archive.sh             ← main capture script
  Capture Radar Images.command  ← Finder launcher (full archive run)
  Test Live Radar.command    ← Finder launcher (interactive single-city test + loop)
  test_logs/
    TIMESTAMP_CITY.txt       ← results from interactive test runs (new June 24)
  phone_logs/
    radar_ai_log.jsonl       ← 9 entries logged in-app (June 20-24, pre-1.6)
    images/                  ← 14 radar images pulled from phone
  runs/
    TIMESTAMP/
      images/*.png           ← radar images
      data/*.json            ← NWS metadata + pixel analysis + FM description
      fm/*.txt               ← Foundation Models descriptions
      voiceover/*.txt        ← VoiceOver descriptions (paste manually)
      summary.json
  index.jsonl                ← cumulative index across all runs
```

---

## What's Next

**Priority 1: Analyze annotation data**  
Archive run `20260624_132032` has 41 cities with both `fm_description` and `fm_description_annotated` plus NWS ground truth (`nws_has_precip`, `nws_conditions`). Compare accuracy: does the annotated variant more reliably match NWS ground truth? Look especially at cities where NWS says "has precip" — does FM with dot say the city is under precipitation more often than FM without dot?

**Priority 2: More test data under varied conditions**  
Keep running `Test Live Radar.command` during active weather. Target: 20+ logged descriptions with a mix of:
- Heavy precipitation directly over city (like the June 24 Madison thunderstorm)
- Clear sky
- Precipitation approaching from one direction
- Active warning polygon visible on map

**Priority 3: Internal TestFlight build**  
Upload 1.6 from `docs/nowcasting-proposal` to TestFlight internal track. Validate Storm Approach, Next Hour narration, and radar map with trusted testers. When confident, cherry-pick mature features (Next Hour, Storm Approach) to main for external users.

**Priority 4: "Big picture" integration**  
The combination already exists in the app: radar FM (visual/structural) + Storm Approach (data-driven motion) + Next Hour nowcast (timeline). The missing piece is surfacing these together in a coherent way. The radar map sheet in WeatherAroundMeView shows the map; the description and Storm Approach card are already adjacent. Consider: does the FM description need to be more aware of the Storm Approach data, or is side-by-side presentation enough?
