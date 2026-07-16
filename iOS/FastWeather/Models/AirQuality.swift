//
//  AirQuality.swift
//  Fast Weather
//
//  Air quality models. The category thresholds and plain-language health
//  guidance here are the platform-portable core — the same table should drive
//  the web and Windows apps so wording never drifts between platforms.
//
//  Design rule (learned from a live Canadian-wildfire smoke event over Madison,
//  where the CAMS forecast model said "Good, 43" while a real monitor read 203
//  "Very Unhealthy"): believe the sky, not the model. Observed monitor readings
//  and active official air quality alerts always outrank a modeled estimate.
//

import SwiftUI

/// EPA US AQI category. The WORD and the health sentence carry the meaning;
/// `color` is decoration only and is always `.accessibilityHidden(true)` in the UI.
enum AQICategory: Int, CaseIterable {
    case good = 0
    case moderate
    case unhealthySensitive
    case unhealthy
    case veryUnhealthy
    case hazardous

    /// Classify a US AQI value (0–500) into its category.
    init(aqi: Int) {
        switch aqi {
        case ..<51:   self = .good
        case ..<101:  self = .moderate
        case ..<151:  self = .unhealthySensitive
        case ..<201:  self = .unhealthy
        case ..<301:  self = .veryUnhealthy
        default:      self = .hazardous
        }
    }

    /// The category word people recognize. Primary signal for everyone,
    /// and the ONLY signal for VoiceOver users.
    var word: String {
        switch self {
        case .good:               return "Good"
        case .moderate:           return "Moderate"
        case .unhealthySensitive: return "Unhealthy for Sensitive Groups"
        case .unhealthy:          return "Unhealthy"
        case .veryUnhealthy:      return "Very Unhealthy"
        case .hazardous:          return "Hazardous"
        }
    }

    /// Plain-language, one-sentence health guidance (paraphrased from EPA AQI guidance).
    var healthGuidance: String {
        switch self {
        case .good:
            return "Air quality is satisfactory and poses little or no risk."
        case .moderate:
            return "Acceptable, but unusually sensitive people should consider limiting long or intense time outdoors."
        case .unhealthySensitive:
            return "Sensitive groups may feel effects. Make outdoor activity shorter and less intense, and watch for coughing or shortness of breath."
        case .unhealthy:
            return "Everyone may begin to feel effects. Sensitive groups should move activities indoors; everyone else should keep outdoor time shorter and lighter."
        case .veryUnhealthy:
            return "Health alert: the risk is increased for everyone. Avoid outdoor exertion, and sensitive groups should stay indoors."
        case .hazardous:
            return "Emergency conditions: everyone should avoid outdoor activity and stay indoors with windows closed."
        }
    }

    /// Decorative band color following the conventional AQI palette. Never the
    /// sole carrier of meaning — always paired with `word` and hidden from VoiceOver.
    var color: Color {
        switch self {
        case .good:               return Color(red: 0.30, green: 0.69, blue: 0.31)
        case .moderate:           return Color(red: 0.85, green: 0.65, blue: 0.13)
        case .unhealthySensitive: return Color(red: 0.90, green: 0.49, blue: 0.13)
        case .unhealthy:          return Color(red: 0.83, green: 0.18, blue: 0.18)
        case .veryUnhealthy:      return Color(red: 0.56, green: 0.20, blue: 0.60)
        case .hazardous:          return Color(red: 0.49, green: 0.09, blue: 0.16)
        }
    }
}

/// One pollutant's contribution to the overall index.
struct AQIPollutant: Identifiable {
    let id = UUID()
    /// Human-readable, e.g. "Fine particles (PM2.5)".
    let displayName: String
    let aqi: Int
    let category: AQICategory
    /// True for the pollutant driving the overall (worst) index.
    let isDominant: Bool
}

/// Where the headline number came from. Drives the "observed" vs "modeled" label.
enum AQISource {
    case airNowObserved   // real ground monitors (US) — trustworthy for "now"
    case modelEstimate    // Open-Meteo CAMS — global, but lags smoke events
}

/// Resolved air-quality state for one city, after applying the "believe the sky" rule.
struct AirQualityReport {
    let reportingArea: String
    let headlineAQI: Int
    let headlineCategory: AQICategory
    /// Pretty name of the dominant pollutant, e.g. "Fine particles (PM2.5)".
    let dominantPollutant: String
    let pollutants: [AQIPollutant]
    let source: AQISource

    /// Active official air quality alert covering this location, if any.
    /// When present it dominates the card — a modeled "Good" must never contradict it.
    let activeAlert: WeatherAlert?

    /// The modeled CAMS estimate, kept only for transparency when it disagrees
    /// with the observed headline. Nil when unavailable or when it agrees.
    let modelDisagreementAQI: Int?

    /// Convenience: is the headline based on real observations?
    var isObserved: Bool { source == .airNowObserved }

    /// One-line VoiceOver summary of the headline — number, word, dominant
    /// pollutant, and health guidance, so the spoken experience never depends on color.
    var accessibilityHeadline: String {
        "Air quality index \(headlineAQI), \(headlineCategory.word). "
        + "Main pollutant, \(dominantPollutant). \(headlineCategory.healthGuidance)"
    }
}
