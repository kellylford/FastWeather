//
//  RadarService.swift
//  Fast Weather
//
//  Service for fetching and processing precipitation nowcast data.
//  Uses WeatherKit minute-by-minute (radar-quality) data where available,
//  falling back to Open-Meteo NWP forecasts for unsupported regions.
//

import Foundation
import CoreLocation
#if canImport(WeatherKit)
import WeatherKit
#endif

class RadarService {
    static let shared = RadarService()
    
    private init() {}
    
    // MARK: - Fetch Precipitation Nowcast

    /// Countries where WeatherKit minute-by-minute forecast is available.
    /// Apple provides radar-quality 1-minute data in these regions.
    private let weatherKitMinuteForecastCountries: Set<String> = [
        "United States", "Canada", "United Kingdom",
        "Ireland", "Australia", "New Zealand"
    ]

    // Coordinate-keyed nowcast cache. The inline Next Hour card fetches on every
    // city-detail open, so without this each open is a billed WeatherKit request.
    // Short TTL keeps the relative phrasing ("in about 11 minutes") honest while
    // deduplicating rapid re-opens; it also keeps the inline card and the full
    // Next Hour screen showing the same data.
    private let nowcastCache = TTLCache<String, RadarData>(ttl: 3 * 60)

    /// Fetches precipitation nowcast, preferring WeatherKit (radar-quality, 1-minute) where
    /// available and falling back to Open-Meteo NWP for unsupported regions.
    func fetchPrecipitationNowcast(for city: City) async throws -> RadarData {
        let cacheKey = String(format: "%.3f,%.3f", city.latitude, city.longitude)
        if let cached = nowcastCache.value(for: cacheKey) {
            return cached
        }
        let result = try await fetchPrecipitationNowcastUncached(for: city)
        nowcastCache.set(result, for: cacheKey)
        return result
    }

    private func fetchPrecipitationNowcastUncached(for city: City) async throws -> RadarData {
        #if canImport(WeatherKit)
        if #available(iOS 16.0, *), FeatureFlags.shared.weatherKitNowcastEnabled {
            let country = city.country
            if weatherKitMinuteForecastCountries.contains(country) {
                debugLog("🌧 Using WeatherKit path for \(city.name) (\(country))")
                do {
                    return try await fetchWeatherKitNowcast(for: city)
                } catch {
                    debugLog("⚠️ WeatherKit nowcast failed for \(city.name): \(error.localizedDescription). Falling back to Open-Meteo.")
                }
            } else {
                debugLog("🌧 Using Open-Meteo path for \(city.name) (country '\(country)' not in WK coverage set)")
            }
        }
        #endif
        return try await fetchOpenMeteoNowcast(for: city)
    }

    // MARK: - WeatherKit Nowcast (radar-quality, 1-minute resolution)

    #if canImport(WeatherKit)
    @available(iOS 16.0, *)
    private func fetchWeatherKitNowcast(for city: City) async throws -> RadarData {
        let location = CLLocation(latitude: city.latitude, longitude: city.longitude)
        let (current, minuteByMinuteOptional) = try await WeatherKit.WeatherService.shared
            .weather(for: location, including: .current, .minute)

        // Use WeatherKit's condition enum as the SOLE authority for whether it is
        // currently precipitating. Intensity alone misses drizzle and can have
        // near-zero floating-point noise during clear conditions.
        let currentIsPrecip = isWKConditionPrecipitating(current.condition)
        // This card is purely about precipitation. Only show the sky condition name
        // when it IS precipitating (e.g. "Drizzle", "Rain"). When dry, say
        // "No precipitation" — not a sky condition like "Cloudy" or "Clear", which
        // would be confused with the timeline's "None" labels.
        let currentConditionLabel = currentIsPrecip ? current.condition.description : "No precipitation"
        let currentStatus = currentIsPrecip
            ? "\(currentConditionLabel) at your location"
            : "No precipitation at your location"
        let currentMmPerHr = precipMmPerHour(current.precipitationIntensity)

        debugLog("🌧 WK nowcast for \(city.name): condition=\(current.condition), " +
              "intensity=\(String(format: "%.4f", currentMmPerHr)) mm/hr, " +
              "minuteForecast=\(minuteByMinuteOptional != nil ? "available" : "nil")")

        guard let minuteByMinute = minuteByMinuteOptional else {
            // .minute is nil for this location (can happen even in supported countries).
            // Do NOT fall back to Open-Meteo — that would throw away the radar-quality
            // current condition above and replace it with an NWP "Clear". Instead, return
            // a minimal response with correct current conditions and no detailed timeline.
            debugLog("⚠️ WK .minute unavailable for \(city.name); using current conditions only")
            let directions = ["North", "Northeast", "East", "Southeast", "South",
                              "Southwest", "West", "Northwest"]
            let generalStatus = currentIsPrecip ? "Precipitation at location" : "None"
            return RadarData(
                currentStatus: currentStatus,
                nearestPrecipitation: nil,
                directionalSectors: directions.map { DirectionalSector(direction: $0, status: generalStatus) },
                timeline: [TimelinePoint(time: "Now", condition: currentConditionLabel,
                                         precipitationMmPerHr: currentMmPerHr)],
                chartData: nil,
                dataSource: .weatherKit
            )
        }

        let allMinutes = minuteByMinute.forecast

        // Refine current-precipitation determination using minute[0] radar data.
        // WeatherKit's summary condition can lag or miss very light precipitation
        // (e.g. condition = .overcast while light snow is actively falling). The
        // minute-by-minute forecast is radar-based and more precise for "right now."
        // If minute[0] explicitly reports a precipitation type, that takes precedence.
        let firstMinutePrecip = allMinutes.first?.precipitation ?? .none
        let isFirstMinutePrecip = firstMinutePrecip != .none
        let effectiveIsPrecip: Bool
        let effectiveConditionLabel: String
        let effectiveStatus: String
        if !currentIsPrecip && isFirstMinutePrecip, let firstMinute = allMinutes.first {
            let mm = precipMmPerHour(firstMinute.precipitationIntensity)
            effectiveConditionLabel = describePrecipitation(firstMinutePrecip, mm: mm)
            effectiveStatus = "\(effectiveConditionLabel) at your location"
            effectiveIsPrecip = true
            debugLog("🌧 WK minute[0] overrides condition for \(city.name): " +
                     "\(current.condition) → \(effectiveConditionLabel)")
        } else {
            effectiveIsPrecip = currentIsPrecip
            effectiveConditionLabel = currentConditionLabel
            effectiveStatus = currentStatus
        }

        // Text timeline at representative intervals.
        // "Now" uses the refined current observation; future minutes use their explicit
        // precipitation type as the sole authority for whether precipitation is occurring.
        let textIntervals = [0, 5, 10, 15, 20, 30, 45, 60]
        let timeline: [TimelinePoint] = textIntervals.compactMap { interval in
            guard interval < allMinutes.count else { return nil }
            if interval == 0 {
                return TimelinePoint(time: "Now", condition: effectiveConditionLabel,
                                     precipitationMmPerHr: currentMmPerHr)
            }
            let minute = allMinutes[interval]
            let mm = precipMmPerHour(minute.precipitationIntensity)
            // precipitation != .none is the explicit type-based signal; intensity is
            // only used when the type is already known to be non-none (for labeling).
            let isPrecip = minute.precipitation != .none
            let condition = isPrecip ? describePrecipitation(minute.precipitation, mm: mm) : "None"
            return TimelinePoint(time: "\(interval) min", condition: condition,
                                 precipitationMmPerHr: mm)
        }

        // Full 1-minute chart data
        let chartData: [ChartPoint] = allMinutes.enumerated().map { (i, minute) in
            let mm = precipMmPerHour(minute.precipitationIntensity)
            let isPrecip = minute.precipitation != .none
            return ChartPoint(
                minute: i,
                precipitationMmPerHr: mm,
                condition: isPrecip ? describePrecipitation(minute.precipitation, mm: mm) : "None"
            )
        }

        // Nearest future precipitation
        let windSpeedMph = max(5.0, current.wind.speed.converted(to: UnitSpeed.milesPerHour).value)
        let windDegrees = compassDirectionDegrees(current.wind.compassDirection)
        let nearest: NearestPrecipitation? = {
            // If already precipitating, nearestPrecipitation = nil (it's here now)
            guard !effectiveIsPrecip else { return nil }
            for (i, minute) in allMinutes.enumerated() where i > 0 {
                guard minute.precipitation != .none else { continue }
                let mm = precipMmPerHour(minute.precipitationIntensity)
                let distanceMiles = Int(Double(i) * windSpeedMph / 60.0)
                let arrival = i == 1 ? "1 minute" : "\(i) minutes"
                let desc = describePrecipitation(minute.precipitation, mm: mm)
                return NearestPrecipitation(
                    distanceMiles: distanceMiles,
                    direction: getOppositeDirection(windDegrees),
                    type: desc,
                    intensity: desc,
                    movementDirection: getCardinalDirection(windDegrees),
                    speedMph: Int(windSpeedMph),
                    arrivalEstimate: arrival
                )
            }
            return nil
        }()

        let hasFuturePrecip = allMinutes.dropFirst().contains { $0.precipitation != .none }
        let generalStatus: String = {
            if effectiveIsPrecip { return "Precipitation at location" }
            return hasFuturePrecip ? "Precipitation approaching" : "None"
        }()
        let directions = ["North", "Northeast", "East", "Southeast", "South",
                          "Southwest", "West", "Northwest"]
        let directionalSectors = directions.map { DirectionalSector(direction: $0, status: generalStatus) }
        let timelineResult = timeline.isEmpty
            ? [TimelinePoint(time: "Now", condition: effectiveConditionLabel,
                             precipitationMmPerHr: currentMmPerHr)]
            : timeline

        // Gap 2: concise relative-phrased nowcast from the per-minute data.
        let summarySamples: [(minutes: Int, mmPerHr: Double, active: Bool)] =
            allMinutes.prefix(61).enumerated().map { (i, minute) in
                let mm = precipMmPerHour(minute.precipitationIntensity)
                let active = i == 0 ? effectiveIsPrecip : (minute.precipitation != .none)
                return (minutes: i, mmPerHr: mm, active: active)
            }
        let nextHourSummary = buildNextHourSummary(samples: summarySamples, windowMinutes: 60)

        return RadarData(
            currentStatus: effectiveStatus,
            nearestPrecipitation: nearest,
            directionalSectors: directionalSectors,
            timeline: timelineResult,
            chartData: chartData.isEmpty ? nil : chartData,
            dataSource: .weatherKit,
            nextHourSummary: nextHourSummary
        )
    }

    /// Returns true for WeatherKit conditions that indicate active precipitation.
    /// Covers all precipitating cases from the complete WeatherCondition enum.
    @available(iOS 16.0, *)
    private func isWKConditionPrecipitating(_ condition: WeatherCondition) -> Bool {
        switch condition {
        case .drizzle, .rain, .heavyRain, .freezingDrizzle, .freezingRain,
             .snow, .heavySnow, .flurries, .sunFlurries, .blowingSnow, .blizzard,
             .sleet, .wintryMix, .hail, .sunShowers,
             .thunderstorms, .scatteredThunderstorms, .isolatedThunderstorms, .strongStorms,
             .tropicalStorm, .hurricane:
            return true
        default:
            return false
        }
    }

    /// Returns a display string for a per-minute precipitation entry, using
    /// the explicit Precipitation type for labeling.
    @available(iOS 16.0, *)
    private func describePrecipitation(_ precipitation: Precipitation, mm: Double) -> String {
        let intensity = formatPrecipitationIntensity(mm)
        switch precipitation {
        case .rain:
            return intensity == "None" ? "Rain" : intensity.replacingOccurrences(of: "precipitation", with: "rain")
        case .snow:
            return intensity == "None" ? "Snow" : intensity.replacingOccurrences(of: "precipitation", with: "snow")
        case .sleet:  return "Sleet"
        case .hail:   return "Hail"
        case .mixed:  return "Wintry mix"
        case .none:   return "None"
        @unknown default: return "Precipitation"
        }
    }

    /// Converts a WeatherKit UnitSpeed precipitation intensity measurement to mm/hr.
    /// Foundation's UnitSpeed base unit is m/s; 1 m/s = 3,600,000 mm/hr.
    private func precipMmPerHour(_ measurement: Measurement<UnitSpeed>) -> Double {
        return measurement.converted(to: UnitSpeed.metersPerSecond).value * 3_600_000.0
    }

    /// Converts a WeatherKit Wind.CompassDirection to an approximate bearing in degrees.
    private func compassDirectionDegrees(_ dir: Wind.CompassDirection) -> Int {
        switch dir {
        case .north:          return 0
        case .northNortheast: return 22
        case .northeast:      return 45
        case .eastNortheast:  return 67
        case .east:           return 90
        case .eastSoutheast:  return 112
        case .southeast:      return 135
        case .southSoutheast: return 157
        case .south:          return 180
        case .southSouthwest: return 202
        case .southwest:      return 225
        case .westSouthwest:  return 247
        case .west:           return 270
        case .westNorthwest:  return 292
        case .northwest:      return 315
        case .northNorthwest: return 337
        @unknown default:     return 0
        }
    }
    #endif

    // MARK: - Open-Meteo NWP Nowcast (fallback)

    /// Fetches 15-minute NWP precipitation forecast from Open-Meteo.
    /// Used when WeatherKit is unavailable or for cities outside WK coverage.
    private func fetchOpenMeteoNowcast(for city: City) async throws -> RadarData {
        // Use the customer endpoint when a paid API key is configured,
        // identical to the pattern used in WeatherService.apiRequest(for:).
        let baseURL = Secrets.openMeteoAPIKey != nil
            ? "https://customer-api.open-meteo.com/v1/forecast"
            : "https://api.open-meteo.com/v1/forecast"

        var components = URLComponents(string: baseURL)!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "latitude", value: String(city.latitude)),
            URLQueryItem(name: "longitude", value: String(city.longitude)),
            URLQueryItem(name: "minutely_15", value: "precipitation"),
            URLQueryItem(name: "hourly", value: "precipitation,weather_code,wind_direction_10m,wind_speed_10m"),
            URLQueryItem(name: "current", value: "precipitation,weather_code,wind_direction_10m"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "forecast_days", value: "1")
        ]
        if let key = Secrets.openMeteoAPIKey, !key.isEmpty {
            queryItems.append(URLQueryItem(name: "apikey", value: key))
        }
        components.queryItems = queryItems

        var radarRequest = URLRequest(url: components.url!)
        radarRequest.setValue("FastWeather/1.5 (weatherfast.online)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: radarRequest)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw RadarError.networkError
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let forecast = try decoder.decode(PrecipitationForecast.self, from: data)
        
        // Process the data into RadarData format
        return processRadarData(forecast, city: city)
    }
    
    // MARK: - Process Radar Data
    
    private func processRadarData(_ forecast: PrecipitationForecast, city: City) -> RadarData {
        // Current status
        let currentStatus = determineCurrentStatus(forecast.current)
        
        // Analyze minutely data for timeline
        let timeline = createTimeline(from: forecast.minutely15)
        
        // For directional sectors, we'd need multiple API calls at different locations
        // For now, use simplified approach based on movement analysis
        let directionalSectors = createDirectionalSectors(from: forecast.minutely15, forecast.hourly)
        
        // Determine nearest precipitation
        let nearestPrecip = findNearestPrecipitation(from: forecast.minutely15, forecast.hourly)

        // Gap 2: concise relative-phrased nowcast from the 15-minute data.
        let nextHourSummary = buildNextHourSummaryFromMinutely15(forecast.minutely15)

        return RadarData(
            currentStatus: currentStatus,
            nearestPrecipitation: nearestPrecip,
            directionalSectors: directionalSectors,
            timeline: timeline,
            nextHourSummary: nextHourSummary
        )
    }

    /// Builds the Next Hour summary from Open-Meteo 15-minute data, starting at
    /// the current step and looking 2 hours ahead.
    private func buildNextHourSummaryFromMinutely15(_ minutely: Minutely15Data?) -> String? {
        guard let minutely = minutely,
              let times = minutely.time,
              let precipitation = minutely.precipitation else { return nil }

        let now = Date()
        var currentIndex = 0
        for (index, timeString) in times.enumerated() {
            if let timeDate = DateParser.parse(timeString), timeDate > now {
                currentIndex = max(0, index - 1)   // step containing "now"
                break
            }
        }

        var samples: [(minutes: Int, mmPerHr: Double, active: Bool)] = []
        for step in 0...8 {   // 0 … 120 minutes
            let index = currentIndex + step
            guard index < precipitation.count else { break }
            let mm15 = precipitation[index] ?? 0
            samples.append((minutes: step * 15, mmPerHr: mm15 * 4, active: mm15 >= 0.1))
        }
        return buildNextHourSummary(samples: samples, windowMinutes: 120)
    }
    
    // MARK: - Helper Methods
    
    private func determineCurrentStatus(_ current: CurrentConditions) -> String {
        if let precip = current.precipitation, precip > 0 {
            let weatherDesc = current.weatherCode.map { WeatherCode(rawValue: $0)?.description ?? "Precipitation" } ?? "Precipitation"
            return "\(weatherDesc) at your location"
        }
        return "No precipitation at your location"
    }
    
    private func createTimeline(from minutely: Minutely15Data?) -> [TimelinePoint] {
        guard let minutely = minutely,
              let times = minutely.time,
              let precipitation = minutely.precipitation else {
            return [TimelinePoint(time: "Now", condition: "No data available")]
        }
        
        // Find the current time index to start from NOW, not from midnight
        let now = Date()
        
        var currentIndex = 0
        for (index, timeString) in times.enumerated() {
            if let timeDate = DateParser.parse(timeString), timeDate > now {
                currentIndex = index
                break
            }
        }
        
        var timeline: [TimelinePoint] = []
        let intervals = [0, 15, 30, 45, 60, 90, 120] // Minutes from now
        
        for interval in intervals {
            let index = currentIndex + (interval / 15)
            
            guard index >= 0 && index < times.count else { continue }
            
            let timeLabel = interval == 0 ? "Now" : "\(interval) min"
            let precipValue = precipitation[index] ?? 0.0
            
            let condition = precipValue > 0 ? formatPrecipitationIntensity(precipValue) : "None"
            timeline.append(TimelinePoint(time: timeLabel, condition: condition, precipitationMmPerHr: precipValue))
        }
        
        return timeline
    }
    
    private func createDirectionalSectors(from minutely: Minutely15Data?, _ hourly: HourlyData?) -> [DirectionalSector] {
        // Since we only have data for the current location, we'll provide a general status
        // based on precipitation patterns in the timeline
        
        let directions = ["North", "Northeast", "East", "Southeast", "South", "Southwest", "West", "Northwest"]
        
        guard let minutely = minutely,
              let precipitation = minutely.precipitation else {
            return directions.map { DirectionalSector(direction: $0, status: "No data") }
        }
        
        // Analyze if precipitation is approaching
        let hasPrecipitation = precipitation.contains { ($0 ?? 0.0) > 0.01 }
        let currentPrecip = (precipitation.first ?? 0.0) ?? 0.0
        
        // Determine general status
        let generalStatus: String
        if currentPrecip > 0.01 {
            generalStatus = "Precipitation at location"
        } else if hasPrecipitation {
            // Find when it arrives
            if let firstPrecipIndex = precipitation.firstIndex(where: { ($0 ?? 0.0) > 0.01 }) {
                let minutesAway = firstPrecipIndex * 15
                if minutesAway <= 30 {
                    generalStatus = "Precipitation approaching"
                } else {
                    generalStatus = "No precipitation, some expected later"
                }
            } else {
                generalStatus = "No precipitation"
            }
        } else {
            generalStatus = "No precipitation"
        }
        
        // Return same status for all directions since we only have single-point data
        return directions.map { DirectionalSector(direction: $0, status: generalStatus) }
    }
    
    private func findNearestPrecipitation(from minutely: Minutely15Data?, _ hourly: HourlyData?) -> NearestPrecipitation? {
        guard let minutely = minutely,
              let times = minutely.time,
              let precipitation = minutely.precipitation else {
            return nil
        }
        
        // Find the current time index to only look at FUTURE precipitation
        let now = Date()
        
        var currentIndex = 0
        for (index, timeString) in times.enumerated() {
            if let timeDate = DateParser.parse(timeString), timeDate > now {
                currentIndex = index
                break
            }
        }
        
        debugLog("🔍 findNearestPrecipitation: now=\(now), currentIndex=\(currentIndex), totalTimes=\(times.count)")
        if currentIndex < times.count {
            debugLog("🔍 Starting search from time: \(times[currentIndex])")
        }
        
        // Search for precipitation starting from current time forward
        for index in currentIndex..<precipitation.count {
            if let precip = precipitation[index], precip > 0.01 {
                let minutesAway = (index - currentIndex) * 15
                
                debugLog("🔍 Found precipitation at index \(index): \(precip)mm, minutesAway=\(minutesAway)")
                
                if minutesAway == 0 {
                    return nil // Already precipitating
                }
                
                let intensity = formatPrecipitationIntensity(precip)
                let arrival = minutesAway < 60 
                    ? "\(minutesAway) minutes"
                    : "Approximately \(minutesAway / 60) hour\(minutesAway / 60 == 1 ? "" : "s")"
                
                // Get current wind direction to determine where precipitation is coming from
                let currentHourIndex = min(index / 4, (hourly?.windDirection10m?.count ?? 1) - 1)
                let windDir = (hourly?.windDirection10m?[currentHourIndex] ?? nil) ?? 0
                let fromDirection = getOppositeDirection(windDir)

                // Use actual wind speed for distance estimate (km/h → mph conversion).
                // Falls back to 15 mph if wind speed data is unavailable.
                let windSpeedKmh = (hourly?.windSpeed10m?[currentHourIndex] ?? nil) ?? 0
                let windSpeedMph = windSpeedKmh > 0 ? max(5, windSpeedKmh * 0.621371) : 15

                let distanceMiles = Int(Double(minutesAway) * windSpeedMph / 60.0)
                let speedMph = Int(windSpeedMph)
                
                debugLog("🔍 Calculated: distance=\(distanceMiles) miles, direction=\(fromDirection), speed=\(speedMph) mph")
                
                return NearestPrecipitation(
                    distanceMiles: distanceMiles,
                    direction: fromDirection,
                    type: intensity,
                    intensity: intensity,
                    movementDirection: getCardinalDirection(windDir),
                    speedMph: speedMph,
                    arrivalEstimate: arrival
                )
            }
        }
        
        debugLog("🔍 No precipitation found in forecast")
        return nil
    }
    
    // MARK: - Next Hour Narration (Gap 2)

    /// Builds a concise, relative-phrased nowcast sentence from a precipitation
    /// series. Each sample is (minutesFromNow, mm/hr rate, isActive). Resolution
    /// can be per-minute (WeatherKit) or 15-minute (Open-Meteo). Returns nil when
    /// there isn't enough data to say anything useful.
    /// Internal (not private) so the unit tests can exercise the phrasing directly.
    func buildNextHourSummary(
        samples: [(minutes: Int, mmPerHr: Double, active: Bool)],
        windowMinutes: Int
    ) -> String? {
        guard samples.count > 1 else { return nil }
        let windowLabel = windowMinutes <= 60 ? "hour" : "\(windowMinutes / 60) hours"

        func minutesPhrase(_ m: Int) -> String {
            if m <= 0 { return "now" }
            if m < 60 { return "about \(m) minutes" }
            let h = m / 60, mm = m % 60
            let hStr = "\(h) hour\(h == 1 ? "" : "s")"
            return mm == 0 ? "about \(hStr)" : "about \(hStr) \(mm) minutes"
        }

        let nowActive = samples.first?.active ?? false

        if nowActive {
            if let end = samples.first(where: { $0.minutes > 0 && !$0.active }) {
                return "Precipitation now, easing off in \(minutesPhrase(end.minutes))."
            }
            return "Precipitation now, continuing through the next \(windowLabel)."
        }

        guard let onset = samples.first(where: { $0.active }) else {
            return "No precipitation expected in the next \(windowLabel)."
        }
        let onsetMin = onset.minutes
        let afterOnset = samples.filter { $0.minutes >= onsetMin }
        let endMin = afterOnset.first(where: { !$0.active })?.minutes
        let activeStretch = afterOnset.prefix(while: { $0.active })
        let peak = activeStretch.max(by: { $0.mmPerHr < $1.mmPerHr })
        let peakIntensity = peak.map { PrecipIntensity(mmPerHour: $0.mmPerHr) } ?? .none

        var s = "Precipitation starting in \(minutesPhrase(onsetMin))"
        if let endMin = endMin {
            s += ", lasting about \(endMin - onsetMin) minutes"
        } else {
            s += ", continuing through the next \(windowLabel)"
        }
        s += "."
        if peakIntensity >= .moderate, let peak = peak, peak.minutes != onsetMin {
            s += " Heaviest \(minutesPhrase(peak.minutes)) from now."
        }
        return s
    }

    private func formatPrecipitationIntensity(_ mm: Double) -> String {
        switch mm {
        case 0..<0.1:
            return "None"
        case 0.1..<2.5:
            return "Light precipitation"
        case 2.5..<10:
            return "Moderate precipitation"
        case 10..<50:
            return "Heavy precipitation"
        default:
            return "Very heavy precipitation"
        }
    }
    
    private func getCardinalDirection(_ degrees: Int) -> String {
        let directions = ["North", "Northeast", "East", "Southeast", "South", "Southwest", "West", "Northwest"]
        let index = Int((Double(degrees) / 45.0).rounded()) % 8
        return directions[index]
    }
    
    private func getOppositeDirection(_ degrees: Int) -> String {
        // Precipitation comes FROM the opposite of wind direction
        let opposite = (degrees + 180) % 360
        return getCardinalDirection(opposite).lowercased()
    }
}

// MARK: - Radar Error

enum RadarError: LocalizedError {
    case networkError
    case invalidData
    case noData
    
    var errorDescription: String? {
        switch self {
        case .networkError:
            return "Unable to connect to weather service"
        case .invalidData:
            return "Received invalid data from weather service"
        case .noData:
            return "No precipitation data available"
        }
    }
}

// MARK: - API Response Models

struct PrecipitationForecast: Codable {
    let latitude: Double
    let longitude: Double
    let timezone: String
    let current: CurrentConditions
    let minutely15: Minutely15Data?
    let hourly: HourlyData?
}

struct CurrentConditions: Codable {
    let time: String
    let precipitation: Double?
    let weatherCode: Int?
    let windDirection10m: Int?
}

struct Minutely15Data: Codable {
    let time: [String]?
    let precipitation: [Double?]?
}

struct HourlyData: Codable {
    let time: [String]?
    let precipitation: [Double?]?
    let weatherCode: [Int?]?
    let windDirection10m: [Int?]?
    let windSpeed10m: [Double?]?
}

// MARK: - Shared Radar Data Models

struct RadarData {
    let currentStatus: String
    let nearestPrecipitation: NearestPrecipitation?
    let directionalSectors: [DirectionalSector]
    let timeline: [TimelinePoint]
    /// Full per-minute chart data from WeatherKit (60 entries). Nil for Open-Meteo.
    var chartData: [ChartPoint]? = nil
    var dataSource: RadarDataSource = .openMeteo
    /// One-sentence relative-phrased nowcast ("Rain starting in about 11 minutes,
    /// lasting about 35 minutes"). Nil when no detailed minute data is available.
    var nextHourSummary: String? = nil
}

struct NearestPrecipitation {
    let distanceMiles: Int
    let direction: String
    let type: String
    let intensity: String
    let movementDirection: String
    let speedMph: Int
    let arrivalEstimate: String?
}

struct DirectionalSector: Equatable {
    let direction: String
    let status: String
}

struct TimelinePoint: Equatable {
    let time: String
    let condition: String
    var precipitationMmPerHr: Double = 0
}

/// Per-minute data point for the precipitation chart.
struct ChartPoint: Equatable {
    let minute: Int
    let precipitationMmPerHr: Double
    let condition: String
}

enum RadarDataSource {
    case openMeteo
    case weatherKit
}
