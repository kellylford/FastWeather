//
//  WeatherAlert.swift
//  Fast Weather
//
//  Weather alert models for severe weather warnings from NWS
//

import Foundation
import SwiftUI

struct WeatherAlert: Codable, Identifiable {
    let id: String
    let event: String           // "Tornado Warning"
    let severity: AlertSeverity
    let headline: String
    let description: String
    let instruction: String?
    let onset: Date
    let expires: Date
    let areaDesc: String?
    
    var isExpired: Bool {
        Date() > expires
    }
}

enum AlertSeverity: String, Codable, CaseIterable {
    case extreme = "Extreme"
    case severe = "Severe"
    case moderate = "Moderate"
    case minor = "Minor"
    case unknown = "Unknown"
    
    var color: Color {
        switch self {
        case .extreme: return .red
        case .severe: return .orange
        case .moderate: return .yellow
        case .minor: return .blue
        case .unknown: return .gray
        }
    }
    
    var iconName: String {
        switch self {
        case .extreme, .severe, .moderate: return "exclamationmark.triangle.fill"
        case .minor: return "exclamationmark.circle.fill"
        case .unknown: return "exclamationmark.circle"
        }
    }
}

// MARK: - NWS API Response Models

struct NWSAlertsResponse: Codable {
    let features: [NWSAlertFeature]
}

struct NWSAlertFeature: Codable {
    let properties: NWSAlertProperties
}

struct NWSAlertProperties: Codable {
    let id: String
    let event: String
    let severity: String?
    let headline: String
    let description: String
    let instruction: String?
    let onset: String?
    let expires: String?
    let areaDesc: String?
}
