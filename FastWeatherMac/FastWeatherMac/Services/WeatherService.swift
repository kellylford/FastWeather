//
//  WeatherService.swift
//  FastWeatherMac
//
//  Created on 12/12/2025.
//  API service for fetching weather data from Open-Meteo
//

import Foundation

class WeatherService {
    static let shared = WeatherService()
    
    private let openMeteoBaseURL = "https://api.open-meteo.com/v1/forecast"
    private let nominatimBaseURL = "https://nominatim.openstreetmap.org/search"
    
    private init() {}
    
    // MARK: - Fetch Weather Data
    func fetchWeather(for city: City, includeHourly: Bool = true, includeDaily: Bool = true) async throws -> WeatherResponse {
        var components = URLComponents(string: openMeteoBaseURL)!
        
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "latitude", value: String(city.latitude)),
            URLQueryItem(name: "longitude", value: String(city.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,rain,showers,snowfall,weather_code,cloud_cover,pressure_msl,surface_pressure,wind_speed_10m,wind_direction_10m,wind_gusts_10m,visibility"),
            URLQueryItem(name: "timezone", value: "auto")
        ]
        
        if includeHourly {
            queryItems.append(URLQueryItem(name: "hourly", value: "temperature_2m,apparent_temperature,relative_humidity_2m,precipitation,weathercode,windspeed_10m,winddirection_10m"))
            queryItems.append(URLQueryItem(name: "forecast_days", value: "1"))
        }
        
        if includeDaily {
            queryItems.append(URLQueryItem(name: "daily", value: "weathercode,temperature_2m_max,temperature_2m_min,apparent_temperature_max,apparent_temperature_min,sunrise,sunset,precipitation_sum,precipitation_probability_max,windspeed_10m_max,winddirection_10m_dominant"))
            queryItems.append(URLQueryItem(name: "forecast_days", value: "7"))
        }
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw WeatherError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw WeatherError.invalidResponse
        }
        
        do {
            let weatherResponse = try JSONDecoder().decode(WeatherResponse.self, from: data)
            return weatherResponse
        } catch {
            throw WeatherError.decodingError(error)
        }
    }
    
    // MARK: - Geocoding
    func searchCity(_ query: String) async throws -> [GeocodingResult] {
        var components = URLComponents(string: nominatimBaseURL)!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "addressdetails", value: "1"),
            URLQueryItem(name: "limit", value: "5")
        ]
        
        guard let url = components.url else {
            throw WeatherError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("FastWeatherMac/1.0", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw WeatherError.invalidResponse
        }
        
        do {
            let results = try JSONDecoder().decode([GeocodingResult].self, from: data)
            return results
        } catch {
            throw WeatherError.decodingError(error)
        }
    }
}

// MARK: - Weather Error
enum WeatherError: LocalizedError {
    case invalidURL
    case invalidResponse
    case decodingError(Error)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .decodingError(let error):
            return "Failed to decode data: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
