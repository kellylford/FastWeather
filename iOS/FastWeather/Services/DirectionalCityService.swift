//
//  DirectionalCityService.swift
//  Fast Weather
//
//  Service to find cities in a specific direction from a center point
//

import Foundation
import CoreLocation

class DirectionalCityService {
    static let shared = DirectionalCityService()
    
    private init() {}
    
    /// Find cities in a directional cone (±22.5°) from center point
    func findCities(from centerCity: City, direction: CardinalDirection, maxDistance: Double = 300) -> [DirectionalCityInfo] {
        let cityDataService = CityDataService()
        let allCities = cityDataService.allCities()
        
        let centerLocation = CLLocation(latitude: centerCity.latitude, longitude: centerCity.longitude)
        let targetBearing = direction.bearing
        let coneWidth: Double = 22.5  // ±22.5° = 45° total cone
        
        var results: [DirectionalCityInfo] = []
        
        for cityLocation in allCities {
            let targetLocation = CLLocation(latitude: cityLocation.latitude, longitude: cityLocation.longitude)
            
            // Calculate distance
            let distanceMeters = centerLocation.distance(from: targetLocation)
            let distanceMiles = distanceMeters * 0.000621371
            
            // Skip if beyond max distance or same city
            if distanceMiles > maxDistance || distanceMiles < 1 {
                continue
            }
            
            // Calculate bearing from center to this city
            let bearing = calculateBearing(from: centerLocation, to: targetLocation)
            
            // Check if bearing is within cone
            if isBearingInCone(bearing: bearing, targetBearing: targetBearing, coneWidth: coneWidth) {
                results.append(DirectionalCityInfo(
                    name: cityLocation.name,
                    state: cityLocation.state,
                    country: cityLocation.country,
                    latitude: cityLocation.latitude,
                    longitude: cityLocation.longitude,
                    distanceMiles: distanceMiles,
                    bearing: bearing
                ))
            }
        }
        
        // Sort by distance (closest first)
        return results.sorted { $0.distanceMiles < $1.distanceMiles }
    }
    
    /// Calculate bearing from one location to another (0-360°)
    private func calculateBearing(from: CLLocation, to: CLLocation) -> Double {
        let lat1 = from.coordinate.latitude * .pi / 180
        let lon1 = from.coordinate.longitude * .pi / 180
        let lat2 = to.coordinate.latitude * .pi / 180
        let lon2 = to.coordinate.longitude * .pi / 180
        
        let dLon = lon2 - lon1
        
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        
        var bearing = atan2(y, x) * 180 / .pi
        bearing = (bearing + 360).truncatingRemainder(dividingBy: 360)
        
        return bearing
    }
    
    /// Check if a bearing is within the cone of target bearing ± coneWidth
    private func isBearingInCone(bearing: Double, targetBearing: Double, coneWidth: Double) -> Bool {
        let lowerBound = (targetBearing - coneWidth + 360).truncatingRemainder(dividingBy: 360)
        let upperBound = (targetBearing + coneWidth).truncatingRemainder(dividingBy: 360)
        
        // Handle wrap-around at 0/360°
        if lowerBound > upperBound {
            // Cone crosses 0° (e.g., North: 337.5° to 22.5°)
            return bearing >= lowerBound || bearing <= upperBound
        } else {
            return bearing >= lowerBound && bearing <= upperBound
        }
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
