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
                    
                    // Daily High/Low temperatures
                    if settingsManager.settings.showDailyHighLowInCityList,
                       let weather = weather,
                       let daily = weather.daily,
                       !daily.temperature2mMax.isEmpty,
                       !daily.temperature2mMin.isEmpty,
                       let maxTemp = daily.temperature2mMax[0],
                       let minTemp = daily.temperature2mMin[0] {
                        HStack(spacing: 4) {
                            Text("H: \(formatTemperature(maxTemp))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("L: \(formatTemperature(minTemp))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
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
                
            case .windGusts:
                if let windGusts = weather.current.windGusts10m {
                    let value = formatWindSpeed(windGusts)
                    parts.append(isDetails ? "Wind Gusts: \(value)" : value)
                }
                
            case .precipitation:
                if let precip = weather.current.precipitation, precip > 0 {
                    let value = formatPrecipitation(precip)
                    parts.append(isDetails ? "Precipitation: \(value)" : value)
                }
                
            case .precipitationProbability:
                // Get from first hour of hourly data if available
                if let hourly = weather.hourly,
                   let probArray = hourly.precipitationProbability,
                   !probArray.isEmpty,
                   let prob = probArray[0], prob > 0 {
                    let value = "\(prob)%"
                    parts.append(isDetails ? "Precip Probability: \(value)" : value)
                }
                
            case .rain:
                if let rain = weather.current.rain, rain > 0 {
                    let value = formatPrecipitation(rain)
                    parts.append(isDetails ? "Rain: \(value)" : value)
                }
                
            case .showers:
                if let showers = weather.current.showers, showers > 0 {
                    let value = formatPrecipitation(showers)
                    parts.append(isDetails ? "Showers: \(value)" : value)
                }
                
            case .snowfall:
                if let snow = weather.current.snowfall, snow > 0 {
                    let value = formatPrecipitation(snow)
                    parts.append(isDetails ? "Snowfall: \(value)" : value)
                }
                
            case .cloudCover:
                let cc = weather.current.cloudCover
                let value = "\(cc)%"
                parts.append(isDetails ? "Cloud Cover: \(value)" : value)
                
            case .pressure:
                if let pressure = weather.current.pressureMsl {
                    let value = formatPressure(pressure)
                    parts.append(isDetails ? "Pressure: \(value)" : value)
                }
                
            case .visibility:
                if let vis = weather.current.visibility {
                    let value = formatVisibility(vis)
                    parts.append(isDetails ? "Visibility: \(value)" : value)
                }
                
            case .uvIndex:
                // Only show during daytime
                if let isDay = weather.current.isDay, isDay == 1,
                   let uvIndex = weather.current.uvIndex {
                    let value = String(format: "%.1f", uvIndex)
                    parts.append(isDetails ? "UV Index: \(value)" : value)
                }
                
            case .dewPoint:
                if let dewPoint = weather.current.dewpoint2m {
                    let value = formatTemperature(dewPoint)
                    parts.append(isDetails ? "Dew Point: \(value)" : value)
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
        
        // Start with city name, then temperature (always shown)
        var label = "\(city.displayName), \(formatTemperature(weather.current.temperature2m))"
        
        // Respect display mode (condensed vs details)
        let isDetails = settingsManager.settings.displayMode == .details
        
        // Build label following the exact order of weatherFields, plus special fields in their positions
        for field in settingsManager.settings.weatherFields where field.isEnabled {
            switch field.type {
            case .temperature:
                // Already added after city name
                break
                
            case .conditions:
                if let weatherCode = weather.current.weatherCodeEnum {
                    label += ", "
                    label += isDetails ? "Conditions: \(weatherCode.description)" : weatherCode.description
                }
                
                // Add alerts immediately after conditions (same position as visual display)
                if let alert = highestSeverityAlert {
                    if alerts.count == 1 {
                        label += ", Alert: \(alert.event)"
                    } else {
                        label += ", Alerts: \(alert.event) and \(alerts.count - 1) more"
                    }
                }
                
            case .feelsLike:
                if let apparentTemp = weather.current.apparentTemperature {
                    label += ", "
                    label += isDetails ? "Feels Like: \(formatTemperature(apparentTemp))" : formatTemperature(apparentTemp)
                }
                
            case .humidity:
                if let humidity = weather.current.relativeHumidity2m {
                    label += ", "
                    label += isDetails ? "Humidity: \(humidity)%" : "\(humidity)%"
                }
                
            case .windSpeed:
                if let windSpeed = weather.current.windSpeed10m {
                    label += ", "
                    label += isDetails ? "Wind Speed: \(formatWindSpeed(windSpeed))" : formatWindSpeed(windSpeed)
                }
                
            case .windDirection:
                if let windDir = weather.current.windDirection10m {
                    label += ", "
                    label += isDetails ? "Wind Direction: \(formatWindDirection(windDir))" : formatWindDirection(windDir)
                }
                
            case .windGusts:
                if let windGusts = weather.current.windGusts10m {
                    label += ", "
                    label += isDetails ? "Wind Gusts: \(formatWindSpeed(windGusts))" : formatWindSpeed(windGusts)
                }
                
            case .precipitation:
                if let precip = weather.current.precipitation, precip > 0 {
                    label += ", "
                    label += isDetails ? "Precipitation: \(formatPrecipitation(precip))" : formatPrecipitation(precip)
                }
                
            case .precipitationProbability:
                // Get from first hour of hourly data if available
                if let hourly = weather.hourly,
                   let probArray = hourly.precipitationProbability,
                   !probArray.isEmpty,
                   let prob = probArray[0], prob > 0 {
                    label += ", "
                    label += isDetails ? "Precipitation Probability: \(prob)%" : "\(prob)%"
                }
                
            case .rain:
                if let rain = weather.current.rain, rain > 0 {
                    label += ", "
                    label += isDetails ? "Rain: \(formatPrecipitation(rain))" : formatPrecipitation(rain)
                }
                
            case .showers:
                if let showers = weather.current.showers, showers > 0 {
                    label += ", "
                    label += isDetails ? "Showers: \(formatPrecipitation(showers))" : formatPrecipitation(showers)
                }
                
            case .snowfall:
                if let snow = weather.current.snowfall, snow > 0 {
                    label += ", "
                    label += isDetails ? "Snowfall: \(formatPrecipitation(snow))" : formatPrecipitation(snow)
                }
                
            case .cloudCover:
                let cc = weather.current.cloudCover
                label += ", "
                label += isDetails ? "Cloud Cover: \(cc)%" : "\(cc)%"
                
            case .pressure:
                if let pressure = weather.current.pressureMsl {
                    label += ", "
                    label += isDetails ? "Pressure: \(formatPressure(pressure))" : formatPressure(pressure)
                }
                
            case .visibility:
                if let vis = weather.current.visibility {
                    label += ", "
                    label += isDetails ? "Visibility: \(formatVisibility(vis))" : formatVisibility(vis)
                }
                
            case .uvIndex:
                // Only show during daytime
                if let isDay = weather.current.isDay, isDay == 1,
                   let uvIndex = weather.current.uvIndex {
                    label += ", "
                    label += isDetails ? "UV Index: \(String(format: "%.1f", uvIndex))" : String(format: "%.1f", uvIndex)
                }
                
            case .dewPoint:
                if let dewPoint = weather.current.dewpoint2m {
                    label += ", "
                    label += isDetails ? "Dew Point: \(formatTemperature(dewPoint))" : formatTemperature(dewPoint)
                }
                
            case .highTemp:
                // Check if using separate daily high/low setting OR individual high/low fields
                if settingsManager.settings.showDailyHighLowInCityList {
                    // Use combined format when daily high/low is enabled
                    if let daily = weather.daily,
                       !daily.temperature2mMax.isEmpty,
                       !daily.temperature2mMin.isEmpty,
                       let maxTemp = daily.temperature2mMax[0],
                       let minTemp = daily.temperature2mMin[0] {
                        label += ", "
                        label += isDetails ? "High: \(formatTemperature(maxTemp)), Low: \(formatTemperature(minTemp))" : "\(formatTemperature(maxTemp)), \(formatTemperature(minTemp))"
                    }
                } else {
                    // Only show high temp individually
                    if let daily = weather.daily, !daily.temperature2mMax.isEmpty, let maxTemp = daily.temperature2mMax[0] {
                        label += ", "
                        label += isDetails ? "High: \(formatTemperature(maxTemp))" : formatTemperature(maxTemp)
                    }
                }
                
            case .lowTemp:
                // Only announce low separately if NOT using combined daily high/low
                if !settingsManager.settings.showDailyHighLowInCityList {
                    if let daily = weather.daily, !daily.temperature2mMin.isEmpty, let minTemp = daily.temperature2mMin[0] {
                        label += ", "
                        label += isDetails ? "Low: \(formatTemperature(minTemp))" : formatTemperature(minTemp)
                    }
                }
                // If showDailyHighLowInCityList is true, already announced with highTemp
                
            case .sunrise:
                if let daily = weather.daily, let sunriseArray = daily.sunrise, !sunriseArray.isEmpty, let sunrise = sunriseArray[0] {
                    label += ", "
                    label += isDetails ? "Sunrise: \(formatTime(sunrise))" : formatTime(sunrise)
                }
                
            case .sunset:
                if let daily = weather.daily, let sunsetArray = daily.sunset, !sunsetArray.isEmpty, let sunset = sunsetArray[0] {
                    label += ", "
                    label += isDetails ? "Sunset: \(formatTime(sunset))" : formatTime(sunset)
                }
            }
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
    
    private func formatPrecipitation(_ mm: Double) -> String {
        let precip = settingsManager.settings.precipitationUnit.convert(mm)
        return String(format: "%.1f %@", precip, settingsManager.settings.precipitationUnit.rawValue)
    }
    
    private func formatPressure(_ hPa: Double) -> String {
        let pressure = settingsManager.settings.pressureUnit.convert(hPa)
        return String(format: "%.1f %@", pressure, settingsManager.settings.pressureUnit.rawValue)
    }
    
    private func formatVisibility(_ meters: Double) -> String {
        let distance = settingsManager.settings.distanceUnit.convert(meters / 1000.0) // Convert m to km first
        return String(format: "%.1f %@", distance, settingsManager.settings.distanceUnit.rawValue)
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
