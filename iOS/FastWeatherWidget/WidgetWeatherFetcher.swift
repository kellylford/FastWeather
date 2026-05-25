import Foundation

// MARK: - Fetch result

struct WidgetDayForecast {
    let dayName: String       // "Today", "Mon", "Tue" …
    let sfSymbol: String
    let highCelsius: Double?
    let lowCelsius: Double?
    let precipProbability: Int?
}

struct WidgetWeatherResult {
    let temperatureCelsius: Double
    let conditionText: String
    let sfSymbol: String
    let isDay: Bool
    let highCelsius: Double?
    let lowCelsius: Double?
    let precipProbability: Int?
    let dailyForecasts: [WidgetDayForecast]   // up to 5 days, index 0 = today
}

// MARK: - Fetcher

enum WidgetWeatherFetcher {
    static func fetch(latitude: Double, longitude: Double) async throws -> WidgetWeatherResult {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude",      value: String(latitude)),
            URLQueryItem(name: "longitude",     value: String(longitude)),
            URLQueryItem(name: "current",       value: "temperature_2m,weather_code,is_day"),
            URLQueryItem(name: "daily",         value: "temperature_2m_max,temperature_2m_min,precipitation_probability_max,weather_code"),
            URLQueryItem(name: "forecast_days", value: "5"),
            URLQueryItem(name: "timezone",      value: "auto"),
        ]
        var request = URLRequest(url: components.url!, timeoutInterval: 15)
        request.setValue("FastWeather/1.5.2 (weatherfast.online)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(WidgetAPIResponse.self, from: data)
        let code    = WidgetWeatherCode(rawValue: decoded.current.weather_code)
        let isDay   = decoded.current.is_day == 1

        // Build per-day forecast rows
        var dailyForecasts: [WidgetDayForecast] = []
        if let daily = decoded.daily {
            let count = min(5, daily.temperature_2m_max.count)
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "yyyy-MM-dd"
            let shortDay = DateFormatter()
            shortDay.dateFormat = "EEE"

            for i in 0..<count {
                let dateStr = daily.time.count > i ? daily.time[i] : nil
                let dayName: String
                if i == 0 {
                    dayName = "Today"
                } else if let str = dateStr,
                          let date = dayFormatter.date(from: str) {
                    dayName = shortDay.string(from: date)
                } else {
                    dayName = "Day \(i + 1)"
                }
                let wCode = daily.weather_code?.count ?? 0 > i
                    ? daily.weather_code![i].flatMap { WidgetWeatherCode(rawValue: $0) }
                    : nil
                dailyForecasts.append(WidgetDayForecast(
                    dayName:           dayName,
                    sfSymbol:          wCode?.sfSymbol(isDay: true) ?? "cloud.fill",
                    highCelsius:       daily.temperature_2m_max[i],
                    lowCelsius:        daily.temperature_2m_min[i],
                    precipProbability: daily.precipitation_probability_max?.count ?? 0 > i
                        ? daily.precipitation_probability_max![i]
                        : nil
                ))
            }
        }

        return WidgetWeatherResult(
            temperatureCelsius: decoded.current.temperature_2m,
            conditionText:      code?.description ?? "Unknown",
            sfSymbol:           code?.sfSymbol(isDay: isDay) ?? "cloud.fill",
            isDay:              isDay,
            highCelsius:        decoded.daily?.temperature_2m_max.first ?? nil,
            lowCelsius:         decoded.daily?.temperature_2m_min.first ?? nil,
            precipProbability:  decoded.daily?.precipitation_probability_max?.first ?? nil,
            dailyForecasts:     dailyForecasts
        )
    }
}

// MARK: - Minimal API response models (widget-only, no shared dependency)

private struct WidgetAPIResponse: Codable {
    let current: Current
    let daily: Daily?

    struct Current: Codable {
        let temperature_2m: Double
        let weather_code: Int
        let is_day: Int
    }

    struct Daily: Codable {
        let time: [String]
        let temperature_2m_max: [Double?]
        let temperature_2m_min: [Double?]
        let precipitation_probability_max: [Int?]?
        let weather_code: [Int?]?
    }
}

// MARK: - WMO weather code (widget-only copy — avoids importing Weather.swift)

enum WidgetWeatherCode: Int {
    case clearSky = 0, mainlyClear = 1, partlyCloudy = 2, overcast = 3
    case fog = 45, depositingRimeFog = 48
    case lightDrizzle = 51, moderateDrizzle = 53, denseDrizzle = 55
    case lightFreezingDrizzle = 56, denseFreezingDrizzle = 57
    case slightRain = 61, moderateRain = 63, heavyRain = 65
    case lightFreezingRain = 66, heavyFreezingRain = 67
    case slightSnow = 71, moderateSnow = 73, heavySnow = 75, snowGrains = 77
    case slightRainShowers = 80, moderateRainShowers = 81, violentRainShowers = 82
    case slightSnowShowers = 85, heavySnowShowers = 86
    case thunderstorm = 95, thunderstormSlightHail = 96, thunderstormHeavyHail = 99

    var description: String {
        switch self {
        case .clearSky:               return "Clear"
        case .mainlyClear:            return "Mainly Clear"
        case .partlyCloudy:           return "Partly Cloudy"
        case .overcast:               return "Overcast"
        case .fog, .depositingRimeFog: return "Foggy"
        case .lightDrizzle, .moderateDrizzle, .denseDrizzle: return "Drizzle"
        case .lightFreezingDrizzle, .denseFreezingDrizzle:   return "Freezing Drizzle"
        case .slightRain:             return "Light Rain"
        case .moderateRain:           return "Rain"
        case .heavyRain:              return "Heavy Rain"
        case .lightFreezingRain, .heavyFreezingRain: return "Freezing Rain"
        case .slightSnow:             return "Light Snow"
        case .moderateSnow:           return "Snow"
        case .heavySnow:              return "Heavy Snow"
        case .snowGrains:             return "Snow Grains"
        case .slightRainShowers, .moderateRainShowers: return "Rain Showers"
        case .violentRainShowers:     return "Heavy Showers"
        case .slightSnowShowers, .heavySnowShowers:    return "Snow Showers"
        case .thunderstorm, .thunderstormSlightHail, .thunderstormHeavyHail: return "Thunderstorm"
        }
    }

    func sfSymbol(isDay: Bool) -> String {
        switch self {
        case .clearSky, .mainlyClear:
            return isDay ? "sun.max.fill" : "moon.stars.fill"
        case .partlyCloudy:
            return isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case .overcast:
            return "cloud.fill"
        case .fog, .depositingRimeFog:
            return "cloud.fog.fill"
        case .lightDrizzle, .moderateDrizzle, .denseDrizzle,
             .lightFreezingDrizzle, .denseFreezingDrizzle:
            return "cloud.drizzle.fill"
        case .slightRain, .moderateRain, .heavyRain,
             .lightFreezingRain, .heavyFreezingRain:
            return "cloud.rain.fill"
        case .slightRainShowers, .moderateRainShowers, .violentRainShowers:
            return "cloud.heavyrain.fill"
        case .slightSnow, .moderateSnow, .heavySnow, .snowGrains,
             .slightSnowShowers, .heavySnowShowers:
            return "cloud.snow.fill"
        case .thunderstorm, .thunderstormSlightHail, .thunderstormHeavyHail:
            return "cloud.bolt.rain.fill"
        }
    }
}
