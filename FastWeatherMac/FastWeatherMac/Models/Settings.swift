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

enum ViewMode: String, CaseIterable, Codable {
    case list = "List"
    case flat = "Flat"
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

enum DistanceUnit: String, CaseIterable, Codable {
    case miles = "mi"
    case kilometers = "km"
    
    /// Convert a distance value from kilometers to the target unit
    func convert(_ kilometers: Double) -> Double {
        switch self {
        case .miles:
            return kilometers * 0.621371
        case .kilometers:
            return kilometers
        }
    }
    
    /// Convert a distance value to kilometers from this unit
    func toKilometers(_ value: Double) -> Double {
        switch self {
        case .miles:
            return value / 0.621371
        case .kilometers:
            return value
        }
    }
    
    /// Get appropriate distance options for Weather Around Me picker
    var weatherAroundMeOptions: [Double] {
        switch self {
        case .miles:
            return [50, 100, 150, 200, 250, 300, 350]
        case .kilometers:
            return [80, 160, 240, 320, 400, 480, 560]
        }
    }
    
    /// Format a distance value with unit
    func format(_ value: Double, decimals: Int = 0) -> String {
        let formatString = decimals > 0 ? "%.\(decimals)f" : "%.0f"
        return String(format: "\(formatString) %@", value, self.rawValue)
    }
    
    /// Snap a distance value to the nearest "nice" value in this unit
    func snapToNearest(_ value: Double) -> Double {
        let options = weatherAroundMeOptions
        guard !options.isEmpty else { return value }
        
        // Find closest option
        return options.min(by: { abs($0 - value) < abs($1 - value) }) ?? options.first!
    }
    
    /// Get default distance unit based on user's locale (no permissions needed)
    static var defaultUnit: DistanceUnit {
        if Locale.current.measurementSystem == .us {
            return .miles
        } else {
            return .kilometers
        }
    }
}

struct AppSettings: Codable {
    var viewMode: ViewMode = .list
    var displayMode: DisplayMode = .condensed
    var temperatureUnit: TemperatureUnit = .fahrenheit
    var windSpeedUnit: WindSpeedUnit = .mph
    var precipitationUnit: PrecipitationUnit = .inches
    var pressureUnit: PressureUnit = .inHg
    var distanceUnit: DistanceUnit = DistanceUnit.defaultUnit
    var historicalYearsBack: Int = 20
    
    // Private storage for weatherAroundMeDistance with validation
    private var _weatherAroundMeDistance: Double = DistanceUnit.defaultUnit == .miles ? 150 : 240
    
    // Public accessor that ensures value is valid for current unit
    var weatherAroundMeDistance: Double {
        get {
            let options = distanceUnit.weatherAroundMeOptions
            // If current value is not in options, snap to nearest
            if !options.contains(_weatherAroundMeDistance) {
                return distanceUnit.snapToNearest(_weatherAroundMeDistance)
            }
            return _weatherAroundMeDistance
        }
        set {
            _weatherAroundMeDistance = newValue
        }
    }
    
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
    
    // Custom CodingKeys to handle private _weatherAroundMeDistance property
    enum CodingKeys: String, CodingKey {
        case viewMode, displayMode, temperatureUnit, windSpeedUnit
        case precipitationUnit, pressureUnit, distanceUnit, historicalYearsBack
        case _weatherAroundMeDistance = "weatherAroundMeDistance"
        case weatherFields, detailCategories
        case showTemperature, showConditions, showFeelsLike, showHumidity
        case showWindSpeed, showWindDirection, showHighTemp, showLowTemp
        case showSunrise, showSunset
    }
}
