//
//  DirectionalCityService.swift
//  Fast Weather
//
//  Service to find cities in a specific direction from a center point
//

import CoreLocation
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
    
    /// Find cities within a cone or corridor in the given direction using the bundled city cache.
    /// Returns immediately (no network calls) with results sorted by distance.
    /// - Parameters:
    ///   - centerCity: The origin city
    ///   - direction: Cardinal direction to search
    ///   - maxDistance: Maximum distance in miles (default 300)
    ///   - explorationMode: Arc or straight line corridor (default .arc)
    ///   - arcWidth: Width of arc in degrees (default .standard = 22.5°)
    ///   - corridorWidth: Width of corridor in miles (default 20)
    func findCities(
        from centerCity: City,
        direction: CardinalDirection,
        maxDistance: Double = 300,
        explorationMode: ExplorationMode = .arc,
        arcWidth: ArcWidth = .standard,
        corridorWidth: CorridorWidth = .twenty
    ) async -> [DirectionalCityInfo] {
        let cacheKey = "\(centerCity.id)-\(direction.rawValue)-\(Int(maxDistance))-\(explorationMode.rawValue)-\(arcWidth.rawValue)-\(corridorWidth.rawValue)"
        
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
            
            // Calculate perpendicular offset from center line
            let bearingDiff = bearing - direction.bearing
            let normalizedDiff = normalizeBearingDifference(bearingDiff)
            let perpendicularOffset = dist * sin(normalizedDiff * .pi / 180.0)
            
            // Check if city is within the search area based on exploration mode
            let isInSearchArea: Bool
            if explorationMode == .arc {
                isInSearchArea = isInCone(cityBearing: bearing, targetBearing: direction.bearing, coneDegrees: arcWidth.halfAngleDegrees)
            } else {
                // Straight line corridor mode: check if perpendicular distance is within corridor width
                isInSearchArea = abs(perpendicularOffset) <= (corridorWidth.rawValue / 2.0)
            }
            
            guard isInSearchArea else { continue }
            
            results.append(DirectionalCityInfo(
                name: cityLocation.name,
                state: cityLocation.state,
                country: cityLocation.country,
                latitude: cityLocation.latitude,
                longitude: cityLocation.longitude,
                distanceMiles: dist,
                bearing: bearing,
                perpendicularOffsetMiles: perpendicularOffset
            ))
        }
        
        results.sort { $0.distanceMiles < $1.distanceMiles }
        let merged = await fillGaps(
            existingCities: results,
            centerCity: centerCity,
            direction: direction,
            maxDistance: maxDistance
        )
        let final = Array(merged.prefix(20))
        
        geocodeCache[cacheKey] = final
        return final
    }
    
    // MARK: - Waypoint Gap Filling
    
    /// Fills gaps (>50mi) in the directional city list with synthetic weather waypoints.
    private func fillGaps(
        existingCities: [DirectionalCityInfo],
        centerCity: City,
        direction: CardinalDirection,
        maxDistance: Double
    ) async -> [DirectionalCityInfo] {
        var waypoints: [DirectionalCityInfo] = []
        
        // Build the gap intervals to fill.
        // If no real cities exist, fill the first 150 miles (or maxDistance, whichever is smaller).
        // Otherwise check each consecutive pair (including from origin to first city) for gaps > 50mi.
        var intervals: [(Double, Double)] = []
        if existingCities.isEmpty {
            intervals = [(0, min(maxDistance, 150.0))]
        } else {
            let checkPoints = [0.0] + existingCities.map(\.distanceMiles)
            for i in 0..<(checkPoints.count - 1) {
                let from = checkPoints[i]
                let to = checkPoints[i + 1]
                if to - from > 50 {
                    intervals.append((from, to))
                }
            }
        }
        
        for (from, to) in intervals {
            var d = from + 15.0
            while d < to {
                // Don't place a waypoint within 10mi of any real city
                let tooClose = existingCities.contains { abs($0.distanceMiles - d) < 10 }
                if !tooClose {
                    let (wLat, wLon) = destinationCoordinate(
                        fromLat: centerCity.latitude,
                        fromLon: centerCity.longitude,
                        bearing: direction.bearing,
                        distanceMiles: d
                    )
                    let geocodedName = await reverseGeocodeWaypoint(lat: wLat, lon: wLon)
                    
                    let waypointName: String
                    let waypointState: String?
                    if let name = geocodedName {
                        let parts = name.components(separatedBy: ", ")
                        waypointName = parts.first ?? name
                        waypointState = parts.count > 1 ? parts[1] : nil
                    } else {
                        waypointName = "~\(Int(d)) mi \(direction.rawValue)"
                        waypointState = nil
                    }
                    
                    waypoints.append(DirectionalCityInfo(
                        name: waypointName,
                        state: waypointState,
                        country: centerCity.country,
                        latitude: wLat,
                        longitude: wLon,
                        distanceMiles: d,
                        bearing: direction.bearing,
                        isWaypoint: true
                    ))
                }
                d += 15.0
            }
        }
        
        if waypoints.isEmpty { return existingCities }
        var all = existingCities + waypoints
        all.sort { $0.distanceMiles < $1.distanceMiles }
        return all
    }
    
    /// Computes a destination coordinate from an origin using flat-earth approximation.
    /// Accurate enough for distances up to 350 miles (same formula as RegionalWeatherService).
    private func destinationCoordinate(
        fromLat: Double, fromLon: Double, bearing: Double, distanceMiles: Double
    ) -> (lat: Double, lon: Double) {
        let bearingRad = bearing * .pi / 180
        let deltaLat = distanceMiles / 69.0 * cos(bearingRad)
        let deltaLon = distanceMiles / 69.0 * sin(bearingRad) / cos(fromLat * .pi / 180)
        return (lat: fromLat + deltaLat, lon: fromLon + deltaLon)
    }
    
    /// Reverse-geocodes a coordinate using CLGeocoder with a persistent UserDefaults cache.
    /// Returns "Locality, AdminArea" if resolved, or nil for water/uninhabited areas.
    private func reverseGeocodeWaypoint(lat: Double, lon: Double) async -> String? {
        let cacheKey = String(format: "%.2f,%.2f", lat, lon)
        let udKey = "DirectionalWaypointLocationCache"
        
        if let existing = UserDefaults.standard.dictionary(forKey: udKey) as? [String: String],
           let cached = existing[cacheKey] {
            return cached.isEmpty ? nil : cached
        }
        
        let location = CLLocation(latitude: lat, longitude: lon)
        do {
            let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)
            let pm = placemarks.first
            var name: String?
            if let locality = pm?.locality {
                if let area = pm?.administrativeArea {
                    name = "\(locality), \(area)"
                } else {
                    name = locality
                }
            } else if let subLocality = pm?.subLocality {
                if let area = pm?.administrativeArea {
                    name = "\(subLocality), \(area)"
                } else {
                    name = subLocality
                }
            } else if let area = pm?.administrativeArea {
                name = area
            }
            
            // Cache result (empty string = nil, so we don't retry unresolvable coords)
            var dict = UserDefaults.standard.dictionary(forKey: udKey) as? [String: String] ?? [:]
            dict[cacheKey] = name ?? ""
            UserDefaults.standard.set(dict, forKey: udKey)
            
            return name
        } catch {
            print("⚠️ DirectionalCityService: reverseGeocode failed for (\(lat), \(lon)): \(error)")
            return nil
        }
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
    
    /// Normalizes bearing difference to range [-180, 180] for perpendicular offset calculation
    /// - Parameter diff: Raw bearing difference (can be any value)
    /// - Returns: Normalized difference in range [-180, 180]
    private func normalizeBearingDifference(_ diff: Double) -> Double {
        var normalized = diff.truncatingRemainder(dividingBy: 360)
        if normalized > 180 {
            normalized -= 360
        } else if normalized < -180 {
            normalized += 360
        }
        return normalized
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
    /// Perpendicular distance from center line in miles (positive = right/east, negative = left/west)
    public let perpendicularOffsetMiles: Double
    /// True for synthetic weather waypoints generated to fill directional gaps; false for cache-sourced cities.
    public let isWaypoint: Bool
    
    public init(
        name: String, state: String?, country: String,
        latitude: Double, longitude: Double,
        distanceMiles: Double, bearing: Double,
        perpendicularOffsetMiles: Double = 0,
        isWaypoint: Bool = false
    ) {
        self.name = name
        self.state = state
        self.country = country
        self.latitude = latitude
        self.longitude = longitude
        self.distanceMiles = distanceMiles
        self.bearing = bearing
        self.perpendicularOffsetMiles = perpendicularOffsetMiles
        self.isWaypoint = isWaypoint
    }
    
    public var displayName: String {
        var parts = [name]
        if let state = state { parts.append(state) }
        parts.append(country)
        return parts.joined(separator: ", ")
    }
    
    public func displayName(relativeTo homeCountry: String) -> String {
        var parts = [name]
        if let state = state { parts.append(state) }
        if country != homeCountry { parts.append(country) }
        return parts.joined(separator: ", ")
    }
    
    /// Formatted offset description for accessibility
    /// Example: "5 miles west of center line" or "On center line"
    public func offsetDescription(distanceUnit: DistanceUnit) -> String {
        let absOffset = abs(perpendicularOffsetMiles)
        
        if absOffset < 1.0 {
            return "On center line"
        }
        
        let direction = perpendicularOffsetMiles > 0 ? "east" : "west"
        let distance: String
        
        if distanceUnit == .miles {
            distance = String(format: "%.0f miles", absOffset)
        } else {
            let km = absOffset * 1.60934
            distance = String(format: "%.0f km", km)
        }
        
        return "\(distance) \(direction) of center line"
    }
}
