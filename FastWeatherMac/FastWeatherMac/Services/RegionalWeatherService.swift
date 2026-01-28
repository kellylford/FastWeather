//
//  RegionalWeatherService.swift
//  Fast Weather
//
//  Service to fetch weather data for surrounding locations
//  Provides regional weather context for accessibility
//

import Foundation
import CoreLocation

class RegionalWeatherService {
    static let shared = RegionalWeatherService()
    
    // Cache for reverse geocoded location names (key: "lat,lon", value: city name)
    private var locationNameCache: [String: String] = [:]
    private let cacheQueue = DispatchQueue(label: "com.fastweather.locationcache")
    
    // Actor to serialize geocoding requests to respect rate limits
    private actor GeocodingCoordinator {
        func geocode(latitude: Double, longitude: Double, reverseGeocodeFn: (Double, Double) async throws -> String) async throws -> String {
            // Add delay to respect Nominatim's 1 request/second limit
            try await Task.sleep(nanoseconds: 1_100_000_000)
            return try await reverseGeocodeFn(latitude, longitude)
        }
    }
    
    private let geocodingCoordinator = GeocodingCoordinator()
    
    private init() {
        loadCache()
    }
    
    /// Convert miles to degrees (approximately 69 miles per degree of latitude)
    private func milesToDegrees(_ miles: Double) -> Double {
        return miles / 69.0
    }
    
    // MARK: - Cache Management
    
    private func cacheKey(latitude: Double, longitude: Double) -> String {
        // Round to 2 decimal places for cache key (sufficient precision for city names)
        return String(format: "%.2f,%.2f", latitude, longitude)
    }
    
    private func getCachedLocationName(latitude: Double, longitude: Double) -> String? {
        let key = cacheKey(latitude: latitude, longitude: longitude)
        return cacheQueue.sync {
            return locationNameCache[key]
        }
    }
    
    private func setCachedLocationName(_ name: String, latitude: Double, longitude: Double) {
        let key = cacheKey(latitude: latitude, longitude: longitude)
        cacheQueue.sync {
            locationNameCache[key] = name
            saveCache()
        }
    }
    
    private func loadCache() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: "RegionalWeatherLocationCache"),
           let cache = try? JSONDecoder().decode([String: String].self, from: data) {
            cacheQueue.sync {
                locationNameCache = cache
            }
            print("📍 Loaded \(cache.count) cached location names")
        }
    }
    
    private func saveCache() {
        if let data = try? JSONEncoder().encode(locationNameCache) {
            UserDefaults.standard.set(data, forKey: "RegionalWeatherLocationCache")
        }
    }
    
    /// Fetch weather for all 8 cardinal directions plus center location
    func fetchRegionalWeather(for city: City, distanceMiles: Double = 50) async throws -> RegionalWeatherData {
        // Calculate coordinates for 8 directions
        let locations = calculateDirectionalLocations(for: city, distanceMiles: distanceMiles)
        
        // Fetch weather for all locations concurrently
        async let centerTask = fetchWeatherForLocation(locations.center)
        async let northTask = fetchWeatherForLocation(locations.north)
        async let northeastTask = fetchWeatherForLocation(locations.northeast)
        async let eastTask = fetchWeatherForLocation(locations.east)
        async let southeastTask = fetchWeatherForLocation(locations.southeast)
        async let southTask = fetchWeatherForLocation(locations.south)
        async let southwestTask = fetchWeatherForLocation(locations.southwest)
        async let westTask = fetchWeatherForLocation(locations.west)
        async let northwestTask = fetchWeatherForLocation(locations.northwest)
        
        // Wait for all results
        let results = try await (
            center: centerTask,
            north: northTask,
            northeast: northeastTask,
            east: eastTask,
            southeast: southeastTask,
            south: southTask,
            southwest: southwestTask,
            west: westTask,
            northwest: northwestTask
        )
        
        // Build ordered array of directions
        let directions: [DirectionalLocation] = [
            results.north,
            results.northeast,
            results.east,
            results.southeast,
            results.south,
            results.southwest,
            results.west,
            results.northwest
        ]
        
        return RegionalWeatherData(
            center: results.center,
            directions: directions
        )
    }
    
    // MARK: - Private Methods
    
    private func calculateDirectionalLocations(for city: City, distanceMiles: Double) -> DirectionalLocations {
        let lat = city.latitude
        let lon = city.longitude
        let dist = milesToDegrees(distanceMiles)
        
        return DirectionalLocations(
            center: (direction: "Center", lat: lat, lon: lon),
            north: (direction: "North", lat: lat + dist, lon: lon),
            northeast: (direction: "Northeast", lat: lat + dist, lon: lon + dist),
            east: (direction: "East", lat: lat, lon: lon + dist),
            southeast: (direction: "Southeast", lat: lat - dist, lon: lon + dist),
            south: (direction: "South", lat: lat - dist, lon: lon),
            southwest: (direction: "Southwest", lat: lat - dist, lon: lon - dist),
            west: (direction: "West", lat: lat, lon: lon - dist),
            northwest: (direction: "Northwest", lat: lat + dist, lon: lon - dist)
        )
    }
    
    private func fetchWeatherForLocation(_ location: (direction: String, lat: Double, lon: Double)) async throws -> DirectionalLocation {
        // Build API request URL
        let params = [
            "latitude": String(location.lat),
            "longitude": String(location.lon),
            "current": "temperature_2m,weather_code",
            "temperature_unit": "celsius",
            "timezone": "auto"
        ]
        
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        // Parse response
        let decoder = JSONDecoder()
        let weatherResponse = try decoder.decode(BasicWeatherResponse.self, from: data)
        
        // Convert weather code to description
        let weatherCode = WeatherCode(rawValue: weatherResponse.current.weatherCode)
        
        // Check cache first, then fetch location name via reverse geocoding if needed
        var locationName: String?
        
        if let cached = getCachedLocationName(latitude: location.lat, longitude: location.lon) {
            locationName = cached
            print("💾 Using cached location for \(location.direction): \(cached)")
        } else {
            // Not in cache - fetch via reverse geocoding using serialized coordinator
            do {
                let name = try await geocodingCoordinator.geocode(
                    latitude: location.lat,
                    longitude: location.lon,
                    reverseGeocodeFn: reverseGeocode
                )
                locationName = name
                setCachedLocationName(name, latitude: location.lat, longitude: location.lon)
                print("✅ Reverse geocoded \(location.direction): \(name)")
            } catch {
                print("⚠️ Failed to reverse geocode \(location.direction): \(error.localizedDescription)")
                locationName = nil
            }
        }
        
        let result = DirectionalLocation(
            direction: location.direction,
            latitude: location.lat,
            longitude: location.lon,
            temperature: weatherResponse.current.temperature2m,
            condition: weatherCode?.description ?? "Unknown",
            locationName: locationName
        )
        
        print("🏁 Returning DirectionalLocation for \(location.direction): locationName = '\(result.locationName ?? "nil")'")
        return result
    }
    
    /// Reverse geocode coordinates to get location name using Apple's CLGeocoder
    private func reverseGeocode(latitude: Double, longitude: Double) async throws -> String {
        print("🌍 Geocoding with CLGeocoder: \(latitude), \(longitude)")
        
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: latitude, longitude: longitude)
        
        let placemarks = try await geocoder.reverseGeocodeLocation(location)
        
        guard let placemark = placemarks.first else {
            print("⚠️ No placemarks found")
            throw URLError(.cannotFindHost)
        }
        
        // Build a concise location name
        var parts: [String] = []
        
        if let locality = placemark.locality {
            parts.append(locality)
        }
        
        if let administrativeArea = placemark.administrativeArea {
            parts.append(administrativeArea)
        } else if let country = placemark.country {
            parts.append(country)
        }
        
        let locationName = parts.isEmpty ? "Unknown location" : parts.joined(separator: ", ")
        print("✅ CLGeocoder result: \(locationName)")
        
        return locationName
    }
}

// MARK: - Helper Types

private struct DirectionalLocations {
    let center: (direction: String, lat: Double, lon: Double)
    let north: (direction: String, lat: Double, lon: Double)
    let northeast: (direction: String, lat: Double, lon: Double)
    let east: (direction: String, lat: Double, lon: Double)
    let southeast: (direction: String, lat: Double, lon: Double)
    let south: (direction: String, lat: Double, lon: Double)
    let southwest: (direction: String, lat: Double, lon: Double)
    let west: (direction: String, lat: Double, lon: Double)
    let northwest: (direction: String, lat: Double, lon: Double)
}

private struct BasicWeatherResponse: Codable {
    let current: BasicCurrentWeather
}

private struct BasicCurrentWeather: Codable {
    let temperature2m: Double
    let weatherCode: Int
    
    enum CodingKeys: String, CodingKey {
        case temperature2m = "temperature_2m"
        case weatherCode = "weather_code"
    }
}
