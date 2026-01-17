//
//  FlatView.swift
//  Weather Fast
//
//  Card-based flat view for displaying weather
//

import SwiftUI

struct FlatView: View {
    @EnvironmentObject var weatherService: WeatherService
    @EnvironmentObject var settingsManager: SettingsManager
    
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
                }
            }
            .padding()
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
                        if settingsManager.settings.showTemperature {
                            Text(formatTemperature(weather.current.temperature2m))
                                .font(.system(size: 48, weight: .bold))
                                .accessibilityLabel(formatTemperature(weather.current.temperature2m))
                        }
                        
                        if settingsManager.settings.showConditions,
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
                
                // Weather Details Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    if settingsManager.settings.showFeelsLike {
                        WeatherDetailItem(
                            label: "Feels Like",
                            value: formatTemperature(weather.current.apparentTemperature)
                        )
                    }
                    
                    if settingsManager.settings.showHumidity {
                        WeatherDetailItem(
                            label: "Humidity",
                            value: "\(weather.current.relativeHumidity2m)%"
                        )
                    }
                    
                    if settingsManager.settings.showWindSpeed {
                        WeatherDetailItem(
                            label: "Wind Speed",
                            value: formatWindSpeed(weather.current.windSpeed10m)
                        )
                    }
                    
                    if settingsManager.settings.showWindDirection {
                        WeatherDetailItem(
                            label: "Wind Direction",
                            value: formatWindDirection(weather.current.windDirection10m)
                        )
                    }
                    
                    if settingsManager.settings.showHighTemp,
                       let daily = weather.daily,
                       !daily.temperature2mMax.isEmpty {
                        WeatherDetailItem(
                            label: "High",
                            value: formatTemperature(daily.temperature2mMax[0])
                        )
                    }
                    
                    if settingsManager.settings.showLowTemp,
                       let daily = weather.daily,
                       !daily.temperature2mMin.isEmpty {
                        WeatherDetailItem(
                            label: "Low",
                            value: formatTemperature(daily.temperature2mMin[0])
                        )
                    }
                    
                    if settingsManager.settings.showSunrise,
                       let daily = weather.daily,
                       !daily.sunrise.isEmpty {
                        WeatherDetailItem(
                            label: "Sunrise",
                            value: formatTime(daily.sunrise[0])
                        )
                    }
                    
                    if settingsManager.settings.showSunset,
                       let daily = weather.daily,
                       !daily.sunset.isEmpty {
                        WeatherDetailItem(
                            label: "Sunset",
                            value: formatTime(daily.sunset[0])
                        )
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
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: isoString) else { return isoString }
        
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
            Text(value)
                .font(.body)
                .fontWeight(.medium)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(value)
    }
}

#Preview {
    FlatView()
        .environmentObject(WeatherService())
        .environmentObject(SettingsManager())
}
