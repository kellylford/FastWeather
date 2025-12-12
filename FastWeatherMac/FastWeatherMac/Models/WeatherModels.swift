//
//  WeatherModels.swift
//  FastWeatherMac
//
//  Created on 12/12/2025.
//  Weather data models for Open-Meteo API
//

import Foundation

// MARK: - City Model
struct City: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var displayName: String
    var latitude: Double
    var longitude: Double
    var state: String?
    var country: String?
    
    init(id: UUID = UUID(), name: String, displayName: String, latitude: Double, longitude: Double, state: String? = nil, country: String? = nil) {
        self.id = id
        self.name = name
        self.displayName = displayName
        self.latitude = latitude
        self.longitude = longitude
        self.state = state
        self.country = country
    }
}

// MARK: - Weather Code Descriptions
enum WeatherCode: Int, Codable {
    case clear = 0
    case mainlyClear = 1
    case partlyCloudy = 2
    case overcast = 3
    case foggy = 45
    case depositingRimeFog = 48
    case drizzleLight = 51
    case drizzleModerate = 53
    case drizzleDense = 55
    case freezingDrizzleLight = 56
    case freezingDrizzleDense = 57
    case rainSlight = 61
    case rainModerate = 63
    case rainHeavy = 65
    case freezingRainLight = 66
    case freezingRainHeavy = 67
    case snowFallSlight = 71
    case snowFallModerate = 73
    case snowFallHeavy = 75
    case snowGrains = 77
    case rainShowersSlight = 80
    case rainShowersModerate = 81
    case rainShowersViolent = 82
    case snowShowersSlight = 85
    case snowShowersHeavy = 86
    case thunderstormSlight = 95
    case thunderstormWithHailSlight = 96
    case thunderstormWithHailHeavy = 99
    
    var description: String {
        switch self {
        case .clear: return "Clear sky"
        case .mainlyClear: return "Mainly clear"
        case .partlyCloudy: return "Partly cloudy"
        case .overcast: return "Overcast"
        case .foggy: return "Foggy"
        case .depositingRimeFog: return "Depositing rime fog"
        case .drizzleLight: return "Light drizzle"
        case .drizzleModerate: return "Moderate drizzle"
        case .drizzleDense: return "Dense drizzle"
        case .freezingDrizzleLight: return "Light freezing drizzle"
        case .freezingDrizzleDense: return "Dense freezing drizzle"
        case .rainSlight: return "Slight rain"
        case .rainModerate: return "Moderate rain"
        case .rainHeavy: return "Heavy rain"
        case .freezingRainLight: return "Light freezing rain"
        case .freezingRainHeavy: return "Heavy freezing rain"
        case .snowFallSlight: return "Slight snow fall"
        case .snowFallModerate: return "Moderate snow fall"
        case .snowFallHeavy: return "Heavy snow fall"
        case .snowGrains: return "Snow grains"
        case .rainShowersSlight: return "Slight rain showers"
        case .rainShowersModerate: return "Moderate rain showers"
        case .rainShowersViolent: return "Violent rain showers"
        case .snowShowersSlight: return "Slight snow showers"
        case .snowShowersHeavy: return "Heavy snow showers"
        case .thunderstormSlight: return "Thunderstorm"
        case .thunderstormWithHailSlight: return "Thunderstorm with slight hail"
        case .thunderstormWithHailHeavy: return "Thunderstorm with heavy hail"
        }
    }
    
    var sfSymbol: String {
        switch self {
        case .clear: return "sun.max.fill"
        case .mainlyClear: return "sun.max"
        case .partlyCloudy: return "cloud.sun.fill"
        case .overcast: return "cloud.fill"
        case .foggy, .depositingRimeFog: return "cloud.fog.fill"
        case .drizzleLight, .drizzleModerate, .drizzleDense: return "cloud.drizzle.fill"
        case .freezingDrizzleLight, .freezingDrizzleDense: return "cloud.sleet.fill"
        case .rainSlight, .rainModerate: return "cloud.rain.fill"
        case .rainHeavy: return "cloud.heavyrain.fill"
        case .freezingRainLight, .freezingRainHeavy: return "cloud.sleet.fill"
        case .snowFallSlight, .snowFallModerate, .snowFallHeavy, .snowGrains: return "cloud.snow.fill"
        case .rainShowersSlight, .rainShowersModerate, .rainShowersViolent: return "cloud.rain.fill"
        case .snowShowersSlight, .snowShowersHeavy: return "cloud.snow.fill"
        case .thunderstormSlight, .thunderstormWithHailSlight, .thunderstormWithHailHeavy: return "cloud.bolt.rain.fill"
        }
    }
}

// MARK: - Current Weather
struct CurrentWeather: Codable {
    let time: String
    let temperature2m: Double
    let relativeHumidity2m: Int
    let apparentTemperature: Double
    let isDay: Int
    let precipitation: Double
    let rain: Double
    let showers: Double
    let snowfall: Double
    let weatherCode: Int
    let cloudCover: Int
    let pressureMsl: Double
    let surfacePressure: Double
    let windSpeed10m: Double
    let windDirection10m: Int
    let windGusts10m: Double
    let visibility: Double
    
    enum CodingKeys: String, CodingKey {
        case time
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
        case surfacePressure = "surface_pressure"
        case windSpeed10m = "wind_speed_10m"
        case windDirection10m = "wind_direction_10m"
        case windGusts10m = "wind_gusts_10m"
        case visibility
    }
    
    var weatherCodeEnum: WeatherCode? {
        WeatherCode(rawValue: weatherCode)
    }
    
    var windDirectionDescription: String {
        let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let index = Int((Double(windDirection10m) + 22.5) / 45.0) % 8
        return directions[index]
    }
}

// MARK: - Daily Weather
struct DailyWeather: Codable {
    let time: [String]
    let weathercode: [Int]
    let temperature2mMax: [Double]
    let temperature2mMin: [Double]
    let apparentTemperatureMax: [Double]
    let apparentTemperatureMin: [Double]
    let sunrise: [String]
    let sunset: [String]
    let precipitationSum: [Double]
    let precipitationProbabilityMax: [Int]?
    let windSpeed10mMax: [Double]
    let windDirection10mDominant: [Int]
    
    enum CodingKeys: String, CodingKey {
        case time
        case weathercode
        case temperature2mMax = "temperature_2m_max"
        case temperature2mMin = "temperature_2m_min"
        case apparentTemperatureMax = "apparent_temperature_max"
        case apparentTemperatureMin = "apparent_temperature_min"
        case sunrise
        case sunset
        case precipitationSum = "precipitation_sum"
        case precipitationProbabilityMax = "precipitation_probability_max"
        case windSpeed10mMax = "windspeed_10m_max"
        case windDirection10mDominant = "winddirection_10m_dominant"
    }
}

// MARK: - Hourly Weather
struct HourlyWeather: Codable {
    let time: [String]
    let temperature2m: [Double]
    let apparentTemperature: [Double]
    let relativeHumidity2m: [Int]
    let precipitation: [Double]
    let weathercode: [Int]
    let windSpeed10m: [Double]
    let windDirection10m: [Int]
    
    enum CodingKeys: String, CodingKey {
        case time
        case temperature2m = "temperature_2m"
        case apparentTemperature = "apparent_temperature"
        case relativeHumidity2m = "relative_humidity_2m"
        case precipitation
        case weathercode
        case windSpeed10m = "windspeed_10m"
        case windDirection10m = "winddirection_10m"
    }
}

// MARK: - Weather Response
struct WeatherResponse: Codable {
    let latitude: Double
    let longitude: Double
    let timezone: String
    let current: CurrentWeather
    let daily: DailyWeather?
    let hourly: HourlyWeather?
}

// MARK: - Geocoding Models
struct GeocodingResult: Codable, Identifiable {
    let id = UUID()
    let displayName: String
    let lat: String
    let lon: String
    let address: Address?
    
    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case lat
        case lon
        case address
    }
    
    struct Address: Codable {
        let city: String?
        let town: String?
        let village: String?
        let state: String?
        let country: String?
    }
    
    var cityName: String {
        address?.city ?? address?.town ?? address?.village ?? "Unknown"
    }
    
    var latitude: Double {
        Double(lat) ?? 0.0
    }
    
    var longitude: Double {
        Double(lon) ?? 0.0
    }
}
