//
//  RadarCrossValidation.swift
//  Fast Weather
//
//  Cross-validation between Storm Approach (numeric motion estimate) and
//  an AI radar image description (text-based motion estimate).
//
//  The QuickRadar experiment proved both tracks independently agree on
//  precipitation presence (100% across 40 runs). The two-frame movement
//  experiment proved the AI can infer movement direction from two radar
//  frames. This service compares the two independent motion estimates and
//  produces a confidence-hedged narration:
//
//    • Both agree on direction → high confidence, state it plainly
//    • They disagree → lower confidence, hedge ("estimates differ")
//    • Only one available → use it with its own confidence level
//    • Neither available → say movement is unknown
//
//  This is the mechanism that turns three independent estimates (steering
//  wind, centroid drift, AI two-frame comparison) into one trustworthy
//  answer for a user who cannot glance at radar to cross-check.
//

import Foundation

/// Result of cross-validating Storm Approach's numeric motion estimate
/// against an AI radar description's text-based motion estimate.
struct CrossValidationResult {
    /// The unified motion direction (degrees, 0 = N). Nil if neither source could determine it.
    let towardBearing: Double?
    /// The unified speed estimate (km/h). Nil if not available.
    let speedKmh: Double?
    /// Confidence after cross-validation. May be higher than either source alone (agreement)
    /// or lower (disagreement).
    let confidence: MotionConfidence
    /// A plain-language narration of the motion, hedged by confidence.
    let narration: String
    /// Whether the two sources agreed on direction (when both were available).
    let sourcesAgree: Bool?
    /// Which sources were available.
    let sourcesUsed: [Source]

    enum Source: String, CaseIterable {
        case stormApproach = "Storm Approach (numeric)"
        case aiDescription = "AI radar description"
    }
}

enum RadarCrossValidation {

    /// Cross-validate Storm Approach's motion estimate against an AI radar description.
    ///
    /// - Parameters:
    ///   - stormApproach: The numeric Storm Approach result (may or may not have motion).
    ///   - aiDescription: The AI text description of the radar image (may mention movement).
    /// - Returns: A cross-validation result with unified direction, confidence, and narration.
    static func validate(stormApproach: StormApproach?,
                        aiDescription: String?) -> CrossValidationResult {

        var sources: [CrossValidationResult.Source] = []
        var stormBearing: Double?
        var stormSpeed: Double?
        var aiBearing: Double?

        // Extract Storm Approach's numeric estimate
        if let storm = stormApproach, let motion = storm.motion {
            stormBearing = motion.towardBearing
            stormSpeed = motion.speedKmh
            sources.append(.stormApproach)
        }

        // Extract AI description's text-based direction
        if let desc = aiDescription, !desc.isEmpty {
            if let bearing = parseDirection(from: desc) {
                aiBearing = bearing
                sources.append(.aiDescription)
            }
        }

        // Cross-validate
        let resultBearing: Double?
        let resultSpeed: Double?
        let confidence: MotionConfidence
        let agree: Bool?
        var narration: String

        switch (stormBearing, aiBearing) {
        case (let sb?, let ab?):
            // Both available — compare
            let diff = GeoMath.angularDifference(sb, ab)
            if diff < 45 {
                // Strong agreement — upgrade confidence
                agree = true
                resultBearing = sb  // prefer the numeric (more precise)
                resultSpeed = stormSpeed
                confidence = .high
                let dir = GeoMath.cardinalName(sb).lowercased()
                narration = "Moving \(dir)"
                if let speed = stormSpeed {
                    narration += " at about \(Int(speed.rounded())) km/h"
                }
                narration += ". Both the precipitation model and radar image analysis agree on this direction."
            } else if diff < 90 {
                // Rough agreement — medium confidence
                agree = false
                resultBearing = sb
                resultSpeed = stormSpeed
                confidence = .medium
                let stormDir = GeoMath.cardinalName(sb).lowercased()
                let aiDir = GeoMath.cardinalName(ab).lowercased()
                narration = "Moving generally \(stormDir). The precipitation model estimates \(stormDir)"
                if let speed = stormSpeed {
                    narration += " at about \(Int(speed.rounded())) km/h"
                }
                narration += ", while the radar image suggests \(aiDir). The estimates are close but not identical."
            } else {
                // Disagreement — low confidence, hedge
                agree = false
                resultBearing = sb
                resultSpeed = stormSpeed
                confidence = .low
                let stormDir = GeoMath.cardinalName(sb).lowercased()
                let aiDir = GeoMath.cardinalName(ab).lowercased()
                narration = "Direction is uncertain. The precipitation model suggests \(stormDir), but the radar image suggests \(aiDir). The estimates disagree — track carefully."
            }

        case (let sb?, nil):
            // Only Storm Approach available
            agree = nil
            resultBearing = sb
            resultSpeed = stormSpeed
            confidence = stormApproach?.motionConfidence ?? .medium
            let dir = GeoMath.cardinalName(sb).lowercased()
            narration = "Moving \(dir)"
            if let speed = stormSpeed {
                narration += " at about \(Int(speed.rounded())) km/h"
            }
            narration += "."
            // If AI description was available but didn't mention movement, note it
            if aiDescription != nil {
                narration += " The radar image description did not indicate a clear direction."
            }

        case (nil, let ab?):
            // Only AI description available
            agree = nil
            resultBearing = ab
            resultSpeed = nil
            confidence = .medium  // AI-only is medium — it can see direction but not speed
            let dir = GeoMath.cardinalName(ab).lowercased()
            narration = "Moving \(dir), based on radar image analysis. Speed is not available from the image."

        case (nil, nil):
            // Neither available
            agree = nil
            resultBearing = nil
            resultSpeed = nil
            confidence = .low
            narration = "Movement direction could not be determined from available data."
        }

        return CrossValidationResult(
            towardBearing: resultBearing,
            speedKmh: resultSpeed,
            confidence: confidence,
            narration: narration,
            sourcesAgree: agree,
            sourcesUsed: sources
        )
    }

    // MARK: - Direction Parsing

    /// Parse a compass direction from natural-language text.
    /// Looks for 8-point and 16-point compass directions in the text.
    /// Returns the bearing in degrees (0 = N), or nil if no direction is found.
    private static func parseDirection(from text: String) -> Double? {
        let lower = text.lowercased()

        // 16-point compass directions, ordered so longer names are checked first
        // (e.g. "north-northeast" before "northeast" before "north")
        let directions: [(phrase: String, bearing: Double)] = [
            ("north-northeast", 22.5),
            ("north-northwest", 337.5),
            ("east-northeast", 67.5),
            ("east-southeast", 112.5),
            ("south-southeast", 157.5),
            ("south-southwest", 202.5),
            ("west-southwest", 247.5),
            ("west-northwest", 292.5),
            ("northeast", 45),
            ("northwest", 315),
            ("southeast", 135),
            ("southwest", 225),
            ("north", 0),
            ("east", 90),
            ("south", 180),
            ("west", 270),
            ("e/ne", 67.5),      // common shorthand in AI descriptions
            ("w/ne", 67.5),
            ("e-ne", 67.5),
            ("n-ne", 22.5),
        ]

        // Look for "moving [direction]" or "toward the [direction]" or
        "movement toward [direction]" patterns first (most reliable),
        // then fall back to any mention of a direction word.
        let movementPatterns = [
            "moving ", "toward the ", "toward ", "movement toward ",
            "moving toward ", "moving generally ", "shifted ", "shifting ",
        ]

        for pattern in movementPatterns {
            if let range = lower.range(of: pattern) {
                let after = String(lower[range.upperBound...])
                for (phrase, bearing) in directions {
                    if after.hasPrefix(phrase) {
                        return bearing
                    }
                }
            }
        }

        // Fall back: look for any direction word near "movement" or "moving"
        if lower.contains("movement") || lower.contains("moving") {
            for (phrase, bearing) in directions {
                if lower.contains(phrase) {
                    return bearing
                }
            }
        }

        return nil
    }
}