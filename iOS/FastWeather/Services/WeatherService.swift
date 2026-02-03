//
//  WeatherService.swift
//  Fast Weather
//
//  Service for fetching weather data from Open-Meteo API
//

import Foundation
import Combine
import CoreLocation
#if canImport(WeatherKit)
import WeatherKit
#endif

class WeatherService: ObservableObject {
    @Published var savedCities: [City] = []
    @Published var weatherCache: [UUID: WeatherData] = [:]
    @Published var browseWeatherCache: [String: WeatherData] = [:] // Cache for browse cities
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let baseURL = "https://api.open-meteo.com/v1/forecast"
    private let historicalURL = "https://archive-api.open-meteo.com/v1/archive"
    private let userDefaultsKey = "SavedCities"
    
    // Performance settings (matching Windows version)
    private let weatherCacheMinutes: TimeInterval = 10 * 60 // 10 minutes in seconds
    private let maxConcurrentRequests = 5 // Limit parallel API calls
    
    // Cache timestamp tracking
    private var cacheTimestamps: [UUID: Date] = [:]
    private var browseCacheTimestamps: [String: Date] = [:]
    
    init() {
        loadSavedCities()
    }
    
    // MARK: - City Management
    
    func addCity(_ city: City) {
        if !savedCities.contains(where: { $0.id == city.id }) {
            savedCities.append(city)
            saveCities()
            Task {
                await fetchWeather(for: city)
            }
        }
    }
    
    func removeCity(_ city: City) {
        savedCities.removeAll { $0.id == city.id }
        weatherCache.removeValue(forKey: city.id)
        cacheTimestamps.removeValue(forKey: city.id)
        saveCities()
    }
    
    func moveCity(from source: IndexSet, to destination: Int) {
        savedCities.move(fromOffsets: source, toOffset: destination)
        saveCities()
    }
    
    // MARK: - Weather Fetching
    
    // Check if cached data is still valid
    private func isCacheValid(timestamp: Date?) -> Bool {
        guard let timestamp = timestamp else { return false }
        return Date().timeIntervalSince(timestamp) < weatherCacheMinutes
    }
    
    // Fetch full weather data (16 days) for detail views
    func fetchWeather(for city: City) async {
        // Check cache first
        if isCacheValid(timestamp: cacheTimestamps[city.id]) {
            print("✅ Using cached weather for \(city.name)")
            return
        }
        
        let params = [
            "latitude": String(city.latitude),
            "longitude": String(city.longitude),
            "current": "temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,rain,showers,snowfall,weather_code,cloud_cover,pressure_msl,wind_speed_10m,wind_direction_10m,visibility,wind_gusts_10m,uv_index,dewpoint_2m",
            "hourly": "temperature_2m,weather_code,precipitation,precipitation_probability,relative_humidity_2m,wind_speed_10m,windgusts_10m,uv_index,dewpoint_2m",
            "daily": "temperature_2m_max,temperature_2m_min,sunrise,sunset,weather_code,precipitation_sum,rain_sum,snowfall_sum,precipitation_probability_max,uv_index_max,daylight_duration,sunshine_duration,windspeed_10m_max,winddirection_10m_dominant",
            "forecast_days": "16",
            "timezone": "auto"
        ]
        
        var components = URLComponents(string: baseURL)!
        components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        
        guard let url = components.url else {
            await MainActor.run {
                self.errorMessage = "Invalid URL"
            }
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoder = JSONDecoder()
            let response = try decoder.decode(WeatherResponse.self, from: data)
            
            await MainActor.run {
                self.weatherCache[city.id] = WeatherData(current: response.current, daily: response.daily, hourly: response.hourly)
                self.cacheTimestamps[city.id] = Date()
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to fetch weather: \(error.localizedDescription)"
                print("Weather fetch error for \(city.name): \(error)")
            }
        }
    }
    
    // Fetch basic weather data (1 day, minimal fields) for list displays - OPTIMIZED
    func fetchWeatherBasic(latitude: Double, longitude: Double) async throws -> WeatherData {
        let cacheKey = "\(latitude),\(longitude)"
        
        // Check cache first
        if let cached = browseWeatherCache[cacheKey],
           isCacheValid(timestamp: browseCacheTimestamps[cacheKey]) {
            return cached
        }
        
        // Minimal params matching Windows "basic" mode
        let params = [
            "latitude": String(latitude),
            "longitude": String(longitude),
            "current": "temperature_2m,weather_code,cloud_cover,is_day,uv_index",
            "hourly": "cloudcover",
            "daily": "temperature_2m_max,temperature_2m_min",
            "forecast_days": "1",
            "timezone": "auto"
        ]
        
        var components = URLComponents(string: baseURL)!
        components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(WeatherResponse.self, from: data)
        let weatherData = WeatherData(current: response.current, daily: response.daily, hourly: response.hourly)
        
        // Cache the result
        await MainActor.run {
            browseWeatherCache[cacheKey] = weatherData
            browseCacheTimestamps[cacheKey] = Date()
        }
        
        return weatherData
    }
    
    // Fetch full weather data (16 days) for detail views
    func fetchWeatherFull(latitude: Double, longitude: Double) async throws -> WeatherData {
        let params = [
            "latitude": String(latitude),
            "longitude": String(longitude),
            "current": "temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,rain,showers,snowfall,weather_code,cloud_cover,pressure_msl,wind_speed_10m,wind_direction_10m,visibility,wind_gusts_10m,uv_index,dewpoint_2m",
            "hourly": "temperature_2m,weather_code,precipitation,precipitation_probability,relative_humidity_2m,wind_speed_10m,windgusts_10m,uv_index,dewpoint_2m",
            "daily": "temperature_2m_max,temperature_2m_min,sunrise,sunset,weather_code,precipitation_sum,rain_sum,snowfall_sum,precipitation_probability_max,uv_index_max,daylight_duration,sunshine_duration,windspeed_10m_max,winddirection_10m_dominant",
            "forecast_days": "16",
            "timezone": "auto"
        ]
        
        var components = URLComponents(string: baseURL)!
        components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(WeatherResponse.self, from: data)
        return WeatherData(current: response.current, daily: response.daily, hourly: response.hourly)
    }
    
    // Batch load weather for multiple locations (parallel with concurrency limit)
    func batchFetchWeatherBasic(for locations: [(latitude: Double, longitude: Double)]) async -> [String: WeatherData] {
        var results: [String: WeatherData] = [:]
        
        await withTaskGroup(of: (String, WeatherData?).self) { group in
            var activeTaskCount = 0
            var locationIndex = 0
            
            // Process locations with concurrency limit
            while locationIndex < locations.count || activeTaskCount > 0 {
                // Add tasks up to the limit
                while activeTaskCount < maxConcurrentRequests && locationIndex < locations.count {
                    let location = locations[locationIndex]
                    let key = "\(location.latitude),\(location.longitude)"
                    locationIndex += 1
                    activeTaskCount += 1
                    
                    group.addTask {
                        do {
                            let weather = try await self.fetchWeatherBasic(
                                latitude: location.latitude,
                                longitude: location.longitude
                            )
                            return (key, weather)
                        } catch {
                            print("❌ Batch fetch error for \(key): \(error)")
                            return (key, nil)
                        }
                    }
                }
                
                // Wait for one task to complete
                if let result = await group.next() {
                    if let weatherData = result.1 {
                        results[result.0] = weatherData
                    }
                    activeTaskCount -= 1
                }
            }
        }
        
        return results
    }
    
    func refreshAllWeather() async {
        await MainActor.run {
            isLoading = true
        }
        
        await withTaskGroup(of: Void.self) { group in
            for city in savedCities {
                group.addTask {
                    await self.fetchWeather(for: city)
                }
            }
        }
        
        await MainActor.run {
            isLoading = false
        }
    }
    
    // MARK: - Historical Weather
    
    // Fetch historical weather for a specific date range
    func fetchHistoricalWeather(for city: City, startDate: String, endDate: String) async throws -> HistoricalWeatherResponse {
        let params = [
            "latitude": String(city.latitude),
            "longitude": String(city.longitude),
            "start_date": startDate,
            "end_date": endDate,
            "daily": "weathercode,temperature_2m_max,temperature_2m_min,apparent_temperature_max,apparent_temperature_min,sunrise,sunset,precipitation_sum,rain_sum,snowfall_sum,precipitation_hours,windspeed_10m_max",
            "timezone": "auto"
        ]
        
        var components = URLComponents(string: historicalURL)!
        components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        
        print("📊 Fetching historical weather from \(startDate) to \(endDate) for \(city.name)")
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(HistoricalWeatherResponse.self, from: data)
        return response
    }
    
    // Fetch same day across multiple years (e.g., all January 19ths from 1940 to now)
    func fetchSameDayHistory(for city: City, monthDay: String, yearsBack: Int = 85, endYear: Int? = nil) async throws -> [HistoricalDay] {
        let calendar = Calendar.current
        let actualEndYear = endYear ?? calendar.component(.year, from: Date())
        let cacheKey = "\(monthDay)-\(actualEndYear)"
        
        // Check cache first - but only use it if it has enough years
        if let cached = HistoricalWeatherCache.shared.getCached(for: city, monthDay: cacheKey) {
            if cached.count >= yearsBack {
                print("✅ Using cached historical data for \(city.name) on \(monthDay) ending \(actualEndYear) (\(cached.count) years cached, \(yearsBack) requested)")
                // Return only the requested number of years (most recent ones)
                return Array(cached.prefix(yearsBack))
            } else {
                print("⚠️ Cache has only \(cached.count) years but \(yearsBack) requested - fetching fresh data")
            }
        }
        
        let startYear = actualEndYear - yearsBack
        
        // Parse month and day from monthDay string (format: "MM-DD")
        let components = monthDay.split(separator: "-")
        guard components.count == 2,
              let month = Int(components[0]),
              let day = Int(components[1]) else {
            throw URLError(.badURL)
        }
        
        // Build start and end dates (one year at a time to avoid API limits)
        var historicalDays: [HistoricalDay] = []
        
        // Fetch in chunks of 10 years to avoid overwhelming the API
        let chunkSize = 10
        for yearChunkStart in stride(from: startYear, to: actualEndYear, by: chunkSize) {
            let yearChunkEnd = min(yearChunkStart + chunkSize - 1, actualEndYear - 1)
            
            let startDate = String(format: "%04d-%02d-%02d", yearChunkStart, month, day)
            let endDate = String(format: "%04d-%02d-%02d", yearChunkEnd, month, day)
            
            do {
                let response = try await fetchHistoricalWeather(for: city, startDate: startDate, endDate: endDate)
                
                // Parse response into HistoricalDay objects, filtering for only the specific month-day
                for (index, dateString) in response.daily.time.enumerated() {
                    guard let dateString = dateString else { continue }
                    
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd"
                    
                    guard let date = dateFormatter.date(from: dateString) else { continue }
                    
                    // Filter: only include dates that match the target month and day
                    let dateMonth = calendar.component(.month, from: date)
                    let dateDay = calendar.component(.day, from: date)
                    
                    guard dateMonth == month && dateDay == day else { continue }
                    
                    let year = calendar.component(.year, from: date)
                    
                    // Skip this day if any required data is nil
                    guard let weatherCode = response.daily.weatherCode[index],
                          let tempMax = response.daily.temperature2mMax[index],
                          let tempMin = response.daily.temperature2mMin[index],
                          let apparentTempMax = response.daily.apparentTemperatureMax[index],
                          let apparentTempMin = response.daily.apparentTemperatureMin[index],
                          let sunrise = response.daily.sunrise[index],
                          let sunset = response.daily.sunset[index],
                          let precipitationSum = response.daily.precipitationSum[index],
                          let rainSum = response.daily.rainSum[index],
                          let snowfallSum = response.daily.snowfallSum[index],
                          let precipitationHours = response.daily.precipitationHours[index],
                          let windSpeedMax = response.daily.windSpeed10mMax[index] else {
                        continue
                    }
                    
                    let historicalDay = HistoricalDay(
                        date: date,
                        year: year,
                        weatherCode: weatherCode,
                        tempMax: tempMax,
                        tempMin: tempMin,
                        apparentTempMax: apparentTempMax,
                        apparentTempMin: apparentTempMin,
                        sunrise: sunrise,
                        sunset: sunset,
                        precipitationSum: precipitationSum,
                        rainSum: rainSum,
                        snowfallSum: snowfallSum,
                        precipitationHours: precipitationHours,
                        windSpeedMax: windSpeedMax
                    )
                    historicalDays.append(historicalDay)
                }
                
                // Small delay between chunks to be respectful to API
                try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            } catch {
                print("⚠️ Error fetching historical chunk \(startDate) to \(endDate): \(error)")
                // Continue with other chunks even if one fails
            }
        }
        
        // Sort by year descending (most recent first)
        historicalDays.sort { $0.year > $1.year }
        
        // Cache the results with endYear in key
        HistoricalWeatherCache.shared.cache(historicalDays, for: city, monthDay: cacheKey)
        
        print("✅ Fetched \(historicalDays.count) years of historical data for \(city.name) on \(monthDay) ending \(actualEndYear)")
        return historicalDays
    }
    
    // MARK: - Weather Alerts (NWS & WeatherKit)
    
    private var alertsCache: [UUID: (alerts: [WeatherAlert], timestamp: Date)] = [:]
    private let alertsCacheMinutes: TimeInterval = 5
    
    /// Countries where WeatherKit alerts are known to work
    /// Source: Apple WeatherKit documentation and real-world testing
    private let weatherKitSupportedCountries = Set([
        "United States",
        "Canada",
        "United Kingdom",
        "Germany",
        "France",
        "Spain",
        "Italy",
        "Netherlands",
        "Belgium",
        "Austria",
        "Switzerland",
        "Denmark",
        "Sweden",
        "Norway",
        "Finland",
        "Ireland",
        "Portugal",
        "Japan",
        "Australia",
        "New Zealand"
    ])
    
    /// Checks if WeatherKit alerts are likely supported for this country
    private func isWeatherKitSupported(for city: City) -> Bool {
        return weatherKitSupportedCountries.contains(city.country)
    }
    
    /// Fetches severe weather alerts using appropriate source based on location
    /// - US cities: National Weather Service (detailed alerts with full text)
    /// - International: Apple WeatherKit (when feature flag enabled AND country supported)
    /// - Returns: Array of active weather alerts (empty if no alerts or service unavailable)
    func fetchNWSAlerts(for city: City) async throws -> [WeatherAlert] {
        // Check cache first
        if let cached = alertsCache[city.id] {
            let age = Date().timeIntervalSince(cached.timestamp)
            if age < alertsCacheMinutes * 60 {
                print("📦 Using cached alerts for \(city.name) (age: \(Int(age))s)")
                return cached.alerts
            }
        }
        
        // US cities: Use NWS for detailed alerts
        if city.country == "United States" {
            return try await fetchNWSAlertsDirectly(for: city)
        }
        
        // International cities: Use WeatherKit if enabled AND country supported
        if FeatureFlags.shared.weatherKitAlertsEnabled {
            if isWeatherKitSupported(for: city) {
                print("🌍 Using WeatherKit for international city: \(city.name) (\(city.country))")
                return try await fetchWeatherKitAlerts(for: city)
            } else {
                print("🚫 WeatherKit not supported for \(city.country), skipping alert request for \(city.name)")
                return []
            }
        } else {
            print("ℹ️ WeatherKit disabled, no alerts for international city: \(city.name)")
            return []
        }
    }
    
    /// Fetches alerts directly from National Weather Service API (US only)
    private func fetchNWSAlertsDirectly(for city: City) async throws -> [WeatherAlert] {
        
        let urlString = "https://api.weather.gov/alerts/active?point=\(city.latitude),\(city.longitude)"
        guard let url = URL(string: urlString) else {
            print("⚠️ Invalid NWS alerts URL for \(city.name)")
            return []
        }
        
        var request = URLRequest(url: url)
        request.setValue("FastWeather/1.0 iOS", forHTTPHeaderField: "User-Agent")
        
        print("🚨 Fetching NWS alerts for \(city.name)...")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("⚠️ NWS alerts API returned non-200 status for \(city.name)")
                return []
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let nwsResponse = try decoder.decode(NWSAlertsResponse.self, from: data)
            
            // Convert NWS features to WeatherAlert objects
            let alerts = nwsResponse.features.compactMap { feature -> WeatherAlert? in
                let props = feature.properties
                
                // Parse severity
                let severity: AlertSeverity
                switch props.severity?.lowercased() {
                case "extreme": severity = .extreme
                case "severe": severity = .severe
                case "moderate": severity = .moderate
                case "minor": severity = .minor
                default: severity = .unknown
                }
                
                // Parse onset and expires dates (ISO8601 format from NWS)
                let dateFormatter = ISO8601DateFormatter()
                let onset = props.onset.flatMap { dateFormatter.date(from: $0) } ?? Date()
                let expires = props.expires.flatMap { dateFormatter.date(from: $0) } ?? Date().addingTimeInterval(86400)
                
                return WeatherAlert(
                    id: props.id,
                    event: props.event,
                    severity: severity,
                    headline: props.headline,
                    description: props.description,
                    instruction: props.instruction,
                    onset: onset,
                    expires: expires,
                    areaDesc: props.areaDesc,
                    source: .nws,
                    detailsURL: nil  // NWS alerts use weather.gov link in UI
                )
            }
            
            // Filter out expired alerts
            let activeAlerts = alerts.filter { !$0.isExpired }
            
            // Cache the results
            alertsCache[city.id] = (activeAlerts, Date())
            
            print("✅ Fetched \(activeAlerts.count) active alerts for \(city.name)")
            return activeAlerts
            
        } catch {
            print("⚠️ Error fetching NWS alerts for \(city.name): \(error)")
            return []
        }
    }
    
    /// Fetches weather alerts from Apple WeatherKit (international cities)
    private func fetchWeatherKitAlerts(for city: City) async throws -> [WeatherAlert] {
        #if canImport(WeatherKit)
        let location = CLLocation(latitude: city.latitude, longitude: city.longitude)
        let appleWeatherService = WeatherKit.WeatherService.shared
        
        do {
            let weatherAlerts = try await appleWeatherService.weather(
                for: location,
                including: .alerts
            )
            
            // Convert WeatherKit alerts to our WeatherAlert model
            let alerts = weatherAlerts?.compactMap { wkAlert -> WeatherAlert? in
                // Map WeatherKit severity to our AlertSeverity
                let severity: AlertSeverity
                switch wkAlert.severity {
                case .extreme: severity = .extreme
                case .severe: severity = .severe
                case .moderate: severity = .moderate
                case .minor: severity = .minor
                case .unknown: severity = .unknown
                @unknown default: severity = .unknown
                }
                
                // WeatherKit provides limited info - just summary and region
                // Build a user-friendly description
                let regionText = wkAlert.region ?? "your area"
                let description = "Government weather alert issued for \(regionText). Tap 'View Alert Details' below for complete information from local authorities."
                
                return WeatherAlert(
                    id: UUID().uuidString,
                    event: wkAlert.summary,
                    severity: severity,
                    headline: wkAlert.summary,
                    description: description,
                    instruction: nil, // WeatherKit doesn't provide safety instructions
                    onset: Date(), // WeatherKit doesn't expose onset directly
                    expires: Date().addingTimeInterval(86400), // Default to 24 hours
                    areaDesc: wkAlert.region,
                    source: .weatherKit,
                    detailsURL: wkAlert.detailsURL.absoluteString
                )
            } ?? []
            
            // Filter expired alerts
            let activeAlerts = alerts.filter { !$0.isExpired }
            
            // Cache results
            alertsCache[city.id] = (activeAlerts, Date())
            
            print("✅ Fetched \(activeAlerts.count) WeatherKit alerts for \(city.name)")
            return activeAlerts
            
        } catch {
            // Parse error to provide helpful messaging
            let nsError = error as NSError
            let errorDescription = nsError.localizedDescription
            
            // HTTP 400 errors typically mean the country/region doesn't support weather alerts
            if errorDescription.contains("400") || errorDescription.contains("responseFailed: 400") {
                print("⚠️ WeatherKit alerts not available for \(city.name)")
                print("   → WeatherKit doesn't support weather alerts in \(city.country)")
                print("   → Coverage is limited to select countries (US, Canada, parts of Europe, etc.)")
            }
            // JWT/Authentication errors
            else if nsError.domain.contains("WDSJWTAuthenticatorServiceListener") {
                print("⚠️ WeatherKit authentication failed for \(city.name)")
                print("   → WeatherKit may not be enabled for your App ID in Apple Developer Portal")
                print("   → Visit https://developer.apple.com/account/resources/identifiers/list")
                print("   → Edit your App ID and enable the WeatherKit capability under App Services")
            }
            // Other WeatherDaemon errors
            else if nsError.domain.contains("WeatherDaemon") {
                print("⚠️ WeatherKit service error for \(city.name): \(errorDescription)")
            }
            // Unknown errors
            else {
                print("⚠️ Error fetching WeatherKit alerts for \(city.name): \(error)")
            }
            
            // Cache empty result to avoid repeated failed requests
            alertsCache[city.id] = ([], Date())
            return []
        }
        #else
        print("⚠️ WeatherKit not available on this platform")
        return []
        #endif
    }
    
    // MARK: - Persistence
    
    private func saveCities() {
        if let encoded = try? JSONEncoder().encode(savedCities) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }
    
    private func loadSavedCities() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let cities = try? JSONDecoder().decode([City].self, from: data) {
            savedCities = cities
            
            // Fetch weather for all cities
            Task {
                await refreshAllWeather()
            }
        } else {
            // Default cities
            savedCities = [
                City(name: "Madison", state: "Wisconsin", country: "United States", latitude: 43.074761, longitude: -89.3837613),
                City(name: "San Diego", state: "California", country: "United States", latitude: 32.7174202, longitude: -117.162772)
            ]
            saveCities()
            Task {
                await refreshAllWeather()
            }
        }
    }
}
