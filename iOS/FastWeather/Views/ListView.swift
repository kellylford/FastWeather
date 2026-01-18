//
//  ListView.swift
//  Fast Weather
//
//  Compact list view for displaying weather
//

import SwiftUI

struct ListView: View {
    @EnvironmentObject var weatherService: WeatherService
    @EnvironmentObject var settingsManager: SettingsManager
    @Environment(\.editMode) var editMode
    
    var body: some View {
        List {
            ForEach(weatherService.savedCities.indices, id: \.self) { index in
                let city = weatherService.savedCities[index]
                NavigationLink(destination: CityDetailView(city: city)) {
                    ListRowView(city: city)
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(editMode?.wrappedValue.isEditing == true ? [.allowsDirectInteraction] : [])
                .accessibilityAction(named: "Remove") {
                    weatherService.removeCity(city)
                }
                .accessibilityAction(named: "Move Up") {
                    moveCityUp(at: index)
                }
                .accessibilityAction(named: "Move Down") {
                    moveCityDown(at: index)
                }
                .accessibilityAction(named: "Move to Top") {
                    moveCityToTop(at: index)
                }
                .accessibilityAction(named: "Move to Bottom") {
                    moveCityToBottom(at: index)
                }
            }
            .onMove(perform: weatherService.moveCity)
            .onDelete(perform: deleteCities)
        }
        .listStyle(.plain)
    }
    
    private func moveCityUp(at index: Int) {
        guard index > 0 else { return }
        let cityName = weatherService.savedCities[index].displayName
        let aboveCityName = weatherService.savedCities[index - 1].displayName
        weatherService.moveCity(from: IndexSet(integer: index), to: index - 1)
        UIAccessibility.post(notification: .announcement, argument: "Moved \(cityName) above \(aboveCityName)")
    }
    
    private func moveCityDown(at index: Int) {
        guard index < weatherService.savedCities.count - 1 else { return }
        let cityName = weatherService.savedCities[index].displayName
        let belowCityName = weatherService.savedCities[index + 1].displayName
        weatherService.moveCity(from: IndexSet(integer: index), to: index + 2)
        UIAccessibility.post(notification: .announcement, argument: "Moved \(cityName) below \(belowCityName)")
    }
    
    private func moveCityToTop(at index: Int) {
        guard index > 0 else { return }
        let cityName = weatherService.savedCities[index].displayName
        weatherService.moveCity(from: IndexSet(integer: index), to: 0)
        UIAccessibility.post(notification: .announcement, argument: "Moved \(cityName) to top of list")
    }
    
    private func moveCityToBottom(at index: Int) {
        guard index < weatherService.savedCities.count - 1 else { return }
        let cityName = weatherService.savedCities[index].displayName
        weatherService.moveCity(from: IndexSet(integer: index), to: weatherService.savedCities.count)
        UIAccessibility.post(notification: .announcement, argument: "Moved \(cityName) to bottom of list")
    }
    
    private func deleteCities(at offsets: IndexSet) {
        offsets.forEach { index in
            let city = weatherService.savedCities[index]
            weatherService.removeCity(city)
        }
    }
}

struct ListRowView: View {
    @EnvironmentObject var weatherService: WeatherService
    @EnvironmentObject var settingsManager: SettingsManager
    let city: City
    
    private var weather: WeatherData? {
        weatherService.weatherCache[city.id]
    }
    
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
            
            // Show temperature on right side if it's enabled
            if let weather = weather,
               settingsManager.settings.weatherFields.first(where: { $0.type == .temperature })?.isEnabled == true {
                Text(formatTemperature(weather.current.temperature2m))
                    .font(.title3)
                    .fontWeight(.semibold)
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(buildAccessibilityLabel())
    }
    
    private func buildWeatherSummary(_ weather: WeatherData) -> String {
        var parts: [String] = []
        let isDetails = settingsManager.settings.displayMode == .details
        
        // Use the ordered and filtered weather fields from settings
        for field in settingsManager.settings.weatherFields where field.isEnabled {
            switch field.type {
            case .temperature:
                // Skip temperature in summary since it's shown separately on the right
                break
                
            case .conditions:
                if let weatherCode = weather.current.weatherCodeEnum {
                    parts.append(isDetails ? "Conditions: \(weatherCode.description)" : weatherCode.description)
                }
                
            case .feelsLike:
                let value = formatTemperature(weather.current.apparentTemperature)
                parts.append(isDetails ? "Feels Like: \(value)" : value)
                
            case .humidity:
                let value = "\(weather.current.relativeHumidity2m)%"
                parts.append(isDetails ? "Humidity: \(value)" : value)
                
            case .windSpeed:
                let value = formatWindSpeed(weather.current.windSpeed10m)
                parts.append(isDetails ? "Wind Speed: \(value)" : value)
                
            case .windDirection:
                let value = formatWindDirection(weather.current.windDirection10m)
                parts.append(isDetails ? "Wind Direction: \(value)" : value)
                
            case .highTemp:
                if let daily = weather.daily, !daily.temperature2mMax.isEmpty {
                    let value = formatTemperature(daily.temperature2mMax[0])
                    parts.append(isDetails ? "High: \(value)" : value)
                }
                
            case .lowTemp:
                if let daily = weather.daily, !daily.temperature2mMin.isEmpty {
                    let value = formatTemperature(daily.temperature2mMin[0])
                    parts.append(isDetails ? "Low: \(value)" : value)
                }
                
            case .sunrise:
                if let daily = weather.daily, !daily.sunrise.isEmpty {
                    let value = formatTime(daily.sunrise[0])
                    parts.append(isDetails ? "Sunrise: \(value)" : value)
                }
                
            case .sunset:
                if let daily = weather.daily, !daily.sunset.isEmpty {
                    let value = formatTime(daily.sunset[0])
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
        
        // Start with city name, then temperature
        var label = "\(city.displayName), \(formatTemperature(weather.current.temperature2m))"
        
        // Add all other weather details in order
        let isDetails = settingsManager.settings.displayMode == .details
        
        for field in settingsManager.settings.weatherFields where field.isEnabled {
            switch field.type {
            case .temperature:
                // Already added after city name
                break
                
            case .conditions:
                if let weatherCode = weather.current.weatherCodeEnum {
                    label += ", "
                    label += isDetails ? "Conditions: \(weatherCode.description)" : weatherCode.description
                }
                
            case .feelsLike:
                let value = formatTemperature(weather.current.apparentTemperature)
                label += ", "
                label += isDetails ? "Feels Like: \(value)" : value
                
            case .humidity:
                let value = "\(weather.current.relativeHumidity2m)%"
                label += ", "
                label += isDetails ? "Humidity: \(value)" : value
                
            case .windSpeed:
                let value = formatWindSpeed(weather.current.windSpeed10m)
                label += ", "
                label += isDetails ? "Wind Speed: \(value)" : value
                
            case .windDirection:
                let value = formatWindDirection(weather.current.windDirection10m)
                label += ", "
                label += isDetails ? "Wind Direction: \(value)" : value
                
            case .highTemp:
                if let daily = weather.daily, !daily.temperature2mMax.isEmpty {
                    let value = formatTemperature(daily.temperature2mMax[0])
                    label += ", "
                    label += isDetails ? "High: \(value)" : value
                }
                
            case .lowTemp:
                if let daily = weather.daily, !daily.temperature2mMin.isEmpty {
                    let value = formatTemperature(daily.temperature2mMin[0])
                    label += ", "
                    label += isDetails ? "Low: \(value)" : value
                }
                
            case .sunrise:
                if let daily = weather.daily, !daily.sunrise.isEmpty {
                    let value = formatTime(daily.sunrise[0])
                    label += ", "
                    label += isDetails ? "Sunrise: \(value)" : value
                }
                
            case .sunset:
                if let daily = weather.daily, !daily.sunset.isEmpty {
                    let value = formatTime(daily.sunset[0])
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
    
    private func formatTime(_ isoString: String) -> String {
        FormatHelper.formatTime(isoString)
    }
}

#Preview {
    ListView()
        .environmentObject(WeatherService())
        .environmentObject(SettingsManager())
}
