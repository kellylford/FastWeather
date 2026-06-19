# iOS 27 Research & Plan: Foundation Models Framework

**From:** Your AI team lead
**Date:** 2026-06-19
**Re:** What iOS 27 / Apple Intelligence gives us, and how it changes the radar description game

---

## The Big Finding

I found the ceiling, and it's better than I thought.

Apple's **Foundation Models framework** (`FoundationModels`) is a native Swift API available on iOS 26+ that gives direct access to Apple Foundation Models — on-device and via Private Cloud Compute. It supports **multimodal prompts** — you send an image *and a custom text prompt* to the on-device model, and it responds with a description.

This is exactly what QuickRadar proved works. The difference: instead of needing Ollama running on a server with gemma4:31b-cloud, the user's iPhone does it natively. No server, no cloud API cost, no privacy concern. The radar image and the custom prompt both stay on the device.

**This closes the gap I flagged earlier.** The `VNGenerateImageObservationsRequest` I used in `RadarDescriptionService.swift` produces generic image descriptions. The Foundation Models framework produces *custom-prompted* descriptions — the same quality as the QuickRadar experiment, but on-device.

---

## What the Foundation Models Framework Gives Us

### 1. Multimodal prompting with custom instructions

From Apple's documentation ("Analyzing images with multimodal prompting"):

```swift
let session = LanguageModelSession()
let response = try await session.respond {
    "You are looking at a weather radar image. Describe the precipitation, intensity, and storm structure..."
    
    Attachment(radarImage)
}
```

You provide:
- **Custom text** — your radar-specific prompt (the same one from `prompt.txt`)
- **Attachment(image)** — the NWS RIDGE radar GIF, converted to CGImage
- **Instructions** — a struct that defines the model's intended behavior

The model processes both the visual content and the text together. This is multimodal AI — image + text in, text out. On-device.

### 2. Structured output with `@Generable`

You can constrain the model's response to a Swift struct:

```swift
@Generable
struct RadarAnalysis {
    @Guide(description: "Is precipitation visible?")
    var hasPrecipitation: Bool
    
    @Guide(description: "Intensity: none, light, moderate, heavy, or very heavy")
    var intensity: String
    
    @Guide(description: "Direction of nearest precipitation relative to user")
    var direction: String?
    
    @Guide(description: "Are any warning polygons visible?")
    var hasWarnings: Bool
    
    @Guide(description: "Free-form description of the radar image")
    var description: String
}
```

The model returns a typed `RadarAnalysis` — not free text that you have to parse. This is huge for the cross-validation logic: instead of parsing "northeast" out of a paragraph, the model returns a structured `direction` field.

### 3. Two-image comparison (for movement detection)

The documentation explicitly shows comparing two images:

```swift
let response = try await session.respond {
    "Compare these two radar images. Has the precipitation moved?"
    
    Attachment(frameOne)
    Attachment(frameTwo, orientation: .right)
}
```

This is the two-frame movement experiment — running on-device. No Ollama needed.

### 4. Private Cloud Compute for harder tasks

When the on-device model isn't enough (more reasoning, larger context), you can route to Private Cloud Compute:

```swift
let session = LanguageModelSession(model: PrivateCloudComputeLanguageModel())
```

Apple's cloud, privacy-preserving, no API key, no per-token cost (free for Small Business Program apps under 2M downloads). This is the fallback for complex analysis without running your own server.

### 5. Tool calling

The model can call custom tools during generation. For example, a tool that fetches the NWS current conditions for the user's location, so the model can compare what it sees in the radar image against the ground-truth station data — the cross-validation, done by the model itself.

### 6. Dynamic profiles

You can swap instructions and tools at runtime. For example:
- Profile A: "Describe this radar image for a general user" (simple language)
- Profile B: "Describe this radar image for a meteorologist" (technical language)
- Profile C: "Compare two radar frames and describe movement" (two-frame mode)

The user picks the level of detail; the session adapts.

---

## What This Means for WeatherFast

### The architecture I shipped needs to be upgraded

The current `RadarDescriptionService.swift` uses `VNGenerateImageObservationsRequest` (Vision framework) — generic image descriptions, no custom prompt. That was the right fallback for iOS 17, but on iOS 26+ we should use the Foundation Models framework instead.

### The upgrade path

| Component | Current (iOS 17) | Upgraded (iOS 26+) |
|-----------|------------------|-------------------|
| Radar description | `VNGenerateImageObservationsRequest` (generic) | `LanguageModelSession` + custom prompt + `Attachment(image)` |
| Movement detection | Not possible on-device | Two `Attachment` images + comparison prompt |
| Cross-validation | Parse text for direction keywords | `@Generable` struct with typed `direction` field |
| Cloud fallback | None | `PrivateCloudComputeLanguageModel` |
| Output format | Free text | `@Generable` structured output |

### What stays the same

- The NWS RIDGE image download (same GIF, same URL)
- The NEXRAD station lookup (same API)
- The radar map overlay (same IEM tiles)
- Storm Approach (same ring sampling, same narration)
- The cross-validation concept (compare numeric + image estimates)

### What changes

- `RadarDescriptionService.swift` gets a new iOS 26+ path using `LanguageModelSession`
- The custom prompt from `prompt.txt` moves into `Instructions` — the same prompt, but on-device
- The cross-validation can use `@Generable` structured output instead of text parsing
- The two-frame movement experiment can run on-device

---

## The Plan (Not Implementing Yet)

### Phase 1: Upgrade RadarDescriptionService for iOS 26+

**What:** Add a new code path in `RadarDescriptionService` that uses `LanguageModelSession` with the custom radar prompt and `Attachment(image)`. Gate it on `#available(iOS 26.0, *)`. Keep the Vision framework fallback for iOS 17-25.

**Why:** This is the single change that takes us from "generic image description" to "QuickRadar-quality description" on-device. The prompt is already written and tested. The image download is already working. The only new code is the `LanguageModelSession` call.

**Risk:** The on-device model may not be as good as gemma4:31b-cloud at reading radar images. Apple's foundation model is a general-purpose model, not trained on weather imagery. The QuickRadar experiment used a 31B parameter model; the on-device model is smaller. We need to test quality.

**Test plan:** Run the same 10 zipcodes through both the on-device model and gemma4:31b-cloud, compare descriptions. If the on-device model can identify precipitation presence, intensity, and warning polygons, it's good enough. If it can't, we fall back to Private Cloud Compute.

### Phase 2: Structured output with @Generable

**What:** Define a `RadarAnalysis` struct with `@Generable` that captures the fields we need for cross-validation: `hasPrecipitation`, `intensity`, `direction`, `hasWarnings`, `description`. Have the model return this struct instead of free text.

**Why:** This eliminates the text parsing in `RadarCrossValidation.swift`. Instead of regex-matching "northeast" out of a paragraph, the model returns `direction: "northeast"` as a typed field. More reliable, easier to maintain.

**Risk:** The `@Generable` macro constrains the model's output, which may reduce description quality. We should keep a free-text `description` field alongside the structured fields.

### Phase 3: On-device two-frame movement

**What:** Download two radar frames (from the NWS RIDGE loop GIF, same as `run_movement_experiment.py`), send both as `Attachment` images to `LanguageModelSession` with the movement comparison prompt.

**Why:** The two-frame experiment proved the AI can infer movement. Running it on-device means no server, no Ollama, instant results. This is the "is it coming at me?" answer, delivered on the user's phone.

**Risk:** The on-device model may struggle with two-image comparison. The QuickRadar experiment used gemma4:31b-cloud, which is a large model. The on-device model is smaller. Need to test.

### Phase 4: Private Cloud Compute fallback

**What:** When the on-device model's description quality isn't sufficient (detected by confidence heuristics or user feedback), route the same prompt + image to `PrivateCloudComputeLanguageModel`.

**Why:** Apple's cloud model is larger and more capable, but still privacy-preserving (Apple doesn't store or share the data). Free for Small Business Program apps. This is the "best of both worlds" — on-device when possible, cloud when needed, no third-party server.

**Risk:** Requires the Private Cloud Compute entitlement. May not be available in all regions. Need to handle gracefully.

### Phase 5: Dynamic profiles for user-controlled detail level

**What:** Use the Dynamic Profiles API to let users choose description detail: "brief" (one sentence), "standard" (the current prompt), "detailed" (full meteorological analysis). The session swaps instructions at runtime.

**Why:** Different users want different levels of detail. A casual user wants "light rain to the southwest." A weather enthusiast wants "a squall line extends from the southwest with embedded heavy cells, moving northeast at 25 mph." Dynamic profiles let one button serve both.

---

## Key Technical Details

### Availability
- Foundation Models framework: **iOS 26.0+, iPadOS 26.0+, macOS 26.0+**
- The app currently targets iOS 17.0. We'd need to conditionally compile for iOS 26+.
- `LanguageModelSession`, `Attachment`, `@Generable` are all beta API (marked Beta in docs)

### Requirements
- Apple Intelligence must be turned on by the user (Settings → Apple Intelligence)
- Supported devices: iPhone 15 Pro and later, iPad with A17 Pro/M1+, Mac with M1+
- No API key, no entitlement for on-device. Private Cloud Compute needs an entitlement.

### Privacy
- On-device: image never leaves the phone
- Private Cloud Compute: Apple processes it, doesn't store or share it
- No third-party server, no Ollama, no API cost

### Token costs
- On-device: zero (free, runs on the Neural Engine)
- Private Cloud Compute: free for Small Business Program apps (<2M downloads)

---

## What I Need to Verify on Your Mac

Before implementing, I need you to check a few things when you load the project:

1. **What iOS version are you building for?** The project currently targets iOS 17.0. The Foundation Models framework needs iOS 26.0+. If you're on the iOS 27 beta (which your commit history suggests — "iOS 27 beta" appears in commit messages), you can test this.

2. **Is Apple Intelligence available on your device?** The on-device model requires Apple Intelligence to be turned on. Check Settings → Apple Intelligence.

3. **What Xcode version?** The Foundation Models framework and `@Generable` macro need the latest Xcode beta (Xcode 26 beta).

4. **Does the current code build?** I committed two changes to the nowcasting branch. Verify they compile before I add more.

---

## My Recommendation

**Start with Phase 1.** It's the smallest change with the biggest impact: swap `VNGenerateImageObservationsRequest` for `LanguageModelSession` + custom prompt + `Attachment(image)`. Same image download, same prompt, same UI — just a better model backend. If the on-device model produces good radar descriptions, we're done. If not, Phase 4 (Private Cloud Compute) is the fallback.

The `@Generable` structured output (Phase 2) and two-frame movement (Phase 3) are natural follow-ups, but they depend on Phase 1 working first. No point building structured output if the model can't describe the image.

I'm ready to implement Phase 1 when you've verified the build environment. Say the word.

---

*Research sources: developer.apple.com/documentation/foundationmodels, developer.apple.com/apple-intelligence, developer.apple.com/machine-learning — all accessed 2026-06-19.*