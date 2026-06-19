# iOS 26 vs iOS 27: What's Available and When

**Purpose:** Clear up confusion about what's in iOS 26 vs iOS 27, what APIs
are available where, and what to target for the WeatherFast radar description
feature.

---

## The Short Version

- **Foundation Models framework** (`LanguageModelSession`, `Attachment`, `@Generable`) was introduced in **iOS 26.0**. It is available now on the iOS 26 beta.
- **iOS 27** adds *new features on top of* the Foundation Models framework — things like Dynamic Profiles, the Evaluations framework, Core AI, and App Intents improvements. But the core multimodal prompting (image + custom text prompt → description) is iOS 26.
- **What we need for the radar description feature** (custom prompt + image attachment → text description) is available on **iOS 26.0+**. We do not need to wait for iOS 27.
- The app currently targets iOS 17.0. We use `#available(iOS 26.0, *)` to conditionally use the Foundation Models framework, keeping iOS 17 support with the Vision framework fallback.

---

## Detailed Breakdown

### iOS 26 (the foundation)

Introduced at WWDC25 (June 2025). This is where the Foundation Models framework first appeared.

**Available on iOS 26.0+:**

| API | What it does | Available |
|-----|-------------|-----------|
| `LanguageModelSession` | On-device AI model session — send prompts, get responses | iOS 26.0+ |
| `Attachment(image)` | Include an image alongside text in a prompt (multimodal) | iOS 26.0+ |
| `Instructions` | Define the model's behavior (custom system prompt) | iOS 26.0+ |
| `@Generable` macro | Structured output — model returns typed Swift structs | iOS 26.0+ |
| `SystemLanguageModel` | The on-device Apple Foundation Model | iOS 26.0+ |
| `PrivateCloudComputeLanguageModel` | Larger cloud model (privacy-preserving) | iOS 26.0+ (Beta) |
| `Tool` protocol | Custom tools the model can call during generation | iOS 26.0+ |
| `Transcript` | Session history (all prompts and responses) | iOS 26.0+ |
| Streaming responses | `streamResponse()` for token-by-token output | iOS 26.0+ |
| `prewarm(promptPrefix:)` | Preload model resources for faster first response | iOS 26.0+ |

**What this means for us:** Everything we need to upgrade `RadarDescriptionService` — custom prompt + image attachment + text response — is available on iOS 26.0. The code pattern is:

```swift
if #available(iOS 26.0, *) {
    let session = LanguageModelSession(instructions: """
        You are looking at a weather radar image. Describe the precipitation,
        intensity, storm structure, and any warning polygons...
        """)
    let response = try await session.respond {
        "Describe this radar image for a screen-reader user."
        Attachment(radarCGImage)
    }
    let description = response.content
} else {
    // iOS 17-25 fallback: Vision framework or accessibility label
}
```

### iOS 27 (the enhancements)

Introduced at WWDC26 (June 2026). Builds on the iOS 26 Foundation Models framework with new capabilities.

**New in iOS 27:**

| Feature | What it adds | Available |
|---------|-------------|-----------|
| Dynamic Profiles | Swap models, tools, and instructions at runtime within a session | iOS 27.0+ (Beta) |
| Evaluations framework | Test and score AI feature quality across conditions | iOS 27.0+ (Beta) |
| Core AI framework | Run your own custom AI models on-device (not Apple's model) | iOS 27.0+ (Beta) |
| App Intents improvements | Siri integration, View Annotations API, App Intents Testing | iOS 27.0+ |
| Image Playground (reimagined) | New generative model on Private Cloud Compute | iOS 27.0+ |
| Visual Intelligence | Camera-based content discovery and actions | iOS 27.0+ |
| `LanguageModel` protocol | Bring any LLM provider (Claude, Gemini, etc.) into the framework | iOS 27.0+ (Beta) |
| `SessionProperty` | Custom session properties for profiles and tools | iOS 27.0+ (Beta) |
| `ContextOptions` | Configure details that appear in the prompt | iOS 27.0+ (Beta) |
| `GenerationOptions` improvements | More control over sampling and generation | iOS 27.0+ (Beta) |

**What this means for us:** iOS 27 features are *nice to have* but not required for the radar description feature. Dynamic Profiles (Phase 5 in our plan — user-controlled detail level) is an iOS 27 feature. The Evaluations framework (testing AI quality) is iOS 27. But the core multimodal prompting is iOS 26.

---

## What We Target

| Feature | Minimum iOS | How |
|---------|------------|-----|
| Radar description (custom prompt + image) | iOS 26.0 | `#available(iOS 26.0, *)` + `LanguageModelSession` |
| Structured output (`@Generable`) | iOS 26.0 | `#available(iOS 26.0, *)` + `respond(generating:)` |
| Two-frame movement comparison | iOS 26.0 | Two `Attachment` images in one prompt |
| Private Cloud Compute fallback | iOS 26.0 | `PrivateCloudComputeLanguageModel()` (Beta) |
| Dynamic Profiles (detail levels) | iOS 27.0 | `#available(iOS 27.0, *)` (future) |
| Evaluations (quality testing) | iOS 27.0 | `#available(iOS 27.0, *)` (future) |
| Vision framework fallback (generic) | iOS 18.0 | `VNGenerateImageObservationsRequest` |
| Basic accessibility label fallback | iOS 17.0 | Current app minimum |

---

## Requirements

### To use the Foundation Models framework (iOS 26+):
- **Device:** iPhone 15 Pro and later, iPad with A17 Pro or M1+, Mac with M1+
- **Apple Intelligence:** Must be turned on by the user (Settings → Apple Intelligence)
- **No API key needed** for on-device
- **No entitlement needed** for on-device
- **Private Cloud Compute** needs the `com.apple.developer.private-cloud-compute` entitlement (Beta)

### To build with the Foundation Models framework:
- **Xcode 26 beta** or later (for iOS 26 SDK)
- **Xcode 27 beta** for iOS 27 features (Dynamic Profiles, Evaluations, Core AI)

### App Store Small Business Program:
- If your app has fewer than 2 million total first-time App Store downloads, Private Cloud Compute is **free** (no cloud API cost)
- This covers WeatherFast easily

---

## Common Confusion Points

### "Is Foundation Models iOS 26 or iOS 27?"

**iOS 26.** The framework was introduced at WWDC25 (2025) and is available on iOS 26.0+. The "What's new in iOS 27" page describes *additions* to the framework that ship in iOS 27, but the core API (`LanguageModelSession`, `Attachment`, `@Generable`, `Instructions`) is iOS 26.

### "Do I need iOS 27 for multimodal prompting (image + text)?"

**No.** `Attachment(image)` and multimodal prompts are iOS 26.0+. You can send an image with a custom text prompt on iOS 26.

### "Do I need iOS 27 for `@Generable` structured output?"

**No.** `@Generable` is iOS 26.0+. You can define a `RadarAnalysis` struct and have the model return it on iOS 26.

### "What's actually new in iOS 27 for us?"

The main iOS 27 features that matter for WeatherFast:
1. **Dynamic Profiles** — swap between "brief" and "detailed" radar descriptions at runtime (Phase 5 of our plan)
2. **Evaluations framework** — systematically test whether the AI produces good radar descriptions (quality assurance)
3. **`LanguageModel` protocol** — bring in Claude or Gemini as an alternative to Apple's model (if Apple's model isn't good enough at radar imagery)
4. **Core AI** — run a custom-trained radar image model on-device (future, if we ever train one)

### "The docs say Beta — is this safe to ship?"

The Foundation Models framework APIs are marked Beta in Apple's documentation as of WWDC26. This means they may change before final release. For a development/experimentation phase this is fine. For App Store production, wait for the stable release or be prepared to update code if the API changes.

---

## What to Do Right Now

1. **Build the current code** (the two commits on `docs/nowcasting-proposal`) to verify it compiles. This code uses the Vision framework fallback, not Foundation Models — it should build on any iOS version.

2. **Check your environment:**
   - What iOS version is on your test device? (Need iOS 26+ for Foundation Models)
   - What Xcode version? (Need Xcode 26 beta for iOS 26 SDK)
   - Is Apple Intelligence turned on? (Settings → Apple Intelligence)

3. **Implement Phase 1** — upgrade `RadarDescriptionService.swift` to use `LanguageModelSession` + `Attachment(image)` + custom prompt, gated on `#available(iOS 26.0, *)`. This is the single change that takes us from generic image descriptions to QuickRadar-quality descriptions on-device.

4. **Test quality** — run the same 10 zipcodes through both the on-device model and the QuickRadar Ollama model, compare descriptions. If the on-device model is good enough, ship it. If not, use Private Cloud Compute as the fallback.

---

## Code Pattern for Phase 1

```swift
import FoundationModels // iOS 26+

class RadarDescriptionService {
    
    func describeRadar(for city: City) async -> DescriptionResult {
        // ... download NEXRAD image (same as current code) ...
        
        let description: String
        
        if #available(iOS 26.0, *) {
            // Use Foundation Models framework with custom prompt
            description = await describeWithFoundationModels(image: radarImage) 
                ?? describeWithVision(image: radarImage) // fallback within fallback
                ?? describeFromLabel(image: radarImage)
        } else if #available(iOS 18.0, *) {
            // iOS 18-25: Vision framework (generic, no custom prompt)
            description = await describeWithVision(image: radarImage) 
                ?? describeFromLabel(image: radarImage)
        } else {
            // iOS 17: just show the image with a context label
            description = describeFromLabel(image: radarImage)
        }
        
        return .success(description: description, image: radarImage, ...)
    }
    
    @available(iOS 26.0, *)
    private func describeWithFoundationModels(image: UIImage) async -> String? {
        guard let cgImage = image.cgImage else { return nil }
        
        let session = LanguageModelSession(instructions: """
            You are looking at a weather radar image. Provide a detailed, 
            objective description suitable for someone who cannot see the image. 
            Describe precipitation presence, intensity (green=light, yellow=moderate, 
            red=heavy), storm structure, warning polygons, and whether the image 
            is mostly clear or active. Be specific and factual.
            """)
        
        do {
            let response = try await session.respond {
                "Describe this radar image for a screen-reader user."
                Attachment(cgImage)
            }
            return response.content
        } catch {
            debugLog("⚠️ Foundation Models error: \(error)")
            return nil
        }
    }
}
```

This is the pattern. The custom prompt from `prompt.txt` goes into `Instructions`. The radar image goes into `Attachment`. The model returns a text description. On-device, private, no API cost.

---

*Researched 2026-06-19. Sources: developer.apple.com/documentation/foundationmodels, developer.apple.com/ios/whats-new/, developer.apple.com/apple-intelligence/whats-new/. All Foundation Models APIs are marked Beta as of WWDC26.*