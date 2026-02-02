//
//  Weather.swift
//  Fast Weather
//
//  Weather data models
//

import Foundation

// WMO Weather interpretation codes
enum WeatherCode: Int, Codable {
    case clearSky = 0
    case mainlyClear = 1
    case partlyCloudy = 2
    case overcast = 3
    case fog = 45
    case depositingRimeFog = 48
    case lightDrizzle = 51
    case moderateDrizzle = 53
    case denseDrizzle = 55
    case lightFreezingDrizzle = 56
    case denseFreezingDrizzle = 57
    case slightRain = 61
    case moderateRain = 63
    case heavyRain = 65
    case lightFreezingRain = 66
    case heavyFreezingRain = 67
    case slightSnowFall = 71
    case moderateSnowFall = 73
    case heavySnowFall = 75
    case snowGrains = 77
    case slightRainShowers = 80
    case moderateRainShowers = 81
    case violentRainShowers = 82
    case slightSnowShowers = 85
    case heavySnowShowers = 86
    case thunderstorm = 95
    case thunderstormWithSlightHail = 96
    case thunderstormWithHeavyHail = 99
    
    var description: String {
        switch self {
        case .clearSky: return "Clear sky"
        case .mainlyClear: return "Mainly clear"
        case .partlyCloudy: return "Partly cloudy"
        case .overcast: return "Overcast"
        case .fog: return "Fog"
        case .depositingRimeFog: return "Depositing rime fog"
        case .lightDrizzle: return "Light drizzle"
        case .moderateDrizzle: return "Moderate drizzle"
        case .denseDrizzle: return "Dense drizzle"
        case .lightFreezingDrizzle: return "Light freezing drizzle"
        case .denseFreezingDrizzle: return "Dense freezing drizzle"
        case .slightRain: return "Slight rain"
        case .moderateRain: return "Moderate rain"
        case .heavyRain: return "Heavy rain"
        case .lightFreezingRain: return "Light freezing rain"
        case .heavyFreezingRain: return "Heavy freezing rain"
        case .slightSnowFall: return "Slight snow fall"
        case .moderateSnowFall: return "Moderate snow fall"
        case .heavySnowFall: return "Heavy snow fall"
        case .snowGrains: return "Snow grains"
        case .slightRainShowers: return "Slight rain showers"
        case .moderateRainShowers: return "Moderate rain showers"
        case .violentRainShowers: return "Violent rain showers"
        case .slightSnowShowers: return "Slight snow showers"
        case .heavySnowShowers: return "Heavy snow showers"
        case .thunderstorm: return "Thunderstorm"
        case .thunderstormWithSlightHail: return "Thunderstorm with slight hail"
        case .thunderstormWithHeavyHail: return "Thunderstorm with heavy hail"
        }
    }
    
    var systemImageName: String {
        switch self {
        case .clearSky, .mainlyClear:
            return "sun.max.fill"
        case .partlyCloudy:
            return "cloud.sun.fill"
        case .overcast:
            return "cloud.fill"
        case .fog, .depositingRimeFog:
            return "cloud.fog.fill"
        case .lightDrizzle, .moderateDrizzle, .denseDrizzle:
            return "cloud.drizzle.fill"
        case .lightFreezingDrizzle, .denseFreezingDrizzle:
            return "cloud.sleet.fill"
        case .slightRain, .moderateRain, .heavyRain:
            return "cloud.rain.fill"
        case .lightFreezingRain, .heavyFreezingRain:
            return "cloud.sleet.fill"
        case .slightSnowFall, .moderateSnowFall, .heavySnowFall, .snowGrains:
            return "cloud.snow.fill"
        case .slightRainShowers, .moderateRainShowers, .violentRainShowers:
            return "cloud.heavyrain.fill"
        case .slightSnowShowers, .heavySnowShowers:
            return "cloud.snow.fill"
        case .thunderstorm, .thunderstormWithSlightHail, .thunderstormWithHeavyHail:
            return "cloud.bolt.rain.fill"
        }
    }
}

struct WeatherData: Codable {
    let current: CurrentWeather
    let daily: DailyWeather?
    let hourly: HourlyWeather?
    
    struct CurrentWeather: Codable {
        let temperature2m: Double
        let relativeHumidity2m: Int?
        let apparentTemperature: Double?
        let isDay: Int?
        let precipitation: Double?
        let rain: Double?
        let showers: Double?
        let snowfall: Double?
        let weatherCode: Int
        let cloudCover: Int
        let pressureMsl: Double?
        let windSpeed10m: Double?
        let windDirection10m: Int?
        let visibility: Double?
        let windGusts10m: Double?
        let uvIndex: Double?
        let dewpoint2m: Double?
        
        enum CodingKeys: String, CodingKey {
            case temperature2m = "temperature_2m"
            case relativeHumidity2m = "relative_humidity_2m"
            case apparentTemperature = "apparent_temperature"
            case isDay = "is_day"
            case precipitation
            case rain
            case showers
            case snowfall
            case weatherCode = "weather_code"
            case cloudCover = "cloud_cover"
            case pressureMsl = "pressure_msl"
            case windSpeed10m = "wind_speed_10m"
            case windDirection10m = "wind_direction_10m"
            case visibility
            case windGusts10m = "wind_gusts_10m"
            case uvIndex = "uv_index"
            case dewpoint2m = "dewpoint_2m"
        }
        
        var weatherCodeEnum: WeatherCode? {
            WeatherCode(rawValue: weatherCode)
        }
    }
    
    struct DailyWeather: Codable {
        let temperature2mMax: [Double?]
        let temperature2mMin: [Double?]
        let sunrise: [String?]?  // Optional for basic mode (not requested)
        let sunset: [String?]?   // Optional for basic mode (not requested)
        let weatherCode: [Int?]? // Optional for basic mode (not requested)
        let precipitationSum: [Double?]? // Optional for basic mode (not requested)
        let precipitationProbabilityMax: [Int?]?
        let uvIndexMax: [Double?]?
        let daylightDuration: [Double?]?
        let sunshineDuration: [Double?]?
        
        enum CodingKeys: String, CodingKey {
            case temperature2mMax = "temperature_2m_max"
            case temperature2mMin = "temperature_2m_min"
            case sunrise
            case sunset
            case weatherCode = "weather_code"
            case precipitationSum = "precipitation_sum"
            case precipitationProbabilityMax = "precipitation_probability_max"
            case uvIndexMax = "uv_index_max"
            case daylightDuration = "daylight_duration"
            case sunshineDuration = "sunshine_duration"
        }
    }
    
    struct HourlyWeather: Codable {
        let time: [String?]?  // Optional for basic mode (not requested)
        let temperature2m: [Double?]?  // Optional for basic mode (not requested)
        let weatherCode: [Int?]?  // Optional for basic mode (not requested)
        let precipitation: [Double?]?  // Optional for basic mode (not requested)
        let relativeHumidity2m: [Int?]?  // Optional for basic mode (not requested)
        let windSpeed10m: [Double?]?  // Optional for basic mode (not requested)
        let cloudcover: [Int?]?  // Used in basic mode
        let precipitationProbability: [Int?]?
        let uvIndex: [Double?]?
        let windgusts10m: [Double?]?
        let dewpoint2m: [Double?]?
        
        enum CodingKeys: String, CodingKey {
            case time
            case temperature2m = "temperature_2m"
            case weatherCode = "weather_code"
            case precipitation
            case relativeHumidity2m = "relative_humidity_2m"
            case windSpeed10m = "wind_speed_10m"
            case cloudcover
            case precipitationProbability = "precipitation_probability"
            case uvIndex = "uv_index"
            case windgusts10m = "windgusts_10m"
            case dewpoint2m = "dewpoint_2m"
        }
    }
}

// Container for API response
struct WeatherResponse: Codable {
    let current: WeatherData.CurrentWeather
    let daily: WeatherData.DailyWeather?
    let hourly: WeatherData.HourlyWeather?
}
