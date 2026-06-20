# Resume Work: QuickRadar + WeatherFast AI Radar Description Project

**Purpose:** Load this file into a new GitHub Copilot Chat session on your Mac to get the AI agent current on everything we've done and what's next. Just open this file, start a chat, and say "read this file and continue."

**Last updated:** 2026-06-20 (logging + ground-truth comparison session — KEY FINDING: VoiceOver beats Foundation Models on radar images; see "Comparison Findings" section)

---

## Current State (June 19, 2026)

### What's Built and Working

The iOS 27 Foundation Models radar description is **fully implemented and committed** on the `docs/nowcasting-proposal` branch (commit `912e5b7`). It builds with Xcode 27 beta and runs on Kelly's iPhone 15 Pro (iOS 27.0 beta). When the on-device model is loaded, it produces good radar descriptions — the model sees the NWS radar image with the custom QuickRadar prompt and describes precipitation, intensity, storm structure, and warnings.

**The code works.** The intermittent failure is a beta OS issue (see Known Issues below).

### What Was Done This Session

1. **Researched the actual SDK APIs** by inspecting the `.swiftinterface` files in both Xcode 26.3 and Xcode 27 beta SDKs on Kelly's Mac. Key finding: `Attachment(cgImage)` and `PrivateCloudComputeLanguageModel` are **iOS 27.0 only** — not iOS 26 as Apple's online docs claim. The other AI agent's `IOS26_VS_IOS27.md` document was based on WWDC25 announcement docs, not the shipping SDK.

2. **Raised the deployment target** from iOS 17.0 to iOS 27.0 for this branch. The `main` branch is untouched (still iOS 17.0, builds with Xcode 26, ships normally).

3. **Created `RadarFoundationModelsService.swift`** — the core iOS 27 service:
   - Sends the NWS RIDGE radar GIF to `LanguageModelSession` via `Attachment(cgImage)` with the custom QuickRadar prompt
   - Supports `@Generable` structured output (`GenerableRadarAnalysis` struct)
   - Two-frame movement detection (downloads loop GIF, extracts first/last frames ~40-60 min apart)
   - Private Cloud Compute fallback (`PrivateCloudComputeLanguageModel`)
   - Model path picker: Auto / On-Device / Private Cloud
   - Vision capability check (`capabilities.contains(.vision)`)
   - Retry logic: on-device → 5s wait → retry → cloud fallback (for error 1046)

4. **Created `RadarAnalysisGenerable.swift`** — `@Generable` struct with typed fields (hasPrecipitation, intensity, direction, hasWarnings, description) plus a plain `RadarAnalysis` Codable struct for app-wide use.

5. **Updated `RadarDescriptionService.swift`** — routes to Foundation Models when flag is on, falls back to image-only accessibility label when off. Added `findNearestStation`, `downloadImage`, `downloadLoopFrames` bridges. Removed broken `VNGenerateImageObservationsRequest` (doesn't exist in Xcode 26.3+ or 27.0 SDKs).

6. **Updated `RadarCrossValidation.swift`** — new `validate(stormApproach:analysis:)` overload using typed `direction` field. Fixed pre-existing comment syntax bug.

7. **Updated `RadarMapView.swift`** — prompt editor (view/edit/customize the AI prompt), error display (was silently swallowed), structured analysis card, two-frame movement card, model path awareness.

8. **Updated `DeveloperSettingsView.swift`** — new "AI Radar Description (iOS 27+)" section with: Foundation Models Radar toggle, Structured Output toggle, Two-Frame Movement toggle, Model Path picker, Detail Level picker.

9. **Updated `FeatureFlags.swift`** — 5 new flags (all OFF by default): `foundationModelsRadarEnabled`, `radarStructuredOutputEnabled`, `radarTwoFrameMovementEnabled`, `radarModelPath` (auto/on-device/cloud), `radarDescriptionDetailLevel` (brief/standard/detailed).

10. **Updated `ListView.swift` and `FlatView.swift`** — VoiceOver "Open Radar Map" accessibility action on every city for quick access to radar. Also added "Radar Map" button to FlatView Actions menu.

11. **Updated `WeatherAroundMeView.swift`** — uses structured analysis for cross-validation when available.

12. **Refined prompts** — city name included in prompt, no "quadrant" language, user-centered compass directions, distinguishes "at your location" vs "nearby."

### VoiceOver Image Accessibility Lessons (June 20, 2026)

Hard-won from debugging VoiceOver not finding radar images on the radar map screen:

**1. `.accessibilityElement(children: .contain)` on a container breaks normal swipe navigation.**
When a `VStack` or other container has `.accessibilityElement(children: .contain)`, VoiceOver treats the entire container as a "group" element. Users must perform an extra gesture to enter the group before they can swipe through its children. This broke ALL element navigation in `RadarMapSheet` — not just the images, but the description cards and buttons too. **Fix: remove this modifier entirely.** Without it, SwiftUI's default traversal lets VoiceOver swipe through all children naturally.

**2. `Image(uiImage:)` with `.accessibilityLabel()` alone is NOT guaranteed to be a VoiceOver element.**
Adding a label to a SwiftUI Image does not always make it an accessibility element. You need `.accessibilityElement(children: .ignore)` first to explicitly declare it as one, then add the label and trait:
```swift
Image(uiImage: image)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("NWS radar image")
    .accessibilityAddTraits(.isImage)
```

**3. `.accessibilityAddTraits(.isImage)` enables iOS 27 VoiceOver image description.**
With the `.isImage` trait set and the element properly declared, iOS 27's expanded VoiceOver image description feature can be triggered on the element (two-finger tap-and-hold). This lets you compare Apple's built-in image description against our Foundation Models prompt output on the same radar image.

**4. The `.accessibilityElement(children: .ignore)` + `.accessibilityAddTraits(.isImage)` pattern must NOT be used inside a container that has `.accessibilityElement(children: .contain)`.** The two fight each other. Remove `.contain` from the parent first.

---

### Radar AI Logging System (June 20, 2026)

A `RadarAILogger` class was added to `RadarFoundationModelsService.swift`. It:
1. Fetches live NWS conditions (temperature, wind, sky) and active alerts at the moment a description is logged
2. Writes a JSON line to `Documents/radar_ai_log.jsonl` in the app container
3. Prints each entry to the debug console with `[RADAR_LOG]` prefix

**Accessing the log file:**
- **Files.app on iPhone**: `UIFileSharingEnabled` was added to `Info.plist`. Open Files.app → On My iPhone → Weather Fast → `radar_ai_log.jsonl`
- **Finder on Mac (USB)**: Connect phone, open Finder, select the phone, go to Files → Weather Fast
- **Console capture**: Launch with `--console` flag; every log entry prints with `[RADAR_LOG]` prefix
- **Pull with devicectl**: `xcrun devicectl device copy files --from-device "Kelly Ford" --source "Documents/radar_ai_log.jsonl" --destination /tmp/`

**Log entry fields:**
- `timestamp`, `city`, `cityLat`, `cityLon`, `stationId`, `stationName`, `promptMode`
- `aiDescription`, `aiHasWarnings`, `aiIntensity`, `aiDirection` (from structured output when available)
- `nwsObsStation`, `nwsConditions`, `nwsTempC`, `nwsWindDirDeg`, `nwsWindSpeedKmh`
- `nwsAlerts` (list of active NWS alert event names, e.g. ["Severe Thunderstorm Warning"])
- `warningMismatch` (true when AI claims warnings but NWS has none — the key QA field)

**Usage**: After tapping "Describe Radar" and a description appears, tap "Log Result with NWS Ground Truth". The button fetches NWS data live (takes ~2-3 seconds), writes the entry, then shows "Logged at HH:mm".

---

### Radar AI Hallucination Root Cause (June 20, 2026)

A QuickRadar experiment on the Mac (using `llava:latest` with the KMKX radar image for Madison, WI) identified the root cause of the on-device model claiming severe thunderstorm warnings on a clear day:

**The NWS RIDGE radar image contains a legend at the top** showing colored boxes labeled:
- TORNADO (red box), SEVERE THUNDERSTORM (orange box), FLASH FLOOD (green box), SPECIAL MARINE (yellow box), SNOW SQUALL (pink box)

These are reference labels showing what warning polygon colors look like. They are NOT active warnings. However, vision models see colored boxes in the image and report "warnings visible."

**Secondary source of confusion:** The red/brown county and state border lines that cover the entire map look exactly like warning polygons to a model without meteorological visual training. County borders are county-sized colored line boxes drawn on the map — visually identical to what an actual warning polygon would look like.

**NWS ground truth at time of test (2026-06-20 08:50 CDT):**
- KMSN (Madison): Clear, 62.6°F, NNW winds 9.2 mph, CLR at 12,500 ft, no precipitation
- The radar map was completely blank (white) — zero precipitation anywhere in the image
- Sunny forecast, no active alerts

**`llava:latest` with old prompt** claimed: precipitation approaching from west-northwest, no warnings (different wrong answer from on-device model's thunderstorm claim)
**`llava:latest` with updated prompt** still hallucinated warning polygons (confusing county borders for warning outlines)
**Foundation Models on-device** claimed: severe thunderstorm warning (confusing legend boxes for active warnings)

**What makes Foundation Models different from llava:** The on-device model is much stronger at visual reasoning and correctly reads the legend colors — but it interprets the legend AS the warning. The new prompts explicitly tell the model the legend is reference-only, white/blank = no precipitation, and red grid lines are county borders.

**Updated prompts (all three modes, both single-frame and two-frame variants) now include:**
```
IMPORTANT — things in this image that are NOT precipitation or warnings:
• TOP OF IMAGE: A legend strip showing colored boxes labeled TORNADO (red),
  SEVERE THUNDERSTORM (orange), FLASH FLOOD (green), SPECIAL MARINE (yellow),
  SNOW SQUALL (pink). These are labels — NOT active warnings. Ignore them.
• BOTTOM OF IMAGE: A color scale bar (dBZ). Reference only.
• RED/BROWN LINES throughout the map: County and state border lines. NOT warnings.
• TEAL/CYAN AREAS: Bodies of water (e.g., Lake Michigan). Not precipitation.
• White/blank map area = no precipitation.
```

The key remaining open question: whether the Foundation Models are capable enough to reliably follow this guidance. The Log Result button will capture the evidence.

---

### Comparison Findings — VoiceOver vs Foundation Models (June 20, 2026, Session 2)

**THIS IS THE MOST IMPORTANT SECTION. Read it before doing any more prompt work.**

We built the logging system (below), captured real on-device results with saved images, and compared three voices on the *same* radar frame: Apple VoiceOver, our Foundation Models prompt, and NWS ground truth. The verdict is consistent and stark.

**Apple's built-in VoiceOver image description is dramatically more accurate than our Foundation Models prompt on these NWS radar images.**

Logged evidence (4 entries in `radar_ai_log.jsonl`; images in `radar_images/`):

| Entry | Scene (ground truth) | VoiceOver | Foundation Models |
|-------|----------------------|-----------|-------------------|
| Fond du Lac, combined | (logged before VO capture) | — | No false warning ✓ |
| Aventura, combined | Mostly clear, no radar polygons | "none currently highlighted on the map" ✓ | "No active warnings" ✓ |
| Madison, combined (19:50) | **Madison clear**; precip 150mi NE near Green Bay | "just north of Green Bay" / "near Sturgeon Bay" ✓ | "moderate precipitation near the **eastern side of Madison**" ✗ |
| Madison, combined (20:00) | **Madison clear**; precip far NE near Sturgeon Bay | "Madison… is clear of precipitation" / "none currently active on the map" ✓✓ | "precipitation near Madison… **severe thunderstorm warning active**" ✗✗ (warningMismatch=True) |

**Two distinct FM failure modes, both reproduced:**
1. **Mislocation** — FM plants precipitation "at the city" even when the actual cell is 150 miles away. It anchors weather to the user's location regardless of where it really is.
2. **Warning hallucination** — FM reports a "severe thunderstorm warning (thick yellow polygon)" on a clear day with zero NWS alerts. The "yellow polygon" wording tracks the SEVERE THUNDERSTORM legend color → it is reading the legend and confabulating.

**Prompt fixes attempted this session — NONE closed the gap:**
- **Legend fix**: prompts now explicitly say the top legend strip is reference-only, white/blank = no precip, red lines = county borders, teal = water. → FM *still* hallucinated a warning in the 20:00 Madison entry.
- **Station-locator fix** (the "center is the radar station, not your city" fix): NWS RIDGE single-station images are centered on the RADAR STATION (KMKX = Milwaukee), not the user's city. The old prompt falsely claimed "the center of the image is [city]." We replaced it with a computed locator: `cityLocator()` + `compassDirection()` in `RadarFoundationModelsService.swift` tell the model e.g. "centered on the Milwaukee radar station; Madison is labeled on the map, toward the **west** of center; find its label." → FM *still* mislocated precipitation to Madison AND hallucinated the warning. The fix did not work; the 20:00 entry (worst result) was logged AFTER it.

**Interpretation:** FM output reads like generic weather confabulation ("moderate precipitation near [city], moving northwest, warning active"), while VoiceOver gives specific, correct geography ("Door Peninsula," "out over Lake Michigan," names Madison as clear). VoiceOver is genuinely seeing the image; FM appears to barely be.

**Two leading hypotheses for WHY FM underperforms (untested — start here next time):**
1. **Model capability** — the on-device model on this iOS 27 beta can't do fine-grained spatial reasoning on a dense radar map and falls back on weather priors.
2. **Image fidelity / downsampling** — `Attachment(cgImage)` may downsample before the model sees it. A heavy downsample would destroy the small NE precipitation cluster while the high-contrast legend bar survives — which fits the pattern exactly (invents precip = lost detail; sees "warnings" = legend survives). **Worth investigating:** does Attachment have a resolution cap? Try cropping the image to just the map area (drop legend + scale bar) before sending, and/or upscaling/centering on the city.

**Strategic recommendation for next session:**
Prompt engineering has not made the FM path reliable. The thing the user actually wants — accurate plain-language radar description — **Apple VoiceOver already does well today on the same image.** Strongly consider pivoting the feature to lean on VoiceOver's native image description (the image is already marked `.isImage` and reachable) rather than the custom FM prompt, at least until the on-device model matures. Decision deferred — discuss with Kelly before more FM prompt work. Do NOT keep iterating prompts without first testing the downsampling hypothesis; if Attachment is the bottleneck, no prompt will fix it.

---

### Radar AI Logging System (June 20, 2026)

A `RadarAILogger` class (in `RadarFoundationModelsService.swift`) captures every "Log Result" tap. It:
1. Fetches live NWS conditions (temp, wind, sky) and active alerts at log time
2. Saves the actual radar image(s) as PNG to `Documents/radar_images/` (timestamped, e.g. `20260620T200042Z_Venus-Way--Madison_later.png`)
3. Writes one JSON line to `Documents/radar_ai_log.jsonl` referencing the image filenames
4. Prints each entry to console with `[RADAR_LOG]` prefix

**Why images are saved:** radar updates every few minutes, so a described frame can't be reliably re-fetched later. Saving the PNG makes each entry independently auditable — you can look at the exact frame the AI/VoiceOver described and judge who was right. This is what made the comparison findings above possible.

**UI (RadarMapView.swift):** After a description appears, a "Log for Comparison" card shows below the images with two TextEditors to paste VoiceOver descriptions (labels adapt: "Earlier/Later frame" in movement mode, "Radar image"/"Radar map" in single mode), then the "Log Result with NWS Ground Truth" button. In movement mode the redundant standalone radar image is hidden so VoiceOver finds exactly two images matching the two paste boxes. Paste fields + logged-status auto-clear on each new Describe.

**No public API for VoiceOver's description:** Confirmed Apple exposes no public API to invoke VoiceOver's image-description model and get the text back (it's in the private accessibility stack). Vision framework only offers OCR/saliency/classification, not captioning. Hence the manual paste-in workflow. Kelly confirmed VoiceOver's description CAN be copied to the clipboard, so paste-in works.

**Pulling the data from the Mac (no phone interaction needed beyond the tap):**
```bash
# JSONL
xcrun devicectl device copy from --device "Kelly Ford" \
  --domain-type appDataContainer --domain-identifier com.weatherfast.app --user mobile \
  --source Documents/radar_ai_log.jsonl --destination /tmp/radarlog/radar_ai_log.jsonl
# Images folder
xcrun devicectl device copy from --device "Kelly Ford" \
  --domain-type appDataContainer --domain-identifier com.weatherfast.app --user mobile \
  --source Documents/radar_images --destination /tmp/radarlog/radar_images
```
Also visible on-device in Files.app → On My iPhone → Weather Fast (UIFileSharingEnabled in Info.plist).

**Log entry fields:** timestamp, city, cityLat/Lon, stationId, stationName, promptMode, aiDescription, aiHasWarnings, aiIntensity, aiDirection, nwsObsStation, nwsConditions, nwsTempC, nwsWindDirDeg, nwsWindSpeedKmh, nwsAlerts (list), warningMismatch (AI claims warning but NWS has none — the key QA flag), voiceoverDesc1/Label1, voiceoverDesc2/Label2, imageFile OR firstFrameFile+lastFrameFile.

---

### Known Issues

**Error 1046 (ModelManagerServices.ModelManagerError)** — The iOS 27 beta's model manager (`modelmanagerd`) intermittently fails to load the vision model after it's been evicted from memory. Both on-device and Private Cloud Compute fail with the same error because they both go through `modelmanagerd`. 

- **Workaround:** Reboot the phone (`xcrun devicectl device reboot --device "Kelly Ford"`) — this restarts `modelmanagerd` and the model works again until it gets evicted.
- **The code is correct** — it works when the model is loaded. Kelly confirmed getting good radar descriptions earlier in the session.
- **This is a beta bug** — should be fixed in a later iOS 27 beta.
- **Siri text generation works** (poems, Writing Tools) even when the vision model fails — the text model and vision model are separate assets.

### Build & Deploy Commands

```bash
# Build with Xcode 27 beta
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodebuild \
  -project iOS/FastWeather.xcodeproj -scheme FastWeather \
  -configuration Debug \
  -destination 'id=00008130-000A11502811401C' build

# Install to phone
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcrun devicectl device install app \
  --device "Kelly Ford" \
  "/Users/kellyford/Library/Developer/Xcode/DerivedData/FastWeather-baktdakqlwnulvfigjnxuuwjpsom/Build/Products/Debug-iphoneos/WeatherFast.app"

# Launch on phone
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcrun devicectl device process launch \
  --device "Kelly Ford" --terminate-existing com.weatherfast.app

# Launch with console (to see debug logs)
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcrun devicectl device process launch \
  --device "Kelly Ford" --terminate-existing --console com.weatherfast.app

# Reboot phone (fixes error 1046 temporarily)
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcrun devicectl device reboot \
  --device "Kelly Ford"
```

### How to Test

1. Build and install (commands above)
2. On phone: Settings → Developer Settings → AI Radar Description (iOS 27+)
3. Turn on **Foundation Models Radar**
4. Use VoiceOver "Open Radar Map" action on any US city
5. Tap **Describe Radar** — model sees the radar image and describes it
6. Try **Customize Prompt** — edit the prompt and tap "Describe with Custom Prompt"
7. Try different **Model Path** settings: Auto / On-Device / Private Cloud
8. Try **Two-Frame Movement** — downloads two frames, model infers movement
9. Try **Structured Output** — typed RadarAnalysis with precipitation/intensity/direction/warnings
10. Try **Detail Level**: Brief / Standard / Detailed

If you get error 1046, reboot the phone and try again immediately.

### What's Next

1. **Wait for iOS 27 beta fix** — the 1046 error is a beta bug. Once Apple fixes the model manager lifecycle, the radar description will work reliably.

2. **Test quality** — once the model is stable, run the same cities through both the on-device model and the QuickRadar Ollama model, compare descriptions. The QuickRadar experiment used gemma4:31b-cloud; the on-device model is smaller.

3. **Refine prompts** — use the custom prompt editor to experiment with different prompt phrasings. Find what produces the best descriptions for screen-reader users.

4. **Consider local models** — the iOS 27 SDK has a `LanguageModel` protocol that custom models can conform to. In theory, a model like gemma4 running via MLX could implement this. This is a significant engineering effort (probably a week+) and would be a separate research project.

5. **Dynamic Profiles (iOS 27)** — the `LanguageModel` protocol and `SessionProperty` API could enable runtime-swappable instruction profiles (brief/standard/detailed) without restarting the session.

6. **Evaluations framework (iOS 27)** — Apple's Evaluations framework could systematically test whether the AI produces good radar descriptions across conditions.

### Key Files

In the **fastweather** repo (on `docs/nowcasting-proposal` branch, commit `912e5b7`):
- `iOS/FastWeather/Services/RadarFoundationModelsService.swift` — **NEW**: iOS 27 multimodal radar description service
- `iOS/FastWeather/Services/RadarAnalysisGenerable.swift` — **NEW**: @Generable structured output
- `iOS/FastWeather/Services/RadarDescriptionService.swift` — updated: routes to Foundation Models, image-only fallback
- `iOS/FastWeather/Services/RadarCrossValidation.swift` — updated: structured analysis cross-validation
- `iOS/FastWeather/Services/FeatureFlags.swift` — updated: 5 new AI radar flags
- `iOS/FastWeather/Views/RadarMapView.swift` — updated: prompt editor, error display, structured/movement cards
- `iOS/FastWeather/Views/DeveloperSettingsView.swift` — updated: AI Radar Description section
- `iOS/FastWeather/Views/ListView.swift` — updated: Open Radar Map VoiceOver action
- `iOS/FastWeather/Views/FlatView.swift` — updated: Open Radar Map VoiceOver action + Actions menu
- `iOS/FastWeather/Views/WeatherAroundMeView.swift` — updated: structured cross-validation
- `iOS/FastWeather.xcodeproj/project.pbxproj` — updated: deployment target iOS 27.0, new file references

In the **quickradar** repo:
- `prompt.txt` — the custom radar description prompt (now built into the iOS app)
- `EXPERIMENT_REPORT.md` — full analysis of the 40-run experiment
- `IOS27_RESEARCH_AND_PLAN.md` — original research on Foundation Models framework
- `IOS26_VS_IOS27.md` — the other AI agent's research (note: some claims about iOS 26 were incorrect — see SDK findings above)

### Important SDK Findings (Verified by Inspecting Actual SDKs)

| API | Apple Docs Say | Actual SDK (Xcode 27 beta) |
|-----|---------------|---------------------------|
| `Attachment(cgImage)` | iOS 26.0+ | **iOS 27.0 only** |
| `PrivateCloudComputeLanguageModel` | iOS 26.0+ (Beta) | **iOS 27.0 only** |
| `LanguageModelSession` | iOS 26.0+ | iOS 26.0+ ✅ |
| `@Generable` | iOS 26.0+ | iOS 26.0+ ✅ |
| `LanguageModel` protocol | iOS 27.0+ | iOS 27.0+ ✅ |
| `LanguageModelCapabilities.vision` | iOS 27.0+ | iOS 27.0+ ✅ |
| `VNGenerateImageObservationsRequest` | iOS 18+ | **Does not exist** in Xcode 26.3 or 27.0 SDKs |

The `IOS26_VS_IOS27.md` document (from the other AI agent) claims multimodal is iOS 26. That is **wrong** — verified by inspecting the actual `.swiftinterface` files. `Attachment` and `PrivateCloudComputeLanguageModel` are `@available(iOS 27.0, *)` in the real SDK.

---

## Who You Are

You are my AI team lead and owner of this project. You don't ask permission — you assess, decide, and execute. You act like an employee who owns the work, not a chatbot waiting for instructions. You show me the ceiling, not the floor.

I am Kelly Ford. I'm building **WeatherFast** (also called FastWeather), a multi-platform accessibility-first weather app. I'm the innovator. I need you to educate me, make decisions, and build.

---

## The Two Repositories

1. **QuickRadar** — `c:\Users\kelly\GitHub\quickradar` (this repo)
   - A Python research tool that downloads NWS radar images, sends them to Ollama for AI description, fetches ground-truth weather data, and writes comparison reports.
   - This is the experiment lab where we proved AI image descriptions work for weather radar.

2. **WeatherFast** — `c:\Users\kelly\GitHub\fastweather` (or `~/github/fastweather` on Mac)
   - The actual app. Multi-platform: iOS (Swift/SwiftUI), Web/PWA, Windows (Python/wxPython).
   - We're working on the **`docs/nowcasting-proposal`** branch of the iOS app.
   - All weather data from Open-Meteo (free, no API key) + WeatherKit (iOS).

---

## What We've Built So Far

### QuickRadar (the experiment lab)

**`quickradar.py`** — the main script:
- Geocodes a US zipcode → finds nearest NEXRAD radar station → downloads NWS RIDGE base-reflectivity GIF → sends to Ollama (gemma4:31b-cloud) with a custom screen-reader-friendly prompt → fetches NWS current conditions from nearest observation station → writes a combined report.
- Reads config from `prompt.txt` (zipcode, model, prompt).
- Supports `--zoom <km>` to crop the radar image to a radius around the user's location (uses Pillow).
- Token counting from Ollama responses.
- Images kept by default (`--no-keep-image` to delete).

**Experiments run:**
- **Initial experiment**: 10 diverse zipcodes, each with full radar + 100km zoom crop (20 runs). 100% agreement between AI descriptions and ground-truth station data. Key finding: AI sees weather the station can't (6 of 10 had active precip in radar field even though station was dry).
- **Storm chase**: 10 zipcodes targeted at active NWS alerts (20 runs). 3 locations had precipitation at the station. AI correctly identified squall lines, read warning polygons, and described storm structure.
- **Two-frame movement experiment** (`run_movement_experiment.py`): Downloads NWS RIDGE animated loop GIF, extracts first/last frames (~1hr apart), sends both to model. **The model can infer movement** — all 6 storm locations correctly showed E/NE movement. Also detected intensification and dissipation.
- **Storm structure experiment** (`run_velocity_experiment.py`): Higher-tilt reflectivity products (products 2-3) with a prompt asking about hook echoes, BWERs, and severe weather signatures. Model correctly identified storm organization and read warning polygons. True velocity images (N0V) are NOT available via free NWS RIDGE URLs — documented as a real limitation.

**Key documents in quickradar repo:**
- `EXPERIMENT_REPORT.md` — full analysis of the 40-run experiment
- `Sunny_Days_Ahead.md` — educational document about weather imagery types (radar, satellite, velocity, etc.)
- `OWNERS_ASSESSMENT.md` — your assessment of the WeatherFast nowcasting branch
- `PROGRESS_REPORT.md` — what you did and why
- `IOS27_RESEARCH_AND_PLAN.md` — research on Apple's Foundation Models framework (the next step)

### WeatherFast iOS (the app)

**Two commits on `docs/nowcasting-proposal` branch:**

1. **`6ec69c5`** — "Add AI radar description service + enable nowcast refinements"
   - `RadarDescriptionService.swift` (new): Downloads nearest NEXRAD image, describes it using Vision framework (`VNGenerateImageObservationsRequest`, iOS 18+) or fallback accessibility label (iOS 17). **NOTE: This uses Apple's generic image description, NOT a custom prompt. This is the gap that needs upgrading.**
   - `RadarMapView.swift` (updated): Added "Describe Radar" button, description card, radar image display with accessibility label.
   - `FeatureFlags.swift` (updated): Turned on `nowcastRefinementsEnabled` by default (was off). Added missing first-launch default.

2. **`da9029d`** — "Add cross-validation between Storm Approach and AI radar description"
   - `RadarCrossValidation.swift` (new): Compares Storm Approach's numeric motion estimate (steering wind + centroid drift) with AI radar description's text-based direction. Parses 16-point compass directions from AI text. Upgrades confidence when both agree (<45°), hedges when they disagree.
   - `WeatherAroundMeView.swift` (updated): Added cross-validation card ("Motion Cross-Check") that appears when both Storm Approach and AI description are available. Fetches AI description after Storm Approach loads (best-effort, non-blocking).

**Existing code on the nowcasting branch (not ours):**
- `StormApproachService.swift` (920 lines): Ring-sampling precipitation at 16 bearings × 3 radii, steering-wind motion estimation, confidence hedging, nearby-town naming, saved-city impact. This is the numeric "radar replacement."
- `RadarTileService.swift`: NWS NEXRAD composite tiles via Iowa Environmental Mesonet (IEM), public domain, US coverage.
- `RadarMapView.swift`: MapKit tile overlay showing radar.
- `RadarService.swift`: WeatherKit minute-by-minute nowcast + Next Hour narration.
- `FeatureFlags.swift`: All features behind flags, most on by default.

---

## The Gap I Identified

The `RadarDescriptionService.swift` I shipped uses Apple's `VNGenerateImageObservationsRequest` — a **generic** image description API with no custom prompt. The QuickRadar experiment proved that **custom-prompted** descriptions (telling the model what to look for: precipitation intensity, color bands, storm cells, warning polygons) produce dramatically better results.

Apple's **Foundation Models framework** (iOS 26+) closes this gap. It supports:
- `LanguageModelSession` — on-device AI model
- `Attachment(image)` — send an image with your prompt
- Custom text prompt — the same radar prompt from `prompt.txt`
- `@Generable` — structured output (typed fields, not free text)
- Two-image comparison — for movement detection
- `PrivateCloudComputeLanguageModel` — larger cloud model fallback (free, privacy-preserving)

---

## What's Next: The Plan

**Phase 1 (priority):** Upgrade `RadarDescriptionService.swift` to use `LanguageModelSession` + custom prompt + `Attachment(image)` on iOS 26+. Keep the Vision framework fallback for iOS 17. This is the single change that takes us from "generic image description" to "QuickRadar-quality description" on-device.

**Phase 2:** `@Generable` structured output (`RadarAnalysis` struct with hasPrecipitation, intensity, direction, hasWarnings, description) to replace text parsing in cross-validation.

**Phase 3:** On-device two-frame movement detection (two `Attachment` images + comparison prompt).

**Phase 4:** Private Cloud Compute fallback when on-device isn't enough.

**Phase 5:** Dynamic profiles for user-controlled detail level (brief/standard/detailed).

**Before implementing Phase 1, verify:**
- Am I on iOS 27 beta? (commit history suggests yes)
- Is Apple Intelligence turned on? (Settings → Apple Intelligence)
- What Xcode version? (Need Xcode 26 beta for Foundation Models)
- Does the current code build? (Two commits on nowcasting branch need to compile)

---

## Key Files to Read

In the **quickradar** repo:
- `prompt.txt` — the custom radar description prompt (this is what goes into `Instructions` for the Foundation Models framework)
- `EXPERIMENT_REPORT.md` — the data behind all findings
- `IOS27_RESEARCH_AND_PLAN.md` — full research on Foundation Models framework with code examples

In the **fastweather** repo (on `docs/nowcasting-proposal` branch):
- `iOS/FastWeather/Services/RadarDescriptionService.swift` — what I shipped (needs upgrading)
- `iOS/FastWeather/Services/RadarCrossValidation.swift` — cross-validation logic
- `iOS/FastWeather/Services/StormApproachService.swift` — the numeric radar replacement (existing, not ours)
- `iOS/FastWeather/Services/RadarTileService.swift` — NEXRAD tile service (existing)
- `iOS/FastWeather/Views/RadarMapView.swift` — radar map UI with "Describe Radar" button
- `iOS/FastWeather/Views/WeatherAroundMeView.swift` — Weather Around Me with cross-validation card
- `iOS/FastWeather/Services/FeatureFlags.swift` — feature flags
- `docs/NOWCASTING_AND_SHORT_TERM_FORECAST_PROPOSAL.md` — the original proposal (on the branch)

---

## How to Resume

1. Open this file on your Mac.
2. Open GitHub Copilot Chat in VS Code.
3. Say: "Read this file and continue. You are my AI team lead. Start by reading the key files listed above, then tell me where we are and what you're doing next."
4. The agent should read the files, understand the context, and pick up where we left off — implementing Phase 1 of the iOS 27 upgrade.

---

## Important Context

- The app targets iOS 17.0 minimum. Foundation Models framework needs iOS 26.0+. Use `#available` for conditional compilation.
- The app module name is `WeatherFast` (used in `@testable import WeatherFast`).
- `Secrets.swift` is gitignored — needs to be created locally before building (see `iOS/README.md`).
- All NWS/NOAA data sources are free and public domain.
- Open-Meteo is the primary weather data source (free tier, no API key).
- WeatherKit is used for minute-by-minute nowcast on iOS (requires Apple Developer entitlement).
- The `prompt.txt` file may have been edited by the user — always read it before using its contents.