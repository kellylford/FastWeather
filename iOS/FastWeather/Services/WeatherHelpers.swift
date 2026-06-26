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
            category = String(localized: "uv.category.unknown", defaultValue: "Unknown", comment: "UV index category when value is unavailable")
            color = Color.gray
            textColor = Color.white
            return
        }
        
        switch uv {
        case 0...2:
            category = String(localized: "uv.category.low", defaultValue: "Low", comment: "UV index category")
            color = Color(red: 0.16, green: 0.58, blue: 0)
            textColor = Color.white
        case 2...5:
            category = String(localized: "uv.category.moderate", defaultValue: "Moderate", comment: "UV index category")
            color = Color(red: 0.97, green: 0.89, blue: 0)
            textColor = Color.black
        case 5...7:
            category = String(localized: "uv.category.high", defaultValue: "High", comment: "UV index category")
            color = Color(red: 0.97, green: 0.35, blue: 0)
            textColor = Color.white
        case 7...10:
            category = String(localized: "uv.category.very_high", defaultValue: "Very High", comment: "UV index category")
            color = Color(red: 0.85, green: 0, blue: 0.11)
            textColor = Color.white
        default:
            category = String(localized: "uv.category.extreme", defaultValue: "Extreme", comment: "UV index category")
            color = Color(red: 0.42, green: 0.29, blue: 0.78)
            textColor = Color.white
        }
    }
}

func getUVIndexDescription(_ uvIndex: Double?) -> String {
    guard let uv = uvIndex else {
        return String(localized: "uv.data_unavailable", defaultValue: "UV data unavailable", comment: "Shown when UV index is not available")
    }
    let category = UVIndexCategory(uvIndex: uv)
    return String(localized: "uv.index_description",
                  defaultValue: "UV Index: \(Int(uv.rounded())) (\(category.category))",
                  comment: "UV index value with its category, e.g. 'UV Index: 7 (High)'")
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
    guard let dp = dewPointF else {
        return String(localized: "comfort.unknown", defaultValue: "Unknown", comment: "Dew point comfort level when unavailable")
    }

    switch dp {
    case ..<50:
        return String(localized: "comfort.dry", defaultValue: "Dry", comment: "Dew point comfort level")
    case 50..<60:
        return String(localized: "comfort.comfortable", defaultValue: "Comfortable", comment: "Dew point comfort level")
    case 60..<65:
        return String(localized: "comfort.slightly_humid", defaultValue: "Slightly humid", comment: "Dew point comfort level")
    case 65..<70:
        return String(localized: "comfort.muggy_uncomfortable", defaultValue: "Muggy/Uncomfortable", comment: "Dew point comfort level")
    default:
        return String(localized: "comfort.oppressive", defaultValue: "Oppressive", comment: "Dew point comfort level")
    }
}

func formatDewPoint(_ dewPointC: Double?, isFahrenheit: Bool) -> String {
    guard let dp = dewPointC else {
        return String(localized: "common.not_available", defaultValue: "N/A", comment: "Shown when a value is not available")
    }

    let temp: Double
    if isFahrenheit {
        temp = (dp * 9/5) + 32
    } else {
        temp = dp
    }

    let comfort = getDewPointComfort(isFahrenheit ? temp : (dp * 9/5) + 32)
    let unit = isFahrenheit ? "°F" : "°C"

    return String(localized: "dewpoint.value_with_comfort",
                  defaultValue: "\(Int(temp.rounded()))\(unit) (\(comfort))",
                  comment: "Dew point temperature with comfort level, e.g. '55°F (Comfortable)'")
}

// MARK: - Duration Helpers
func formatDuration(_ seconds: Double?) -> String {
    guard let secs = seconds else {
        return String(localized: "common.not_available", defaultValue: "N/A", comment: "Shown when a value is not available")
    }

    let hours = Int(secs / 3600)
    let minutes = Int((secs.truncatingRemainder(dividingBy: 3600)) / 60)

    return String(localized: "duration.hours_minutes",
                  defaultValue: "\(hours)h \(minutes)m",
                  comment: "Duration in hours and minutes, e.g. '5h 30m'")
}

// MARK: - Wind Formatting
func formatWind(speed: Double?, direction: Int?, gusts: Double? = nil, unit: String = "mph", degreesToCardinal: (Int) -> String) -> String {
    guard let windSpeed = speed, let windDir = direction else {
        return String(localized: "common.not_available", defaultValue: "N/A", comment: "Shown when a value is not available")
    }

    let cardinal = degreesToCardinal(windDir)
    var text = "\(Int(windSpeed.rounded())) \(unit) \(cardinal)"

    if let gustSpeed = gusts, gustSpeed > windSpeed {
        text += String(localized: "wind.gusts_suffix",
                       defaultValue: ", gusts \(Int(gustSpeed.rounded())) \(unit)",
                       comment: "Appended to wind text to show gust speed, e.g. ', gusts 30 mph'")
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
    let directions = [
        String(localized: "direction.north", defaultValue: "North", comment: "Compass direction"),
        String(localized: "direction.northeast", defaultValue: "Northeast", comment: "Compass direction"),
        String(localized: "direction.east", defaultValue: "East", comment: "Compass direction"),
        String(localized: "direction.southeast", defaultValue: "Southeast", comment: "Compass direction"),
        String(localized: "direction.south", defaultValue: "South", comment: "Compass direction"),
        String(localized: "direction.southwest", defaultValue: "Southwest", comment: "Compass direction"),
        String(localized: "direction.west", defaultValue: "West", comment: "Compass direction"),
        String(localized: "direction.northwest", defaultValue: "Northwest", comment: "Compass direction")
    ]
    let index = Int((Double(degrees) + 22.5) / 45.0) % 8
    return directions[index]
}
