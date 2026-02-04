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
    let source: AlertSource      // NWS or WeatherKit
    let detailsURL: String?      // Optional URL for more info
    
    var isExpired: Bool {
        Date() > expires
    }
}

enum AlertSource: String, Codable {
    case nws = "NWS"              // US National Weather Service
    case weatherKit = "WeatherKit" // Apple WeatherKit (international)
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
    private let headlineRaw: FlexibleStringOrArray?
    private let descriptionRaw: FlexibleStringOrArray?
    private let instructionRaw: FlexibleStringOrArray?
    let onset: String?
    let expires: String?
    private let areaDescRaw: FlexibleStringOrArray?
    
    var headline: String {
        switch headlineRaw {
        case .string(let str): return str
        case .array(let arr): return arr.joined(separator: " ")
        case .none: return ""
        }
    }
    
    var description: String {
        switch descriptionRaw {
        case .string(let str): return str
        case .array(let arr): return arr.joined(separator: "\n")
        case .none: return ""
        }
    }
    
    var instruction: String? {
        switch instructionRaw {
        case .string(let str): return str.isEmpty ? nil : str
        case .array(let arr): return arr.isEmpty ? nil : arr.joined(separator: "\n")
        case .none: return nil
        }
    }
    
    var areaDesc: String? {
        switch areaDescRaw {
        case .string(let str): return str
        case .array(let arr): return arr.joined(separator: ", ")
        case .none: return nil
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case id, event, severity, onset, expires
        case headlineRaw = "headline"
        case descriptionRaw = "description"
        case instructionRaw = "instruction"
        case areaDescRaw = "areaDesc"
    }
}

// Helper enum to handle NWS API's inconsistent field types
enum FlexibleStringOrArray: Codable {
    case string(String)
    case array([String])
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        // Try standard types first
        if let str = try? container.decode(String.self) {
            self = .string(str)
            return
        }
        
        if let arr = try? container.decode([String].self) {
            self = .array(arr)
            return
        }
        
        // Handle numeric types (NWS API bug - sometimes returns numbers for text fields)
        if let int = try? container.decode(Int.self) {
            print("⚠️ NWS API returned Int (\(int)) for string field - converting to string")
            self = .string(String(int))
            return
        }
        
        if let double = try? container.decode(Double.self) {
            print("⚠️ NWS API returned Double (\(double)) for string field - converting to string")
            self = .string(String(double))
            return
        }
        
        if let bool = try? container.decode(Bool.self) {
            print("⚠️ NWS API returned Bool (\(bool)) for string field - converting to string")
            self = .string(String(bool))
            return
        }
        
        // Handle Date objects (another NWS API bug)
        if let date = try? container.decode(Date.self) {
            print("⚠️ NWS API returned Date object for string field - using empty string")
            self = .string("")
            return
        }
        
        // Handle null values
        if container.decodeNil() {
            self = .string("")
            return
        }
        
        // Last resort - log the failure and use empty string
        print("⚠️ NWS API returned unknown type for string field - using empty string")
        print("   CodingPath: \(decoder.codingPath.map { $0.stringValue }.joined(separator: "."))")
        self = .string("")
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let str): try container.encode(str)
        case .array(let arr): try container.encode(arr)
        }
    }
}

