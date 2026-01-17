//
//  TableView.swift
//  Fast Weather
//
//  Table view for displaying weather data in a compact tabular format
//

import SwiftUI

struct TableView: View {
    @EnvironmentObject var weatherService: WeatherService
    @EnvironmentObject var settingsManager: SettingsManager
    
    var body: some View {
        List {
            ForEach(weatherService.savedCities.indices, id: \.self) { index in
                let city = weatherService.savedCities[index]
                NavigationLink(destination: CityDetailView(city: city)) {
                    TableRowView(city: city)
                }
                .accessibilityElement(children: .combine)
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
        .listStyle(.insetGrouped)
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

struct TableRowView: View {
    @EnvironmentObject var weatherService: WeatherService
    @EnvironmentObject var settingsManager: SettingsManager
    let city: City
    
    private var weather: WeatherData? {
        weatherService.weatherCache[city.id]
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(city.displayName)
                .font(.headline)
            
            if let weather = weather {
                let isDetails = settingsManager.settings.displayMode == .details
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(settingsManager.settings.weatherFields.filter { $0.isEnabled }) { field in
                            if let (label, value) = getFieldLabelAndValue(for: field.type, weather: weather, showLabel: isDetails) {
                                CompactWeatherItem(label: label, value: value)
                            }
                        }
                    }
                }
            } else {
                ProgressView("Loading...")
                    .progressViewStyle(.circular)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatTemperature(_ celsius: Double) -> String {
        let temp = settingsManager.settings.temperatureUnit.convert(celsius)
        return String(format: "%.0f%@", temp, settingsManager.settings.temperatureUnit.rawValue)
    }
    
    private func getFieldLabelAndValue(for fieldType: WeatherFieldType, weather: WeatherData, showLabel: Bool) -> (String, String)? {
        switch fieldType {
        case .temperature:
            return (showLabel ? "Temperature" : "", formatTemperature(weather.current.temperature2m))
            
        case .conditions:
            guard let weatherCode = weather.current.weatherCodeEnum else { return nil }
            return (showLabel ? "Conditions" : "", weatherCode.description)
            
        case .feelsLike:
            return (showLabel ? "Feels Like" : "", formatTemperature(weather.current.apparentTemperature))
            
        case .humidity:
            return (showLabel ? "Humidity" : "", "\(weather.current.relativeHumidity2m)%")
            
        case .windSpeed:
            return (showLabel ? "Wind Speed" : "", formatWindSpeed(weather.current.windSpeed10m))
            
        case .windDirection:
            return (showLabel ? "Wind Direction" : "", formatWindDirection(weather.current.windDirection10m))
            
        case .highTemp:
            guard let daily = weather.daily, !daily.temperature2mMax.isEmpty else { return nil }
            return (showLabel ? "High" : "", formatTemperature(daily.temperature2mMax[0]))
            
        case .lowTemp:
            guard let daily = weather.daily, !daily.temperature2mMin.isEmpty else { return nil }
            return (showLabel ? "Low" : "", formatTemperature(daily.temperature2mMin[0]))
            
        case .sunrise:
            guard let daily = weather.daily, !daily.sunrise.isEmpty else { return nil }
            return (showLabel ? "Sunrise" : "", formatTime(daily.sunrise[0]))
            
        case .sunset:
            guard let daily = weather.daily, !daily.sunset.isEmpty else { return nil }
            return (showLabel ? "Sunset" : "", formatTime(daily.sunset[0]))
        }
    }
    
    private func formatWindSpeed(_ kmh: Double) -> String {
        let speed = settingsManager.settings.windSpeedUnit.convert(kmh)
        return String(format: "%.0f %@", speed, settingsManager.settings.windSpeedUnit.rawValue)
    }
    
    private func formatWindDirection(_ degrees: Int) -> String {
        let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let index = Int((Double(degrees) / 45.0).rounded()) % 8
        return directions[index]
    }
    
    private func formatTime(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: isoString) else { return isoString }
        
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        return timeFormatter.string(from: date)
    }
}

struct CompactWeatherItem: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if !label.isEmpty {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label.isEmpty ? value : "\(label): \(value)")
    }
}

#Preview {
    TableView()
        .environmentObject(WeatherService())
        .environmentObject(SettingsManager())
}
