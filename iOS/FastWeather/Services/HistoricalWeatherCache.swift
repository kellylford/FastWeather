//
//  HistoricalWeatherCache.swift
//  Fast Weather
//
//  Cache for historical weather data
//

import Foundation

class HistoricalWeatherCache {
    static let shared = HistoricalWeatherCache()
    
    private let fileManager = FileManager.default
    private var cacheDirectory: URL {
        let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        let cacheDir = documentsDirectory.appendingPathComponent("HistoricalWeather", isDirectory: true)
        
        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: cacheDir.path) {
            try? fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        }
        
        return cacheDir
    }
    
    private func cityDirectory(for city: City) -> URL {
        let cityKey = String(format: "city_%.4f_%.4f", city.latitude, city.longitude)
        let cityDir = cacheDirectory.appendingPathComponent(cityKey, isDirectory: true)
        
        if !fileManager.fileExists(atPath: cityDir.path) {
            try? fileManager.createDirectory(at: cityDir, withIntermediateDirectories: true)
        }
        
        return cityDir
    }
    
    private func cacheFile(for city: City, monthDay: String) -> URL {
        let cityDir = cityDirectory(for: city)
        return cityDir.appendingPathComponent("\(monthDay).json")
    }
    
    // Get cached historical data for a specific month-day (e.g., "01-19" for Jan 19)
    func getCached(for city: City, monthDay: String) -> [HistoricalDay]? {
        let file = cacheFile(for: city, monthDay: monthDay)
        
        guard fileManager.fileExists(atPath: file.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: file)
            let cached = try JSONDecoder().decode([HistoricalDay].self, from: data)
            print("✅ Loaded cached historical data for \(city.name) on \(monthDay): \(cached.count) years")
            return cached
        } catch {
            print("❌ Error loading cached historical data: \(error)")
            return nil
        }
    }
    
    // Cache historical data for a specific month-day
    func cache(_ data: [HistoricalDay], for city: City, monthDay: String) {
        let file = cacheFile(for: city, monthDay: monthDay)
        
        do {
            let encoded = try JSONEncoder().encode(data)
            try encoded.write(to: file)
            print("✅ Cached historical data for \(city.name) on \(monthDay): \(data.count) years")
        } catch {
            print("❌ Error caching historical data: \(error)")
        }
    }
    
    // Clear all cached data for a city
    func clearCache(for city: City) {
        let cityDir = cityDirectory(for: city)
        try? fileManager.removeItem(at: cityDir)
        print("✅ Cleared historical cache for \(city.name)")
    }
    
    // Clear all cached historical data
    func clearAllCaches() {
        try? fileManager.removeItem(at: cacheDirectory)
        print("✅ Cleared all historical weather caches")
    }
    
    // Get cache size for a city in bytes
    func cacheSize(for city: City) -> Int64 {
        let cityDir = cityDirectory(for: city)
        
        guard let enumerator = fileManager.enumerator(at: cityDir, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        
        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
               let fileSize = attributes[.size] as? Int64 {
                totalSize += fileSize
            }
        }
        
        return totalSize
    }
}
