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

// MARK: - WeatherCacheKey
/// Cache key for date-aware weather data
/// Allows caching weather for the same city on different days
struct WeatherCacheKey: Hashable {
    let cityId: UUID
    let dateOffset: Int  // 0 = today, +1 = tomorrow, -1 = yesterday
    
    init(cityId: UUID, dateOffset: Int = 0) {
        self.cityId = cityId
        self.dateOffset = dateOffset
    }
}

class WeatherService: ObservableObject {
    @Published var savedCities: [City] = []
    @Published var weatherCache: [WeatherCacheKey: WeatherData] = [:]
    @Published var marineCache: [WeatherCacheKey: MarineData] = [:]
    @Published var browseWeatherCache: [String: WeatherData] = [:] // Cache for browse cities
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // DISABLED: Persistent cache is too slow (8.9s to load from UserDefaults)
    // Only using in-memory cache for now
    // private let persistentCache = WeatherCache.shared
    
    private let baseURL = "https://api.open-meteo.com/v1/forecast"
    private let historicalURL = "https://archive-api.open-meteo.com/v1/archive"
    private let marineURL = "https://marine-api.open-meteo.com/v1/marine"
    private let userDefaultsKey = "SavedCities"
    
    // Performance settings (matching Windows version)
    private let weatherCacheMinutes: TimeInterval = 10 * 60 // 10 minutes in seconds
    private let maxConcurrentRequests = 5 // Limit parallel API calls
    
    // Cache timestamp tracking
    private var cacheTimestamps: [WeatherCacheKey: Date] = [:]
    private var marineCacheTimestamps: [WeatherCacheKey: Date] = [:]
    private var browseCacheTimestamps: [String: Date] = [:]
    
    init() {
        loadSavedCities()
        migrateCountryNamesIfNeeded()
    }
    
    // MARK: - My Data Dynamic Parameters
    
    /// Appends user-selected My Data API parameters to the base current params string.
    /// Reads directly from UserDefaults to avoid coupling to SettingsManager.
    static func appendMyDataParameters(to baseParams: String) -> String {
        guard let data = UserDefaults.standard.data(forKey: "AppSettings"),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return baseParams
        }
        
        let enabledParams = settings.myDataFields.filter { $0.isEnabled }
        guard !enabledParams.isEmpty else { return baseParams }
        
        let existingKeys = Set(baseParams.split(separator: ",").map { String($0) })
        let newKeys = enabledParams
            .map { $0.parameter.apiKey }
            .filter { !existingKeys.contains($0) }
        
        if newKeys.isEmpty { return baseParams }
        return baseParams + "," + newKeys.joined(separator: ",")
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
        // Remove all cached weather data for this city (all date offsets)
        weatherCache = weatherCache.filter { $0.key.cityId != city.id }
        cacheTimestamps = cacheTimestamps.filter { $0.key.cityId != city.id }
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
        // Default to today (dateOffset = 0) for backward compatibility
        await fetchWeatherForDate(for: city, dateOffset: 0)
    }
    
    // Fetch weather data for a specific date offset
    func fetchWeatherForDate(for city: City, dateOffset: Int) async {
        let cacheKey = WeatherCacheKey(cityId: city.id, dateOffset: dateOffset)
        
        // Check in-memory cache
        if isCacheValid(timestamp: cacheTimestamps[cacheKey]) {
            return
        }
        
        // Calculate the target date
        let calendar = Calendar.current
        guard let targetDate = calendar.date(byAdding: .day, value: dateOffset, to: Date()) else {
            await MainActor.run {
                self.errorMessage = "Invalid date calculation"
            }
            return
        }
        
        // For past dates, use archive API
        if dateOffset < 0 {
            await fetchHistoricalWeatherForCity(city: city, targetDate: targetDate, cacheKey: cacheKey)
            return
        }
        
        // For today and future dates, use forecast API
        // Build current parameters including any My Data selections
        let baseCurrentParams = "temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,rain,showers,snowfall,weather_code,cloud_cover,pressure_msl,wind_speed_10m,wind_direction_10m,visibility,wind_gusts_10m,uv_index,dewpoint_2m"
        let currentParams = Self.appendMyDataParameters(to: baseCurrentParams)
        
        let params = [
            "latitude": String(city.latitude),
            "longitude": String(city.longitude),
            "current": currentParams,
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
            
            // For dateOffset = 0 (today), use the current weather directly
            // For dateOffset > 0 (future), extract that day's data from daily/hourly arrays
            let weatherData: WeatherData
            if dateOffset == 0 {
                weatherData = WeatherData(current: response.current, daily: response.daily, hourly: response.hourly)
            } else {
                // Extract the specific day's data from the arrays
                guard let daily = response.daily,
                      dateOffset < daily.temperature2mMax.count else {
                    await MainActor.run {
                        self.errorMessage = "Future date out of range"
                    }
                    return
                }
                
                // Build synthetic "current" weather from that day's max/min temps and weather code
                let avgTemp = ((daily.temperature2mMax[dateOffset] ?? 0) + (daily.temperature2mMin[dateOffset] ?? 0)) / 2
                let current = WeatherData.CurrentWeather(
                    temperature2m: avgTemp,
                    relativeHumidity2m: nil,
                    apparentTemperature: avgTemp,
                    isDay: 1,
                    precipitation: daily.precipitationSum?[dateOffset] ?? 0,
                    rain: daily.rainSum?[dateOffset] ?? 0,
                    showers: nil,
                    snowfall: daily.snowfallSum?[dateOffset] ?? 0,
                    weatherCode: daily.weatherCode?[dateOffset] ?? 0,
                    cloudCover: 0,
                    pressureMsl: nil,
                    windSpeed10m: daily.windSpeed10mMax?[dateOffset] ?? 0,
                    windDirection10m: nil,
                    visibility: nil,
                    windGusts10m: nil,
                    uvIndex: daily.uvIndexMax?[dateOffset] ?? nil,
                    dewpoint2m: nil
                )
                
                // Extract just this day's data from daily arrays (single-element arrays)
                let singleDayDaily = WeatherData.DailyWeather(
                    temperature2mMax: [daily.temperature2mMax[dateOffset]].compactMap { $0 },
                    temperature2mMin: [daily.temperature2mMin[dateOffset]].compactMap { $0 },
                    sunrise: daily.sunrise.map { [$0[dateOffset]].compactMap { $0 } },
                    sunset: daily.sunset.map { [$0[dateOffset]].compactMap { $0 } },
                    weatherCode: daily.weatherCode.map { [$0[dateOffset]].compactMap { $0 } },
                    precipitationSum: daily.precipitationSum.map { [$0[dateOffset]].compactMap { $0 } },
                    rainSum: daily.rainSum.map { [$0[dateOffset]].compactMap { $0 } },
                    snowfallSum: daily.snowfallSum.map { [$0[dateOffset]].compactMap { $0 } },
                    precipitationProbabilityMax: daily.precipitationProbabilityMax.map { [$0[dateOffset]].compactMap { $0 } },
                    uvIndexMax: daily.uvIndexMax.map { [$0[dateOffset]].compactMap { $0 } },
                    daylightDuration: daily.daylightDuration.map { [$0[dateOffset]].compactMap { $0 } },
                    sunshineDuration: daily.sunshineDuration.map { [$0[dateOffset]].compactMap { $0 } },
                    windSpeed10mMax: daily.windSpeed10mMax.map { [$0[dateOffset]].compactMap { $0 } },
                    winddirection10mDominant: daily.winddirection10mDominant.map { [$0[dateOffset]].compactMap { $0 } }
                )
                
                // Extract hourly data for that specific day (24 hours starting at midnight of target date)
                // Each day has 24 hourly entries, so day N starts at index N*24
                var hourlyForDay: WeatherData.HourlyWeather? = nil
                if let hourly = response.hourly,
                   let hourlyTemp = hourly.temperature2m,
                   let hourlyTime = hourly.time {
                    let hourlyStartIdx = dateOffset * 24
                    let hourlyEndIdx = min(hourlyStartIdx + 24, hourlyTemp.count)
                    if hourlyStartIdx < hourlyTemp.count {
                        hourlyForDay = WeatherData.HourlyWeather(
                            time: Array(hourlyTime[hourlyStartIdx..<hourlyEndIdx]),
                            temperature2m: Array(hourlyTemp[hourlyStartIdx..<hourlyEndIdx]),
                            weatherCode: hourly.weatherCode.map { Array($0[hourlyStartIdx..<hourlyEndIdx]) },
                            precipitation: hourly.precipitation.map { Array($0[hourlyStartIdx..<hourlyEndIdx]) },
                            relativeHumidity2m: hourly.relativeHumidity2m.map { Array($0[hourlyStartIdx..<hourlyEndIdx]) },
                            windSpeed10m: hourly.windSpeed10m.map { Array($0[hourlyStartIdx..<hourlyEndIdx]) },
                            cloudcover: hourly.cloudcover.map { Array($0[hourlyStartIdx..<hourlyEndIdx]) },
                            precipitationProbability: hourly.precipitationProbability.map { Array($0[hourlyStartIdx..<hourlyEndIdx]) },
                            uvIndex: hourly.uvIndex.map { Array($0[hourlyStartIdx..<hourlyEndIdx]) },
                            windgusts10m: hourly.windgusts10m.map { Array($0[hourlyStartIdx..<hourlyEndIdx]) },
                            dewpoint2m: hourly.dewpoint2m.map { Array($0[hourlyStartIdx..<hourlyEndIdx]) }
                        )
                    }
                }
                
                weatherData = WeatherData(current: current, daily: singleDayDaily, hourly: hourlyForDay)
            }
            
            await MainActor.run {
                self.weatherCache[cacheKey] = weatherData
                self.cacheTimestamps[cacheKey] = Date()
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to fetch weather: \(error.localizedDescription)"
            }
        }
    }
    
    // Helper: Fetch historical weather for a city on a specific past date
    private func fetchHistoricalWeatherForCity(city: City, targetDate: Date, cacheKey: WeatherCacheKey) async {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: targetDate)
        
        do {
            // Fetch single day from archive API
            let response = try await fetchHistoricalWeather(for: city, startDate: dateString, endDate: dateString)
            
            // Convert historical data to WeatherData format
            let daily = response.daily
            guard !daily.time.isEmpty,
                  let firstIndex = daily.time.indices.first else {
                await MainActor.run {
                    self.errorMessage = "No historical data available for \(dateString)"
                }
                return
            }
            
            // Create minimal current weather from daily data
            let avgTemp = ((daily.temperature2mMax[firstIndex] ?? 0) + (daily.temperature2mMin[firstIndex] ?? 0)) / 2
            let avgApparentTemp = ((daily.apparentTemperatureMax[firstIndex] ?? 0) + (daily.apparentTemperatureMin[firstIndex] ?? 0)) / 2
            
            let current = WeatherData.CurrentWeather(
                temperature2m: avgTemp,
                relativeHumidity2m: nil,
                apparentTemperature: avgApparentTemp,
                isDay: 1,
                precipitation: daily.precipitationSum[firstIndex] ?? 0,
                rain: daily.rainSum[firstIndex] ?? 0,
                showers: nil,
                snowfall: daily.snowfallSum[firstIndex] ?? 0,
                weatherCode: daily.weatherCode[firstIndex] ?? 0,
                cloudCover: 0,
                pressureMsl: nil,
                windSpeed10m: daily.windSpeed10mMax[firstIndex] ?? 0,
                windDirection10m: nil,
                visibility: nil,
                windGusts10m: nil,
                uvIndex: nil,
                dewpoint2m: nil
            )
            
            // Create daily weather data
            let dailyWeather = WeatherData.DailyWeather(
                temperature2mMax: daily.temperature2mMax,
                temperature2mMin: daily.temperature2mMin,
                sunrise: daily.sunrise,
                sunset: daily.sunset,
                weatherCode: daily.weatherCode,
                precipitationSum: daily.precipitationSum,
                rainSum: daily.rainSum,
                snowfallSum: daily.snowfallSum,
                precipitationProbabilityMax: nil,
                uvIndexMax: nil,
                daylightDuration: nil,
                sunshineDuration: nil,
                windSpeed10mMax: daily.windSpeed10mMax,
                winddirection10mDominant: nil
            )
            
            let weatherData = WeatherData(current: current, daily: dailyWeather, hourly: nil)
            
            await MainActor.run {
                self.weatherCache[cacheKey] = weatherData
                self.cacheTimestamps[cacheKey] = Date()
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to fetch historical weather: \(error.localizedDescription)"
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
    
    // MARK: - Marine Weather
    
    // Fetch marine forecast data for a specific city and date offset
    func fetchMarineData(for city: City, dateOffset: Int = 0) async {
        let cacheKey = WeatherCacheKey(cityId: city.id, dateOffset: dateOffset)
        
        // Check in-memory cache
        if isCacheValid(timestamp: marineCacheTimestamps[cacheKey]) {
            return
        }
        
        // Marine API params - request all available marine variables
        let params = [
            "latitude": String(city.latitude),
            "longitude": String(city.longitude),
            "hourly": "wave_height,wave_direction,wave_period,wave_peak_period,wind_wave_height,wind_wave_direction,wind_wave_period,swell_wave_height,swell_wave_direction,swell_wave_period,ocean_current_velocity,ocean_current_direction,sea_surface_temperature,sea_level_height_msl",
            "forecast_days": "7",
            "timezone": "auto",
            "cell_selection": "sea"  // Prefer sea grid cells for accurate marine data
        ]
        
        var components = URLComponents(string: marineURL)!
        components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        
        guard let url = components.url else {
            await MainActor.run {
                self.errorMessage = "Invalid marine API URL"
            }
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoder = JSONDecoder()
            let response = try decoder.decode(MarineResponse.self, from: data)
            
            // Extract marine data for the specific date offset
            var marineData: MarineData
            
            if dateOffset == 0 {
                // For today, use all data as-is
                marineData = MarineData(hourly: response.hourly)
            } else if dateOffset > 0 {
                // For future dates, extract that day's hourly data (24 hours)
                guard let hourly = response.hourly,
                      let hourlyTime = hourly.time else {
                    await MainActor.run {
                        self.errorMessage = "No marine data available"
                    }
                    return
                }
                
                let hourlyStartIdx = dateOffset * 24
                let hourlyEndIdx = min(hourlyStartIdx + 24, hourlyTime.count)
                
                if hourlyStartIdx < hourlyTime.count {
                    let extractedHourly = MarineData.MarineHourly(
                        time: Array(hourlyTime[hourlyStartIdx..<hourlyEndIdx]),
                        waveHeight: hourly.waveHeight.map { Array($0[hourlyStartIdx..<hourlyEndIdx]) },
                        waveDirection: hourly.waveDirection.map { Array($0[hourlyStartIdx..<hourlyEndIdx]) },
                        wavePeriod: hourly.wavePeriod.map { Array($0[hourlyStartIdx..<hourlyEndIdx]) },
                        wavePeakPeriod: hourly.wavePeakPeriod.map { Array($0[hourlyStartIdx..<hourlyEndIdx]) },
                        windWaveHeight: hourly.windWaveHeight.map { Array($0[hourlyStartIdx..<hourlyEndIdx]) },
                        windWaveDirection: hourly.windWaveDirection.map { Array($0[hourlyStartIdx..<hourlyEndIdx]) },
                        windWavePeriod: hourly.windWavePeriod.map { Array($0[hourlyStartIdx..<hourlyEndIdx]) },
                        swellWaveHeight: hourly.swellWaveHeight.map { Array($0[hourlyStartIdx..<hourlyEndIdx]) },
                        swellWaveDirection: hourly.swellWaveDirection.map { Array($0[hourlyStartIdx..<hourlyEndIdx]) },
                        swellWavePeriod: hourly.swellWavePeriod.map { Array($0[hourlyStartIdx..<hourlyEndIdx]) },
                        oceanCurrentVelocity: hourly.oceanCurrentVelocity.map { Array($0[hourlyStartIdx..<hourlyEndIdx]) },
                        oceanCurrentDirection: hourly.oceanCurrentDirection.map { Array($0[hourlyStartIdx..<hourlyEndIdx]) },
                        seaSurfaceTemperature: hourly.seaSurfaceTemperature.map { Array($0[hourlyStartIdx..<hourlyEndIdx]) },
                        seaLevelHeight: hourly.seaLevelHeight.map { Array($0[hourlyStartIdx..<hourlyEndIdx]) }
                    )
                    marineData = MarineData(hourly: extractedHourly)
                } else {
                    await MainActor.run {
                        self.errorMessage = "Marine data not available for this date"
                    }
                    return
                }
            } else {
                // dateOffset < 0 - past dates not supported by marine API (no historical marine data)
                await MainActor.run {
                    self.errorMessage = "Historical marine data not available"
                }
                return
            }
            
            await MainActor.run {
                self.marineCache[cacheKey] = marineData
                self.marineCacheTimestamps[cacheKey] = Date()
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to fetch marine data: \(error.localizedDescription)"
            }
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
                return try await fetchWeatherKitAlerts(for: city)
            } else {
                return []
            }
        } else {
            return []
        }
    }
    
    /// Fetches alerts directly from National Weather Service API (US only)
    private func fetchNWSAlertsDirectly(for city: City) async throws -> [WeatherAlert] {
        
        let urlString = "https://api.weather.gov/alerts/active?point=\(city.latitude),\(city.longitude)"
        guard let url = URL(string: urlString) else {
            return []
        }
        
        var request = URLRequest(url: url)
        request.setValue("FastWeather/1.0 iOS", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return []
            }
            
            // Don't use .iso8601 date decoding strategy - it interferes with FlexibleStringOrArray
            // and causes crashes when NWS API puts ISO date strings in text fields
            let decoder = JSONDecoder()
            
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
            
            return activeAlerts
            
        } catch {
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
    
    // MARK: - Cache Management
    
    /// Get cache metadata for a city (for displaying "Using cached data from...")
    func getCacheMetadata(for cacheKey: WeatherCacheKey) async -> CachedWeather? {
        guard let timestamp = cacheTimestamps[cacheKey],
              let weather = weatherCache[cacheKey] else {
            return nil
        }
        
        return CachedWeather(weather: weather, timestamp: timestamp, cityId: cacheKey.cityId)
    }
    
    /// Clear all persistent cached weather data
    func clearPersistentCache() {
        // DISABLED: Persistent cache too slow
        print("ℹ️ Persistent cache disabled for performance")
    }
    
    // MARK: - Persistence
    
    private func saveCities() {
        if let encoded = try? JSONEncoder().encode(savedCities) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }
    
    // MARK: - Data Migration
    
    /// Migrate country names from native language to English (one-time)
    private func migrateCountryNamesIfNeeded() {
        let migrationKey = "countryNamesMigrated_v1"
        
        // Check if migration already completed
        guard !UserDefaults.standard.bool(forKey: migrationKey) else {
            print("✅ Country names already migrated")
            return
        }
        
        print("🔄 Migrating country names to English...")
        var migratedCount = 0
        
        // Create backup before migration
        if let encoded = try? JSONEncoder().encode(savedCities) {
            UserDefaults.standard.set(encoded, forKey: "cities_backup_preMigration")
            print("  Created backup of \(savedCities.count) cities")
        }
        
        // Migrate each city's country name
        var updatedCities: [City] = []
        for city in savedCities {
            let oldCountry = city.country
            let normalizedCountry = CountryNames.normalize(oldCountry)
            let newCountry = normalizedCountry ?? oldCountry // Use original if normalization returns nil
            
            if oldCountry != newCountry {
                // Create new City with updated country
                let updatedCity = City(
                    id: city.id,
                    name: city.name,
                    state: city.state,
                    country: newCountry,
                    latitude: city.latitude,
                    longitude: city.longitude
                )
                updatedCities.append(updatedCity)
                migratedCount += 1
                print("  \(city.name): '\(oldCountry)' → '\(newCountry)'")
            } else {
                updatedCities.append(city)
            }
        }
        
        // Update savedCities with migrated data
        savedCities = updatedCities
        
        // Save migrated cities if any changes made
        if migratedCount > 0 {
            saveCities()
            print("✅ Migration complete: \(migratedCount) cities updated")
            
            // Note: VoiceOver announcement handled by view layer
        } else {
            print("✅ Migration complete: No cities needed updating")
        }
        
        // Mark migration as complete (even if no changes)
        UserDefaults.standard.set(true, forKey: migrationKey)
    }
    
    // MARK: - Persistence
    
    private func loadSavedCities() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let cities = try? JSONDecoder().decode([City].self, from: data) {
            savedCities = cities
            
            // DON'T fetch weather during init - let the view trigger it after appearing
            // This allows the UI to show immediately
        } else {
            // Default cities
            savedCities = [
                City(name: "Madison", state: "Wisconsin", country: "United States", latitude: 43.074761, longitude: -89.3837613),
                City(name: "San Diego", state: "California", country: "United States", latitude: 32.7174202, longitude: -117.162772)
            ]
            saveCities()
        }
    }
}
