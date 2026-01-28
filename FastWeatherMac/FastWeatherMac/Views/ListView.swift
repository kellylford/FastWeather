//
//  ListView.swift
//  FastWeatherMac
//
//  Compact list view for displaying weather
//  Adapted from iOS implementation for macOS
//

import SwiftUI

struct ListView: View {
    let cities: [City]
    @Binding var selectedCity: City?
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var weatherCache: [UUID: WeatherResponse] = [:]
    
    var body: some View {
        List(selection: $selectedCity) {
            ForEach(cities) { city in
                ListRowView(city: city, weather: weatherCache[city.id])
                    .tag(city)
                    .task(id: city.id) {
                        await loadWeather(for: city)
                    }
            }
        }
        .listStyle(.plain)
    }
    
    private func loadWeather(for city: City) async {
        guard weatherCache[city.id] == nil else { return }
        
        do {
            let weather = try await WeatherService.shared.fetchWeather(
                for: city,
                includeHourly: false,
                includeDaily: true
            )
            await MainActor.run {
                weatherCache[city.id] = weather
            }
        } catch {
            print("Failed to load weather for \(city.name): \(error)")
        }
    }
}

// MARK: - List Row View
struct ListRowView: View {
    let city: City
    let weather: WeatherResponse?
    @EnvironmentObject var settingsManager: SettingsManager
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(city.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                
                if let weather = weather {
                    Text(buildWeatherSummary(weather))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                } else {
                    Text("Loading...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if let weather = weather,
               settingsManager.settings.weatherFields.first(where: { $0.type == .temperature && $0.isEnabled }) != nil {
                Text(formatTemperature(weather.current.temperature2m))
                    .font(.title3)
                    .fontWeight(.semibold)
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(buildAccessibilityLabel())
    }
    
    private func buildWeatherSummary(_ weather: WeatherResponse) -> String {
        var parts: [String] = []
        let isDetails = settingsManager.settings.displayMode == .details
        
        for field in settingsManager.settings.weatherFields where field.isEnabled {
            switch field.type {
            case .temperature:
                break
                
            case .conditions:
                if let weatherCode = weather.current.weatherCodeEnum {
                    parts.append(isDetails ? "Conditions: \(weatherCode.description)" : weatherCode.description)
                }
                
            case .feelsLike:
                let apparentTemp = weather.current.apparentTemperature
                let value = formatTemperature(apparentTemp)
                parts.append(isDetails ? "Feels Like: \(value)" : value)
                
            case .humidity:
                let humidity = weather.current.relativeHumidity2m
                let value = "\(humidity)%"
                parts.append(isDetails ? "Humidity: \(value)" : value)
                
            case .windSpeed:
                let windSpeed = weather.current.windSpeed10m
                let value = formatWindSpeed(windSpeed)
                parts.append(isDetails ? "Wind Speed: \(value)" : value)
                
            case .windDirection:
                let windDir = weather.current.windDirection10m
                let value = formatWindDirection(windDir)
                parts.append(isDetails ? "Wind Direction: \(value)" : value)
                
            case .highTemp:
                if let daily = weather.daily, !daily.temperature2mMax.isEmpty {
                    let maxTemp = daily.temperature2mMax[0]
                    let value = formatTemperature(maxTemp)
                    parts.append(isDetails ? "High: \(value)" : value)
                }
                
            case .lowTemp:
                if let daily = weather.daily, !daily.temperature2mMin.isEmpty {
                    let minTemp = daily.temperature2mMin[0]
                    let value = formatTemperature(minTemp)
                    parts.append(isDetails ? "Low: \(value)" : value)
                }
                
            case .sunrise:
                if let daily = weather.daily, !daily.sunrise.isEmpty {
                    let sunrise = daily.sunrise[0]
                    let value = FormatHelper.formatTime(sunrise)
                    parts.append(isDetails ? "Sunrise: \(value)" : value)
                }
                
            case .sunset:
                if let daily = weather.daily, !daily.sunset.isEmpty {
                    let sunset = daily.sunset[0]
                    let value = FormatHelper.formatTime(sunset)
                    parts.append(isDetails ? "Sunset: \(value)" : value)
                }
            }
        }
        
        return parts.joined(separator: " • ")
    }
    
    private func buildAccessibilityLabel() -> String {
        guard let weather = weather else {
            return "\(city.displayName), Loading"
        }
        
        var label = "\(city.displayName), \(formatTemperature(weather.current.temperature2m))"
        let isDetails = settingsManager.settings.displayMode == .details
        
        if settingsManager.settings.weatherFields.first(where: { $0.type == .conditions && $0.isEnabled }) != nil,
           let weatherCode = weather.current.weatherCodeEnum {
            label += ", "
            label += isDetails ? "Conditions: \(weatherCode.description)" : weatherCode.description
        }
        
        for field in settingsManager.settings.weatherFields where field.isEnabled {
            switch field.type {
            case .temperature, .conditions:
                break
                
            case .feelsLike:
                let apparentTemp = weather.current.apparentTemperature
                let value = formatTemperature(apparentTemp)
                label += ", "
                label += isDetails ? "Feels Like: \(value)" : value
                
            case .humidity:
                let humidity = weather.current.relativeHumidity2m
                let value = "\(humidity)%"
                label += ", "
                label += isDetails ? "Humidity: \(value)" : value
                
            case .windSpeed:
                let windSpeed = weather.current.windSpeed10m
                let value = formatWindSpeed(windSpeed)
                label += ", "
                label += isDetails ? "Wind Speed: \(value)" : value
                
            case .windDirection:
                let windDir = weather.current.windDirection10m
                let value = formatWindDirection(windDir)
                label += ", "
                label += isDetails ? "Wind Direction: \(value)" : value
                
            case .highTemp:
                if let daily = weather.daily, !daily.temperature2mMax.isEmpty {
                    let maxTemp = daily.temperature2mMax[0]
                    let value = formatTemperature(maxTemp)
                    label += ", "
                    label += isDetails ? "High: \(value)" : value
                }
                
            case .lowTemp:
                if let daily = weather.daily, !daily.temperature2mMin.isEmpty {
                    let minTemp = daily.temperature2mMin[0]
                    let value = formatTemperature(minTemp)
                    label += ", "
                    label += isDetails ? "Low: \(value)" : value
                }
                
            case .sunrise:
                if let daily = weather.daily, !daily.sunrise.isEmpty {
                    let sunrise = daily.sunrise[0]
                    let value = FormatHelper.formatTime(sunrise)
                    label += ", "
                    label += isDetails ? "Sunrise: \(value)" : value
                }
                
            case .sunset:
                if let daily = weather.daily, !daily.sunset.isEmpty {
                    let sunset = daily.sunset[0]
                    let value = FormatHelper.formatTime(sunset)
                    label += ", "
                    label += isDetails ? "Sunset: \(value)" : value
                }
            }
        }
        
        return label
    }
    
    private func formatTemperature(_ celsius: Double) -> String {
        let temp = settingsManager.settings.temperatureUnit.convert(celsius)
        return String(format: "%.0f%@", temp, settingsManager.settings.temperatureUnit.rawValue)
    }
    
    private func formatWindSpeed(_ kmh: Double) -> String {
        let speed = settingsManager.settings.windSpeedUnit.convert(kmh)
        return String(format: "%.0f %@", speed, settingsManager.settings.windSpeedUnit.rawValue)
    }
    
    private func formatWindDirection(_ degrees: Int) -> String {
        let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let index = Int((Double(degrees) + 22.5) / 45.0) % 8
        return directions[index]
    }
}

#Preview {
    ListView(
        cities: [
            City(id: UUID(), name: "San Diego", displayName: "San Diego, California", latitude: 32.7157, longitude: -117.1611)
        ],
        selectedCity: .constant(nil)
    )
    .environmentObject(SettingsManager())
}
