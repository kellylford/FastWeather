//
//  DirectionalCityService.swift
//  Fast Weather
//
//  Service to find cities in a specific direction from a center point
//

import Foundation

class DirectionalCityService {
    static let shared = DirectionalCityService()
    
    private init() {}
    
    // Cache results to avoid recomputing for the same direction/distance
    private var geocodeCache: [String: [DirectionalCityInfo]] = [:]
    
    // Lazy-loaded city list from bundled cache JSON
    private var _allCachedCities: [CityLocation]? = nil
    private func allCachedCities() -> [CityLocation] {
        if let cached = _allCachedCities { return cached }
        var all: [CityLocation] = []
        for resource in ["us-cities-cached", "international-cities-cached"] {
            if let url = Bundle.main.url(forResource: resource, withExtension: "json"),
               let data = try? Data(contentsOf: url),
               let decoded = try? JSONDecoder().decode([String: [CityLocation]].self, from: data) {
                all.append(contentsOf: decoded.values.flatMap { $0 })
            } else {
                print("⚠️ DirectionalCityService: could not load \(resource).json")
            }
        }
        _allCachedCities = all
        return all
    }
    
    /// Find cities within a ±22.5° cone in the given direction using the bundled city cache.
    /// Returns immediately (no network calls) with results sorted by distance.
    func findCities(from centerCity: City, direction: CardinalDirection, maxDistance: Double = 300) async -> [DirectionalCityInfo] {
        let cacheKey = "\(centerCity.id)-\(direction.rawValue)-\(Int(maxDistance))"
        
        if let cached = geocodeCache[cacheKey] {
            return cached
        }
        
        let cities = allCachedCities()
        var results: [DirectionalCityInfo] = []
        
        for cityLocation in cities {
            // Skip the center city itself
            if cityLocation.name.lowercased() == centerCity.name.lowercased(),
               (cityLocation.state ?? "") == (centerCity.state ?? "") {
                continue
            }
            
            let dist = distanceMilesBetween(
                fromLat: centerCity.latitude, fromLon: centerCity.longitude,
                toLat: cityLocation.latitude, toLon: cityLocation.longitude
            )
            guard dist > 0, dist <= maxDistance else { continue }
            
            let bearing = bearingBetween(
                fromLat: centerCity.latitude, fromLon: centerCity.longitude,
                toLat: cityLocation.latitude, toLon: cityLocation.longitude
            )
            guard isInCone(cityBearing: bearing, targetBearing: direction.bearing) else { continue }
            
            results.append(DirectionalCityInfo(
                name: cityLocation.name,
                state: cityLocation.state,
                country: cityLocation.country,
                latitude: cityLocation.latitude,
                longitude: cityLocation.longitude,
                distanceMiles: dist,
                bearing: bearing
            ))
        }
        
        results.sort { $0.distanceMiles < $1.distanceMiles }
        let final = Array(results.prefix(20))
        
        geocodeCache[cacheKey] = final
        return final
    }
    
    // MARK: - Geometry helpers
    
    /// Forward azimuth (0–360°) from one lat/lon to another.
    private func bearingBetween(fromLat: Double, fromLon: Double, toLat: Double, toLon: Double) -> Double {
        let lat1 = fromLat * .pi / 180
        let lon1 = fromLon * .pi / 180
        let lat2 = toLat * .pi / 180
        let lon2 = toLon * .pi / 180
        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        var b = atan2(y, x) * 180 / .pi
        b = (b + 360).truncatingRemainder(dividingBy: 360)
        return b
    }
    
    /// Great-circle distance in miles between two lat/lon points.
    private func distanceMilesBetween(fromLat: Double, fromLon: Double, toLat: Double, toLon: Double) -> Double {
        let earthRadiusMiles = 3958.8
        let lat1 = fromLat * .pi / 180
        let lat2 = toLat * .pi / 180
        let dLat = lat2 - lat1
        let dLon = (toLon - fromLon) * .pi / 180
        let a = sin(dLat/2) * sin(dLat/2) + cos(lat1) * cos(lat2) * sin(dLon/2) * sin(dLon/2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return earthRadiusMiles * c
    }
    
    /// Returns true if `cityBearing` falls within `coneDegrees` of `targetBearing` (handles 0°/360° wrap).
    private func isInCone(cityBearing: Double, targetBearing: Double, coneDegrees: Double = 22.5) -> Bool {
        let diff = abs((cityBearing - targetBearing + 180).truncatingRemainder(dividingBy: 360) - 180)
        return diff <= coneDegrees
    }
}


// MARK: - Data Models

public enum CardinalDirection: String, CaseIterable {
    case north = "North"
    case northeast = "Northeast"
    case east = "East"
    case southeast = "Southeast"
    case south = "South"
    case southwest = "Southwest"
    case west = "West"
    case northwest = "Northwest"
    
    var bearing: Double {
        switch self {
        case .north: return 0
        case .northeast: return 45
        case .east: return 90
        case .southeast: return 135
        case .south: return 180
        case .southwest: return 225
        case .west: return 270
        case .northwest: return 315
        }
    }
    
    var icon: String {
        switch self {
        case .north: return "arrow.up"
        case .northeast: return "arrow.up.right"
        case .east: return "arrow.right"
        case .southeast: return "arrow.down.right"
        case .south: return "arrow.down"
        case .southwest: return "arrow.down.left"
        case .west: return "arrow.left"
        case .northwest: return "arrow.up.left"
        }
    }
}

public struct DirectionalCityInfo: Identifiable {
    public let id = UUID()
    public let name: String
    public let state: String?
    public let country: String
    public let latitude: Double
    public let longitude: Double
    public let distanceMiles: Double
    public let bearing: Double
    
    public var displayName: String {
        var parts = [name]
        if let state = state {
            parts.append(state)
        }
        parts.append(country)
        return parts.joined(separator: ", ")
    }
}
