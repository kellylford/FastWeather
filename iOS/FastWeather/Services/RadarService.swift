//
//  RadarService.swift
//  Fast Weather
//
//  Service for fetching and processing precipitation nowcast data from Open-Meteo
//  Uses minute-by-minute precipitation forecasts to provide radar-like experience
//

import Foundation

class RadarService {
    static let shared = RadarService()
    
    private init() {}
    
    // MARK: - Fetch Precipitation Nowcast
    
    /// Fetches minute-by-minute precipitation forecast from Open-Meteo
    /// - Parameters:
    ///   - city: The city to get precipitation data for
    /// - Returns: RadarData with precipitation nowcast information
    func fetchPrecipitationNowcast(for city: City) async throws -> RadarData {
        // Open-Meteo API endpoint with minutely precipitation
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(city.latitude)),
            URLQueryItem(name: "longitude", value: String(city.longitude)),
            URLQueryItem(name: "minutely_15", value: "precipitation"),
            URLQueryItem(name: "hourly", value: "precipitation,weather_code,wind_direction_10m"),
            URLQueryItem(name: "current", value: "precipitation,weather_code,wind_direction_10m"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "forecast_days", value: "1")
        ]
        
        let (data, response) = try await URLSession.shared.data(from: components.url!)
        
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
        
        return RadarData(
            currentStatus: currentStatus,
            nearestPrecipitation: nearestPrecip,
            directionalSectors: directionalSectors,
            timeline: timeline
        )
    }
    
    // MARK: - Helper Methods
    
    private func determineCurrentStatus(_ current: CurrentConditions) -> String {
        if let precip = current.precipitation, precip > 0 {
            let weatherDesc = current.weatherCode.map { WeatherCode(rawValue: $0)?.description ?? "Precipitation" } ?? "Precipitation"
            return "\(weatherDesc) at your location"
        }
        return "Clear at your location"
    }
    
    private func createTimeline(from minutely: Minutely15Data?) -> [TimelinePoint] {
        guard let minutely = minutely,
              let times = minutely.time,
              let precipitation = minutely.precipitation else {
            return [TimelinePoint(time: "Now", condition: "No data available")]
        }
        
        var timeline: [TimelinePoint] = []
        let intervals = [0, 15, 30, 45, 60, 90, 120] // Minutes from now
        
        for interval in intervals {
            let index = min(interval / 15, times.count - 1)
            
            guard index >= 0 && index < times.count else { continue }
            
            let timeLabel = interval == 0 ? "Now" : "\(interval) min"
            let precipValue = precipitation[index] ?? 0.0
            
            let condition = precipValue > 0 ? formatPrecipitationIntensity(precipValue) : "Clear"
            timeline.append(TimelinePoint(time: timeLabel, condition: condition))
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
                    generalStatus = "Clear, precipitation expected later"
                }
            } else {
                generalStatus = "Clear"
            }
        } else {
            generalStatus = "Clear"
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
        
        // Find when precipitation starts
        for (index, precip) in precipitation.enumerated() {
            if let precip = precip, precip > 0.01 {
                let minutesAway = index * 15
                
                if minutesAway == 0 {
                    return nil // Already precipitating
                }
                
                let intensity = formatPrecipitationIntensity(precip)
                let arrival = minutesAway < 60 
                    ? "\(minutesAway) minutes"
                    : "Approximately \(minutesAway / 60) hour\(minutesAway / 60 == 1 ? "" : "s")"
                
                // Get wind direction to determine where precipitation is coming from
                let windDir = (hourly?.windDirection10m?.first ?? nil) ?? 0
                let fromDirection = getOppositeDirection(windDir)
                
                return NearestPrecipitation(
                    distanceMiles: estimateDistance(fromMinutes: minutesAway),
                    direction: fromDirection,
                    type: intensity,
                    intensity: intensity,
                    movementDirection: getCardinalDirection(windDir),
                    speedMph: estimateSpeed(fromMinutes: minutesAway),
                    arrivalEstimate: arrival
                )
            }
        }
        
        return nil
    }
    
    private func formatPrecipitationIntensity(_ mm: Double) -> String {
        switch mm {
        case 0..<0.1:
            return "Clear"
        case 0.1..<2.5:
            return "Light rain"
        case 2.5..<10:
            return "Moderate rain"
        case 10..<50:
            return "Heavy rain"
        default:
            return "Very heavy rain"
        }
    }
    
    private func estimateDistance(fromMinutes minutes: Int) -> Int {
        // Rough estimate: assume 15mph average storm movement
        return (minutes * 15) / 60
    }
    
    private func estimateSpeed(fromMinutes minutes: Int) -> Int {
        // Default average storm speed
        return 15
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
}
