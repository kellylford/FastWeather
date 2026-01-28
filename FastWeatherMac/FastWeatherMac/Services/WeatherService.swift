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
    private let historicalURL = "https://archive-api.open-meteo.com/v1/archive"
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
    
    // MARK: - Historical Weather
    func fetchHistoricalWeather(for city: City, startDate: String, endDate: String) async throws -> HistoricalWeatherResponse {
        let params = [
            "latitude": String(city.latitude),
            "longitude": String(city.longitude),
            "start_date": startDate,
            "end_date": endDate,
            "daily": "weathercode,temperature_2m_max,temperature_2m_min,apparent_temperature_max,apparent_temperature_min,sunrise,sunset,precipitation_sum,rain_sum,snowfall_sum,precipitation_hours,windspeed_10m_max",
            "timezone": "auto"
        ]
        
        var components = URLComponents(string: self.historicalURL)!
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
}
