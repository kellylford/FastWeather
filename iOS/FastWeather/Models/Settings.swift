//
//  Settings.swift
//  Fast Weather
//
//  App settings and configuration
//

import Foundation

// MARK: - My Location Settings

enum MyLocationPosition: String, CaseIterable, Codable {
    case beforeCityList = "Before City List"
    case afterCityList  = "After City List"
}

// MARK: - Weather Around Me Settings

enum ExplorationMode: String, CaseIterable, Codable {
    case arc = "Arc"
    case straightLine = "Straight Line Corridor"

    var localizedLabel: String {
        switch self {
        case .arc:          String(localized: "around_me.mode.arc", defaultValue: "Arc", comment: "Weather Around Me search shape option")
        case .straightLine: String(localized: "around_me.mode.corridor", defaultValue: "Straight Line Corridor", comment: "Weather Around Me search shape option")
        }
    }

    var description: String {
        switch self {
        case .arc:
            return String(localized: "around_me.mode.arc.desc", defaultValue: "Fan-shaped search expanding outward", comment: "Explanation of the Arc search shape")
        case .straightLine:
            return String(localized: "around_me.mode.corridor.desc", defaultValue: "Fixed-width corridor along center line", comment: "Explanation of the corridor search shape")
        }
    }
}

enum ArcWidth: Double, CaseIterable, Codable {
    case narrow = 10.0       // ±5° (10° total)
    case standard = 22.5     // ±11.25° (22.5° total)
    case medium = 45.0       // ±22.5° (45° total, previous default)
    case wide = 90.0         // ±45° (90° total)
    
    var displayName: String {
        switch self {
        case .narrow:   return String(localized: "around_me.arc.narrow", defaultValue: "Narrow (10°)", comment: "Arc width option; the (10°) is the angular width and stays as-is")
        case .standard: return String(localized: "around_me.arc.standard", defaultValue: "Standard (22.5°)", comment: "Arc width option; the (22.5°) stays as-is")
        case .medium:   return String(localized: "around_me.arc.medium", defaultValue: "Medium (45°)", comment: "Arc width option; the (45°) stays as-is")
        case .wide:     return String(localized: "around_me.arc.wide", defaultValue: "Wide (90°)", comment: "Arc width option; the (90°) stays as-is")
        }
    }

    var description: String {
        switch self {
        case .narrow:   return String(localized: "around_me.arc.narrow.desc", defaultValue: "Precise tracking - 17 mi wide at 100 mi", comment: "Arc width explanation")
        case .standard: return String(localized: "around_me.arc.standard.desc", defaultValue: "Balanced coverage - 39 mi wide at 100 mi", comment: "Arc width explanation")
        case .medium:   return String(localized: "around_me.arc.medium.desc", defaultValue: "Broad search - 78 mi wide at 100 mi", comment: "Arc width explanation")
        case .wide:     return String(localized: "around_me.arc.wide.desc", defaultValue: "Maximum coverage - 141 mi wide at 100 mi", comment: "Arc width explanation")
        }
    }
    
    /// Half-angle in degrees (±angle from center line)
    var halfAngleDegrees: Double {
        return rawValue / 2.0
    }
}

enum CorridorWidth: Double, CaseIterable, Codable {
    case ten = 10.0
    case twenty = 20.0
    case thirty = 30.0
    case fifty = 50.0
    
    var displayName: String {
        return String(localized: "around_me.corridor.width", defaultValue: "\(Int(rawValue)) miles", comment: "Corridor total width, e.g. '20 miles'. %lld is the number of miles.")
    }

    var description: String {
        switch self {
        case .ten:    return String(localized: "around_me.corridor.ten.desc", defaultValue: "±5 miles from center line", comment: "Corridor half-width explanation")
        case .twenty: return String(localized: "around_me.corridor.twenty.desc", defaultValue: "±10 miles from center line", comment: "Corridor half-width explanation")
        case .thirty: return String(localized: "around_me.corridor.thirty.desc", defaultValue: "±15 miles from center line", comment: "Corridor half-width explanation")
        case .fifty:  return String(localized: "around_me.corridor.fifty.desc", defaultValue: "±25 miles from center line", comment: "Corridor half-width explanation")
        }
    }
}

// MARK: - Display Settings

enum DisplayMode: String, CaseIterable, Codable {
    case condensed = "Condensed"
    case details = "Details"
}

enum ViewMode: String, CaseIterable, Codable {
    case flat = "Flat"
    case list = "List"
    case table = "Table"
}

enum ForecastDetailLayout: String, CaseIterable, Codable {
    case list = "List"
    case headings = "Headings"
}

enum WeatherFieldType: String, CaseIterable, Codable {
    case weatherAlerts = "Weather Alerts"
    case temperature = "Temperature"
    case conditions = "Conditions"
    case feelsLike = "Feels Like"
    case humidity = "Humidity"
    case windDirection = "Wind Direction"
    case windSpeed = "Wind Speed"
    case windGusts = "Wind Gusts"
    case precipitation = "Precipitation"
    case precipitationProbability = "Precipitation Probability"
    case rain = "Rain"
    case showers = "Showers"
    case snowfall = "Snowfall"
    case cloudCover = "Cloud Cover"
    case pressure = "Pressure"
    case visibility = "Visibility"
    case uvIndex = "UV Index"
    case dewPoint = "Dew Point"
    case highTemp = "High Temperature"
    case lowTemp = "Low Temperature"
    case sunrise = "Sunrise"
    case sunset = "Sunset"
}

enum HourlyFieldType: String, CaseIterable, Codable {
    case temperature = "Temperature"
    case conditions = "Conditions"
    case feelsLike = "Feels Like"
    case humidity = "Humidity"
    case precipitation = "Precipitation"
    case precipitationProbability = "Precipitation Probability"
    case rain = "Rain"
    case showers = "Showers"
    case snowfall = "Snowfall"
    case windSpeed = "Wind Speed"
    case windDirection = "Wind Direction"
    case windGusts = "Wind Gusts"
    case cloudCover = "Cloud Cover"
    case pressure = "Pressure"
    case visibility = "Visibility"
    case uvIndex = "UV Index"
    case dewPoint = "Dew Point"
}

enum DailyFieldType: String, CaseIterable, Codable {
    case temperatureMax = "High Temperature"
    case temperatureMin = "Low Temperature"
    case conditions = "Conditions"
    case feelsLikeMax = "Feels Like High"
    case feelsLikeMin = "Feels Like Low"
    case sunrise = "Sunrise"
    case sunset = "Sunset"
    case precipitationSum = "Precipitation Total"
    case precipitationProbability = "Precipitation Probability"
    case precipitationHours = "Precipitation Hours"
    case rainSum = "Rain Total"
    case showersSum = "Showers Total"
    case snowfallSum = "Snowfall Total"
    case windSpeedMax = "Max Wind Speed"
    case windGustsMax = "Max Wind Gusts"
    case windDirectionDominant = "Wind Direction"
    case uvIndexMax = "UV Index Max"
    case daylightDuration = "Daylight Duration"
    case sunshineDuration = "Sunshine Duration"
}

enum MarineFieldType: String, CaseIterable, Codable {
    case waveHeight = "Wave Height"
    case waveDirection = "Wave Direction"
    case wavePeriod = "Wave Period"
    case seaSurfaceTemperature = "Sea Surface Temperature"
    case swellWaveHeight = "Swell Wave Height"
    case oceanCurrentVelocity = "Ocean Current Velocity"
    case windWaveHeight = "Wind Wave Height"
    case swellWaveDirection = "Swell Wave Direction"
    case oceanCurrentDirection = "Ocean Current Direction"
    case seaLevelHeight = "Sea Level Height (Tides)"
    case wavePeakPeriod = "Wave Peak Period"
    case windWaveDirection = "Wind Wave Direction"
    case windWavePeriod = "Wind Wave Period"
    case swellWavePeriod = "Swell Wave Period"
}

struct HourlyField: Codable, Identifiable, Equatable {
    let id: String
    let type: HourlyFieldType
    var isEnabled: Bool
    
    init(type: HourlyFieldType, isEnabled: Bool = true) {
        self.id = type.rawValue
        self.type = type
        self.isEnabled = isEnabled
    }
}

struct DailyField: Codable, Identifiable, Equatable {
    let id: String
    let type: DailyFieldType
    var isEnabled: Bool
    
    init(type: DailyFieldType, isEnabled: Bool = true) {
        self.id = type.rawValue
        self.type = type
        self.isEnabled = isEnabled
    }
}

struct MarineField: Codable, Identifiable, Equatable {
    let id: String
    let type: MarineFieldType
    var isEnabled: Bool
    
    init(type: MarineFieldType, isEnabled: Bool = true) {
        self.id = type.rawValue
        self.type = type
        self.isEnabled = isEnabled
    }
}

enum DetailCategory: String, CaseIterable, Codable {
    case weatherAlerts = "Weather Alerts"
    case currentConditions = "Current Conditions"
    case todaysForecast = "Today's Forecast"
    case hourlyForecast = "24-Hour Forecast"
    case dailyForecast = "16-Day Forecast"
    case marineForecast = "Marine Forecast"
    case historicalWeather = "Historical Weather"
    case location = "Location"
    case myData = "My Data"
    case astronomy = "Astronomy"
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

struct MyDataField: Codable, Identifiable, Equatable {
    let id: String
    let parameter: MyDataParameter
    var isEnabled: Bool
    
    init(parameter: MyDataParameter, isEnabled: Bool = true) {
        self.id = parameter.rawValue
        self.parameter = parameter
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
    
    static var defaultUnit: TemperatureUnit {
        if Locale.current.measurementSystem == .us {
            return .fahrenheit
        } else {
            return .celsius
        }
    }
}

enum WindSpeedUnit: String, CaseIterable, Codable {
    case mph = "mph"
    case kmh = "km/h"
    case ms  = "m/s"

    func convert(_ kmh: Double) -> Double {
        switch self {
        case .mph: return kmh * 0.621371
        case .kmh: return kmh
        case .ms:  return kmh / 3.6
        }
    }

    static var defaultUnit: WindSpeedUnit {
        let msRegions: Set<String> = [
            "NO", "SE", "FI", "IS",        // Nordic
            "RU", "UA", "BY", "KZ",        // Russia / CIS
            "EE", "LV", "LT",              // Baltic
            "JP", "KR", "CN",              // East Asia
            "IL"                           // Israel
        ]
        if let region = Locale.current.region?.identifier, msRegions.contains(region) {
            return .ms
        }
        if Locale.current.measurementSystem == .us {
            return .mph
        }
        return .kmh
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
    
    static var defaultUnit: PrecipitationUnit {
        if Locale.current.measurementSystem == .us {
            return .inches
        } else {
            return .millimeters
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
    
    static var defaultUnit: PressureUnit {
        let mmHgRegions: Set<String> = [
            "RU", "UA", "BY", "KZ",        // Russia / CIS
            "EE", "LV", "LT"               // Baltic
        ]
        if let region = Locale.current.region?.identifier, mmHgRegions.contains(region) {
            return .mmHg
        }
        if Locale.current.measurementSystem == .us {
            return .inHg
        }
        return .hPa
    }
}

public enum DistanceUnit: String, CaseIterable, Codable {
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
    // Settings schema version - increment when structure changes
    // v3: Force wipe of v2 stored data — NSException crash caused by type mismatch in stored JSON
    //     (e.g. a field stored as a number where decoder expects an array).
    //     Bumping version triggers a one-time settings reset on all affected devices.
    static let currentVersion = 3  // Note: My Data fields handled via migration in init(from:)
    var settingsVersion: Int = AppSettings.currentVersion  // = 3

    var myLocationEnabled: Bool = true
    var myLocationPosition: MyLocationPosition = .beforeCityList

    var viewMode: ViewMode = .list
    var displayMode: DisplayMode = .condensed
    var forecastDetailLayout: ForecastDetailLayout = .list
    var temperatureUnit: TemperatureUnit = TemperatureUnit.defaultUnit
    var windSpeedUnit: WindSpeedUnit = WindSpeedUnit.defaultUnit
    var precipitationUnit: PrecipitationUnit = PrecipitationUnit.defaultUnit
    var pressureUnit: PressureUnit = PressureUnit.defaultUnit
    var distanceUnit: DistanceUnit = DistanceUnit.defaultUnit
    var historicalYearsBack: Int = 20
    var glanceAheadHours: Int = 4
    
    // Granular UV Index display options (by section)
    var showUVIndexInCurrentConditions: Bool = true
    var showUVIndexInTodaysForecast: Bool = true  // Shows as warnings when high
    var showUVIndexInDailyForecast: Bool = false  // Off by default for 16-day
    var showUVIndexInCityList: Bool = false  // Off by default (reduces clutter)
    
    // City List display options
    var showDailyHighLowInCityList: Bool = true  // Show today's high/low in city list
    
    // Granular Wind Gusts display options (by section)
    var showWindGustsInCurrentConditions: Bool = true
    var showWindGustsInTodaysForecast: Bool = true  // Shows as alerts when high
    
    // Current precipitation rate in current conditions section
    var showCurrentPrecipitationInCurrentConditions: Bool = true
    
    // Astronomy section options
    var showMoonriseInAstronomy: Bool = true
    var showMoonsetInAstronomy: Bool = true
    
    // Granular Precipitation Probability options (by section)
    var showPrecipitationProbabilityInPrecipitation: Bool = true
    var showPrecipitationProbabilityInTodaysForecast: Bool = true  // Shows as alerts
    
    // Other enhanced weather data display options
    var showPrecipitationAmount: Bool = true  // Show rain/snow amounts
    var showDewPoint: Bool = false  // Off by default (advanced)
    var showDaylightDuration: Bool = true
    var showSunshineDuration: Bool = false  // Off by default
    
    // Hourly forecast data items
    var hourlyShowTemperature: Bool = true
    var hourlyShowConditions: Bool = true
    var hourlyShowPrecipitationProbability: Bool = true
    var hourlyShowWind: Bool = true
    
    // Daily forecast data items
    var dailyShowHighLow: Bool = true
    var dailyShowConditions: Bool = true
    var dailyShowPrecipitationProbability: Bool = true
    var dailyShowPrecipitationAmount: Bool = true
    var dailyShowWind: Bool = false  // Off by default (reduces clutter)
    
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
    
    // Weather Around Me exploration settings
    var weatherAroundMeExplorationMode: ExplorationMode = .arc
    var weatherAroundMeArcWidth: ArcWidth = .standard
    var weatherAroundMeCorridorWidth: CorridorWidth = .twenty
    var showWeatherAroundMeOffsetDistance: Bool = true
    var showWeatherAroundMeBearing: Bool = false
    var showWeatherAroundMeMovement: Bool = true
    var showWeatherAroundMePressureTrends: Bool = false
    var showWeatherAroundMeAlerts: Bool = true
    
    // Ordered weather fields with enable/disable state (City List)
    var weatherFields: [WeatherField] = [
        WeatherField(type: .weatherAlerts, isEnabled: true),
        WeatherField(type: .temperature, isEnabled: true),
        WeatherField(type: .conditions, isEnabled: true),
        WeatherField(type: .feelsLike, isEnabled: true),
        WeatherField(type: .humidity, isEnabled: false),
        WeatherField(type: .windDirection, isEnabled: true),
        WeatherField(type: .windSpeed, isEnabled: true),
        WeatherField(type: .windGusts, isEnabled: false),
        WeatherField(type: .precipitation, isEnabled: true),
        WeatherField(type: .precipitationProbability, isEnabled: false),
        WeatherField(type: .rain, isEnabled: false),
        WeatherField(type: .showers, isEnabled: false),
        WeatherField(type: .snowfall, isEnabled: false),
        WeatherField(type: .cloudCover, isEnabled: false),
        WeatherField(type: .pressure, isEnabled: false),
        WeatherField(type: .visibility, isEnabled: false),
        WeatherField(type: .uvIndex, isEnabled: false),
        WeatherField(type: .dewPoint, isEnabled: false),
        WeatherField(type: .highTemp, isEnabled: true),
        WeatherField(type: .lowTemp, isEnabled: true),
        WeatherField(type: .sunrise, isEnabled: false),
        WeatherField(type: .sunset, isEnabled: false)
    ]
    
    // Ordered hourly forecast fields with enable/disable state (24-Hour Forecast)
    var hourlyFields: [HourlyField] = [
        HourlyField(type: .temperature, isEnabled: true),
        HourlyField(type: .conditions, isEnabled: true),
        HourlyField(type: .feelsLike, isEnabled: true),
        HourlyField(type: .humidity, isEnabled: true),
        HourlyField(type: .precipitation, isEnabled: true),
        HourlyField(type: .precipitationProbability, isEnabled: true),
        HourlyField(type: .rain, isEnabled: true),
        HourlyField(type: .showers, isEnabled: true),
        HourlyField(type: .snowfall, isEnabled: false), // disabled: .precipitation already shows snow amounts
        HourlyField(type: .windSpeed, isEnabled: true),
        HourlyField(type: .windDirection, isEnabled: true),
        HourlyField(type: .windGusts, isEnabled: true),
        HourlyField(type: .cloudCover, isEnabled: true),
        HourlyField(type: .pressure, isEnabled: true),
        HourlyField(type: .visibility, isEnabled: true),
        HourlyField(type: .uvIndex, isEnabled: true),
        HourlyField(type: .dewPoint, isEnabled: true)
    ]
    
    // Ordered daily forecast fields with enable/disable state (16-Day Forecast)
    var dailyFields: [DailyField] = [
        DailyField(type: .temperatureMax, isEnabled: true),
        DailyField(type: .temperatureMin, isEnabled: true),
        DailyField(type: .conditions, isEnabled: true),
        DailyField(type: .feelsLikeMax, isEnabled: false),
        DailyField(type: .feelsLikeMin, isEnabled: false),
        DailyField(type: .sunrise, isEnabled: true),
        DailyField(type: .sunset, isEnabled: true),
        DailyField(type: .precipitationSum, isEnabled: true),   // enabled: shows snow or rain amount
        DailyField(type: .precipitationProbability, isEnabled: true),
        DailyField(type: .precipitationHours, isEnabled: false),
        DailyField(type: .rainSum, isEnabled: false),
        DailyField(type: .showersSum, isEnabled: false),
        DailyField(type: .snowfallSum, isEnabled: false),
        DailyField(type: .windSpeedMax, isEnabled: false),
        DailyField(type: .windGustsMax, isEnabled: false),
        DailyField(type: .windDirectionDominant, isEnabled: false),
        DailyField(type: .uvIndexMax, isEnabled: false),
        DailyField(type: .daylightDuration, isEnabled: false),
        DailyField(type: .sunshineDuration, isEnabled: false)
    ]
    
    // Ordered marine forecast fields with enable/disable state (Marine Forecast)
    var marineFields: [MarineField] = [
        MarineField(type: .seaLevelHeight, isEnabled: true),  // Tides - shown first
        MarineField(type: .waveHeight, isEnabled: true),
        MarineField(type: .waveDirection, isEnabled: true),
        MarineField(type: .wavePeriod, isEnabled: true),
        MarineField(type: .seaSurfaceTemperature, isEnabled: true),
        MarineField(type: .swellWaveHeight, isEnabled: true),
        MarineField(type: .oceanCurrentVelocity, isEnabled: true),
        MarineField(type: .windWaveHeight, isEnabled: false),
        MarineField(type: .swellWaveDirection, isEnabled: false),
        MarineField(type: .oceanCurrentDirection, isEnabled: false),
        MarineField(type: .wavePeakPeriod, isEnabled: false),
        MarineField(type: .windWaveDirection, isEnabled: false),
        MarineField(type: .windWavePeriod, isEnabled: false),
        MarineField(type: .swellWavePeriod, isEnabled: false)
    ]
    
    // Detail categories with enable/disable and order control
    var detailCategories: [DetailCategoryField] = [
        DetailCategoryField(category: .weatherAlerts, isEnabled: true),
        DetailCategoryField(category: .todaysForecast, isEnabled: true),
        DetailCategoryField(category: .currentConditions, isEnabled: true),
        DetailCategoryField(category: .hourlyForecast, isEnabled: true),
        DetailCategoryField(category: .dailyForecast, isEnabled: true),
        DetailCategoryField(category: .historicalWeather, isEnabled: true),
        DetailCategoryField(category: .marineForecast, isEnabled: true),
        DetailCategoryField(category: .location, isEnabled: true)
    ]
    
    // User-configured My Data fields (custom section with Open-Meteo parameters)
    var myDataFields: [MyDataField] = []
    
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
        case myLocationEnabled, myLocationPosition
        case settingsVersion, viewMode, displayMode, temperatureUnit, windSpeedUnit
        case precipitationUnit, pressureUnit, distanceUnit, historicalYearsBack, glanceAheadHours
        // Granular UV Index settings
        case showUVIndexInCurrentConditions, showUVIndexInTodaysForecast
        case showUVIndexInDailyForecast, showUVIndexInCityList
        case showDailyHighLowInCityList
        // Granular Wind Gusts settings
        case showWindGustsInCurrentConditions, showWindGustsInTodaysForecast
        // Current precipitation rate
        case showCurrentPrecipitationInCurrentConditions
        // Astronomy section
        case showMoonriseInAstronomy, showMoonsetInAstronomy
        // Granular Precipitation Probability settings
        case showPrecipitationProbabilityInPrecipitation, showPrecipitationProbabilityInTodaysForecast
        // Other enhanced data
        case showPrecipitationAmount
        case showDewPoint, showDaylightDuration, showSunshineDuration
        case hourlyShowTemperature, hourlyShowConditions, hourlyShowPrecipitationProbability, hourlyShowWind
        case dailyShowHighLow, dailyShowConditions, dailyShowPrecipitationProbability, dailyShowPrecipitationAmount, dailyShowWind
        case _weatherAroundMeDistance = "weatherAroundMeDistance"
        // Weather Around Me exploration settings
        case weatherAroundMeExplorationMode, weatherAroundMeArcWidth, weatherAroundMeCorridorWidth
        case showWeatherAroundMeOffsetDistance, showWeatherAroundMeBearing, showWeatherAroundMeMovement, showWeatherAroundMePressureTrends, showWeatherAroundMeAlerts
        case weatherFields, hourlyFields, dailyFields, marineFields, detailCategories
        case myDataFields
        case forecastDetailLayout
        // Legacy properties
        case showTemperature, showConditions, showFeelsLike, showHumidity
        case showWindSpeed, showWindDirection, showHighTemp, showLowTemp
        case showSunrise, showSunset
        // Deprecated (for migration)
        case showUVIndex, showWindGusts, showPrecipitationProbability
    }
    
    // Default initializer (uses default values from property declarations)
    init() {
        // All properties have default values, so we just need to set weatherFields, hourlyFields, dailyFields, and detailCategories
        self.weatherFields = [
            WeatherField(type: .weatherAlerts, isEnabled: true),
            WeatherField(type: .temperature, isEnabled: true),
            WeatherField(type: .conditions, isEnabled: true),
            WeatherField(type: .feelsLike, isEnabled: true),
            WeatherField(type: .humidity, isEnabled: false),
            WeatherField(type: .windDirection, isEnabled: true),
            WeatherField(type: .windSpeed, isEnabled: true),
            WeatherField(type: .windGusts, isEnabled: false),
            WeatherField(type: .precipitation, isEnabled: true),
            WeatherField(type: .precipitationProbability, isEnabled: false),
            WeatherField(type: .rain, isEnabled: false),
            WeatherField(type: .showers, isEnabled: false),
            WeatherField(type: .snowfall, isEnabled: false),
            WeatherField(type: .cloudCover, isEnabled: false),
            WeatherField(type: .pressure, isEnabled: false),
            WeatherField(type: .visibility, isEnabled: false),
            WeatherField(type: .uvIndex, isEnabled: false),
            WeatherField(type: .dewPoint, isEnabled: false),
            WeatherField(type: .highTemp, isEnabled: true),
            WeatherField(type: .lowTemp, isEnabled: true),
            WeatherField(type: .sunrise, isEnabled: false),
            WeatherField(type: .sunset, isEnabled: false)
        ]
        
        self.hourlyFields = [
            HourlyField(type: .temperature, isEnabled: true),
            HourlyField(type: .conditions, isEnabled: true),
            HourlyField(type: .feelsLike, isEnabled: true),
            HourlyField(type: .humidity, isEnabled: true),
            HourlyField(type: .precipitation, isEnabled: true),
            HourlyField(type: .precipitationProbability, isEnabled: true),
            HourlyField(type: .rain, isEnabled: true),
            HourlyField(type: .showers, isEnabled: true),
            HourlyField(type: .snowfall, isEnabled: false), // disabled: .precipitation already shows snow amounts
            HourlyField(type: .windSpeed, isEnabled: true),
            HourlyField(type: .windDirection, isEnabled: true),
            HourlyField(type: .windGusts, isEnabled: true),
            HourlyField(type: .cloudCover, isEnabled: true),
            HourlyField(type: .pressure, isEnabled: true),
            HourlyField(type: .visibility, isEnabled: true),
            HourlyField(type: .uvIndex, isEnabled: true),
            HourlyField(type: .dewPoint, isEnabled: true)
        ]
        
        self.dailyFields = [
            DailyField(type: .temperatureMax, isEnabled: true),
            DailyField(type: .temperatureMin, isEnabled: true),
            DailyField(type: .conditions, isEnabled: true),
            DailyField(type: .feelsLikeMax, isEnabled: false),
            DailyField(type: .feelsLikeMin, isEnabled: false),
            DailyField(type: .sunrise, isEnabled: true),
            DailyField(type: .sunset, isEnabled: true),
            DailyField(type: .precipitationSum, isEnabled: true),   // enabled: shows snow or rain amount
            DailyField(type: .precipitationProbability, isEnabled: true),
            DailyField(type: .precipitationHours, isEnabled: false),
            DailyField(type: .rainSum, isEnabled: false),
            DailyField(type: .showersSum, isEnabled: false),
            DailyField(type: .snowfallSum, isEnabled: false),
            DailyField(type: .windSpeedMax, isEnabled: false),
            DailyField(type: .windGustsMax, isEnabled: false),
            DailyField(type: .windDirectionDominant, isEnabled: false),
            DailyField(type: .uvIndexMax, isEnabled: false),
            DailyField(type: .daylightDuration, isEnabled: false),
            DailyField(type: .sunshineDuration, isEnabled: false)
        ]
        
        self.marineFields = [
            MarineField(type: .seaLevelHeight, isEnabled: true),  // Tides - shown first
            MarineField(type: .waveHeight, isEnabled: true),
            MarineField(type: .waveDirection, isEnabled: true),
            MarineField(type: .wavePeriod, isEnabled: true),
            MarineField(type: .seaSurfaceTemperature, isEnabled: true),
            MarineField(type: .swellWaveHeight, isEnabled: true),
            MarineField(type: .oceanCurrentVelocity, isEnabled: true),
            MarineField(type: .windWaveHeight, isEnabled: false),
            MarineField(type: .swellWaveDirection, isEnabled: false),
            MarineField(type: .oceanCurrentDirection, isEnabled: false),
            MarineField(type: .wavePeakPeriod, isEnabled: false),
            MarineField(type: .windWaveDirection, isEnabled: false),
            MarineField(type: .windWavePeriod, isEnabled: false),
            MarineField(type: .swellWavePeriod, isEnabled: false)
        ]
        
        self.detailCategories = [
            DetailCategoryField(category: .weatherAlerts, isEnabled: true),
            DetailCategoryField(category: .todaysForecast, isEnabled: true),
            DetailCategoryField(category: .astronomy, isEnabled: true),
            DetailCategoryField(category: .currentConditions, isEnabled: true),
            DetailCategoryField(category: .hourlyForecast, isEnabled: true),
            DetailCategoryField(category: .dailyForecast, isEnabled: true),
            DetailCategoryField(category: .historicalWeather, isEnabled: true),
            DetailCategoryField(category: .marineForecast, isEnabled: true),
            DetailCategoryField(category: .location, isEnabled: true),
            DetailCategoryField(category: .myData, isEnabled: false),
        ]
        
        self.myDataFields = []
    }
    
    // Custom Decodable implementation
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        myLocationEnabled = try container.decodeIfPresent(Bool.self, forKey: .myLocationEnabled) ?? true
        myLocationPosition = try container.decodeIfPresent(MyLocationPosition.self, forKey: .myLocationPosition) ?? .beforeCityList

        viewMode = try container.decodeIfPresent(ViewMode.self, forKey: .viewMode) ?? .list
        displayMode = try container.decodeIfPresent(DisplayMode.self, forKey: .displayMode) ?? .condensed
        temperatureUnit = try container.decodeIfPresent(TemperatureUnit.self, forKey: .temperatureUnit) ?? TemperatureUnit.defaultUnit
        windSpeedUnit = try container.decodeIfPresent(WindSpeedUnit.self, forKey: .windSpeedUnit) ?? WindSpeedUnit.defaultUnit
        precipitationUnit = try container.decodeIfPresent(PrecipitationUnit.self, forKey: .precipitationUnit) ?? PrecipitationUnit.defaultUnit
        pressureUnit = try container.decodeIfPresent(PressureUnit.self, forKey: .pressureUnit) ?? PressureUnit.defaultUnit
        distanceUnit = try container.decodeIfPresent(DistanceUnit.self, forKey: .distanceUnit) ?? DistanceUnit.defaultUnit
        historicalYearsBack = try container.decodeIfPresent(Int.self, forKey: .historicalYearsBack) ?? 20
        glanceAheadHours = try container.decodeIfPresent(Int.self, forKey: .glanceAheadHours) ?? 4
        
        // Granular UV Index settings (with migration from deprecated showUVIndex)
        if let deprecated = try? container.decode(Bool.self, forKey: .showUVIndex) {
            // Migrate from old shared setting to new granular settings
            showUVIndexInCurrentConditions = deprecated
            showUVIndexInTodaysForecast = deprecated
            showUVIndexInDailyForecast = false  // Keep default off
            showUVIndexInCityList = false
            showDailyHighLowInCityList = true
        } else {
            showUVIndexInCurrentConditions = try container.decodeIfPresent(Bool.self, forKey: .showUVIndexInCurrentConditions) ?? true
            showUVIndexInTodaysForecast = try container.decodeIfPresent(Bool.self, forKey: .showUVIndexInTodaysForecast) ?? true
            showUVIndexInDailyForecast = try container.decodeIfPresent(Bool.self, forKey: .showUVIndexInDailyForecast) ?? false
            showUVIndexInCityList = try container.decodeIfPresent(Bool.self, forKey: .showUVIndexInCityList) ?? false
            showDailyHighLowInCityList = try container.decodeIfPresent(Bool.self, forKey: .showDailyHighLowInCityList) ?? true
        }
        
        // Granular Wind Gusts settings (with migration)
        if let deprecated = try? container.decode(Bool.self, forKey: .showWindGusts) {
            showWindGustsInCurrentConditions = deprecated
            showWindGustsInTodaysForecast = deprecated
        } else {
            showWindGustsInCurrentConditions = try container.decodeIfPresent(Bool.self, forKey: .showWindGustsInCurrentConditions) ?? true
            showWindGustsInTodaysForecast = try container.decodeIfPresent(Bool.self, forKey: .showWindGustsInTodaysForecast) ?? true
        }
        
        // Granular Precipitation Probability settings (with migration)
        if let deprecated = try? container.decode(Bool.self, forKey: .showPrecipitationProbability) {
            showPrecipitationProbabilityInPrecipitation = deprecated
            showPrecipitationProbabilityInTodaysForecast = deprecated
        } else {
            showPrecipitationProbabilityInPrecipitation = try container.decodeIfPresent(Bool.self, forKey: .showPrecipitationProbabilityInPrecipitation) ?? true
            showPrecipitationProbabilityInTodaysForecast = try container.decodeIfPresent(Bool.self, forKey: .showPrecipitationProbabilityInTodaysForecast) ?? true
        }
        
        // Other enhanced data
        showPrecipitationAmount = try container.decodeIfPresent(Bool.self, forKey: .showPrecipitationAmount) ?? true
        showCurrentPrecipitationInCurrentConditions = try container.decodeIfPresent(Bool.self, forKey: .showCurrentPrecipitationInCurrentConditions) ?? true
        showMoonriseInAstronomy = try container.decodeIfPresent(Bool.self, forKey: .showMoonriseInAstronomy) ?? true
        showMoonsetInAstronomy = try container.decodeIfPresent(Bool.self, forKey: .showMoonsetInAstronomy) ?? true
        showDewPoint = try container.decodeIfPresent(Bool.self, forKey: .showDewPoint) ?? false
        showDaylightDuration = try container.decodeIfPresent(Bool.self, forKey: .showDaylightDuration) ?? true
        showSunshineDuration = try container.decodeIfPresent(Bool.self, forKey: .showSunshineDuration) ?? false
        
        // Hourly forecast items
        hourlyShowTemperature = try container.decodeIfPresent(Bool.self, forKey: .hourlyShowTemperature) ?? true
        hourlyShowConditions = try container.decodeIfPresent(Bool.self, forKey: .hourlyShowConditions) ?? true
        hourlyShowPrecipitationProbability = try container.decodeIfPresent(Bool.self, forKey: .hourlyShowPrecipitationProbability) ?? true
        hourlyShowWind = try container.decodeIfPresent(Bool.self, forKey: .hourlyShowWind) ?? true
        
        // Daily forecast items
        dailyShowHighLow = try container.decodeIfPresent(Bool.self, forKey: .dailyShowHighLow) ?? true
        dailyShowConditions = try container.decodeIfPresent(Bool.self, forKey: .dailyShowConditions) ?? true
        dailyShowPrecipitationProbability = try container.decodeIfPresent(Bool.self, forKey: .dailyShowPrecipitationProbability) ?? true
        dailyShowPrecipitationAmount = try container.decodeIfPresent(Bool.self, forKey: .dailyShowPrecipitationAmount) ?? true
        dailyShowWind = try container.decodeIfPresent(Bool.self, forKey: .dailyShowWind) ?? false
        forecastDetailLayout = try container.decodeIfPresent(ForecastDetailLayout.self, forKey: .forecastDetailLayout) ?? .list
        
        _weatherAroundMeDistance = try container.decodeIfPresent(Double.self, forKey: ._weatherAroundMeDistance) ?? (DistanceUnit.defaultUnit == .miles ? 150 : 240)
        
        // Weather fields with migration: merge saved fields with new defaults
        let defaultFields: [WeatherField] = [
            WeatherField(type: .temperature, isEnabled: true),
            WeatherField(type: .conditions, isEnabled: true),
            WeatherField(type: .feelsLike, isEnabled: true),
            WeatherField(type: .humidity, isEnabled: true),
            WeatherField(type: .windSpeed, isEnabled: true),
            WeatherField(type: .windDirection, isEnabled: true),
            WeatherField(type: .windGusts, isEnabled: true),
            WeatherField(type: .precipitation, isEnabled: true),
            WeatherField(type: .precipitationProbability, isEnabled: true),
            WeatherField(type: .rain, isEnabled: true),
            WeatherField(type: .showers, isEnabled: true),
            WeatherField(type: .snowfall, isEnabled: true),
            WeatherField(type: .cloudCover, isEnabled: true),
            WeatherField(type: .pressure, isEnabled: true),
            WeatherField(type: .visibility, isEnabled: true),
            WeatherField(type: .uvIndex, isEnabled: true),
            WeatherField(type: .dewPoint, isEnabled: true),
            WeatherField(type: .highTemp, isEnabled: true),
            WeatherField(type: .lowTemp, isEnabled: true),
            WeatherField(type: .sunrise, isEnabled: true),
            WeatherField(type: .sunset, isEnabled: true)
        ]
        
        if let savedFields = try container.decodeIfPresent([WeatherField].self, forKey: .weatherFields) {
            // Merge: keep saved fields and add any new ones that don't exist
            var mergedFields = savedFields
            let existingTypes = Set(savedFields.map { $0.type })
            
            for defaultField in defaultFields {
                if !existingTypes.contains(defaultField.type) {
                    // Add new field at the end, enabled by default
                    mergedFields.append(defaultField)
                }
            }
            
            weatherFields = mergedFields
        } else {
            // No saved data, use all defaults
            weatherFields = defaultFields
        }
        
        // Hourly fields with migration: merge saved fields with new defaults
        let defaultHourlyFields: [HourlyField] = [
            HourlyField(type: .temperature, isEnabled: true),
            HourlyField(type: .conditions, isEnabled: true),
            HourlyField(type: .feelsLike, isEnabled: true),
            HourlyField(type: .humidity, isEnabled: true),
            HourlyField(type: .precipitation, isEnabled: true),
            HourlyField(type: .precipitationProbability, isEnabled: true),
            HourlyField(type: .rain, isEnabled: true),
            HourlyField(type: .showers, isEnabled: true),
            HourlyField(type: .snowfall, isEnabled: false), // disabled: .precipitation already shows snow amounts
            HourlyField(type: .windSpeed, isEnabled: true),
            HourlyField(type: .windDirection, isEnabled: true),
            HourlyField(type: .windGusts, isEnabled: true),
            HourlyField(type: .cloudCover, isEnabled: true),
            HourlyField(type: .pressure, isEnabled: true),
            HourlyField(type: .visibility, isEnabled: true),
            HourlyField(type: .uvIndex, isEnabled: true),
            HourlyField(type: .dewPoint, isEnabled: true)
        ]
        
        if let savedHourlyFields = try container.decodeIfPresent([HourlyField].self, forKey: .hourlyFields) {
            // Merge: keep saved fields and add any new ones that don't exist
            var mergedFields = savedHourlyFields
            let existingTypes = Set(savedHourlyFields.map { $0.type })
            
            for defaultField in defaultHourlyFields {
                if !existingTypes.contains(defaultField.type) {
                    // Add new field at the end, enabled by default
                    mergedFields.append(defaultField)
                }
            }
            
            hourlyFields = mergedFields
        } else {
            // No saved data, use all defaults
            hourlyFields = defaultHourlyFields
        }
        
        // Daily fields with migration: merge saved fields with new defaults
        let defaultDailyFields: [DailyField] = [
            DailyField(type: .temperatureMax, isEnabled: true),
            DailyField(type: .temperatureMin, isEnabled: true),
            DailyField(type: .conditions, isEnabled: true),
            DailyField(type: .feelsLikeMax, isEnabled: false),
            DailyField(type: .feelsLikeMin, isEnabled: false),
            DailyField(type: .sunrise, isEnabled: true),
            DailyField(type: .sunset, isEnabled: true),
            DailyField(type: .precipitationSum, isEnabled: true),   // enabled: shows snow or rain amount
            DailyField(type: .precipitationProbability, isEnabled: true),
            DailyField(type: .precipitationHours, isEnabled: false),
            DailyField(type: .rainSum, isEnabled: false),
            DailyField(type: .showersSum, isEnabled: false),
            DailyField(type: .snowfallSum, isEnabled: false),
            DailyField(type: .windSpeedMax, isEnabled: false),
            DailyField(type: .windGustsMax, isEnabled: false),
            DailyField(type: .windDirectionDominant, isEnabled: false),
            DailyField(type: .uvIndexMax, isEnabled: false),
            DailyField(type: .daylightDuration, isEnabled: false),
            DailyField(type: .sunshineDuration, isEnabled: false)
        ]
        
        if let savedDailyFields = try container.decodeIfPresent([DailyField].self, forKey: .dailyFields) {
            // Merge: keep saved fields and add any new ones that don't exist
            var mergedFields = savedDailyFields
            let existingTypes = Set(savedDailyFields.map { $0.type })
            
            for defaultField in defaultDailyFields {
                if !existingTypes.contains(defaultField.type) {
                    // Add new field at the end, enabled by default
                    mergedFields.append(defaultField)
                }
            }
            
            dailyFields = mergedFields
        } else {
            // No saved data, use all defaults
            dailyFields = defaultDailyFields
        }
        
        // Marine fields with migration: merge saved fields with new defaults
        let defaultMarineFields: [MarineField] = [
            MarineField(type: .seaLevelHeight, isEnabled: true),  // Tides - shown first
            MarineField(type: .waveHeight, isEnabled: true),
            MarineField(type: .waveDirection, isEnabled: true),
            MarineField(type: .wavePeriod, isEnabled: true),
            MarineField(type: .seaSurfaceTemperature, isEnabled: true),
            MarineField(type: .swellWaveHeight, isEnabled: true),
            MarineField(type: .oceanCurrentVelocity, isEnabled: true),
            MarineField(type: .windWaveHeight, isEnabled: false),
            MarineField(type: .swellWaveDirection, isEnabled: false),
            MarineField(type: .oceanCurrentDirection, isEnabled: false),
            MarineField(type: .wavePeakPeriod, isEnabled: false),
            MarineField(type: .windWaveDirection, isEnabled: false),
            MarineField(type: .windWavePeriod, isEnabled: false),
            MarineField(type: .swellWavePeriod, isEnabled: false)
        ]
        
        if let savedMarineFields = try container.decodeIfPresent([MarineField].self, forKey: .marineFields) {
            // Merge: keep saved fields and add any new ones that don't exist
            var mergedFields = savedMarineFields
            let existingTypes = Set(savedMarineFields.map { $0.type })
            
            for defaultField in defaultMarineFields {
                if !existingTypes.contains(defaultField.type) {
                    // Add new field at the end
                    mergedFields.append(defaultField)
                }
            }
            
            marineFields = mergedFields
        } else {
            // No saved data, use all defaults
            marineFields = defaultMarineFields
        }
        
        // Detail categories with migration: merge saved categories with new defaults
        let defaultCategories: [DetailCategoryField] = [
            DetailCategoryField(category: .weatherAlerts, isEnabled: true),
            DetailCategoryField(category: .todaysForecast, isEnabled: true),
            DetailCategoryField(category: .astronomy, isEnabled: true),
            DetailCategoryField(category: .currentConditions, isEnabled: true),
            DetailCategoryField(category: .hourlyForecast, isEnabled: true),
            DetailCategoryField(category: .dailyForecast, isEnabled: true),
            DetailCategoryField(category: .historicalWeather, isEnabled: true),
            DetailCategoryField(category: .marineForecast, isEnabled: true),
            DetailCategoryField(category: .location, isEnabled: true),
            DetailCategoryField(category: .myData, isEnabled: false)
        ]
        
        if let savedCategories = try container.decodeIfPresent([DetailCategoryField].self, forKey: .detailCategories) {
            // Merge: keep saved categories and add any new ones that don't exist
            var mergedCategories = savedCategories
            let existingCategoryTypes = Set(savedCategories.map { $0.category })
            
            for defaultCategory in defaultCategories {
                if !existingCategoryTypes.contains(defaultCategory.category) {
                    // Insert before My Data so it always stays last
                    if let myDataIndex = mergedCategories.firstIndex(where: { $0.category == .myData }) {
                        mergedCategories.insert(defaultCategory, at: myDataIndex)
                    } else {
                        mergedCategories.append(defaultCategory)
                    }
                }
            }
            
            detailCategories = mergedCategories
        } else {
            // No saved data, use all defaults
            detailCategories = defaultCategories
        }
        
        // My Data fields (user-configured custom data points)
        myDataFields = try container.decodeIfPresent([MyDataField].self, forKey: .myDataFields) ?? []
        
        // Legacy properties
        showTemperature = try container.decodeIfPresent(Bool.self, forKey: .showTemperature) ?? true
        showConditions = try container.decodeIfPresent(Bool.self, forKey: .showConditions) ?? true
        showFeelsLike = try container.decodeIfPresent(Bool.self, forKey: .showFeelsLike) ?? true
        showHumidity = try container.decodeIfPresent(Bool.self, forKey: .showHumidity) ?? true
        showWindSpeed = try container.decodeIfPresent(Bool.self, forKey: .showWindSpeed) ?? true
        showWindDirection = try container.decodeIfPresent(Bool.self, forKey: .showWindDirection) ?? true
        showHighTemp = try container.decodeIfPresent(Bool.self, forKey: .showHighTemp) ?? true
        showLowTemp = try container.decodeIfPresent(Bool.self, forKey: .showLowTemp) ?? true
        showSunrise = try container.decodeIfPresent(Bool.self, forKey: .showSunrise) ?? true
        showSunset = try container.decodeIfPresent(Bool.self, forKey: .showSunset) ?? true
    }
    
    // Custom Encodable implementation
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(myLocationEnabled, forKey: .myLocationEnabled)
        try container.encode(myLocationPosition, forKey: .myLocationPosition)

        try container.encode(viewMode, forKey: .viewMode)
        try container.encode(displayMode, forKey: .displayMode)
        try container.encode(temperatureUnit, forKey: .temperatureUnit)
        try container.encode(windSpeedUnit, forKey: .windSpeedUnit)
        try container.encode(precipitationUnit, forKey: .precipitationUnit)
        try container.encode(pressureUnit, forKey: .pressureUnit)
        try container.encode(distanceUnit, forKey: .distanceUnit)
        try container.encode(historicalYearsBack, forKey: .historicalYearsBack)
        try container.encode(glanceAheadHours, forKey: .glanceAheadHours)
        
        // Granular settings
        try container.encode(showUVIndexInCurrentConditions, forKey: .showUVIndexInCurrentConditions)
        try container.encode(showUVIndexInTodaysForecast, forKey: .showUVIndexInTodaysForecast)
        try container.encode(showUVIndexInDailyForecast, forKey: .showUVIndexInDailyForecast)
        try container.encode(showUVIndexInCityList, forKey: .showUVIndexInCityList)
        try container.encode(showDailyHighLowInCityList, forKey: .showDailyHighLowInCityList)
        
        try container.encode(showWindGustsInCurrentConditions, forKey: .showWindGustsInCurrentConditions)
        try container.encode(showWindGustsInTodaysForecast, forKey: .showWindGustsInTodaysForecast)
        try container.encode(showCurrentPrecipitationInCurrentConditions, forKey: .showCurrentPrecipitationInCurrentConditions)
        try container.encode(showMoonriseInAstronomy, forKey: .showMoonriseInAstronomy)
        try container.encode(showMoonsetInAstronomy, forKey: .showMoonsetInAstronomy)
        
        try container.encode(showPrecipitationProbabilityInPrecipitation, forKey: .showPrecipitationProbabilityInPrecipitation)
        try container.encode(showPrecipitationProbabilityInTodaysForecast, forKey: .showPrecipitationProbabilityInTodaysForecast)
        
        // Other enhanced data
        try container.encode(showPrecipitationAmount, forKey: .showPrecipitationAmount)
        try container.encode(showDewPoint, forKey: .showDewPoint)
        try container.encode(showDaylightDuration, forKey: .showDaylightDuration)
        try container.encode(showSunshineDuration, forKey: .showSunshineDuration)
        
        try container.encode(hourlyShowTemperature, forKey: .hourlyShowTemperature)
        try container.encode(hourlyShowConditions, forKey: .hourlyShowConditions)
        try container.encode(hourlyShowPrecipitationProbability, forKey: .hourlyShowPrecipitationProbability)
        try container.encode(hourlyShowWind, forKey: .hourlyShowWind)
        
        try container.encode(dailyShowHighLow, forKey: .dailyShowHighLow)
        try container.encode(dailyShowConditions, forKey: .dailyShowConditions)
        try container.encode(dailyShowPrecipitationProbability, forKey: .dailyShowPrecipitationProbability)
        try container.encode(dailyShowPrecipitationAmount, forKey: .dailyShowPrecipitationAmount)
        try container.encode(dailyShowWind, forKey: .dailyShowWind)
        try container.encode(forecastDetailLayout, forKey: .forecastDetailLayout)
        
        try container.encode(_weatherAroundMeDistance, forKey: ._weatherAroundMeDistance)
        try container.encode(weatherFields, forKey: .weatherFields)
        try container.encode(hourlyFields, forKey: .hourlyFields)
        try container.encode(dailyFields, forKey: .dailyFields)
        try container.encode(marineFields, forKey: .marineFields)
        try container.encode(detailCategories, forKey: .detailCategories)
        try container.encode(myDataFields, forKey: .myDataFields)
        
        // Legacy properties
        try container.encode(showTemperature, forKey: .showTemperature)
        try container.encode(showConditions, forKey: .showConditions)
        try container.encode(showFeelsLike, forKey: .showFeelsLike)
        try container.encode(showHumidity, forKey: .showHumidity)
        try container.encode(showWindSpeed, forKey: .showWindSpeed)
        try container.encode(showWindDirection, forKey: .showWindDirection)
        try container.encode(showHighTemp, forKey: .showHighTemp)
        try container.encode(showLowTemp, forKey: .showLowTemp)
        try container.encode(showSunrise, forKey: .showSunrise)
        try container.encode(showSunset, forKey: .showSunset)
    }
}

// MARK: - Localized Display Labels
//
// IMPORTANT: The `String` raw values of the enums below are STABLE STORAGE KEYS.
// They are persisted to UserDefaults (via Codable) and used as struct `id`s.
// They must never change and must never be shown to a user.
//
// Everything the user sees comes from the `localizedLabel` / localized computed
// properties here, which resolve through the String Catalog at runtime. To localize
// a label, translate its catalog key — no code change required.

extension WeatherFieldType {
    var localizedLabel: String {
        switch self {
        case .weatherAlerts:            String(localized: "field.weather_alerts", defaultValue: "Weather Alerts", comment: "Weather data field name")
        case .temperature:              String(localized: "field.temperature", defaultValue: "Temperature", comment: "Weather data field name")
        case .conditions:               String(localized: "field.conditions", defaultValue: "Conditions", comment: "Weather data field name (sky conditions, e.g. Partly Cloudy)")
        case .feelsLike:                String(localized: "field.feels_like", defaultValue: "Feels Like", comment: "Weather data field name (apparent temperature)")
        case .humidity:                 String(localized: "field.humidity", defaultValue: "Humidity", comment: "Weather data field name")
        case .windDirection:            String(localized: "field.wind_direction", defaultValue: "Wind Direction", comment: "Weather data field name")
        case .windSpeed:                String(localized: "field.wind_speed", defaultValue: "Wind Speed", comment: "Weather data field name")
        case .windGusts:                String(localized: "field.wind_gusts", defaultValue: "Wind Gusts", comment: "Weather data field name")
        case .precipitation:            String(localized: "field.precipitation", defaultValue: "Precipitation", comment: "Weather data field name (rain/snow amount)")
        case .precipitationProbability: String(localized: "field.precipitation_probability", defaultValue: "Precipitation Probability", comment: "Weather data field name (chance of precipitation)")
        case .rain:                     String(localized: "field.rain", defaultValue: "Rain", comment: "Weather data field name")
        case .showers:                  String(localized: "field.showers", defaultValue: "Showers", comment: "Weather data field name")
        case .snowfall:                 String(localized: "field.snowfall", defaultValue: "Snowfall", comment: "Weather data field name")
        case .cloudCover:               String(localized: "field.cloud_cover", defaultValue: "Cloud Cover", comment: "Weather data field name")
        case .pressure:                 String(localized: "field.pressure", defaultValue: "Pressure", comment: "Weather data field name (barometric pressure)")
        case .visibility:               String(localized: "field.visibility", defaultValue: "Visibility", comment: "Weather data field name")
        case .uvIndex:                  String(localized: "field.uv_index", defaultValue: "UV Index", comment: "Weather data field name (ultraviolet index)")
        case .dewPoint:                 String(localized: "field.dew_point", defaultValue: "Dew Point", comment: "Weather data field name")
        case .highTemp:                 String(localized: "field.high_temperature", defaultValue: "High Temperature", comment: "Weather data field name (daily maximum)")
        case .lowTemp:                  String(localized: "field.low_temperature", defaultValue: "Low Temperature", comment: "Weather data field name (daily minimum)")
        case .sunrise:                  String(localized: "field.sunrise", defaultValue: "Sunrise", comment: "Weather data field name")
        case .sunset:                   String(localized: "field.sunset", defaultValue: "Sunset", comment: "Weather data field name")
        }
    }
}

extension HourlyFieldType {
    var localizedLabel: String {
        switch self {
        case .temperature:              String(localized: "field.temperature", defaultValue: "Temperature", comment: "Weather data field name")
        case .conditions:               String(localized: "field.conditions", defaultValue: "Conditions", comment: "Weather data field name (sky conditions, e.g. Partly Cloudy)")
        case .feelsLike:                String(localized: "field.feels_like", defaultValue: "Feels Like", comment: "Weather data field name (apparent temperature)")
        case .humidity:                 String(localized: "field.humidity", defaultValue: "Humidity", comment: "Weather data field name")
        case .precipitation:            String(localized: "field.precipitation", defaultValue: "Precipitation", comment: "Weather data field name (rain/snow amount)")
        case .precipitationProbability: String(localized: "field.precipitation_probability", defaultValue: "Precipitation Probability", comment: "Weather data field name (chance of precipitation)")
        case .rain:                     String(localized: "field.rain", defaultValue: "Rain", comment: "Weather data field name")
        case .showers:                  String(localized: "field.showers", defaultValue: "Showers", comment: "Weather data field name")
        case .snowfall:                 String(localized: "field.snowfall", defaultValue: "Snowfall", comment: "Weather data field name")
        case .windSpeed:                String(localized: "field.wind_speed", defaultValue: "Wind Speed", comment: "Weather data field name")
        case .windDirection:            String(localized: "field.wind_direction", defaultValue: "Wind Direction", comment: "Weather data field name")
        case .windGusts:                String(localized: "field.wind_gusts", defaultValue: "Wind Gusts", comment: "Weather data field name")
        case .cloudCover:               String(localized: "field.cloud_cover", defaultValue: "Cloud Cover", comment: "Weather data field name")
        case .pressure:                 String(localized: "field.pressure", defaultValue: "Pressure", comment: "Weather data field name (barometric pressure)")
        case .visibility:               String(localized: "field.visibility", defaultValue: "Visibility", comment: "Weather data field name")
        case .uvIndex:                  String(localized: "field.uv_index", defaultValue: "UV Index", comment: "Weather data field name (ultraviolet index)")
        case .dewPoint:                 String(localized: "field.dew_point", defaultValue: "Dew Point", comment: "Weather data field name")
        }
    }
}

extension DailyFieldType {
    var localizedLabel: String {
        switch self {
        case .temperatureMax:           String(localized: "field.high_temperature", defaultValue: "High Temperature", comment: "Weather data field name (daily maximum)")
        case .temperatureMin:           String(localized: "field.low_temperature", defaultValue: "Low Temperature", comment: "Weather data field name (daily minimum)")
        case .conditions:               String(localized: "field.conditions", defaultValue: "Conditions", comment: "Weather data field name (sky conditions, e.g. Partly Cloudy)")
        case .feelsLikeMax:             String(localized: "field.feels_like_high", defaultValue: "Feels Like High", comment: "Weather data field name (apparent daily maximum)")
        case .feelsLikeMin:             String(localized: "field.feels_like_low", defaultValue: "Feels Like Low", comment: "Weather data field name (apparent daily minimum)")
        case .sunrise:                  String(localized: "field.sunrise", defaultValue: "Sunrise", comment: "Weather data field name")
        case .sunset:                   String(localized: "field.sunset", defaultValue: "Sunset", comment: "Weather data field name")
        case .precipitationSum:         String(localized: "field.precipitation_total", defaultValue: "Precipitation Total", comment: "Weather data field name (daily total)")
        case .precipitationProbability: String(localized: "field.precipitation_probability", defaultValue: "Precipitation Probability", comment: "Weather data field name (chance of precipitation)")
        case .precipitationHours:       String(localized: "field.precipitation_hours", defaultValue: "Precipitation Hours", comment: "Weather data field name (hours with precipitation)")
        case .rainSum:                  String(localized: "field.rain_total", defaultValue: "Rain Total", comment: "Weather data field name (daily total)")
        case .showersSum:               String(localized: "field.showers_total", defaultValue: "Showers Total", comment: "Weather data field name (daily total)")
        case .snowfallSum:              String(localized: "field.snowfall_total", defaultValue: "Snowfall Total", comment: "Weather data field name (daily total)")
        case .windSpeedMax:             String(localized: "field.max_wind_speed", defaultValue: "Max Wind Speed", comment: "Weather data field name (daily maximum)")
        case .windGustsMax:             String(localized: "field.max_wind_gusts", defaultValue: "Max Wind Gusts", comment: "Weather data field name (daily maximum)")
        case .windDirectionDominant:    String(localized: "field.wind_direction", defaultValue: "Wind Direction", comment: "Weather data field name")
        case .uvIndexMax:               String(localized: "field.uv_index_max", defaultValue: "UV Index Max", comment: "Weather data field name (daily maximum UV index)")
        case .daylightDuration:         String(localized: "field.daylight_duration", defaultValue: "Daylight Duration", comment: "Weather data field name")
        case .sunshineDuration:         String(localized: "field.sunshine_duration", defaultValue: "Sunshine Duration", comment: "Weather data field name")
        }
    }
}

extension MarineFieldType {
    var localizedLabel: String {
        switch self {
        case .waveHeight:             String(localized: "field.wave_height", defaultValue: "Wave Height", comment: "Marine weather field name")
        case .waveDirection:          String(localized: "field.wave_direction", defaultValue: "Wave Direction", comment: "Marine weather field name")
        case .wavePeriod:             String(localized: "field.wave_period", defaultValue: "Wave Period", comment: "Marine weather field name (seconds between waves)")
        case .seaSurfaceTemperature:  String(localized: "field.sea_surface_temperature", defaultValue: "Sea Surface Temperature", comment: "Marine weather field name")
        case .swellWaveHeight:        String(localized: "field.swell_wave_height", defaultValue: "Swell Wave Height", comment: "Marine weather field name")
        case .oceanCurrentVelocity:   String(localized: "field.ocean_current_velocity", defaultValue: "Ocean Current Velocity", comment: "Marine weather field name")
        case .windWaveHeight:         String(localized: "field.wind_wave_height", defaultValue: "Wind Wave Height", comment: "Marine weather field name")
        case .swellWaveDirection:     String(localized: "field.swell_wave_direction", defaultValue: "Swell Wave Direction", comment: "Marine weather field name")
        case .oceanCurrentDirection:  String(localized: "field.ocean_current_direction", defaultValue: "Ocean Current Direction", comment: "Marine weather field name")
        case .seaLevelHeight:         String(localized: "field.sea_level_height", defaultValue: "Sea Level Height (Tides)", comment: "Marine weather field name")
        case .wavePeakPeriod:         String(localized: "field.wave_peak_period", defaultValue: "Wave Peak Period", comment: "Marine weather field name")
        case .windWaveDirection:      String(localized: "field.wind_wave_direction", defaultValue: "Wind Wave Direction", comment: "Marine weather field name")
        case .windWavePeriod:         String(localized: "field.wind_wave_period", defaultValue: "Wind Wave Period", comment: "Marine weather field name")
        case .swellWavePeriod:        String(localized: "field.swell_wave_period", defaultValue: "Swell Wave Period", comment: "Marine weather field name")
        }
    }
}

extension DetailCategory {
    var localizedLabel: String {
        switch self {
        case .weatherAlerts:     String(localized: "field.weather_alerts", defaultValue: "Weather Alerts", comment: "Weather data field name")
        case .currentConditions: String(localized: "category.current_conditions", defaultValue: "Current Conditions", comment: "Section header in city detail")
        case .todaysForecast:    String(localized: "category.todays_forecast", defaultValue: "Today's Forecast", comment: "Section header in city detail")
        case .hourlyForecast:    String(localized: "category.hourly_forecast", defaultValue: "24-Hour Forecast", comment: "Section header in city detail")
        case .dailyForecast:     String(localized: "category.daily_forecast", defaultValue: "16-Day Forecast", comment: "Section header in city detail")
        case .marineForecast:    String(localized: "category.marine_forecast", defaultValue: "Marine Forecast", comment: "Section header in city detail")
        case .historicalWeather: String(localized: "category.historical_weather", defaultValue: "Historical Weather", comment: "Section header in city detail")
        case .location:          String(localized: "category.location", defaultValue: "Location", comment: "Section header in city detail")
        case .myData:            String(localized: "category.my_data", defaultValue: "My Data", comment: "Section header in city detail — user-chosen custom data")
        case .astronomy:         String(localized: "category.astronomy", defaultValue: "Astronomy", comment: "Section header in city detail (sunrise/sunset/moon)")
        }
    }
}

extension MyLocationPosition {
    var localizedLabel: String {
        switch self {
        case .beforeCityList: String(localized: "setting.location_position.before", defaultValue: "Before City List", comment: "Where to show the current-location entry in the city list")
        case .afterCityList:  String(localized: "setting.location_position.after", defaultValue: "After City List", comment: "Where to show the current-location entry in the city list")
        }
    }
}

extension DisplayMode {
    var localizedLabel: String {
        switch self {
        case .condensed: String(localized: "setting.display_mode.condensed", defaultValue: "Condensed", comment: "Display density option")
        case .details:   String(localized: "setting.display_mode.details", defaultValue: "Details", comment: "Display density option")
        }
    }
}

extension ViewMode {
    var localizedLabel: String {
        switch self {
        case .flat:  String(localized: "setting.view_mode.flat", defaultValue: "Flat", comment: "City list layout option")
        case .list:  String(localized: "setting.view_mode.list", defaultValue: "List", comment: "City list layout option")
        case .table: String(localized: "setting.view_mode.table", defaultValue: "Table", comment: "City list layout option")
        }
    }
}

extension ForecastDetailLayout {
    var localizedLabel: String {
        switch self {
        case .list:     String(localized: "setting.forecast_layout.list", defaultValue: "List", comment: "Forecast detail layout option")
        case .headings: String(localized: "setting.forecast_layout.headings", defaultValue: "Headings", comment: "Forecast detail layout option")
        }
    }
}
