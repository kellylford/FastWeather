//
//  RadarAnalysisGenerable.swift
//  Fast Weather
//
//  Structured output for the AI radar description using Apple's Foundation
//  Models framework (@Generable). Instead of free text that we regex-parse
//  for direction keywords, the model returns a typed struct with discrete
//  fields — hasPrecipitation, intensity, direction, hasWarnings, and a
//  free-form description.
//
//  Requires iOS 27.0+ (deployment target for this branch). Gated behind
//  FeatureFlags.radarStructuredOutputEnabled (OFF by default). When the flag
//  is off, the app uses the free-text path.
//

import Foundation
import FoundationModels

/// A structured radar analysis. This is the plain app-level type used
/// throughout the app. On iOS 27+ with the structured-output flag on, it's
/// populated directly from the Foundation Model's @Generable response.
struct RadarAnalysis: Codable, Equatable {
    /// Whether any precipitation is visible in the radar image.
    let hasPrecipitation: Bool
    /// Intensity bucket: "none", "light", "moderate", "heavy", or "very heavy".
    let intensity: String
    /// Compass direction of the nearest precipitation relative to the user,
    /// e.g. "northeast". Nil when no precipitation or direction is discernible.
    let direction: String?
    /// Whether any NWS warning polygons are visible in the image.
    let hasWarnings: Bool
    /// Free-form plain-language description of the radar image.
    let description: String

    /// Compass bearing (degrees, 0 = N) parsed from `direction`, or nil.
    var directionBearing: Double? {
        RadarAnalysis.bearing(for: direction)
    }

    /// Map a 16-point compass string to a bearing in degrees.
    static func bearing(for direction: String?) -> Double? {
        guard let dir = direction?.lowercased().trimmingCharacters(in: .whitespaces) else {
            return nil
        }
        let table: [String: Double] = [
            "north": 0, "n": 0,
            "north-northeast": 22.5, "nne": 22.5, "n-ne": 22.5,
            "northeast": 45, "ne": 45,
            "east-northeast": 67.5, "ene": 67.5, "e-ne": 67.5,
            "east": 90, "e": 90,
            "east-southeast": 112.5, "ese": 112.5, "e-se": 112.5,
            "southeast": 135, "se": 135,
            "south-southeast": 157.5, "sse": 157.5, "s-se": 157.5,
            "south": 180, "s": 180,
            "south-southwest": 202.5, "ssw": 202.5, "s-sw": 202.5,
            "southwest": 225, "sw": 225,
            "west-southwest": 247.5, "wsw": 247.5, "w-sw": 247.5,
            "west": 270, "w": 270,
            "west-northwest": 292.5, "wnw": 292.5, "w-nw": 292.5,
            "northwest": 315, "nw": 315,
            "north-northwest": 337.5, "nnw": 337.5, "n-nw": 337.5,
        ]
        if let b = table[dir] { return b }
        if let firstWord = dir.split(separator: " ").first,
           let b = table[String(firstWord)] {
            return b
        }
        return nil
    }
}

/// The @Generable wrapper that the Foundation Model fills in. Converted to
/// a plain RadarAnalysis for use throughout the app.
@Generable
struct GenerableRadarAnalysis {
    @Guide(description: "Is any precipitation visible in the radar image?")
    var hasPrecipitation: Bool

    @Guide(description: "Intensity of the nearest precipitation: none, light, moderate, heavy, or very heavy")
    var intensity: String

    @Guide(description: "Compass direction of the nearest precipitation relative to the center of the image (e.g. northeast, southwest). Omit if no precipitation or direction is unclear.")
    var direction: String?

    @Guide(description: "Are any NWS warning polygons (colored outlines) visible in the image?")
    var hasWarnings: Bool

    @Guide(description: "A detailed plain-language description of the radar image suitable for a screen-reader user")
    var description: String
}

extension GenerableRadarAnalysis {
    /// Convert the @Generable struct to the plain app-level RadarAnalysis.
    func toRadarAnalysis() -> RadarAnalysis {
        RadarAnalysis(
            hasPrecipitation: hasPrecipitation,
            intensity: intensity,
            direction: direction,
            hasWarnings: hasWarnings,
            description: description
        )
    }
}