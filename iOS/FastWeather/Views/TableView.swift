//
//  TableView.swift
//  FastWeather
//
//  Table view for displaying weather data in a compact tabular format
//

import SwiftUI

struct TableView: View {
    @EnvironmentObject var weatherService: WeatherService
    @EnvironmentObject var settingsManager: SettingsManager
    
    var body: some View {
        List {
            ForEach(weatherService.savedCities) { city in
                NavigationLink(destination: CityDetailView(city: city)) {
                    TableRowView(city: city)
                }
                .accessibilityElement(children: .combine)
                .accessibilityAction(named: "Remove") {
                    weatherService.removeCity(city)
                }
            }
            .onMove(perform: weatherService.moveCity)
            .onDelete(perform: deleteCities)
        }
        .listStyle(.insetGrouped)
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
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        if settingsManager.settings.showTemperature {
                            CompactWeatherItem(
                                label: "Temp",
                                value: formatTemperature(weather.current.temperature2m)
                            )
                        }
                        
                        if settingsManager.settings.showConditions,
                           let weatherCode = weather.current.weatherCodeEnum {
                            CompactWeatherItem(
                                label: "Conditions",
                                value: weatherCode.description
                            )
                        }
                        
                        if settingsManager.settings.showFeelsLike {
                            CompactWeatherItem(
                                label: "Feels",
                                value: formatTemperature(weather.current.apparentTemperature)
                            )
                        }
                        
                        if settingsManager.settings.showHumidity {
                            CompactWeatherItem(
                                label: "Humidity",
                                value: "\(weather.current.relativeHumidity2m)%"
                            )
                        }
                        
                        if settingsManager.settings.showWindSpeed {
                            CompactWeatherItem(
                                label: "Wind",
                                value: formatWindSpeed(weather.current.windSpeed10m)
                            )
                        }
                        
                        if settingsManager.settings.showWindDirection {
                            CompactWeatherItem(
                                label: "Direction",
                                value: formatWindDirection(weather.current.windDirection10m)
                            )
                        }
                        
                        if settingsManager.settings.showHighTemp,
                           let daily = weather.daily,
                           !daily.temperature2mMax.isEmpty {
                            CompactWeatherItem(
                                label: "High",
                                value: formatTemperature(daily.temperature2mMax[0])
                            )
                        }
                        
                        if settingsManager.settings.showLowTemp,
                           let daily = weather.daily,
                           !daily.temperature2mMin.isEmpty {
                            CompactWeatherItem(
                                label: "Low",
                                value: formatTemperature(daily.temperature2mMin[0])
                            )
                        }
                        
                        if settingsManager.settings.showSunrise,
                           let daily = weather.daily,
                           !daily.sunrise.isEmpty {
                            CompactWeatherItem(
                                label: "Sunrise",
                                value: formatTime(daily.sunrise[0])
                            )
                        }
                        
                        if settingsManager.settings.showSunset,
                           let daily = weather.daily,
                           !daily.sunset.isEmpty {
                            CompactWeatherItem(
                                label: "Sunset",
                                value: formatTime(daily.sunset[0])
                            )
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
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

#Preview {
    TableView()
        .environmentObject(WeatherService())
        .environmentObject(SettingsManager())
}
