//
//  WeatherMovementAnalyzer.swift
//  Fast Weather
//
//  Analyzes weather system movement using wind direction
//

import Foundation

/// Analyzes weather movement direction relative to a center point
struct WeatherMovementAnalyzer {
    
    /// Weather movement direction relative to center point
    enum MovementDirection: String {
        case approaching = "Approaching"
        case receding = "Moving away"
        case parallel = "Moving parallel"
        case calm = "Calm"
        
        var description: String {
            switch self {
            case .approaching:
                return "Weather approaching your location"
            case .receding:
                return "Weather moving away"
            case .parallel:
                return "Weather moving parallel to your location"
            case .calm:
                return "Calm conditions, minimal movement"
            }
        }
    }
    
    /// Analyze weather movement based on wind direction at remote location
    /// - Parameters:
    ///   - windDirection: Wind direction in degrees at remote location (0=N, 90=E, etc.)
    ///   - windSpeed: Wind speed in km/h at remote location
    ///   - bearingToLocation: Bearing from center point to remote location (0=N, 90=E, etc.)
    /// - Returns: Movement direction and angle difference
    static func analyzeMovement(
        windDirection: Double,
        windSpeed: Double,
        bearingToLocation: Double
    ) -> (direction: MovementDirection, angleDifference: Double) {
        // Calm conditions (< 5 km/h)
        guard windSpeed >= 5 else {
            return (.calm, 0)
        }
        
        // Calculate the bearing FROM the remote location BACK TO the center point
        let bearingBackToCenter = (bearingToLocation + 180).truncatingRemainder(dividingBy: 360)
        
        // Calculate angle between wind direction and bearing back to center
        // If wind is blowing in the same direction as bearing back to center, weather is approaching
        var angleDiff = windDirection - bearingBackToCenter
        
        // Normalize to [-180, 180]
        if angleDiff > 180 {
            angleDiff -= 360
        } else if angleDiff < -180 {
            angleDiff += 360
        }
        
        let absAngle = abs(angleDiff)
        
        // Categorize movement
        // 0° = directly approaching (wind blowing toward center)
        // 180° = directly receding (wind blowing away from center)
        // 90° = perpendicular (moving parallel)
        let movement: MovementDirection
        if absAngle < 45 {
            movement = .approaching
        } else if absAngle > 135 {
            movement = .receding
        } else {
            movement = .parallel
        }
        
        return (movement, angleDiff)
    }
    
    /// Analyze weather movement with detailed description
    /// - Parameters:
    ///   - windDirection: Wind direction in degrees at remote location
    ///   - windSpeed: Wind speed in km/h at remote location
    ///   - windSpeedUnit: User's preferred wind speed unit for output
    ///   - bearingToLocation: Bearing from center point to remote location
    ///   - locationName: Name of location for description
    /// - Returns: Human-readable movement description
    static func movementDescription(
        windDirection: Double,
        windSpeed: Double,
        windSpeedUnit: WindSpeedUnit,
        bearingToLocation: Double,
        locationName: String? = nil
    ) -> String {
        let (movement, angleDiff) = analyzeMovement(
            windDirection: windDirection,
            windSpeed: windSpeed,
            bearingToLocation: bearingToLocation
        )
        
        let convertedSpeed = windSpeedUnit.convert(windSpeed)
        let speedStr = "\(Int(convertedSpeed.rounded())) \(windSpeedUnit.rawValue)"
        
        let locationStr = locationName.map { " at \($0)" } ?? ""
        
        switch movement {
        case .calm:
            return "Winds \(speedStr)\(locationStr)"
        case .approaching:
            return "Approaching\(locationStr) at \(speedStr)"
        case .receding:
            return "Moving away\(locationStr) at \(speedStr)"
        case .parallel:
            let direction = abs(angleDiff) > 90 ? "roughly parallel" : "parallel"
            return "Moving \(direction)\(locationStr) at \(speedStr)"
        }
    }
}
