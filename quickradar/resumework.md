# Resume Work: QuickRadar + WeatherFast AI Radar Description Project

**Purpose:** Load this file into a new GitHub Copilot Chat session on your Mac to get the AI agent current on everything we've done and what's next. Just open this file, start a chat, and say "read this file and continue."

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