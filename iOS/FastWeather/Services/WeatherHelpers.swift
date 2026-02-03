//
//  WeatherHelpers.swift
//  Fast Weather
//
//  Helper functions for weather data display and formatting
//

import SwiftUI

// MARK: - UV Index Helpers
struct UVIndexCategory {
    let category: String
    let color: Color
    let textColor: Color
    
    init(uvIndex: Double?) {
        guard let uv = uvIndex else {
            category = "Unknown"
            color = Color.gray
            textColor = Color.white
            return
        }
        
        switch uv {
        case 0...2:
            category = "Low"
            color = Color(red: 0.16, green: 0.58, blue: 0)
            textColor = Color.white
        case 2...5:
            category = "Moderate"
            color = Color(red: 0.97, green: 0.89, blue: 0)
            textColor = Color.black
        case 5...7:
            category = "High"
            color = Color(red: 0.97, green: 0.35, blue: 0)
            textColor = Color.white
        case 7...10:
            category = "Very High"
            color = Color(red: 0.85, green: 0, blue: 0.11)
            textColor = Color.white
        default:
            category = "Extreme"
            color = Color(red: 0.42, green: 0.29, blue: 0.78)
            textColor = Color.white
        }
    }
}

func getUVIndexDescription(_ uvIndex: Double?) -> String {
    guard let uv = uvIndex else { return "UV data unavailable" }
    let category = UVIndexCategory(uvIndex: uv)
    return "UV Index: \(Int(uv.rounded())) (\(category.category))"
}

// MARK: - UV Index Badge View Component
struct UVBadge: View {
    let uvIndex: Double?
    
    var body: some View {
        if let uv = uvIndex {
            let category = UVIndexCategory(uvIndex: uv)
            Text("UV: \(Int(uv.rounded())) (\(category.category))")
                .font(.caption)
                .fontWeight(.semibold)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(category.color)
                .foregroundColor(category.textColor)
                .cornerRadius(12)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(getUVIndexDescription(uv))
        }
    }
}

// MARK: - Dew Point Helpers
func getDewPointComfort(_ dewPointF: Double?) -> String {
    guard let dp = dewPointF else { return "Unknown" }
    
    switch dp {
    case ..<50:
        return "Dry"
    case 50..<60:
        return "Comfortable"
    case 60..<65:
        return "Slightly humid"
    case 65..<70:
        return "Muggy/Uncomfortable"
    default:
        return "Oppressive"
    }
}

func formatDewPoint(_ dewPointC: Double?, isFahrenheit: Bool) -> String {
    guard let dp = dewPointC else { return "N/A" }
    
    let temp: Double
    if isFahrenheit {
        temp = (dp * 9/5) + 32
    } else {
        temp = dp
    }
    
    let comfort = getDewPointComfort(isFahrenheit ? temp : (dp * 9/5) + 32)
    let unit = isFahrenheit ? "°F" : "°C"
    
    return "\(Int(temp.rounded()))\(unit) (\(comfort))"
}

// MARK: - Duration Helpers
func formatDuration(_ seconds: Double?) -> String {
    guard let secs = seconds else { return "N/A" }
    
    let hours = Int(secs / 3600)
    let minutes = Int((secs.truncatingRemainder(dividingBy: 3600)) / 60)
    
    return "\(hours)h \(minutes)m"
}

// MARK: - Wind Formatting
func formatWind(speed: Double?, direction: Int?, gusts: Double? = nil, unit: String = "mph", degreesToCardinal: (Int) -> String) -> String {
    guard let windSpeed = speed, let windDir = direction else { return "N/A" }
    
    let cardinal = degreesToCardinal(windDir)
    var text = "\(Int(windSpeed.rounded())) \(unit) \(cardinal)"
    
    if let gustSpeed = gusts, gustSpeed > windSpeed {
        text += ", gusts \(Int(gustSpeed.rounded())) \(unit)"
    }
    
    return text
}

// MARK: - Cardinal Direction Helper
func degreesToCardinal(_ degrees: Int) -> String {
    let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
    let index = Int((Double(degrees) + 22.5) / 45.0) % 8
    return directions[index]
}

func degreesToCardinalLong(_ degrees: Int) -> String {
    let directions = ["North", "Northeast", "East", "Southeast", "South", "Southwest", "West", "Northwest"]
    let index = Int((Double(degrees) + 22.5) / 45.0) % 8
    return directions[index]
}
