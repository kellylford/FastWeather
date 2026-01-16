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
            ForEach(weatherService.savedCities) { city in
                NavigationLink(destination: CityDetailView(city: city)) {
                    ListRowView(city: city)
                }
                .accessibilityElement(children: .combine)
                .accessibilityAction(named: "Remove") {
                    weatherService.removeCity(city)
                }
            }
            .onMove(perform: weatherService.moveCity)
            .onDelete(perform: deleteCities)
        }
        .listStyle(.plain)
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
