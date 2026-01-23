//
//  FlatView.swift
//  Fast Weather
//
//  Card-based flat view for displaying weather
//

import SwiftUI

struct FlatView: View {
    @EnvironmentObject var weatherService: WeatherService
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var selectedCityForHistory: City?
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(weatherService.savedCities.indices, id: \.self) { index in
                    let city = weatherService.savedCities[index]
                    NavigationLink(destination: CityDetailView(city: city)) {
                        CityCardView(city: city)
                    }
                    .buttonStyle(PlainButtonStyle())
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
                    .accessibilityAction(named: "View Historical Weather") {
                        viewHistoricalWeather(for: city)
                    }
                }
            }
            .padding()
            .background(
                NavigationLink(
                    destination: selectedCityForHistory.map { city in
                        HistoricalWeatherView(city: city)
                            .navigationTitle("Historical Weather")
                            .navigationBarTitleDisplayMode(.inline)
                    },
                    isActive: Binding(
                        get: { selectedCityForHistory != nil },
                        set: { if !$0 { selectedCityForHistory = nil } }
                    )
                ) {
                    EmptyView()
                }
                .hidden()
            )
        }
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
    
    private func viewHistoricalWeather(for city: City) {
        selectedCityForHistory = city
        UIAccessibility.post(notification: .announcement, argument: "Opening historical weather for \(city.displayName)")
    }
}

struct CityCardView: View {
    @EnvironmentObject var weatherService: WeatherService
    @EnvironmentObject var settingsManager: SettingsManager
    let city: City
    
    private var weather: WeatherData? {
        weatherService.weatherCache[city.id]
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text(city.displayName)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Menu {
                    Button(role: .destructive, action: {
                        weatherService.removeCity(city)
                    }) {
                        Label("Remove", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.secondary)
                }
                .accessibilityLabel("Options for \(city.displayName)")
            }
            
            if let weather = weather {
                // Weather Summary
                HStack(alignment: .top, spacing: 20) {
                    // Temperature and condition
                    VStack(alignment: .leading, spacing: 4) {
                        // Check if temperature should be shown
                        if let tempField = settingsManager.settings.weatherFields.first(where: { $0.type == .temperature }),
                           tempField.isEnabled {
                            Text(formatTemperature(weather.current.temperature2m))
                                .font(.system(size: 48, weight: .bold))
                                .accessibilityLabel(formatTemperature(weather.current.temperature2m))
                        }
                        
                        // Check if conditions should be shown
                        if let condField = settingsManager.settings.weatherFields.first(where: { $0.type == .conditions }),
                           condField.isEnabled,
                           let weatherCode = weather.current.weatherCodeEnum {
                            HStack(spacing: 8) {
                                Image(systemName: weatherCode.systemImageName)
                                    .font(.title2)
                                Text(weatherCode.description)
                                    .font(.body)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel(weatherCode.description)
                        }
                    }
                    
                    Spacer()
                }
                
                // Weather Details Grid - using ordered fields from settings
                let enabledFields = settingsManager.settings.weatherFields.filter { $0.isEnabled && $0.type != .temperature && $0.type != .conditions }
                let isDetails = settingsManager.settings.displayMode == .details
                
                if !enabledFields.isEmpty {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(enabledFields) { field in
                            if let (label, value) = getFieldLabelAndValue(for: field.type, weather: weather, showLabel: isDetails) {
                                WeatherDetailItem(label: label, value: value)
                            }
                        }
                    }
                }
            } else {
                ProgressView("Loading weather...")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    private func formatTemperature(_ celsius: Double) -> String {
        let temp = settingsManager.settings.temperatureUnit.convert(celsius)
        return String(format: "%.0f%@", temp, settingsManager.settings.temperatureUnit.rawValue)
    }
    
    private func getFieldLabelAndValue(for fieldType: WeatherFieldType, weather: WeatherData, showLabel: Bool) -> (String, String)? {
        switch fieldType {
        case .temperature, .conditions:
            return nil
            
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
        return "\(directions[index]) (\(degrees)°)"
    }
    
    private func formatTime(_ isoString: String) -> String {
        guard let date = DateParser.parse(isoString) else { return isoString }
        
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        return timeFormatter.string(from: date)
    }
}

struct WeatherDetailItem: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !label.isEmpty {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.body)
                .fontWeight(.medium)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label.isEmpty ? value : "\(label): \(value)")
    }
}

#Preview {
    FlatView()
        .environmentObject(WeatherService())
        .environmentObject(SettingsManager())
}
