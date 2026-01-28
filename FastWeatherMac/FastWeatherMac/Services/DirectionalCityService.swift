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
    
    // Cache geocoded results to avoid repeated API calls
    private var geocodeCache: [String: [DirectionalCityInfo]] = [:]
    
    /// Find cities along a bearing using reverse geocoding
    func findCities(from centerCity: City, direction: CardinalDirection, maxDistance: Double = 300) async -> [DirectionalCityInfo] {
        let cacheKey = "\(centerCity.id)-\(direction.rawValue)-\(Int(maxDistance))"
        
        // Return cached results if available
        if let cached = geocodeCache[cacheKey] {
            return cached
        }
        
        var results: [DirectionalCityInfo] = []
        let geocoder = CLGeocoder()
        let centerLocation = CLLocation(latitude: centerCity.latitude, longitude: centerCity.longitude)
        
        // Calculate points at 10-mile intervals up to maxDistance
        let interval: Double = 10
        var distance: Double = interval
        
        while distance <= maxDistance {
            // Calculate destination coordinates
            let destination = calculateDestination(
                from: centerLocation.coordinate,
                bearing: direction.bearing,
                distanceMiles: distance
            )
            
            let location = CLLocation(latitude: destination.latitude, longitude: destination.longitude)
            
            // Reverse geocode to find city at this point
            do {
                // Rate limit: 2 seconds per request to respect Apple's CLGeocoder limits
                // (Apple recommends 1 request/minute, but allows burst capacity with delays)
                if distance > interval {
                    try await Task.sleep(nanoseconds: 2_000_000_000)
                }
                
                let placemarks = try await geocoder.reverseGeocodeLocation(location)
                
                if let placemark = placemarks.first,
                   let cityName = placemark.locality ?? placemark.subLocality {
                    
                    // Skip if this is the same as center city
                    if cityName.lowercased() != centerCity.name.lowercased() {
                        let state = placemark.administrativeArea
                        let country = placemark.country ?? "Unknown"
                        
                        // Calculate actual bearing to verify
                        let actualBearing = calculateBearing(from: centerLocation, to: location)
                        
                        let cityInfo = DirectionalCityInfo(
                            name: cityName,
                            state: state,
                            country: country,
                            latitude: destination.latitude,
                            longitude: destination.longitude,
                            distanceMiles: distance,
                            bearing: actualBearing
                        )
                        
                        // Only add if not duplicate
                        if !results.contains(where: { $0.name.lowercased() == cityName.lowercased() }) {
                            results.append(cityInfo)
                        }
                    }
                }
            } catch {
                print("⚠️ Geocoding failed at \(distance) miles (\(direction.rawValue)): \(error.localizedDescription)")
                
                // If we hit rate limit, wait longer before continuing
                if (error as NSError).domain == kCLErrorDomain,
                   (error as NSError).code == CLError.network.rawValue {
                    print("🚫 Rate limit detected, waiting 5 seconds...")
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                }
                // Continue to next point even if this one fails
            }
            
            distance += interval
            
            // Limit to reasonable number of requests
            if results.count >= 20 {
                break
            }
        }
        
        // Cache results
        geocodeCache[cacheKey] = results
        
        return results
    }
    
    /// Calculate destination coordinates given start point, bearing, and distance
    private func calculateDestination(from: CLLocationCoordinate2D, bearing: Double, distanceMiles: Double) -> CLLocationCoordinate2D {
        let distanceMeters = distanceMiles * 1609.34
        let earthRadius: Double = 6371000 // meters
        
        let lat1 = from.latitude * .pi / 180
        let lon1 = from.longitude * .pi / 180
        let bearingRad = bearing * .pi / 180
        
        let lat2 = asin(sin(lat1) * cos(distanceMeters / earthRadius) +
                       cos(lat1) * sin(distanceMeters / earthRadius) * cos(bearingRad))
        
        let lon2 = lon1 + atan2(sin(bearingRad) * sin(distanceMeters / earthRadius) * cos(lat1),
                                cos(distanceMeters / earthRadius) - sin(lat1) * sin(lat2))
        
        return CLLocationCoordinate2D(
            latitude: lat2 * 180 / .pi,
            longitude: lon2 * 180 / .pi
        )
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
