//
//  ListView.swift
//  Weather Fast
//
//  Compact list view for displaying weather
//

import SwiftUI

struct ListView: View {
    @EnvironmentObject var weatherService: WeatherService
    @EnvironmentObject var settingsManager: SettingsManager
    
    var body: some View {
        List {
            ForEach(weatherService.savedCities.indices, id: \.self) { index in
                let city = weatherService.savedCities[index]
                NavigationLink(destination: CityDetailView(city: city)) {
                    ListRowView(city: city)
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
            
            if let weather = weather,
               settingsManager.settings.showTemperature {
                Text(formatTemperature(weather.current.temperature2m))
                    .font(.title3)
                    .fontWeight(.semibold)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func buildWeatherSummary(_ weather: WeatherData) -> String {
        var parts: [String] = []
        
        if settingsManager.settings.showConditions,
           let weatherCode = weather.current.weatherCodeEnum {
            parts.append(weatherCode.description)
        }
        
        if settingsManager.settings.showFeelsLike {
            parts.append("Feels: \(formatTemperature(weather.current.apparentTemperature))")
        }
        
        if settingsManager.settings.showHumidity {
            parts.append("Humidity: \(weather.current.relativeHumidity2m)%")
        }
        
        if settingsManager.settings.showWindSpeed {
            parts.append("Wind: \(formatWindSpeed(weather.current.windSpeed10m))")
        }
        
        if settingsManager.settings.showHighTemp,
           let daily = weather.daily,
           !daily.temperature2mMax.isEmpty {
            parts.append("High: \(formatTemperature(daily.temperature2mMax[0]))")
        }
        
        if settingsManager.settings.showLowTemp,
           let daily = weather.daily,
           !daily.temperature2mMin.isEmpty {
            parts.append("Low: \(formatTemperature(daily.temperature2mMin[0]))")
        }
        
        return parts.joined(separator: " • ")
    }
    
    private func formatTemperature(_ celsius: Double) -> String {
        let temp = settingsManager.settings.temperatureUnit.convert(celsius)
        return String(format: "%.0f%@", temp, settingsManager.settings.temperatureUnit.rawValue)
    }
    
    private func formatWindSpeed(_ kmh: Double) -> String {
        let speed = settingsManager.settings.windSpeedUnit.convert(kmh)
        return String(format: "%.0f %@", speed, settingsManager.settings.windSpeedUnit.rawValue)
    }
}

#Preview {
    ListView()
        .environmentObject(WeatherService())
        .environmentObject(SettingsManager())
}
