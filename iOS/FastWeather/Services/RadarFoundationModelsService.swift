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

/// The prompt mode for the radar description.
enum RadarDetailLevel: String, CaseIterable {
    case interpret
    case describe
    case combined

    var label: String {
        switch self {
        case .interpret: return "Interpret"
        case .describe:  return "Describe"
        case .combined:  return "Combined"
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

        let detail = RadarDetailLevel(
            rawValue: FeatureFlags.shared.radarDescriptionDetailLevel) ?? .interpret

        // Interpret mode always uses two frames — motion is the essence of radar
        // for an accessibility user who just wants to know what's coming.
        // Describe/Combined use two frames only when the explicit flag is on.
        // Custom prompt is always single-frame.
        if customPrompt == nil, detail == .interpret || FeatureFlags.shared.radarTwoFrameMovementEnabled {
            let result = await describeMovement(city: city, station: station)
            if case .error(let msg) = result {
                debugLog("📡 Movement failed (\(msg)), falling back to single-frame")
                // Fall through to single-frame below
            } else {
                return result
            }
        }

        // Single-frame path (Describe / Combined modes, or interpret fallback)
        guard let image = await RadarDescriptionService.shared.downloadImage(
            stationId: station.id) else {
            return .error("Could not download the radar image for station \(station.id).")
        }

        guard let cgImage = image.cgImage else {
            return .error("The radar image could not be processed.")
        }

        let useStructured = customPrompt == nil && FeatureFlags.shared.radarStructuredOutputEnabled
        // Direction the city lies relative to the radar station (which is the
        // image center). Lets the prompt tell the model where to look.
        let cityDir = Self.compassDirection(fromLat: station.lat, fromLon: station.lon,
                                            toLat: city.latitude, toLon: city.longitude)
        // Use custom prompt if provided, otherwise the built-in prompt
        let prompt = customPrompt ?? Self.prompt(for: detail, structured: useStructured,
                                                 cityName: city.name,
                                                 stationName: station.name,
                                                 cityDirection: cityDir)

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
            rawValue: FeatureFlags.shared.radarDescriptionDetailLevel) ?? .interpret
        let useStructured = FeatureFlags.shared.radarStructuredOutputEnabled
        let cityDir = Self.compassDirection(fromLat: station.lat, fromLon: station.lon,
                                            toLat: city.latitude, toLon: city.longitude)
        let prompt = Self.movementPrompt(for: detail, structured: useStructured,
                                         cityName: city.name,
                                         stationName: station.name,
                                         cityDirection: cityDir)

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
                // Interpret mode: plain text result — the user doesn't need to know
                // two frames were used, they just get the interpretation.
                if detail == .interpret {
                    return .text(description: analysis.description, image: lastFrame,
                                 stationId: station.id, stationName: station.name)
                }
                return .movement(analysis, firstFrame: firstFrame, lastFrame: lastFrame,
                                 stationId: station.id, stationName: station.name)
            } else {
                let response = try await session.respond {
                    prompt
                    firstAttachment
                    lastAttachment
                }
                if detail == .interpret {
                    return .text(description: response.content, image: lastFrame,
                                 stationId: station.id, stationName: station.name)
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
            rawValue: FeatureFlags.shared.radarDescriptionDetailLevel) ?? .interpret
        return Self.prompt(for: detail, structured: false, cityName: cityName)
    }

    /// Compass direction (8-point) FROM one coordinate TO another — e.g. the
    /// direction the city lies relative to the radar station.
    static func compassDirection(fromLat: Double, fromLon: Double,
                                 toLat: Double, toLon: Double) -> String {
        let dLon = (toLon - fromLon) * .pi / 180
        let lat1 = fromLat * .pi / 180
        let lat2 = toLat * .pi / 180
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        var deg = atan2(y, x) * 180 / .pi
        if deg < 0 { deg += 360 }
        let points = ["north", "northeast", "east", "southeast",
                      "south", "southwest", "west", "northwest"]
        let idx = Int((deg + 22.5) / 45) % 8
        return points[idx]
    }

    /// Builds the "where is the city in this image" preamble. NWS RIDGE single-
    /// station images are centered on the RADAR STATION, not the user's city, so
    /// the model must locate the city by its on-map label, not assume center.
    static func cityLocator(cityName: String, stationName: String?,
                            cityDirection: String?, plural: Bool) -> String {
        let imageRef = plural ? "Both images are" : "This image is"
        if let station = stationName {
            let offset = cityDirection.map { " toward the \($0) of center" } ?? ""
            return """
            LOCATING \(cityName): \(imageRef) from the \(station) radar station, centered on that station — NOT on \(cityName). \(cityName) is labeled on the map\(offset). The image covers a large area containing many cities and counties.

            Describe where precipitation actually IS using the named cities, counties, and geographic features visible on the map. Then state clearly whether \(cityName) itself is under precipitation or is clear. Do NOT assume precipitation elsewhere on the map is near \(cityName) — report where it actually is by name.
            """
        } else {
            return """
            LOCATING \(cityName): \(cityName) is labeled on the map. \(imageRef) centered on a radar station, not on \(cityName), and covers a large area containing many cities and counties.

            Describe where precipitation actually IS using the named cities, counties, and geographic features visible on the map. Then state clearly whether \(cityName) itself is under precipitation or is clear. Do NOT assume precipitation elsewhere on the map is near \(cityName) — report where it actually is by name.
            """
        }
    }

    /// Radar description prompt for the selected mode.
    /// - interpret: plain-language impact for someone in cityName — no jargon
    /// - describe: objective, technical description of what is visible — no advice
    /// - combined: description first, then plain-language interpretation
    static func prompt(for level: RadarDetailLevel, structured: Bool, cityName: String,
                       stationName: String? = nil, cityDirection: String? = nil) -> String {
        let locator = cityLocator(cityName: cityName, stationName: stationName,
                                  cityDirection: cityDirection, plural: false)
        let base: String
        switch level {
        case .interpret:
            base = """
            You are interpreting a weather radar image for \(cityName).

            \(locator)

            IMPORTANT — things in this image that are NOT precipitation or warnings:
            • TOP OF IMAGE: A legend strip showing colored boxes labeled TORNADO (red), SEVERE THUNDERSTORM (orange), FLASH FLOOD (green), SPECIAL MARINE (yellow), SNOW SQUALL (pink). These are labels describing what warning polygons look like — they are NOT active warnings. Ignore them.
            • BOTTOM OF IMAGE: A color scale bar (dBZ range). This is a reference scale, not precipitation.
            • RED/BROWN LINES throughout the map: County and state border lines. These are NOT warnings.
            • BLUE/TEAL FILLED REGION (Lake Michigan, lakes): Solid, fixed shape on the eastern edge of the map — NOT precipitation. Do NOT confuse this with blue precipitation echoes.
            • BLUE PATCHES scattered across the map: These ARE real precipitation (light rain, 5–35 dBZ). Blue is the most common precipitation color and must not be ignored or mistaken for water.
            • If the map area is white or blank, there is no precipitation.

            An ACTIVE WARNING POLYGON looks like: a large, thick colored outline (red, orange, or yellow) drawn directly over the map geography, enclosing a county-sized area. It is clearly separate from the thin county border grid.

            In 2–3 sentences, tell me in plain language:
            - Where is precipitation (blue, green, yellow, red, purple) on this map? Name the cities, counties, or regions it covers. Blue is light rain and counts as precipitation.
            - Is \(cityName) itself under precipitation, or is it clear? If precipitation is nearby, say where it is and whether it appears to be approaching \(cityName).
            - Are there any active warning polygons (thick colored outlines enclosing map areas, NOT the top legend boxes)?
            Focus on what this means for someone in \(cityName). No technical jargon. If the map area is mostly white/blank, say there is no precipitation.
            """
        case .describe:
            base = """
            You are looking at a weather radar image for \(cityName).

            \(locator)

            IMPORTANT — things in this image that are NOT precipitation or warnings:
            • TOP OF IMAGE: A legend strip showing warning type icons (TORNADO, SEVERE THUNDERSTORM, FLASH FLOOD, etc.). These are reference labels — NOT active warnings on the map.
            • BOTTOM OF IMAGE: A color scale bar (dBZ). Reference only — not precipitation.
            • RED/BROWN LINES throughout the map: County and state borders, always present. NOT warnings.
            • BLUE/TEAL FILLED REGION (Lake Michigan, lakes): Solid, fixed shape on the eastern edge of the map — NOT precipitation. Do NOT confuse this with blue precipitation echoes.
            • BLUE PATCHES scattered across the map: These ARE real precipitation (light rain, 5–35 dBZ). Blue is the most common precipitation color and must not be ignored or mistaken for water.
            • If the map area is white or uniformly blank, there is no precipitation.

            Provide an objective, factual description of what is visible in the MAP AREA ONLY:
            - Precipitation: its presence (or absence), and where it is — name the cities, counties, or geographic features it covers. Color key: blue = light rain (very common), green = light-moderate, yellow = moderate, red = heavy, purple = extreme. White/blank = none.
            - Storm structure: any distinct cells, squall lines, or clusters, and which named areas they are over.
            - Active warning polygons: THICK colored outlines enclosing county-sized geographic areas, distinct from the thin county/state border grid. Only report if clearly an overlay on the map — not the top legend.
            - Whether \(cityName) itself is under precipitation or clear. If precipitation exists but is not over \(cityName), state where it is.
            Describe only what is in the map area. Do not interpret or offer advice.
            """
        case .combined:
            base = """
            You are looking at a weather radar image for \(cityName).

            \(locator)

            IMPORTANT — things in this image that are NOT precipitation or warnings:
            • TOP: A legend strip with colored boxes for TORNADO, SEVERE THUNDERSTORM, FLASH FLOOD, etc. Reference only — not active.
            • BOTTOM: A color scale bar. Reference only.
            • RED/BROWN LINES across the map: County and state borders. Not warnings.
            • BLUE/TEAL FILLED REGION (Lake Michigan, lakes): Solid, fixed shape on the eastern edge of the map — NOT precipitation. Do NOT confuse this with blue precipitation echoes.
            • BLUE PATCHES scattered across the map: These ARE real precipitation (light rain, 5–35 dBZ). Blue is the most common precipitation color and must not be ignored or mistaken for water.
            • White/blank map area = no precipitation.

            Active warnings are THICK colored polygon outlines drawn directly over map geography — clearly separate from the thin county border grid. The top legend boxes are not warnings.

            Provide a two-part response:

            Part 1 — Description: Describe what is visible in the map area. Name the cities, counties, or geographic features where precipitation is located (blue=light, green=light-moderate, yellow=moderate, red=heavy, purple=extreme; white/blank=none). Note any storm cells or squall lines and which areas they cover. Note any active warning polygons (thick outlines over the map — not the legend). State whether \(cityName) itself is under precipitation or clear.

            Part 2 — Interpretation: In plain language, state what this means for someone in \(cityName) — is precipitation over or approaching \(cityName), how intense, and do any active map warnings affect \(cityName)?
            """
        }

        if structured {
            return base + "\n\nFill the structured fields: hasPrecipitation (is there precipitation visible anywhere in the image), intensity (of the nearest precipitation to \(cityName)), direction (compass direction of the nearest precipitation relative to \(cityName), or omit if none), hasWarnings, and a detailed description."
        }
        return base
    }

    /// Two-frame movement comparison prompt for the selected mode.
    static func movementPrompt(for level: RadarDetailLevel, structured: Bool, cityName: String,
                               stationName: String? = nil, cityDirection: String? = nil) -> String {
        let locator = cityLocator(cityName: cityName, stationName: stationName,
                                  cityDirection: cityDirection, plural: true)
        let base: String
        switch level {
        case .interpret:
            base = """
            You are looking at two weather radar images for \(cityName), taken about an hour apart. The first image is earlier, the second is later.

            \(locator)

            IMPORTANT — things in both images that are NOT precipitation or warnings:
            • TOP OF IMAGE: A legend strip showing colored boxes for TORNADO, SEVERE THUNDERSTORM, FLASH FLOOD, etc. Reference labels — not active warnings.
            • BOTTOM: Color scale bar. Reference only.
            • RED/BROWN LINES: County and state borders, identical in both frames. Not warnings.
            • BLUE/TEAL FILLED REGION (Lake Michigan, lakes): Solid, fixed shape on the eastern edge of the map — NOT precipitation. Do NOT confuse this with blue precipitation echoes.
            • BLUE PATCHES scattered across the map: These ARE real precipitation (light rain, 5–35 dBZ). Blue is the most common precipitation color and must not be ignored or mistaken for water.
            • White/blank map area = no precipitation.

            Focus on what CHANGED in the colored precipitation areas (blue, green, yellow, red, purple) between the two frames. Blue patches are light rain and count as precipitation. In 2–3 sentences: Name where the precipitation is on the map and how it moved — which cities or regions gained or lost coverage. Is it moving toward \(cityName) or away from it? What should someone in \(cityName) expect in the coming hour? If both frames show no precipitation (white/blank map), say so clearly.
            """
        case .describe:
            base = """
            You are comparing two weather radar images for \(cityName), taken about an hour apart. The first image is earlier, the second is later.

            \(locator)

            IMPORTANT — things present in both images that are NOT precipitation or warnings:
            • TOP: Legend strip with TORNADO, SEVERE THUNDERSTORM, FLASH FLOOD labels — reference, not active.
            • BOTTOM: Color scale bar — reference only.
            • RED/BROWN LINES: County and state borders — always present, NOT warnings.
            • BLUE/TEAL FILLED REGION (Lake Michigan, lakes): Solid, fixed shape on the eastern edge of the map — NOT precipitation. Do NOT confuse this with blue precipitation echoes.
            • BLUE PATCHES scattered across the map: These ARE real precipitation (light rain, 5–35 dBZ). Blue is the most common precipitation color and must not be ignored or mistaken for water.
            • White/blank map area = no precipitation.

            Active warnings are THICK colored polygon outlines drawn over map geography — clearly separate from the thin county border grid.

            Describe the changes between the two MAP AREAS objectively:
            - Where precipitation (blue=light, green=light-moderate, yellow=moderate, red=heavy, purple=extreme) moved — name the cities, counties, or regions it covered in each frame. If no precipitation in either frame, say so.
            - Whether intensity changed (color band shifts).
            - How the coverage area changed, and whether \(cityName) moved into or out of precipitation.
            - Any changes in storm structure (cells, squall lines, rotation).
            - Any changes in active warning polygons (thick map overlays, not the top legend).
            Describe only what changed between the frames. Do not speculate or offer advice.
            """
        case .combined:
            base = """
            You are comparing two weather radar images for \(cityName), taken about an hour apart. The first image is earlier, the second is later.

            \(locator)

            IMPORTANT — NOT precipitation or warnings:
            • TOP: Legend boxes (TORNADO, SEVERE THUNDERSTORM, etc.) — reference labels, not active.
            • BOTTOM: Color scale bar — reference only.
            • RED/BROWN LINES: County/state borders, always present. Not warnings.
            • BLUE/TEAL FILLED REGION (Lake Michigan, lakes): Solid, fixed shape on the eastern edge of the map — NOT precipitation. Do NOT confuse this with blue precipitation echoes.
            • BLUE PATCHES scattered across the map: These ARE real precipitation (light rain, 5–35 dBZ). Blue is the most common precipitation color and must not be ignored or mistaken for water.
            • White/blank = no precipitation.

            Active warnings = THICK colored polygon outlines over map geography, distinct from the thin county grid.

            Provide a two-part response:

            Part 1 — Changes: Describe what changed in the map area between the two frames: name which cities, counties, or regions gained or lost precipitation coverage (blue=light, green=light-moderate, yellow=moderate, red=heavy, purple=extreme), how intensity shifted, how storm structure changed, and any changes in active map warning polygons. State whether \(cityName) is under precipitation in either frame. If both frames show no precipitation (white/blank), say so.

            Part 2 — Meaning: In plain language, state what these changes mean for \(cityName) — is weather approaching or receding from \(cityName), getting stronger or weaker, and what should someone in \(cityName) expect in the coming hour?
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

