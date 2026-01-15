//
//  Settings.swift
//  FastWeather
//
//  App settings and configuration
//

import Foundation

enum ViewType: String, CaseIterable, Codable {
    case flat = "Flat"
    case table = "Table"
    case list = "List"
}

enum TemperatureUnit: String, CaseIterable, Codable {
    case fahrenheit = "°F"
    case celsius = "°C"
    
    func convert(_ celsius: Double) -> Double {
        switch self {
        case .fahrenheit:
            return celsius * 9/5 + 32
        case .celsius:
            return celsius
        }
    }
}

enum WindSpeedUnit: String, CaseIterable, Codable {
    case mph = "mph"
    case kmh = "km/h"
    
    func convert(_ kmh: Double) -> Double {
        switch self {
        case .mph:
            return kmh * 0.621371
        case .kmh:
            return kmh
        }
    }
}

enum PrecipitationUnit: String, CaseIterable, Codable {
    case inches = "in"
    case millimeters = "mm"
    
    func convert(_ mm: Double) -> Double {
        switch self {
        case .inches:
            return mm * 0.0393701
        case .millimeters:
            return mm
        }
    }
}

struct AppSettings: Codable {
    var defaultView: ViewType = .flat
    var temperatureUnit: TemperatureUnit = .fahrenheit
    var windSpeedUnit: WindSpeedUnit = .mph
    var precipitationUnit: PrecipitationUnit = .inches
    
    // Display settings for city list
    var showTemperature: Bool = true
    var showConditions: Bool = true
    var showFeelsLike: Bool = true
    var showHumidity: Bool = true
    var showWindSpeed: Bool = true
    var showWindDirection: Bool = true
    var showHighTemp: Bool = true
    var showLowTemp: Bool = true
    var showSunrise: Bool = true
    var showSunset: Bool = true
}
