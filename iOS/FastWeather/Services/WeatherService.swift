//
//  WeatherService.swift
//  Weather Fast
//
//  Service for fetching weather data from Open-Meteo API
//

import Foundation
import Combine

class WeatherService: ObservableObject {
    @Published var savedCities: [City] = []
    @Published var weatherCache: [UUID: WeatherData] = [:]
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let baseURL = "https://api.open-meteo.com/v1/forecast"
    private let userDefaultsKey = "SavedCities"
    
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
        saveCities()
    }
    
    func moveCity(from source: IndexSet, to destination: Int) {
        savedCities.move(fromOffsets: source, toOffset: destination)
        saveCities()
    }
    
    // MARK: - Weather Fetching
    
    func fetchWeather(for city: City) async {
        let params = [
            "latitude": String(city.latitude),
            "longitude": String(city.longitude),
            "current": "temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,rain,showers,snowfall,weather_code,cloud_cover,pressure_msl,wind_speed_10m,wind_direction_10m,visibility",
            "daily": "temperature_2m_max,temperature_2m_min,sunrise,sunset",
            "forecast_days": "1",
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
            let response = try JSONDecoder().decode(WeatherResponse.self, from: data)
            
            await MainActor.run {
                self.weatherCache[city.id] = WeatherData(current: response.current, daily: response.daily)
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to fetch weather: \(error.localizedDescription)"
            }
        }
    }
    
    // Fetch weather for any coordinates (used for browsing cities)
    func fetchWeather(latitude: Double, longitude: Double) async throws -> WeatherData {
        let params = [
            "latitude": String(latitude),
            "longitude": String(longitude),
            "current": "temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,rain,showers,snowfall,weather_code,cloud_cover,pressure_msl,wind_speed_10m,wind_direction_10m,visibility",
            "daily": "temperature_2m_max,temperature_2m_min,sunrise,sunset",
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
        
        return WeatherData(current: response.current, daily: response.daily)
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
