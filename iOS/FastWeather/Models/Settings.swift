//
//  Settings.swift
//  Fast Weather
//
//  App settings and configuration
//

import Foundation

enum DisplayMode: String, CaseIterable, Codable {
    case condensed = "Condensed"
    case details = "Details"
}

enum WeatherFieldType: String, CaseIterable, Codable {
    case temperature = "Temperature"
    case conditions = "Conditions"
    case feelsLike = "Feels Like"
    case humidity = "Humidity"
    case windSpeed = "Wind Speed"
    case windDirection = "Wind Direction"
    case highTemp = "High Temperature"
    case lowTemp = "Low Temperature"
    case sunrise = "Sunrise"
    case sunset = "Sunset"
}

enum DetailCategory: String, CaseIterable, Codable {
    case weatherAlerts = "Weather Alerts"
    case currentConditions = "Current Conditions"
    case precipitation = "Precipitation"
    case todaysForecast = "Today's Forecast"
    case hourlyForecast = "24-Hour Forecast"
    case dailyForecast = "16-Day Forecast"
    case historicalWeather = "Historical Weather"
    case location = "Location"
}

struct DetailCategoryField: Codable, Identifiable, Equatable {
    let id: String
    let category: DetailCategory
    var isEnabled: Bool
    
    init(category: DetailCategory, isEnabled: Bool = true) {
        self.id = category.rawValue
        self.category = category
        self.isEnabled = isEnabled
    }
}

struct WeatherField: Codable, Identifiable, Equatable {
    let id: String
    let type: WeatherFieldType
    var isEnabled: Bool
    
    init(type: WeatherFieldType, isEnabled: Bool = true) {
        self.id = type.rawValue
        self.type = type
        self.isEnabled = isEnabled
    }
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

enum PressureUnit: String, CaseIterable, Codable {
    case hPa = "hPa"
    case inHg = "inHg"
    case mmHg = "mmHg"
    
    func convert(_ hPa: Double) -> Double {
        switch self {
        case .hPa:
            return hPa
        case .inHg:
            return hPa * 0.02953
        case .mmHg:
            return hPa * 0.750062
        }
    }
}

struct AppSettings: Codable {
    var displayMode: DisplayMode = .condensed
    var temperatureUnit: TemperatureUnit = .fahrenheit
    var windSpeedUnit: WindSpeedUnit = .mph
    var precipitationUnit: PrecipitationUnit = .inches
    var pressureUnit: PressureUnit = .inHg
    var historicalYearsBack: Int = 20
    
    // Ordered weather fields with enable/disable state
    var weatherFields: [WeatherField] = [
        WeatherField(type: .temperature, isEnabled: true),
        WeatherField(type: .conditions, isEnabled: true),
        WeatherField(type: .feelsLike, isEnabled: true),
        WeatherField(type: .humidity, isEnabled: true),
        WeatherField(type: .windSpeed, isEnabled: true),
        WeatherField(type: .windDirection, isEnabled: true),
        WeatherField(type: .highTemp, isEnabled: true),
        WeatherField(type: .lowTemp, isEnabled: true),
        WeatherField(type: .sunrise, isEnabled: true),
        WeatherField(type: .sunset, isEnabled: true)
    ]
    
    // Detail categories with enable/disable and order control
    var detailCategories: [DetailCategoryField] = [
        DetailCategoryField(category: .weatherAlerts, isEnabled: true),
        DetailCategoryField(category: .todaysForecast, isEnabled: true),
        DetailCategoryField(category: .currentConditions, isEnabled: true),
        DetailCategoryField(category: .precipitation, isEnabled: true),
        DetailCategoryField(category: .hourlyForecast, isEnabled: true),
        DetailCategoryField(category: .dailyForecast, isEnabled: true),
        DetailCategoryField(category: .location, isEnabled: true)
    ]
    
    // Legacy properties for backward compatibility (deprecated)
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
