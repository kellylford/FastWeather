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
    @State private var alertSheetItem: AlertSheetItem?  // Stable sheet item to prevent re-presentation loop
    
    // Date navigation parameters
    let dateOffset: Int
    let selectedDate: Date
    
    var body: some View {
        List {
            ForEach(weatherService.savedCities.indices, id: \.self) { index in
                let city = weatherService.savedCities[index]
                citySection(for: city, at: index)
            }
        }
        .listStyle(.grouped)
        .sheet(item: $alertSheetItem) { item in
            AlertDetailView(alert: item.alert)
        }
    }
    
    @ViewBuilder
    private func citySection(for city: City, at index: Int) -> some View {
        Section {
            // Weather detail rows
            let cacheKey = WeatherCacheKey(cityId: city.id, dateOffset: dateOffset)
            if let weather = weatherService.weatherCache[cacheKey] {
                weatherDetailRows(for: weather)
            } else {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
            }
            
            // Actions button
            actionsMenu(for: city, at: index)
        } header: {
            CitySectionHeader(city: city, dateOffset: dateOffset, onAlertTap: { alert in
                alertSheetItem = AlertSheetItem(city: city, alert: alert)
            })
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
        case .weatherAlerts:
            // Weather alerts displayed separately, not as a field
            return nil
            
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
            
        case .windGusts:
            guard let windGusts = weather.current.windGusts10m else { return nil }
            return (showLabel ? "Wind Gusts" : "", formatWindSpeed(windGusts))
            
        case .precipitation:
            guard let precip = weather.current.precipitation, precip > 0 else { return nil }
            return (showLabel ? "Precipitation" : "", formatPrecipitation(precip))
            
        case .precipitationProbability:
            guard let hourly = weather.hourly,
                  let probArray = hourly.precipitationProbability,
                  !probArray.isEmpty,
                  let prob = probArray[0], prob > 0 else { return nil }
            // Also get expected precipitation amount for that hour
            var value = "\(prob)%"
            if let precipArray = hourly.precipitation,
               !precipArray.isEmpty,
               let precipAmount = precipArray[0], precipAmount > 0.0 {
                value += " (\(formatPrecipitation(precipAmount)))"
            }
            return (showLabel ? "Precip Probability" : "", value)
            
        case .rain:
            guard let rain = weather.current.rain, rain > 0 else { return nil }
            return (showLabel ? "Rain" : "", formatPrecipitation(rain))
            
        case .showers:
            guard let showers = weather.current.showers, showers > 0 else { return nil }
            return (showLabel ? "Showers" : "", formatPrecipitation(showers))
            
        case .snowfall:
            guard let snow = weather.current.snowfall, snow > 0 else { return nil }
            return (showLabel ? "Snowfall" : "", formatPrecipitation(snow))
            
        case .cloudCover:
            let cc = weather.current.cloudCover
            return (showLabel ? "Cloud Cover" : "", "\(cc)%")
            
        case .pressure:
            guard let pressure = weather.current.pressureMsl else { return nil }
            return (showLabel ? "Pressure" : "", formatPressure(pressure))
            
        case .visibility:
            guard let vis = weather.current.visibility else { return nil }
            return (showLabel ? "Visibility" : "", formatVisibility(vis))
            
        case .uvIndex:
            guard let isDay = weather.current.isDay, isDay == 1,
                  let uvIndex = weather.current.uvIndex else { return nil }
            return (showLabel ? "UV Index" : "", String(format: "%.1f", uvIndex))
            
        case .dewPoint:
            guard let dewPoint = weather.current.dewpoint2m else { return nil }
            return (showLabel ? "Dew Point" : "", formatTemperature(dewPoint))
            
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
        let unit = settingsManager.settings.temperatureUnit == .fahrenheit ? "F" : "C"
        return String(format: "%.0f°%@", temp, unit)
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
    
    private func formatPrecipitation(_ mm: Double) -> String {
        let precip = settingsManager.settings.precipitationUnit.convert(mm)
        return String(format: "%.1f %@", precip, settingsManager.settings.precipitationUnit.rawValue)
    }
    
    private func formatPressure(_ hPa: Double) -> String {
        let pressure = settingsManager.settings.pressureUnit.convert(hPa)
        return String(format: "%.1f %@", pressure, settingsManager.settings.pressureUnit.rawValue)
    }
    
    private func formatVisibility(_ meters: Double) -> String {
        let distance = settingsManager.settings.distanceUnit.convert(meters / 1000.0)
        return String(format: "%.1f %@", distance, settingsManager.settings.distanceUnit.rawValue)
    }
    
    private func formatTime(_ isoString: String) -> String {
        return FormatHelper.formatTime(isoString)
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

// MARK: - City Section Header
struct CitySectionHeader: View {
    @EnvironmentObject var weatherService: WeatherService
    @EnvironmentObject var settingsManager: SettingsManager
    let city: City
    let dateOffset: Int
    let onAlertTap: (WeatherAlert) -> Void
    
    @State private var alerts: [WeatherAlert] = []
    @State private var hasLoadedAlerts = false
    
    private var weather: WeatherData? {
        let cacheKey = WeatherCacheKey(cityId: city.id, dateOffset: dateOffset)
        return weatherService.weatherCache[cacheKey]
    }
    
    private var highestSeverityAlert: WeatherAlert? {
        alerts.max(by: { $0.severity.rawValue < $1.severity.rawValue })
    }
    
    var body: some View {
        if let weather = weather {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(city.displayName)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    
                    // UV Index badge (only during daytime)
                    if settingsManager.settings.showUVIndexInCityList,
                       let isDay = weather.current.isDay, isDay == 1,
                       let uvIndex = weather.current.uvIndex {
                        UVBadge(uvIndex: uvIndex)
                    }
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    // Alert badge (if any)
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
                    
                    Text(formatTemperature(weather.current.temperature2m))
                        .font(.title2.weight(.semibold))
                }
            }
            .textCase(nil)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(buildAccessibilityLabel(weather: weather))
            .animation(.easeInOut(duration: 0.2), value: highestSeverityAlert?.id)
            .task(id: "\(city.id)-\(dateOffset)") {
                // Fetch weather for this city at this date offset if not cached
                let cacheKey = WeatherCacheKey(cityId: city.id, dateOffset: dateOffset)
                if weatherService.weatherCache[cacheKey] == nil {
                    await weatherService.fetchWeatherForDate(for: city, dateOffset: dateOffset)
                }
                
                // Load alerts (only for current date)
                // Clear alerts when viewing past/future days
                if dateOffset != 0 {
                    alerts = []
                    hasLoadedAlerts = false
                    return
                }
                
                guard !hasLoadedAlerts else { return }
                hasLoadedAlerts = true
                
                do {
                    alerts = try await weatherService.fetchNWSAlerts(for: city)
                } catch {
                    // Silently fail - alerts are optional
                }
            }
        } else {
            Text(city.displayName)
                .font(.headline)
                .textCase(nil)
        }
    }
    
    private func buildAccessibilityLabel(weather: WeatherData) -> String {
        var label = "\(city.displayName), \(formatTemperature(weather.current.temperature2m))"
        
        // Add alerts if enabled and present
        if settingsManager.settings.weatherFields.first(where: { $0.type == .weatherAlerts })?.isEnabled == true,
           let alert = highestSeverityAlert {
            label += ", "
            if alerts.count == 1 {
                label += "Alert: \(alert.event)"
            } else {
                label += "Alerts: \(alert.event) and \(alerts.count - 1) more"
            }
        }
        
        return label
    }
    
    private func formatTemperature(_ celsius: Double) -> String {
        let temp = settingsManager.settings.temperatureUnit.convert(celsius)
        let unit = settingsManager.settings.temperatureUnit == .fahrenheit ? "F" : "C"
        return String(format: "%.0f°%@", temp, unit)
    }
}

#Preview {
    FlatView(
        selectedCityForHistory: .constant(nil),
        selectedCityForDetail: .constant(nil),
        dateOffset: 0,
        selectedDate: Date()
    )
        .environmentObject(WeatherService())
        .environmentObject(SettingsManager())
}
