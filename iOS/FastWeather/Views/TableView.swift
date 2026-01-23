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
    @Binding var selectedCityForHistory: City?
    
    var body: some View {
        List {
            ForEach(weatherService.savedCities.indices, id: \.self) { index in
                let city = weatherService.savedCities[index]
                NavigationLink(destination: CityDetailView(city: city)) {
                    TableRowView(city: city)
                }
                .accessibilityElement(children: .combine)
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
                .accessibilityAction(named: "View Historical Weather") {
                    viewHistoricalWeather(for: city)
                }
                .contextMenu {
                    contextMenuContent(for: city, at: index)
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
        for index in offsets {
            let cityName = weatherService.savedCities[index].displayName
            weatherService.removeCity(weatherService.savedCities[index])
            UIAccessibility.post(notification: .announcement, argument: "Removed \(cityName)")
        }
    }
    
    private func viewHistoricalWeather(for city: City) {
        selectedCityForHistory = city
        UIAccessibility.post(notification: .announcement, argument: "Opening historical weather for \(city.displayName)")
    }
    
    @ViewBuilder
    private func contextMenuContent(for city: City, at index: Int) -> some View {
        Button(role: .destructive, action: {
            weatherService.removeCity(city)
        }) {
            Label("Remove City", systemImage: "trash")
        }
        
        if index > 0 {
            Button(action: {
                moveCityUp(at: index)
            }) {
                Label("Move Up", systemImage: "arrow.up")
            }
        }
        
        if index < weatherService.savedCities.count - 1 {
            Button(action: {
                moveCityDown(at: index)
            }) {
                Label("Move Down", systemImage: "arrow.down")
            }
        }
        
        Button(action: {
            viewHistoricalWeather(for: city)
        }) {
            Label("View Historical Weather", systemImage: "calendar")
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
            guard let apparentTemp = weather.current.apparentTemperature else { return nil }
            return (showLabel ? "Feels Like" : "", formatTemperature(apparentTemp))
            
        case .humidity:
            guard let humidity = weather.current.relativeHumidity2m else { return nil }
            return (showLabel ? "Humidity" : "", "\(humidity)%")
            
        case .windSpeed:
            guard let windSpeed = weather.current.windSpeed10m else { return nil }
            return (showLabel ? "Wind Speed" : "", formatWindSpeed(windSpeed))
            
        case .windDirection:
            guard let windDir = weather.current.windDirection10m else { return nil }
            return (showLabel ? "Wind Direction" : "", formatWindDirection(windDir))
            
        case .highTemp:
            guard let daily = weather.daily, !daily.temperature2mMax.isEmpty, let maxTemp = daily.temperature2mMax[0] else { return nil }
            return (showLabel ? "High" : "", formatTemperature(maxTemp))
            
        case .lowTemp:
            guard let daily = weather.daily, !daily.temperature2mMin.isEmpty, let minTemp = daily.temperature2mMin[0] else { return nil }
            return (showLabel ? "Low" : "", formatTemperature(minTemp))
            
        case .sunrise:
            guard let daily = weather.daily, let sunriseArray = daily.sunrise, !sunriseArray.isEmpty, let sunrise = sunriseArray[0] else { return nil }
            return (showLabel ? "Sunrise" : "", formatTime(sunrise))
            
        case .sunset:
            guard let daily = weather.daily, let sunsetArray = daily.sunset, !sunsetArray.isEmpty, let sunset = sunsetArray[0] else { return nil }
            return (showLabel ? "Sunset" : "", formatTime(sunset))
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
        guard let date = DateParser.parse(isoString) else { return isoString }
        
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
    TableView(selectedCityForHistory: .constant(nil))
        .environmentObject(WeatherService())
        .environmentObject(SettingsManager())
}
