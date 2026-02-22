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
        /// Additional dynamic values from My Data parameters not in the base model
        var myDataValues: [String: Double]?
        
        // Known keys that are decoded into named properties
        private static let knownKeys: Set<String> = [
            "temperature_2m", "relative_humidity_2m", "apparent_temperature",
            "is_day", "precipitation", "rain", "showers", "snowfall",
            "weather_code", "cloud_cover", "pressure_msl", "wind_speed_10m",
            "wind_direction_10m", "visibility", "wind_gusts_10m", "uv_index",
            "dewpoint_2m", "time", "interval"
        ]
        
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
            case myDataValues
        }
        
        // Custom dynamic key for sweeping extra API fields
        private struct DynamicCodingKey: CodingKey {
            var stringValue: String
            init?(stringValue: String) { self.stringValue = stringValue }
            var intValue: Int? { nil }
            init?(intValue: Int) { nil }
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            temperature2m = try container.decode(Double.self, forKey: .temperature2m)
            relativeHumidity2m = try container.decodeIfPresent(Int.self, forKey: .relativeHumidity2m)
            apparentTemperature = try container.decodeIfPresent(Double.self, forKey: .apparentTemperature)
            isDay = try container.decodeIfPresent(Int.self, forKey: .isDay)
            precipitation = try container.decodeIfPresent(Double.self, forKey: .precipitation)
            rain = try container.decodeIfPresent(Double.self, forKey: .rain)
            showers = try container.decodeIfPresent(Double.self, forKey: .showers)
            snowfall = try container.decodeIfPresent(Double.self, forKey: .snowfall)
            weatherCode = try container.decode(Int.self, forKey: .weatherCode)
            cloudCover = try container.decode(Int.self, forKey: .cloudCover)
            pressureMsl = try container.decodeIfPresent(Double.self, forKey: .pressureMsl)
            windSpeed10m = try container.decodeIfPresent(Double.self, forKey: .windSpeed10m)
            windDirection10m = try container.decodeIfPresent(Int.self, forKey: .windDirection10m)
            visibility = try container.decodeIfPresent(Double.self, forKey: .visibility)
            windGusts10m = try container.decodeIfPresent(Double.self, forKey: .windGusts10m)
            uvIndex = try container.decodeIfPresent(Double.self, forKey: .uvIndex)
            dewpoint2m = try container.decodeIfPresent(Double.self, forKey: .dewpoint2m)
            
            // Sweep any extra numeric keys into myDataValues
            let dynamicContainer = try decoder.container(keyedBy: DynamicCodingKey.self)
            var extras: [String: Double] = [:]
            for key in dynamicContainer.allKeys {
                guard !Self.knownKeys.contains(key.stringValue) else { continue }
                if let val = try? dynamicContainer.decode(Double.self, forKey: key) {
                    extras[key.stringValue] = val
                } else if let intVal = try? dynamicContainer.decode(Int.self, forKey: key) {
                    extras[key.stringValue] = Double(intVal)
                }
            }
            myDataValues = extras.isEmpty ? nil : extras
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(temperature2m, forKey: .temperature2m)
            try container.encodeIfPresent(relativeHumidity2m, forKey: .relativeHumidity2m)
            try container.encodeIfPresent(apparentTemperature, forKey: .apparentTemperature)
            try container.encodeIfPresent(isDay, forKey: .isDay)
            try container.encodeIfPresent(precipitation, forKey: .precipitation)
            try container.encodeIfPresent(rain, forKey: .rain)
            try container.encodeIfPresent(showers, forKey: .showers)
            try container.encodeIfPresent(snowfall, forKey: .snowfall)
            try container.encode(weatherCode, forKey: .weatherCode)
            try container.encode(cloudCover, forKey: .cloudCover)
            try container.encodeIfPresent(pressureMsl, forKey: .pressureMsl)
            try container.encodeIfPresent(windSpeed10m, forKey: .windSpeed10m)
            try container.encodeIfPresent(windDirection10m, forKey: .windDirection10m)
            try container.encodeIfPresent(visibility, forKey: .visibility)
            try container.encodeIfPresent(windGusts10m, forKey: .windGusts10m)
            try container.encodeIfPresent(uvIndex, forKey: .uvIndex)
            try container.encodeIfPresent(dewpoint2m, forKey: .dewpoint2m)
            try container.encodeIfPresent(myDataValues, forKey: .myDataValues)
        }
        
        // Memberwise init for synthetic weather data (historical/future dates)
        init(temperature2m: Double, relativeHumidity2m: Int?, apparentTemperature: Double?,
             isDay: Int?, precipitation: Double?, rain: Double?, showers: Double?,
             snowfall: Double?, weatherCode: Int, cloudCover: Int, pressureMsl: Double?,
             windSpeed10m: Double?, windDirection10m: Int?, visibility: Double?,
             windGusts10m: Double?, uvIndex: Double?, dewpoint2m: Double?,
             myDataValues: [String: Double]? = nil) {
            self.temperature2m = temperature2m
            self.relativeHumidity2m = relativeHumidity2m
            self.apparentTemperature = apparentTemperature
            self.isDay = isDay
            self.precipitation = precipitation
            self.rain = rain
            self.showers = showers
            self.snowfall = snowfall
            self.weatherCode = weatherCode
            self.cloudCover = cloudCover
            self.pressureMsl = pressureMsl
            self.windSpeed10m = windSpeed10m
            self.windDirection10m = windDirection10m
            self.visibility = visibility
            self.windGusts10m = windGusts10m
            self.uvIndex = uvIndex
            self.dewpoint2m = dewpoint2m
            self.myDataValues = myDataValues
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
        let rainSum: [Double?]? // Amount that fell as rain (mm)
        let snowfallSum: [Double?]? // Amount that fell as snow (cm)
        let precipitationProbabilityMax: [Int?]?
        let uvIndexMax: [Double?]?
        let daylightDuration: [Double?]?
        let sunshineDuration: [Double?]?
        let windSpeed10mMax: [Double?]?
        let winddirection10mDominant: [Int?]?
        
        enum CodingKeys: String, CodingKey {
            case temperature2mMax = "temperature_2m_max"
            case temperature2mMin = "temperature_2m_min"
            case sunrise
            case sunset
            case weatherCode = "weather_code"
            case precipitationSum = "precipitation_sum"
            case rainSum = "rain_sum"
            case snowfallSum = "snowfall_sum"
            case precipitationProbabilityMax = "precipitation_probability_max"
            case uvIndexMax = "uv_index_max"
            case daylightDuration = "daylight_duration"
            case sunshineDuration = "sunshine_duration"
            case windSpeed10mMax = "windspeed_10m_max"
            case winddirection10mDominant = "winddirection_10m_dominant"
        }
    }
    
    struct HourlyWeather: Codable {
        let time: [String?]?  // Optional for basic mode (not requested)
        let temperature2m: [Double?]?  // Optional for basic mode (not requested)
        let weatherCode: [Int?]?  // Optional for basic mode (not requested)
        let precipitation: [Double?]?  // Total precipitation (rain+showers+snow water equiv) in mm
        let relativeHumidity2m: [Int?]?  // Optional for basic mode (not requested)
        let windSpeed10m: [Double?]?  // Optional for basic mode (not requested)
        let cloudcover: [Int?]?  // Used in basic mode
        let precipitationProbability: [Int?]?
        let uvIndex: [Double?]?
        let windgusts10m: [Double?]?
        let dewpoint2m: [Double?]?
        let snowfall: [Double?]?  // Hourly snowfall in cm
        
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
            case snowfall
        }
    }
}

// Container for API response
struct WeatherResponse: Codable {
    let current: WeatherData.CurrentWeather
    let daily: WeatherData.DailyWeather?
    let hourly: WeatherData.HourlyWeather?
}

// MARK: - Marine Weather Models

struct MarineData: Codable {
    let current: MarineCurrent?
    let hourly: MarineHourly?
    
    struct MarineCurrent: Codable {
        var myDataValues: [String: Double]?
        
        enum CodingKeys: String, CodingKey {
            // Marine API parameter keys
            case wave_height, wave_direction, wave_period, wave_peak_period
            case wind_wave_height, wind_wave_direction, wind_wave_period
            case swell_wave_height, swell_wave_direction, swell_wave_period
            case ocean_current_velocity, ocean_current_direction
            case sea_surface_temperature, sea_level_height_msl
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            var extras: [String: Double] = [:]
            
            // Sweep all marine current parameters into myDataValues
            for key in container.allKeys {
                if let value = try? container.decode(Double.self, forKey: key) {
                    extras[key.stringValue] = value
                }
            }
            
            myDataValues = extras.isEmpty ? nil : extras
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            // Encode myDataValues back to individual keys
            if let values = myDataValues {
                for (key, value) in values {
                    if let codingKey = CodingKeys(stringValue: key) {
                        try container.encode(value, forKey: codingKey)
                    }
                }
            }
        }
    }
    
    struct MarineHourly: Codable {
        let time: [String?]?
        let waveHeight: [Double?]?
        let waveDirection: [Int?]?
        let wavePeriod: [Double?]?
        let wavePeakPeriod: [Double?]?
        let windWaveHeight: [Double?]?
        let windWaveDirection: [Int?]?
        let windWavePeriod: [Double?]?
        let swellWaveHeight: [Double?]?
        let swellWaveDirection: [Int?]?
        let swellWavePeriod: [Double?]?
        let oceanCurrentVelocity: [Double?]?
        let oceanCurrentDirection: [Int?]?
        let seaSurfaceTemperature: [Double?]?
        let seaLevelHeight: [Double?]?
        
        enum CodingKeys: String, CodingKey {
            case time
            case waveHeight = "wave_height"
            case waveDirection = "wave_direction"
            case wavePeriod = "wave_period"
            case wavePeakPeriod = "wave_peak_period"
            case windWaveHeight = "wind_wave_height"
            case windWaveDirection = "wind_wave_direction"
            case windWavePeriod = "wind_wave_period"
            case swellWaveHeight = "swell_wave_height"
            case swellWaveDirection = "swell_wave_direction"
            case swellWavePeriod = "swell_wave_period"
            case oceanCurrentVelocity = "ocean_current_velocity"
            case oceanCurrentDirection = "ocean_current_direction"
            case seaSurfaceTemperature = "sea_surface_temperature"
            case seaLevelHeight = "sea_level_height_msl"
        }
    }
}

// Container for Marine API response
struct MarineResponse: Codable {
    let current: MarineData.MarineCurrent?
    let hourly: MarineData.MarineHourly?
}

// MARK: - Air Quality Models

struct AirQualityData: Codable {
    let current: AirQualityCurrent?
    
    struct AirQualityCurrent: Codable {
        var myDataValues: [String: Double]?
        
        enum CodingKeys: String, CodingKey {
            // Air Quality API parameter keys - Basic Pollutants
            case pm10, pm2_5, carbon_monoxide, nitrogen_dioxide, sulphur_dioxide, ozone
            case aerosol_optical_depth, dust, uv_index, uv_index_clear_sky
            case ammonia, carbon_dioxide, methane
            
            // Pollen
            case alder_pollen, birch_pollen, grass_pollen, mugwort_pollen
            case olive_pollen, ragweed_pollen
            
            // Air Quality Indices (main)
            case european_aqi, us_aqi
            
            // Air Quality sub-indices (returned by API even when not requested)
            case european_aqi_pm2_5, european_aqi_pm10
            case european_aqi_nitrogen_dioxide, european_aqi_ozone, european_aqi_sulphur_dioxide
            case us_aqi_pm2_5, us_aqi_pm10, us_aqi_nitrogen_dioxide
            case us_aqi_carbon_monoxide, us_aqi_ozone, us_aqi_sulphur_dioxide
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            var extras: [String: Double] = [:]
            
            // Sweep all air quality current parameters into myDataValues
            for key in container.allKeys {
                if let value = try? container.decode(Double.self, forKey: key) {
                    extras[key.stringValue] = value
                }
            }
            
            myDataValues = extras.isEmpty ? nil : extras
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            // Encode myDataValues back to individual keys
            if let values = myDataValues {
                for (key, value) in values {
                    if let codingKey = CodingKeys(stringValue: key) {
                        try container.encode(value, forKey: codingKey)
                    }
                }
            }
        }
    }
}

// Container for Air Quality API response
struct AirQualityResponse: Codable {
    let current: AirQualityData.AirQualityCurrent?
}
