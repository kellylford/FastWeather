//
//  AirQualityService.swift
//  Fast Weather
//
//  Fetches air quality for a city and applies the "believe the sky, not the
//  model" rule:
//    1. AirNow      -> OBSERVED AQI from real monitors (US). The headline when available.
//    2. NWS alerts  -> active Air Quality Alert (reuses WeatherService's cached fetch).
//                      When present, it dominates the card.
//    3. Open-Meteo  -> CAMS MODEL estimate. Never the headline in the US; kept only to
//                      explain a disagreement ("model says Good, monitor says Purple").
//
//  Outside AirNow coverage (non-US) the modeled estimate is the headline, clearly
//  labelled as modeled.
//

import Foundation

class AirQualityService {
    static let shared = AirQualityService()
    private init() {}

    // Short-lived cache; observed AQI updates hourly, alerts every few minutes.
    private var cache: [UUID: (data: AirQualityReport, timestamp: Date)] = [:]
    private let cacheMinutes: Double = 10

    /// - Parameter activeAlert: an active air quality alert for this location, already
    ///   resolved by the caller from the app's existing (cached) NWS alert fetch. When
    ///   present it dominates the resulting card. Pass nil if none / unknown.
    func fetchAirQuality(for city: City, activeAlert airAlert: WeatherAlert?) async throws -> AirQualityReport {
        if let cached = cache[city.id],
           Date().timeIntervalSince(cached.timestamp) < cacheMinutes * 60 {
            return cached.data
        }

        // Observed monitors (US only). Best-effort — empty for non-US or on failure.
        let observed = (try? await fetchAirNowObserved(for: city)) ?? []

        // Modeled estimate for contrast / non-US fallback.
        let modelAQI = try? await fetchModelUSAQI(for: city)

        let data: AirQualityReport
        if let headline = observed.max(by: { $0.aqi < $1.aqi }) {
            // OBSERVED headline (trustworthy for "now").
            let pollutants = observed
                .sorted { $0.aqi > $1.aqi }
                .map { obs in
                    AQIPollutant(displayName: prettyPollutant(obs.parameterName),
                                 aqi: obs.aqi,
                                 category: AQICategory(aqi: obs.aqi),
                                 isDominant: obs.parameterName == headline.parameterName)
                }
            let headlineCat = AQICategory(aqi: headline.aqi)
            // Only surface the model number when it disagrees by at least one category.
            let disagreement: Int? = {
                guard let m = modelAQI, AQICategory(aqi: m) != headlineCat else { return nil }
                return m
            }()
            data = AirQualityReport(
                reportingArea: headline.reportingArea,
                headlineAQI: headline.aqi,
                headlineCategory: headlineCat,
                dominantPollutant: prettyPollutant(headline.parameterName),
                pollutants: pollutants,
                source: .airNowObserved,
                activeAlert: airAlert,
                modelDisagreementAQI: disagreement
            )
        } else if let m = modelAQI {
            // MODELED fallback (non-US, or no nearby monitor). Clearly labelled modeled.
            let cat = AQICategory(aqi: m)
            data = AirQualityReport(
                reportingArea: city.displayName,
                headlineAQI: m,
                headlineCategory: cat,
                dominantPollutant: "Fine particles (PM2.5)",
                pollutants: [AQIPollutant(displayName: "Fine particles (PM2.5)",
                                          aqi: m, category: cat, isDominant: true)],
                source: .modelEstimate,
                activeAlert: airAlert,
                modelDisagreementAQI: nil
            )
        } else {
            throw AirQualityError.noData
        }

        cache[city.id] = (data, Date())
        return data
    }

    /// Picks the most severe active air quality alert from a list (e.g. the city's
    /// already-fetched NWS alerts). Caller passes the result into `fetchAirQuality`.
    static func airQualityAlert(in alerts: [WeatherAlert]) -> WeatherAlert? {
        alerts
            .filter { $0.event.lowercased().contains("air quality") && !$0.isExpired }
            .min { $0.severity.sortOrder < $1.severity.sortOrder }
    }

    // MARK: - AirNow observed (US ground monitors)

    private func fetchAirNowObserved(for city: City) async throws -> [AirNowObservation] {
        guard let key = Secrets.airNowAPIKey, !key.isEmpty else { return [] }
        // AirNow coverage is US-only; skip the call elsewhere.
        guard city.country == "United States" else { return [] }

        var components = URLComponents(string: "https://www.airnowapi.org/aq/observation/latLong/current/")!
        components.queryItems = [
            URLQueryItem(name: "format", value: "application/json"),
            URLQueryItem(name: "latitude", value: String(city.latitude)),
            URLQueryItem(name: "longitude", value: String(city.longitude)),
            URLQueryItem(name: "distance", value: "50"),
            URLQueryItem(name: "API_KEY", value: key)
        ]
        var request = URLRequest(url: components.url!)
        request.setValue("WeatherFast/1.0 iOS", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AirQualityError.networkError
        }
        return try JSONDecoder().decode([AirNowObservation].self, from: data)
    }

    // MARK: - Open-Meteo CAMS modeled estimate (contrast / non-US fallback)

    private func fetchModelUSAQI(for city: City) async throws -> Int {
        let base = Secrets.openMeteoAPIKey != nil
            ? "https://customer-air-quality-api.open-meteo.com/v1/air-quality"
            : "https://air-quality-api.open-meteo.com/v1/air-quality"
        var components = URLComponents(string: base)!
        var items = [
            URLQueryItem(name: "latitude", value: String(city.latitude)),
            URLQueryItem(name: "longitude", value: String(city.longitude)),
            URLQueryItem(name: "current", value: "us_aqi"),
            URLQueryItem(name: "timezone", value: "auto")
        ]
        if let key = Secrets.openMeteoAPIKey, !key.isEmpty {
            items.append(URLQueryItem(name: "apikey", value: key))
        }
        components.queryItems = items

        var request = URLRequest(url: components.url!)
        request.setValue("FastWeather/1.5 (weatherfast.online)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AirQualityError.networkError
        }
        let decoded = try JSONDecoder().decode(OpenMeteoAQIResponse.self, from: data)
        guard let aqi = decoded.current.usAqi else { throw AirQualityError.noData }
        return Int(aqi.rounded())
    }

    // MARK: - Pollutant display names

    private func prettyPollutant(_ raw: String) -> String {
        switch raw.uppercased() {
        case "PM2.5": return "Fine particles (PM2.5)"
        case "PM10":  return "Coarse particles (PM10)"
        case "O3":    return "Ozone"
        case "NO2":   return "Nitrogen dioxide"
        case "SO2":   return "Sulfur dioxide"
        case "CO":    return "Carbon monoxide"
        default:      return raw
        }
    }
}

// MARK: - Errors

enum AirQualityError: LocalizedError {
    case networkError
    case noData

    var errorDescription: String? {
        switch self {
        case .networkError: return "Unable to reach the air quality service"
        case .noData:       return "No air quality data available for this location"
        }
    }
}

// MARK: - API response models

/// One AirNow observation row (PascalCase JSON keys).
struct AirNowObservation: Decodable {
    let reportingArea: String
    let stateCode: String
    let parameterName: String
    let aqi: Int
    let categoryName: String

    enum CodingKeys: String, CodingKey {
        case reportingArea = "ReportingArea"
        case stateCode = "StateCode"
        case parameterName = "ParameterName"
        case aqi = "AQI"
        case category = "Category"
    }
    enum CategoryKeys: String, CodingKey {
        case name = "Name"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        reportingArea = (try? c.decode(String.self, forKey: .reportingArea)) ?? "Air quality"
        stateCode = (try? c.decode(String.self, forKey: .stateCode)) ?? ""
        parameterName = try c.decode(String.self, forKey: .parameterName)
        aqi = try c.decode(Int.self, forKey: .aqi)
        let cat = try c.nestedContainer(keyedBy: CategoryKeys.self, forKey: .category)
        categoryName = (try? cat.decode(String.self, forKey: .name)) ?? ""
    }
}

struct OpenMeteoAQIResponse: Decodable {
    struct Current: Decodable {
        let usAqi: Double?
        enum CodingKeys: String, CodingKey { case usAqi = "us_aqi" }
    }
    let current: Current
}
