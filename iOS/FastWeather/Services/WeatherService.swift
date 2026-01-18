//
//  WeatherService.swift
//  Fast Weather
//
//  Service for fetching weather data from Open-Meteo API
//

import Foundation
import Combine

class WeatherService: ObservableObject {
    @Published var savedCities: [City] = []
    @Published var weatherCache: [UUID: WeatherData] = [:]
    @Published var browseWeatherCache: [String: WeatherData] = [:] // Cache for browse cities
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let baseURL = "https://api.open-meteo.com/v1/forecast"
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
            "current": "temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,rain,showers,snowfall,weather_code,cloud_cover,pressure_msl,wind_speed_10m,wind_direction_10m,visibility",
            "hourly": "temperature_2m,weather_code,precipitation,relative_humidity_2m,wind_speed_10m",
            "daily": "temperature_2m_max,temperature_2m_min,sunrise,sunset,weather_code,precipitation_sum",
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
            "current": "temperature_2m,weather_code,cloud_cover",
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
            "current": "temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,rain,showers,snowfall,weather_code,cloud_cover,pressure_msl,wind_speed_10m,wind_direction_10m,visibility",
            "hourly": "temperature_2m,weather_code,precipitation,relative_humidity_2m,wind_speed_10m",
            "daily": "temperature_2m_max,temperature_2m_min,sunrise,sunset,weather_code,precipitation_sum",
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
