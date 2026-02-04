//
//  WeatherCache.swift
//  Fast Weather
//
//  Weather data caching service for offline support and performance
//

import Foundation

/// Cached weather data with timestamp
struct CachedWeather: Codable {
    let weather: WeatherData
    let timestamp: Date
    let cityId: UUID
    
    /// Age of cached data in seconds
    var age: TimeInterval {
        Date().timeIntervalSince(timestamp)
    }
    
    /// Human-readable age description
    var ageDescription: String {
        let minutes = Int(age / 60)
        let hours = minutes / 60
        let days = hours / 24
        
        if days > 0 {
            return "\(days) day\(days == 1 ? "" : "s") ago"
        } else if hours > 0 {
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        } else if minutes > 0 {
            return "\(minutes) minute\(minutes == 1 ? "" : "s") ago"
        } else {
            return "just now"
        }
    }
    
    /// Whether the cached data is considered stale (>30 minutes)
    var isStale: Bool {
        age > 1800 // 30 minutes in seconds
    }
}

/// Weather data caching service
@MainActor
class WeatherCache: ObservableObject {
    static let shared = WeatherCache()
    
    @Published private(set) var cache: [UUID: CachedWeather] = [:]
    
    private let userDefaultsKey = "WeatherCache"
    private let maxCacheAge: TimeInterval = 86400 // 24 hours
    private var hasLoadedFromDisk = false
    
    private init() {
        // Don't load from disk immediately - defer until first access
        print("📦 [LAUNCH] WeatherCache initialized (lazy loading enabled)")
    }
    
    // MARK: - Public Methods
    
    /// Get cached weather for a city
    /// - Parameter cityId: The city's unique identifier
    /// - Returns: Cached weather if available and not expired, nil otherwise
    func get(for cityId: UUID) -> CachedWeather? {
        // Lazy-load cache from disk on first access (not during app launch)
        if !hasLoadedFromDisk {
            loadCacheFromDisk()
        }
        
        guard let cached = cache[cityId] else {
            return nil
        }
        
        // Check if cache is too old (>24 hours)
        if cached.age > maxCacheAge {
            print("🗑️ Cache expired for city \(cityId) (age: \(cached.ageDescription))")
            cache.removeValue(forKey: cityId)
            saveCache()
            return nil
        }
        
        print("📦 Using cached data for city \(cityId) (age: \(cached.ageDescription))")
        return cached
    }
    
    /// Store weather data in cache
    /// - Parameters:
    ///   - weather: The weather data to cache
    ///   - cityId: The city's unique identifier
    func set(_ weather: WeatherData, for cityId: UUID) {
        let cached = CachedWeather(weather: weather, timestamp: Date(), cityId: cityId)
        cache[cityId] = cached
        saveCache()
        print("💾 Cached weather for city \(cityId)")
    }
    
    /// Clear cached data for a specific city
    /// - Parameter cityId: The city's unique identifier
    func clear(for cityId: UUID) {
        cache.removeValue(forKey: cityId)
        saveCache()
        print("🗑️ Cleared cache for city \(cityId)")
    }
    
    /// Clear all cached data
    func clearAll() {
        cache.removeAll()
        saveCache()
        print("🗑️ Cleared all weather cache")
    }
    
    /// Remove expired entries from cache
    func removeExpired() {
        let originalCount = cache.count
        cache = cache.filter { $0.value.age <= maxCacheAge }
        let removed = originalCount - cache.count
        
        if removed > 0 {
            saveCache()
            print("🗑️ Removed \(removed) expired cache \(removed == 1 ? "entry" : "entries")")
        }
    }
    
    // MARK: - Persistence
    
    private func loadCacheFromDisk() {
        let startTime = Date()
        print("📦 [CACHE] Loading weather cache from disk...")
        hasLoadedFromDisk = true
        
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            print("📦 [CACHE] No cached weather data found (\(String(format: "%.3f", Date().timeIntervalSince(startTime)))s)")
            return
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let cachedArray = try decoder.decode([CachedWeather].self, from: data)
            
            // Convert array to dictionary
            cache = Dictionary(uniqueKeysWithValues: cachedArray.map { ($0.cityId, $0) })
            
            // Remove expired entries
            removeExpired()
            
            print("📦 [CACHE] Loaded \(cache.count) cached weather \(cache.count == 1 ? "entry" : "entries") (\(String(format: "%.3f", Date().timeIntervalSince(startTime)))s)")
        } catch {
            print("⚠️ [CACHE] Failed to load weather cache: \(error.localizedDescription)")
            cache.removeAll()
        }
    }
    
    private func saveCache() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            
            // Convert dictionary to array for encoding
            let cachedArray = Array(cache.values)
            let data = try encoder.encode(cachedArray)
            
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
            print("💾 Saved \(cache.count) weather cache \(cache.count == 1 ? "entry" : "entries")")
        } catch {
            print("⚠️ Failed to save weather cache: \(error.localizedDescription)")
        }
    }
}
