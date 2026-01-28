//
//  FlatView.swift
//  FastWeatherMac
//
//  Sectioned list view for displaying all weather details inline
//  Adapted from iOS implementation for macOS
//

import SwiftUI

struct FlatView: View {
    let cities: [City]
    @Binding var selectedCity: City?
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var weatherCache: [UUID: WeatherResponse] = [:]
    
    var body: some View {
        List(selection: $selectedCity) {
            ForEach(cities) { city in
                Section {
                    // Weather detail rows
                    if let weather = weatherCache[city.id] {
                        weatherDetailRows(for: weather)
                    } else {
                        HStack {
                            Spacer()
                            ProgressView("Loading...")
                            Spacer()
                        }
                    }
                } header: {
                    cityHeader(for: city)
                }
                .tag(city)
                .task(id: city.id) {
                    await loadWeather(for: city)
                }
            }
        }
        .listStyle(.inset)
    }
    
    @ViewBuilder
    private func cityHeader(for city: City) -> some View {
        if let weather = weatherCache[city.id] {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(city.displayName)
                    .font(.headline)
                
                Spacer()
                
                Text(formatTemperature(weather.current.temperature2m))
                    .font(.title2.weight(.semibold))
            }
            .textCase(nil)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(city.displayName), \(formatTemperature(weather.current.temperature2m))")
        } else {
            Text(city.displayName)
                .font(.headline)
                .textCase(nil)
        }
    }
    
    @ViewBuilder
    private func weatherDetailRows(for weather: WeatherResponse) -> some View {
        let enabledFields = settingsManager.settings.weatherFields.filter { $0.isEnabled }
        
        ForEach(enabledFields) { field in
            if let (label, value) = getFieldLabelAndValue(for: field.type, weather: weather) {
                HStack {
                    Text(label)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(value)
                        .fontWeight(.regular)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(label): \(value)")
            }
        }
    }
    
    private func getFieldLabelAndValue(for field: WeatherFieldType, weather: WeatherResponse) -> (String, String)? {
        switch field {
        case .temperature:
            return ("Temperature", formatTemperature(weather.current.temperature2m))
            
        case .conditions:
            guard let weatherCode = weather.current.weatherCodeEnum else { return nil }
            return ("Conditions", weatherCode.description)
            
        case .feelsLike:
            let apparentTemp = weather.current.apparentTemperature
            return ("Feels Like", formatTemperature(apparentTemp))
            
        case .humidity:
            let humidity = weather.current.relativeHumidity2m
            return ("Humidity", "\(humidity)%")
            
        case .windSpeed:
            let windSpeed = weather.current.windSpeed10m
            return ("Wind Speed", formatWindSpeed(windSpeed))
            
        case .windDirection:
            let windDir = weather.current.windDirection10m
            return ("Wind Direction", formatWindDirection(windDir))
            
        case .highTemp:
            guard let daily = weather.daily, !daily.temperature2mMax.isEmpty else { return nil }
            let maxTemp = daily.temperature2mMax[0]
            return ("High", formatTemperature(maxTemp))
            
        case .lowTemp:
            guard let daily = weather.daily, !daily.temperature2mMin.isEmpty else { return nil }
            let minTemp = daily.temperature2mMin[0]
            return ("Low", formatTemperature(minTemp))
            
        case .sunrise:
            guard let daily = weather.daily, !daily.sunrise.isEmpty else { return nil }
            let sunrise = daily.sunrise[0]
            return ("Sunrise", FormatHelper.formatTime(sunrise))
            
        case .sunset:
            guard let daily = weather.daily, !daily.sunset.isEmpty else { return nil }
            let sunset = daily.sunset[0]
            return ("Sunset", FormatHelper.formatTime(sunset))
        }
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
