//
//  FlatView.swift
//  Fast Weather
//
//  Sectioned list view for displaying weather
//

import SwiftUI

struct FlatView: View {
    @EnvironmentObject var weatherService: WeatherService
    @EnvironmentObject var settingsManager: SettingsManager
    @Binding var selectedCityForHistory: City?
    @Binding var selectedCityForDetail: City?
    
    var body: some View {
        List {
            ForEach(weatherService.savedCities.indices, id: \.self) { index in
                let city = weatherService.savedCities[index]
                citySection(for: city, at: index)
            }
        }
        .listStyle(.grouped)
    }
    
    @ViewBuilder
    private func citySection(for city: City, at index: Int) -> some View {
        Section {
            // Weather detail rows
            if let weather = weatherService.weatherCache[city.id] {
                weatherDetailRows(for: weather)
            } else {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
            }
            
            // Actions button
            actionsMenu(for: city, at: index)
        } header: {
            cityHeader(for: city)
        }
    }
    
    @ViewBuilder
    private func cityHeader(for city: City) -> some View {
        if let weather = weatherService.weatherCache[city.id] {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(city.displayName)
                        .font(.headline)
                    
                    // UV Index badge (only during daytime)
                    if settingsManager.settings.showUVIndexInCityList,
                       let isDay = weather.current.isDay, isDay == 1,
                       let uvIndex = weather.current.uvIndex {
                        UVBadge(uvIndex: uvIndex)
                    }
                }
                
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
    private func weatherDetailRows(for weather: WeatherData) -> some View {
        let enabledFields = settingsManager.settings.weatherFields.filter { $0.isEnabled }
        // Flat view always shows labels (details mode)
        let isDetails = true
        
        ForEach(enabledFields) { field in
            if let (label, value) = getFieldLabelAndValue(for: field.type, weather: weather, showLabel: isDetails) {
                HStack {
                    if isDetails && !label.isEmpty {
                        Text(label)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    Text(value)
                        .fontWeight(isDetails ? .regular : .medium)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(label.isEmpty ? value : "\(label): \(value)")
            }
        }
    }
    
    @ViewBuilder
    private func actionsMenu(for city: City, at index: Int) -> some View {
        Menu {
            Button(action: {
                selectedCityForDetail = city
            }) {
                Label("Full Details", systemImage: "info.circle")
            }
            
            Button(action: {
                viewHistoricalWeather(for: city)
            }) {
                Label("Historical Weather", systemImage: "calendar")
            }
            
            Divider()
            
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
            
            if index > 0 {
                Button(action: {
                    moveCityToTop(at: index)
                }) {
                    Label("Move to Top", systemImage: "arrow.up.to.line")
                }
            }
            
            if index < weatherService.savedCities.count - 1 {
                Button(action: {
                    moveCityToBottom(at: index)
                }) {
                    Label("Move to Bottom", systemImage: "arrow.down.to.line")
                }
            }
            
            Divider()
            
            Button(role: .destructive, action: {
                withAnimation {
                    weatherService.removeCity(city)
                }
            }) {
                Label("Remove City", systemImage: "trash")
            }
        } label: {
            HStack {
                Spacer()
                Text("Actions")
                    .foregroundColor(.accentColor)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .listRowBackground(Color(.secondarySystemGroupedBackground))
        .accessibilityLabel("Actions for \(city.displayName)")
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
        guard let date = DateParser.parse(isoString) else { return isoString }
        
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        return timeFormatter.string(from: date)
    }
    
// MARK: - Actions
    
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

#Preview {
    FlatView(selectedCityForHistory: .constant(nil), selectedCityForDetail: .constant(nil))
        .environmentObject(WeatherService())
        .environmentObject(SettingsManager())
}
