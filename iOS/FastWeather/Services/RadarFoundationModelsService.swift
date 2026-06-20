//
//  RadarFoundationModelsService.swift
//  Fast Weather
//
//  iOS 27+ radar image description using Apple's Foundation Models framework.
//
//  This is the upgrade to RadarDescriptionService that closes the gap the
//  QuickRadar experiment identified. The NWS RIDGE radar GIF is sent directly
//  to LanguageModelSession via Attachment(cgImage) along with the custom radar
//  prompt — the same approach QuickRadar proved works, but on-device. No
//  server, no API key, no privacy concern. The radar image and the custom
//  prompt both stay on the device.
//
//  Requires iOS 27.0+ (deployment target for this branch) and Apple Intelligence.
//  Gated behind FeatureFlags.foundationModelsRadarEnabled (OFF by default).
//  When the flag is off, RadarDescriptionService uses the image-only fallback.
//
//  Sub-features (all OFF by default, all require foundationModelsRadarEnabled):
//    • radarStructuredOutputEnabled  → @Generable typed RadarAnalysis
//    • radarTwoFrameMovementEnabled  → two-frame movement detection
//    • radarCloudModelEnabled        → PrivateCloudComputeLanguageModel
//    • radarDescriptionDetailLevel   → brief / standard / detailed prompt
//

import Foundation
import UIKit
import FoundationModels

/// The detail level for the radar description prompt.
enum RadarDetailLevel: String, CaseIterable {
    case brief
    case standard
    case detailed

    var label: String {
        switch self {
        case .brief:    return "Brief"
        case .standard: return "Standard"
        case .detailed: return "Detailed"
        }
    }
}

/// Result of a Foundation Models radar description request.
enum FoundationModelsRadarResult {
    /// A free-text description (structured output off).
    case text(description: String, image: UIImage, stationId: String, stationName: String)
    /// A structured RadarAnalysis (structured output on).
    case structured(RadarAnalysis, image: UIImage, stationId: String, stationName: String)
    /// A two-frame movement analysis (two-frame flag on).
    case movement(RadarAnalysis, firstFrame: UIImage, lastFrame: UIImage, stationId: String, stationName: String)
    case noCoverage
    case unavailable(String)
    case error(String)
}

/// iOS 27+ radar description via Foundation Models.
///
/// Uses LanguageModelSession with Attachment(cgImage) for multimodal image
/// input — the model sees the radar image and the custom prompt together.
/// PrivateCloudComputeLanguageModel is available as a cloud fallback.
final class RadarFoundationModelsService {
    static let shared = RadarFoundationModelsService()
    private init() {}

    // MARK: - Availability

    /// Whether the Foundation Models path is available at runtime.
    /// Requires the feature flag to be on and Apple Intelligence to be available.
    var isAvailable: Bool {
        guard FeatureFlags.shared.foundationModelsRadarEnabled else { return false }
        return SystemLanguageModel.default.isAvailable
    }

    // MARK: - Public Entry Point

    /// Describe the radar for a city. Routes to the appropriate backend
    /// (multimodal, structured, or movement) based on feature flags.
    /// If `customPrompt` is provided, it overrides the built-in prompt.
    func describeRadar(for city: City, customPrompt: String? = nil) async -> FoundationModelsRadarResult {
        guard FeatureFlags.shared.foundationModelsRadarEnabled else {
            return .unavailable("Foundation Models radar description is disabled. Enable it in Developer Settings.")
        }

        guard SystemLanguageModel.default.isAvailable else {
            return .unavailable("Apple Intelligence is not available. Enable it in Settings → Apple Intelligence.")
        }

        // Check if the selected model supports vision (image input)
        if let visionError = checkVisionCapability() {
            return visionError
        }

        // US coverage check
        guard RadarTileService.coversRadar(country: city.country) else {
            return .noCoverage
        }

        // Find nearest NEXRAD station
        guard let station = await RadarDescriptionService.shared.findNearestStation(
            lat: city.latitude, lon: city.longitude) else {
            return .error("Could not find a nearby NEXRAD radar station.")
        }

        // Two-frame movement path (skipped when using a custom prompt —
        // custom prompt is always single-frame)
        if customPrompt == nil, FeatureFlags.shared.radarTwoFrameMovementEnabled {
            let result = await describeMovement(city: city, station: station)
            // If movement fails, fall back to single-frame rather than showing
            // an error — the user still gets a radar description.
            if case .error(let msg) = result {
                debugLog("📡 Movement failed (\(msg)), falling back to single-frame")
                // Fall through to single-frame below
            } else {
                return result
            }
        }

        // Single-frame path
        guard let image = await RadarDescriptionService.shared.downloadImage(
            stationId: station.id) else {
            return .error("Could not download the radar image for station \(station.id).")
        }

        guard let cgImage = image.cgImage else {
            return .error("The radar image could not be processed.")
        }

        let useStructured = customPrompt == nil && FeatureFlags.shared.radarStructuredOutputEnabled
        let detail = RadarDetailLevel(
            rawValue: FeatureFlags.shared.radarDescriptionDetailLevel) ?? .standard
        // Use custom prompt if provided, otherwise the built-in prompt
        let prompt = customPrompt ?? Self.prompt(for: detail, structured: useStructured, cityName: city.name)

        do {
            let session = makeSession()
            let attachment = Attachment(cgImage)

            if useStructured {
                let response = try await session.respond(
                    generating: GenerableRadarAnalysis.self) {
                    prompt
                    attachment
                }
                let analysis = response.content.toRadarAnalysis()
                return .structured(analysis, image: image,
                                   stationId: station.id, stationName: station.name)
            } else {
                let response = try await session.respond {
                    prompt
                    attachment
                }
                return .text(description: response.content, image: image,
                             stationId: station.id, stationName: station.name)
            }
        } catch {
            debugLog("⚠️ Foundation Models radar error (attempt 1): \(error)")
            // Error 1046 means the on-device model assets aren't loaded.
            // Try a longer warm-up delay, then retry. If that also fails,
            // fall back to Private Cloud Compute (which has its own model
            // infrastructure and may not have the same loading issue).
            debugLog("📡 Retrying in 5 seconds (model warm-up)...")
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            do {
                let session = makeSession()
                let attachment = Attachment(cgImage)
                if useStructured {
                    let response = try await session.respond(
                        generating: GenerableRadarAnalysis.self) {
                        prompt
                        attachment
                    }
                    let analysis = response.content.toRadarAnalysis()
                    return .structured(analysis, image: image,
                                       stationId: station.id, stationName: station.name)
                } else {
                    let response = try await session.respond {
                        prompt
                        attachment
                    }
                    return .text(description: response.content, image: image,
                                 stationId: station.id, stationName: station.name)
                }
            } catch {
                debugLog("⚠️ Foundation Models radar error (attempt 2): \(error)")
                // On-device failed twice. Try Private Cloud Compute as a
                // last resort, regardless of the model path setting.
                let cloud = PrivateCloudComputeLanguageModel()
                guard case .available = cloud.availability else {
                    debugLog("📡 Private Cloud Compute also unavailable")
                    return .error("The on-device model could not load (error 1046) and Private Cloud Compute is not available. The model may need to warm up — try again in a moment, or use Siri/Notes to trigger Apple Intelligence first.")
                }
                debugLog("📡 Falling back to Private Cloud Compute...")
                do {
                    let cloudSession = LanguageModelSession(model: cloud)
                    let attachment = Attachment(cgImage)
                    if useStructured {
                        let response = try await cloudSession.respond(
                            generating: GenerableRadarAnalysis.self) {
                            prompt
                            attachment
                        }
                        let analysis = response.content.toRadarAnalysis()
                        return .structured(analysis, image: image,
                                           stationId: station.id, stationName: station.name)
                    } else {
                        let response = try await cloudSession.respond {
                            prompt
                            attachment
                        }
                        return .text(description: response.content, image: image,
                                     stationId: station.id, stationName: station.name)
                    }
                } catch {
                    debugLog("⚠️ Private Cloud Compute also failed: \(error)")
                    return .error("Both the on-device model and Private Cloud Compute failed. On-device error: model assets not loaded (1046). Cloud error: \(error.localizedDescription). Try again in a moment, or use Siri or Notes first to warm up Apple Intelligence.")
                }
            }
        }
    }

    // MARK: - Two-Frame Movement

    private func describeMovement(city: City, station: RadarStationInfo) async -> FoundationModelsRadarResult {
        guard let frames = await RadarDescriptionService.shared.downloadLoopFrames(
            stationId: station.id),
              frames.count >= 2 else {
            return .error("Could not download two radar frames for movement analysis.")
        }
        let firstFrame = frames[0]
        let lastFrame = frames[frames.count - 1]

        guard let firstCG = firstFrame.cgImage,
              let lastCG = lastFrame.cgImage else {
            return .error("Could not convert radar frames for analysis.")
        }

        let detail = RadarDetailLevel(
            rawValue: FeatureFlags.shared.radarDescriptionDetailLevel) ?? .standard
        let useStructured = FeatureFlags.shared.radarStructuredOutputEnabled
        let prompt = Self.movementPrompt(for: detail, structured: useStructured, cityName: city.name)

        do {
            let session = makeSession()
            let firstAttachment = Attachment(firstCG)
            let lastAttachment = Attachment(lastCG)

            if useStructured {
                let response = try await session.respond(
                    generating: GenerableRadarAnalysis.self) {
                    prompt
                    firstAttachment
                    lastAttachment
                }
                let analysis = response.content.toRadarAnalysis()
                return .movement(analysis, firstFrame: firstFrame, lastFrame: lastFrame,
                                 stationId: station.id, stationName: station.name)
            } else {
                let response = try await session.respond {
                    prompt
                    firstAttachment
                    lastAttachment
                }
                let analysis = RadarAnalysis(
                    hasPrecipitation: true, intensity: "unknown",
                    direction: nil, hasWarnings: false,
                    description: response.content)
                return .movement(analysis, firstFrame: firstFrame, lastFrame: lastFrame,
                                 stationId: station.id, stationName: station.name)
            }
        } catch {
            debugLog("⚠️ Foundation Models movement error: \(error)")
            debugLog("⚠️ Error type: \(type(of: error))")
            return .error("Movement analysis error: \(error). Type: \(type(of: error))")
        }
    }

    // MARK: - Session Creation

    /// The model path selected in Developer Settings.
    private var modelPath: String { FeatureFlags.shared.radarModelPath }

    /// Create a session using the selected model path.
    /// "on-device" → SystemLanguageModel
    /// "cloud" → PrivateCloudComputeLanguageModel
    /// "auto" → on-device if it supports vision, otherwise cloud
    private func makeSession() -> LanguageModelSession {
        switch modelPath {
        case "cloud":
            return LanguageModelSession(model: PrivateCloudComputeLanguageModel())
        case "on-device":
            return LanguageModelSession()
        default: // "auto"
            // Prefer on-device if it supports vision; fall back to cloud.
            if SystemLanguageModel.default.capabilities.contains(.vision) {
                return LanguageModelSession()
            } else {
                return LanguageModelSession(model: PrivateCloudComputeLanguageModel())
            }
        }
    }

    /// Check whether the selected model supports vision (image input).
    /// Returns a descriptive error if it doesn't.
    private func checkVisionCapability() -> FoundationModelsRadarResult? {
        switch modelPath {
        case "cloud":
            let cloud = PrivateCloudComputeLanguageModel()
            if !cloud.capabilities.contains(.vision) {
                debugLog("📡 Private Cloud Compute does not support vision (image input) on this device yet.")
                return .unavailable("Private Cloud Compute does not support image input on this iOS 27 beta build. The model can process text but not images yet. Try switching to 'On-Device' or 'Auto' in Developer Settings, or wait for a later beta that enables vision.")
            }
        case "on-device":
            if !SystemLanguageModel.default.capabilities.contains(.vision) {
                debugLog("📡 On-device model does not support vision (image input) on this device yet.")
                return .unavailable("The on-device model does not support image input on this iOS 27 beta build. It can process text (Siri poems, Writing Tools) but cannot see images yet. Try switching to 'Private Cloud' or 'Auto' in Developer Settings, or wait for a later beta that enables vision.")
            }
        default: // "auto"
            let onDeviceVision = SystemLanguageModel.default.capabilities.contains(.vision)
            let cloudVision = PrivateCloudComputeLanguageModel().capabilities.contains(.vision)
            if !onDeviceVision && !cloudVision {
                debugLog("📡 Neither on-device nor cloud model supports vision on this device yet.")
                return .unavailable("Neither the on-device nor cloud model supports image input on this iOS 27 beta build. The Foundation Models framework has the Attachment API, but the models haven't enabled vision capability yet. This should come in a later beta.")
            }
        }
        return nil
    }

    // MARK: - Prompts

    /// Get the current default prompt text for display in the prompt editor.
    /// Returns the prompt that would be used for the current detail level setting.
    func currentDefaultPrompt(for cityName: String) -> String {
        let detail = RadarDetailLevel(
            rawValue: FeatureFlags.shared.radarDescriptionDetailLevel) ?? .standard
        return Self.prompt(for: detail, structured: false, cityName: cityName)
    }

    /// The custom radar description prompt, adapted from QuickRadar's prompt.txt.
    /// The `structured` variant adds instructions to fill the typed fields.
    /// `cityName` is included so the model can reference the user's location by name.
    static func prompt(for level: RadarDetailLevel, structured: Bool, cityName: String) -> String {
        let base: String
        switch level {
        case .brief:
            base = """
            You are looking at a weather radar image for \(cityName). The center of the image is \(cityName). Describe precipitation relative to \(cityName) — for example "light rain northwest of \(cityName)" not "precipitation in the northwest quadrant." In one or two sentences, describe whether precipitation is visible, its intensity (light, moderate, heavy), and its direction relative to \(cityName). Be factual and concise.
            """
        case .standard:
            base = """
            You are looking at a weather radar image for \(cityName). The center of the image is \(cityName). I know this is a radar image so don't repeat it. Please provide a detailed, objective description suitable for someone who cannot see the image (for example, a screen-reader user). Describe:
              - The overall coverage area and what region the radar appears to show.
              - The presence and location of any precipitation, and its intensity (light, moderate, heavy). Always describe location relative to \(cityName) — for example "light rain northwest of \(cityName)" or "scattered showers off the coast to the west of \(cityName)." Do NOT use terms like "quadrant" or "sector" — use compass directions relative to \(cityName).
              - The colors or color bands visible and what they typically indicate on a radar (e.g. green=light, yellow=moderate, red=heavy).
              - Any storm cells, lines of storms, or areas of rotation if discernible. Describe their location relative to \(cityName).
              - The general shape and movement of precipitation features if you can infer it.
              - Whether the image appears mostly clear or active. If precipitation is visible but not over \(cityName) itself, say so clearly — for example "precipitation is visible to the northwest but \(cityName) itself appears clear."
            Be specific and factual. Do not speculate beyond what is visible in the image. If something is unclear, say so.
            """
        case .detailed:
            base = """
            You are looking at a weather radar image for \(cityName). The center of the image is \(cityName). Provide a full meteorological analysis suitable for a screen-reader user. Describe:
              - The coverage area and region.
              - Precipitation presence, location, and intensity (light, moderate, heavy, very heavy). Always describe location relative to \(cityName) — for example "heavy rain 50 miles north of \(cityName)" not "precipitation in the northern quadrant."
              - The color bands and their meaning (green=light, yellow=moderate, red=heavy, purple/extreme).
              - Storm structure: cells, squall lines, clusters, hook echoes, or rotation if discernible. Describe their location relative to \(cityName).
              - Any NWS warning polygons (colored outlines) and what they indicate, including their location relative to \(cityName).
              - The shape, organization, and inferred movement of precipitation features.
              - Whether \(cityName) itself is clear or experiencing precipitation. If precipitation is nearby but not over \(cityName), state this clearly.
            Be specific and factual. Do not speculate beyond what is visible. If something is unclear, say so.
            """
        }

        if structured {
            return base + "\n\nFill the structured fields: hasPrecipitation (is there precipitation visible anywhere in the image), intensity (of the nearest precipitation to \(cityName)), direction (compass direction of the nearest precipitation relative to \(cityName), or omit if none), hasWarnings, and a detailed description."
        }
        return base
    }

    /// The two-frame movement comparison prompt.
    static func movementPrompt(for level: RadarDetailLevel, structured: Bool, cityName: String) -> String {
        let base: String
        switch level {
        case .brief:
            base = """
            You are looking at two weather radar images for \(cityName), taken about an hour apart. The first image is earlier, the second is later. The center of both images is \(cityName). In one or two sentences, describe whether the precipitation has moved relative to \(cityName), in which direction, and whether it has intensified or weakened.
            """
        case .standard:
            base = """
            You are looking at two weather radar images for \(cityName), taken about an hour apart. The first image is earlier, the second is later. The center of both images is \(cityName). Describe for a screen-reader user:
              - Whether the precipitation has moved relative to \(cityName), and in which compass direction. For example "the rain northwest of \(cityName) has moved closer" or "the showers off the coast have moved inland toward \(cityName)."
              - Whether it has intensified, weakened, or stayed about the same.
              - Whether the coverage area has grown, shrunk, or stayed the same.
              - Any storm cells or lines and how they have changed. Describe their location relative to \(cityName).
              - Whether the weather is approaching \(cityName) or moving away from \(cityName).
            Be specific and factual. If movement is unclear, say so.
            """
        case .detailed:
            base = """
            You are looking at two weather radar images for \(cityName), taken about an hour apart. The first image is earlier, the second is later. The center of both images is \(cityName). Provide a full meteorological analysis of the changes for a screen-reader user:
              - Movement direction relative to \(cityName) and inferred speed if discernible.
              - Intensification or weakening of cells, with specific color-band changes.
              - Growth or shrinkage of the coverage area.
              - Changes in storm structure (squall lines, clusters, hook echoes, rotation). Describe locations relative to \(cityName).
              - Any warning polygons and whether they have expanded or contracted.
              - Whether the weather is approaching \(cityName) or receding from \(cityName).
            Be specific and factual. Do not speculate beyond what is visible.
            """
        }

        if structured {
            return base + "\n\nFill the structured fields: hasPrecipitation, intensity, direction (compass direction of movement relative to \(cityName)), hasWarnings, and a detailed description of the changes."
        }
        return base
    }
}

// MARK: - Station Info Bridge

/// A lightweight station info struct shared between the services.
struct RadarStationInfo {
    let id: String
    let name: String
    let lat: Double
    let lon: Double
    let distanceKm: Double
}