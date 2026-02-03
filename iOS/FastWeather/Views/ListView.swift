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
    @Binding var selectedCityForHistory: City?
    @State private var alertSheetItem: AlertSheetItem?  // Stable sheet item to prevent re-presentation loop
    
    var body: some View {
        List {
            ForEach(weatherService.savedCities.indices, id: \.self) { index in
                let city = weatherService.savedCities[index]
                cityRow(for: city, at: index)
            }
            .onMove(perform: weatherService.moveCity)
            .onDelete(perform: deleteCities)
        }
        .listStyle(.plain)
        .sheet(item: $alertSheetItem) { item in
            AlertDetailView(alert: item.alert)
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
    
    private func deleteCities(at offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let cityName = weatherService.savedCities[index].displayName
                weatherService.removeCity(weatherService.savedCities[index])
                UIAccessibility.post(notification: .announcement, argument: "Removed \(cityName)")
            }
        }
    }
    
    private func viewHistoricalWeather(for city: City) {
        selectedCityForHistory = city
        UIAccessibility.post(notification: .announcement, argument: "Opening historical weather for \(city.displayName)")
    }
    
    @ViewBuilder
    private func contextMenuContent(for city: City, at index: Int) -> some View {
        Button(role: .destructive, action: {
            withAnimation {
                weatherService.removeCity(city)
            }
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
    
    @ViewBuilder
    private func cityRow(for city: City, at index: Int) -> some View {
        NavigationLink(destination: CityDetailView(city: city)) {
            ListRowView(city: city, onAlertTap: { alert in
                // Create stable AlertSheetItem to prevent re-presentation loop
                alertSheetItem = AlertSheetItem(city: city, alert: alert)
            })
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(editMode?.wrappedValue.isEditing == true ? [.allowsDirectInteraction] : [])
        .accessibilityAction(named: "Remove") {
            withAnimation {
                weatherService.removeCity(city)
            }
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
        .contextMenu {
            contextMenuContent(for: city, at: index)
        }
    }
}

// MARK: - Alert Sheet Helper
struct AlertSheetItem: Identifiable, Equatable {
    let id = UUID()
    let city: City
    let alert: WeatherAlert
    
    static func == (lhs: AlertSheetItem, rhs: AlertSheetItem) -> Bool {
        // Two alert sheet items are equal if they show the same alert for the same city
        lhs.city.id == rhs.city.id && lhs.alert.id == rhs.alert.id
    }
}

struct ListRowView: View {
    @EnvironmentObject var weatherService: WeatherService
    @EnvironmentObject var settingsManager: SettingsManager
    let city: City
    let onAlertTap: (WeatherAlert) -> Void
    
    @State private var alerts: [WeatherAlert] = []
    @State private var hasLoadedAlerts = false
    
    private var weather: WeatherData? {
        weatherService.weatherCache[city.id]
    }
    
    private var highestSeverityAlert: WeatherAlert? {
        alerts.max(by: { $0.severity.rawValue < $1.severity.rawValue })
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
            
            // Alert badge (if any) - reserve space to prevent layout shift
            HStack(spacing: 8) {
                if let alert = highestSeverityAlert {
                    Button(action: {
                        onAlertTap(alert)
                    }) {
                        Image(systemName: alert.severity.iconName)
                            .foregroundColor(alert.severity.color)
                            .font(.title3)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Weather alert: \(alert.event)")
                    .accessibilityHint("Double tap to view alert details")
                    .transition(.scale.combined(with: .opacity))
                }
                
                VStack(alignment: .trailing, spacing: 4) {
                    // Show temperature on right side if it's enabled
                    if let weather = weather,
                       settingsManager.settings.weatherFields.first(where: { $0.type == .temperature })?.isEnabled == true {
                        Text(formatTemperature(weather.current.temperature2m))
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    
                    // UV Index badge (only during daytime)
                    if settingsManager.settings.showUVIndex,
                       let weather = weather,
                       let isDay = weather.current.isDay, isDay == 1,
                       let uvIndex = weather.current.uvIndex {
                        UVBadge(uvIndex: uvIndex)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(buildAccessibilityLabel())
        .animation(.easeInOut(duration: 0.2), value: highestSeverityAlert?.id)
        .task(id: city.id) {
            guard !hasLoadedAlerts else { return }
            hasLoadedAlerts = true
            
            do {
                alerts = try await weatherService.fetchNWSAlerts(for: city)
            } catch {
                print("Failed to fetch alerts for \(city.name): \(error)")
            }
        }
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
                if let apparentTemp = weather.current.apparentTemperature {
                    let value = formatTemperature(apparentTemp)
                    parts.append(isDetails ? "Feels Like: \(value)" : value)
                }
                
            case .humidity:
                if let humidity = weather.current.relativeHumidity2m {
                    let value = "\(humidity)%"
                    parts.append(isDetails ? "Humidity: \(value)" : value)
                }
                
            case .windSpeed:
                if let windSpeed = weather.current.windSpeed10m {
                    let value = formatWindSpeed(windSpeed)
                    parts.append(isDetails ? "Wind Speed: \(value)" : value)
                }
                
            case .windDirection:
                if let windDir = weather.current.windDirection10m {
                    let value = formatWindDirection(windDir)
                    parts.append(isDetails ? "Wind Direction: \(value)" : value)
                }
                
            case .highTemp:
                if let daily = weather.daily, !daily.temperature2mMax.isEmpty, let maxTemp = daily.temperature2mMax[0] {
                    let value = formatTemperature(maxTemp)
                    parts.append(isDetails ? "High: \(value)" : value)
                }
                
            case .lowTemp:
                if let daily = weather.daily, !daily.temperature2mMin.isEmpty, let minTemp = daily.temperature2mMin[0] {
                    let value = formatTemperature(minTemp)
                    parts.append(isDetails ? "Low: \(value)" : value)
                }
                
            case .sunrise:
                if let daily = weather.daily, let sunriseArray = daily.sunrise, !sunriseArray.isEmpty, let sunrise = sunriseArray[0] {
                    let value = formatTime(sunrise)
                    parts.append(isDetails ? "Sunrise: \(value)" : value)
                }
                
            case .sunset:
                if let daily = weather.daily, let sunsetArray = daily.sunset, !sunsetArray.isEmpty, let sunset = sunsetArray[0] {
                    let value = formatTime(sunset)
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
        
        // Add weather conditions first
        let isDetails = settingsManager.settings.displayMode == .details
        
        // Add conditions if enabled (should be early in announcement)
        if settingsManager.settings.weatherFields.first(where: { $0.type == .conditions && $0.isEnabled }) != nil,
           let weatherCode = weather.current.weatherCodeEnum {
            label += ", "
            label += isDetails ? "Conditions: \(weatherCode.description)" : weatherCode.description
        }
        
        // Add alert information after conditions
        if let alert = highestSeverityAlert {
            if alerts.count == 1 {
                label += ", Alert: \(alert.event)"
            } else {
                label += ", Alerts: \(alert.event) and \(alerts.count - 1) more"
            }
        }
        
        // Add remaining weather details in order
        for field in settingsManager.settings.weatherFields where field.isEnabled {
            switch field.type {
            case .temperature:
                // Already added after city name
                break
                
            case .conditions:
                // Already added before alerts
                break
                
            case .feelsLike:
                if let apparentTemp = weather.current.apparentTemperature {
                    let value = formatTemperature(apparentTemp)
                    label += ", "
                    label += isDetails ? "Feels Like: \(value)" : value
                }
                
            case .humidity:
                if let humidity = weather.current.relativeHumidity2m {
                    let value = "\(humidity)%"
                    label += ", "
                    label += isDetails ? "Humidity: \(value)" : value
                }
                
            case .windSpeed:
                if let windSpeed = weather.current.windSpeed10m {
                    let value = formatWindSpeed(windSpeed)
                    label += ", "
                    label += isDetails ? "Wind Speed: \(value)" : value
                }
                
            case .windDirection:
                if let windDir = weather.current.windDirection10m {
                    let value = formatWindDirection(windDir)
                    label += ", "
                    label += isDetails ? "Wind Direction: \(value)" : value
                }
                
            case .highTemp:
                if let daily = weather.daily, !daily.temperature2mMax.isEmpty, let maxTemp = daily.temperature2mMax[0] {
                    let value = formatTemperature(maxTemp)
                    label += ", "
                    label += isDetails ? "High: \(value)" : value
                }
                
            case .lowTemp:
                if let daily = weather.daily, !daily.temperature2mMin.isEmpty, let minTemp = daily.temperature2mMin[0] {
                    let value = formatTemperature(minTemp)
                    label += ", "
                    label += isDetails ? "Low: \(value)" : value
                }
                
            case .sunrise:
                if let daily = weather.daily, let sunriseArray = daily.sunrise, !sunriseArray.isEmpty, let sunrise = sunriseArray[0] {
                    let value = formatTime(sunrise)
                    label += ", "
                    label += isDetails ? "Sunrise: \(value)" : value
                }
                
            case .sunset:
                if let daily = weather.daily, let sunsetArray = daily.sunset, !sunsetArray.isEmpty, let sunset = sunsetArray[0] {
                    let value = formatTime(sunset)
                    label += ", "
                    label += isDetails ? "Sunset: \(value)" : value
                }
            }
        }
        
        // Add UV Index if enabled and during daytime
        if settingsManager.settings.showUVIndex,
           let isDay = weather.current.isDay, isDay == 1,
           let uvIndex = weather.current.uvIndex {
            label += ", \(getUVIndexDescription(uvIndex))"
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
    ListView(selectedCityForHistory: .constant(nil))
        .environmentObject(WeatherService())
        .environmentObject(SettingsManager())
}
