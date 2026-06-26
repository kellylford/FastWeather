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
    @EnvironmentObject var myLocationService: MyLocationService
    @Environment(\.editMode) var editMode
    @Binding var selectedCityForHistory: City?
    @State private var alertSheetItem: AlertSheetItem?  // Stable sheet item to prevent re-presentation loop

    // Date navigation parameters
    let dateOffset: Int
    let selectedDate: Date

    // Whether to show the My Location section (feature flag + user setting combined by caller)
    let showMyLocation: Bool

    var body: some View {
        List {
            if showMyLocation && settingsManager.settings.myLocationPosition == .beforeCityList {
                myLocationSection()
            }
            ForEach(weatherService.savedCities) { city in
                cityRow(for: city)
            }
            .onMove(perform: weatherService.moveCity)
            .onDelete(perform: deleteCities)
            if showMyLocation && settingsManager.settings.myLocationPosition == .afterCityList {
                myLocationSection()
            }
        }
        .listStyle(.plain)
        .sheet(item: $alertSheetItem) { item in
            AlertDetailView(alert: item.alert)
        }
    }

    // MARK: - My Location Section

    @ViewBuilder
    private func myLocationSection() -> some View {
        Section {
            switch myLocationState() {
            case .permissionNotDetermined:
                Button {
                    myLocationService.requestPermissionIfNeeded()
                } label: {
                    Label("Enable Location Access", systemImage: "location.slash")
                        .foregroundColor(.accentColor)
                }
                .accessibilityLabel("Enable Location Access")
                .accessibilityHint("Requests permission to use your current location for weather.")

            case .permissionDenied:
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("Open Settings to Enable Location", systemImage: "location.slash.fill")
                        .foregroundColor(.secondary)
                }
                .accessibilityLabel("Open Settings to Enable Location")
                .accessibilityHint("Location access is denied. Opens Settings so you can enable it.")

            case .loading:
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Locating…")
                        .foregroundColor(.secondary)
                }
                .accessibilityLabel("Locating your current position")

            case .error(let message):
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.secondary)
                        .accessibilityHidden(true)
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .accessibilityLabel("Location error: \(message)")

            case .loaded(let city):
                myLocationRow(for: city)
            }
        }
    }

    @ViewBuilder
    private func myLocationRow(for city: City) -> some View {
        NavigationLink(destination: CityDetailView(city: city, dateOffset: dateOffset, selectedDate: selectedDate)) {
            ListRowView(city: city, dateOffset: dateOffset, onAlertTap: { alert in
                alertSheetItem = AlertSheetItem(city: city, alert: alert)
            })
        }
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: "Add to My City List") {
            myLocationService.addToMyCityList(weatherService: weatherService)
        }
        .accessibilityAction(named: "Refresh My Location") {
            UIAccessibility.post(notification: .announcement, argument: "Refreshing location")
            Task { await myLocationService.refresh() }
        }
        .accessibilityAction(named: "View Historical Weather") {
            selectedCityForHistory = city
            UIAccessibility.post(notification: .announcement, argument: "Opening historical weather for \(city.displayName)")
        }
        .accessibilityAction(named: "Glance Ahead") {
            let cacheKey = WeatherCacheKey(cityId: city.id, dateOffset: 0)
            let hasHourly = weatherService.weatherCache[cacheKey]?.hourly != nil
            if hasHourly {
                let summary = glanceAheadSummary(for: city)
                UIAccessibility.post(notification: .announcement, argument: summary)
            } else {
                UIAccessibility.post(notification: .announcement, argument: "Loading forecast, please try again in a moment")
                Task { await weatherService.fetchWeatherForDate(for: city, dateOffset: 0, includeHourly: true) }
            }
        }
        .contextMenu {
            Button {
                myLocationService.addToMyCityList(weatherService: weatherService)
            } label: {
                Label("Add to My City List", systemImage: "plus.circle")
            }

            Button {
                Task { await myLocationService.refresh() }
            } label: {
                Label("Refresh My Location", systemImage: "arrow.clockwise")
            }

            Divider()

            Button {
                selectedCityForHistory = city
            } label: {
                Label("View Historical Weather", systemImage: "calendar")
            }
        } preview: {
            myLocationGlancePreview(for: city)
        }
    }

    @ViewBuilder
    private func myLocationGlancePreview(for city: City) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "location.fill")
                    .font(.caption)
                    .foregroundColor(.accentColor)
                    .accessibilityHidden(true)
                Text(city.displayName)
                    .font(.headline)
                    .lineLimit(2)
            }
            Text("My Location")
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            let cacheKey = WeatherCacheKey(cityId: city.id, dateOffset: 0)
            if weatherService.weatherCache[cacheKey]?.hourly != nil {
                Text(glanceAheadSummary(for: city))
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Loading forecast…")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(minWidth: 280, alignment: .leading)
        .background(.regularMaterial)
    }

    // MARK: - My Location State

    private enum MyLocationState {
        case permissionNotDetermined
        case permissionDenied
        case loading
        case error(String)
        case loaded(City)
    }

    private func myLocationState() -> MyLocationState {
        switch myLocationService.permissionStatus {
        case .notDetermined:
            return .permissionNotDetermined
        case .denied, .restricted:
            return .permissionDenied
        default:
            break
        }
        if myLocationService.isLoading && myLocationService.locationCity == nil {
            return .loading
        }
        if let city = myLocationService.locationCity {
            return .loaded(city)
        }
        if let error = myLocationService.errorMessage {
            return .error(error)
        }
        return .loading
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
    
    private func glanceAheadSummary(for city: City) -> String {
        let cacheKey = WeatherCacheKey(cityId: city.id, dateOffset: 0)
        guard let weather = weatherService.weatherCache[cacheKey],
              let hourly = weather.hourly,
              let times = hourly.time,
              let temps = hourly.temperature2m,
              let precips = hourly.precipitationProbability else {
            return String(localized: "glance.forecast_not_loaded", defaultValue: "Forecast not yet loaded", comment: "Shown when the forecast data has not loaded yet")
        }

        // Find the first hourly index whose timestamp is at or after the current moment,
        // using the city's timezone so the comparison is correct for international cities.
        let now = Date()
        let cityTimeZone = weather.timeZone
        var startIndex = 0
        for (i, timeString) in times.enumerated() {
            guard let ts = timeString,
                  let date = DateParser.parse(ts, in: cityTimeZone) else { continue }
            if date >= now {
                startIndex = i
                break
            }
        }

        let endIndex = min(startIndex + settingsManager.settings.glanceAheadHours, times.count)
        guard startIndex < endIndex else {
            return String(localized: "glance.forecast_not_loaded", defaultValue: "Forecast not yet loaded", comment: "Shown when the forecast data has not loaded yet")
        }

        let unit = settingsManager.settings.temperatureUnit
        let tempSlice = (startIndex..<endIndex).compactMap { i -> Double? in
            guard i < temps.count, let raw = temps[i] else { return nil }
            return unit.convert(raw)
        }
        let precipSlice = (startIndex..<endIndex).compactMap { i -> Int? in
            guard i < precips.count else { return nil }
            return precips[i]
        }

        guard let firstTemp = tempSlice.first, let lastTemp = tempSlice.last else {
            return String(localized: "glance.forecast_not_loaded", defaultValue: "Forecast not yet loaded", comment: "Shown when the forecast data has not loaded yet")
        }

        let roundedLast = Int(lastTemp.rounded())
        let diff = lastTemp - firstTemp
        // unit.rawValue is a temperature symbol (°F/°C) — left raw by policy.
        let tempPart: String
        if abs(diff) < 3 {
            tempPart = String(localized: "forecast.trend.steady",
                              defaultValue: "Around \(roundedLast)\(unit.rawValue)",
                              comment: "Glance ahead temperature trend, roughly steady. Placeholder is temperature with unit symbol.")
        } else if diff > 0 {
            tempPart = String(localized: "forecast.trend.increasing",
                              defaultValue: "Increasing to around \(roundedLast)\(unit.rawValue)",
                              comment: "Glance ahead temperature trend, rising. Placeholder is temperature with unit symbol.")
        } else {
            tempPart = String(localized: "forecast.trend.decreasing",
                              defaultValue: "Decreasing to around \(roundedLast)\(unit.rawValue)",
                              comment: "Glance ahead temperature trend, falling. Placeholder is temperature with unit symbol.")
        }

        let maxPrecip = precipSlice.max() ?? 0
        let precipPart: String
        if maxPrecip <= 5 {
            precipPart = String(localized: "forecast.no_precipitation", defaultValue: "no precipitation expected", comment: "Glance ahead summary: no precipitation expected")
        } else {
            precipPart = String(localized: "forecast.precip_chance",
                                defaultValue: "\(maxPrecip)% chance of precipitation",
                                comment: "Glance ahead summary: chance of precipitation. Placeholder is a percentage.")
        }

        return String(localized: "glance.summary",
                      defaultValue: "\(tempPart), \(precipPart)",
                      comment: "Glance ahead summary combining temperature trend and precipitation, e.g. 'Around 70°F, no precipitation expected'")
    }

    @ViewBuilder
    private func glanceAheadPreview(for city: City) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(city.displayName)
                .font(.headline)
                .lineLimit(2)
            Text("Next 4 Hours")
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            Text(glanceAheadSummary(for: city))
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(minWidth: 280, alignment: .leading)
        .background(.regularMaterial)
    }

    @ViewBuilder
    private func cityRow(for city: City) -> some View {
        let index = weatherService.savedCities.firstIndex(where: { $0.id == city.id }) ?? 0
        return NavigationLink(destination: CityDetailView(city: city, dateOffset: dateOffset, selectedDate: selectedDate)) {
            ListRowView(city: city, dateOffset: dateOffset, onAlertTap: { alert in
                // Create stable AlertSheetItem to prevent re-presentation loop
                alertSheetItem = AlertSheetItem(city: city, alert: alert)
            })
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(editMode?.wrappedValue.isEditing == true ? [.allowsDirectInteraction] : [])
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
        .accessibilityAction(named: "Glance Ahead") {
            let cacheKey = WeatherCacheKey(cityId: city.id, dateOffset: 0)
            let hasHourly = weatherService.weatherCache[cacheKey]?.hourly != nil
            if hasHourly {
                let summary = glanceAheadSummary(for: city)
                UIAccessibility.post(notification: .announcement, argument: summary)
            } else {
                UIAccessibility.post(notification: .announcement, argument: "Loading forecast, please try again in a moment")
                Task {
                    await weatherService.fetchWeatherForDate(for: city, dateOffset: 0, includeHourly: true)
                }
            }
        }
        .contextMenu(menuItems: {
            contextMenuContent(for: city, at: index)
        }) {
            glanceAheadPreview(for: city)
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
    let dateOffset: Int
    let onAlertTap: (WeatherAlert) -> Void
    
    @State private var alerts: [WeatherAlert] = []
    
    private var weather: WeatherData? {
        let cacheKey = WeatherCacheKey(cityId: city.id, dateOffset: dateOffset)
        return weatherService.weatherCache[cacheKey]
    }
    
    private var highestSeverityAlert: WeatherAlert? {
        alerts.min(by: { $0.severity.sortOrder < $1.severity.sortOrder })
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(city.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .truncationMode(.tail)
                
                if let weather = weather {
                    Text(buildWeatherSummary(weather))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .truncationMode(.tail)
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
        .task(id: "\(city.id)-\(dateOffset)") {
            // Fetch weather for this city at this date offset if not cached
            let cacheKey = WeatherCacheKey(cityId: city.id, dateOffset: dateOffset)
            // Skip if already failed (don't loop on persistent errors)
            guard !weatherService.failedCacheKeys.contains(cacheKey) else { return }

            if weatherService.weatherCache[cacheKey] == nil {
                // Full fetch — includes hourly so Glance Ahead works in list view
                await weatherService.fetchWeatherForDate(for: city, dateOffset: dateOffset, includeHourly: true)
            } else if weatherService.weatherCache[cacheKey]?.hourly == nil {
                // Light data cached but no hourly — upgrade to full fetch for Glance Ahead
                await weatherService.fetchWeatherForDate(for: city, dateOffset: dateOffset, includeHourly: true)
            }
            
            // Load alerts (only for current date)
            // Clear alerts when viewing past/future days
            if dateOffset != 0 {
                alerts = []
                return
            }
            
            do {
                alerts = try await weatherService.fetchNWSAlerts(for: city)
            } catch {
                // Silently fail - alerts are optional
            }
        }
        .task(id: weatherService.alertsRefreshID) {
            // Re-fetch alerts when alertsRefreshID changes (on refresh)
            guard dateOffset == 0 else { return }
            
            do {
                alerts = try await weatherService.fetchNWSAlerts(for: city)
            } catch {
                // Silently fail - alerts are optional
            }
        }
    }
    
    private func buildWeatherSummary(_ weather: WeatherData) -> String {
        var parts: [String] = []
        let isDetails = settingsManager.settings.displayMode == .details
        
        // Use the ordered and filtered weather fields from settings
        for field in settingsManager.settings.weatherFields where field.isEnabled {
            switch field.type {
            case .weatherAlerts:
                // Weather alerts shown separately in UI, not as text field
                break
                
            case .temperature:
                // Skip temperature in summary since it's shown separately on the right
                break
                
            case .conditions:
                if let weatherCode = weather.current.weatherCodeEnum {
                    parts.append(isDetails ? String(localized: "summary.conditions", defaultValue: "Conditions: \(weatherCode.description)", comment: "City list summary field") : weatherCode.description)
                }

            case .feelsLike:
                if let apparentTemp = weather.current.apparentTemperature {
                    let value = formatTemperature(apparentTemp)
                    parts.append(isDetails ? String(localized: "summary.feels_like", defaultValue: "Feels Like: \(value)", comment: "City list summary field") : value)
                }

            case .humidity:
                if let humidity = weather.current.relativeHumidity2m {
                    let value = "\(humidity)%"
                    parts.append(isDetails ? String(localized: "summary.humidity", defaultValue: "Humidity: \(value)", comment: "City list summary field") : value)
                }

            case .windSpeed:
                if let windSpeed = weather.current.windSpeed10m {
                    let value = formatWindSpeed(windSpeed)
                    parts.append(isDetails ? String(localized: "summary.wind_speed", defaultValue: "Wind Speed: \(value)", comment: "City list summary field") : value)
                }

            case .windDirection:
                if let windDir = weather.current.windDirection10m {
                    let value = formatWindDirection(windDir)
                    parts.append(isDetails ? String(localized: "summary.wind_direction", defaultValue: "Wind Direction: \(value)", comment: "City list summary field") : value)
                }

            case .windGusts:
                if let windGusts = weather.current.windGusts10m {
                    let value = formatWindSpeed(windGusts)
                    parts.append(isDetails ? String(localized: "summary.wind_gusts", defaultValue: "Wind Gusts: \(value)", comment: "City list summary field") : value)
                }

            case .precipitation:
                let snowfall = weather.daily?.snowfallSum?.first.flatMap { $0 } ?? weather.current.snowfall ?? 0
                let precip = weather.daily?.precipitationSum?.first.flatMap { $0 } ?? weather.current.precipitation ?? 0
                if snowfall > 0 {
                    let value = formatSnowfall(snowfall)
                    parts.append(isDetails ? String(localized: "summary.snow", defaultValue: "Snow: \(value)", comment: "City list summary field") : value)
                } else if precip > 0 {
                    let value = formatPrecipitation(precip)
                    parts.append(isDetails ? String(localized: "summary.rain", defaultValue: "Rain: \(value)", comment: "City list summary field") : value)
                }

            case .precipitationProbability:
                // Get from first hour of hourly data if available
                if let hourly = weather.hourly,
                   let probArray = hourly.precipitationProbability,
                   !probArray.isEmpty,
                   let prob = probArray[0], prob > 0 {
                    // Also get expected precipitation amount for that hour
                    var value = "\(prob)%"
                    if let precipArray = hourly.precipitation,
                       !precipArray.isEmpty,
                       let precipAmount = precipArray[0], precipAmount > 0.0 {
                        value += " (\(formatPrecipitation(precipAmount)))"
                    }
                    parts.append(isDetails ? String(localized: "summary.precip_probability", defaultValue: "Precip Probability: \(value)", comment: "City list summary field") : value)
                }

            case .rain:
                if let rain = weather.current.rain, rain > 0 {
                    let value = formatPrecipitation(rain)
                    parts.append(isDetails ? String(localized: "summary.rain", defaultValue: "Rain: \(value)", comment: "City list summary field") : value)
                }

            case .showers:
                if let showers = weather.current.showers, showers > 0 {
                    let value = formatPrecipitation(showers)
                    parts.append(isDetails ? String(localized: "summary.showers", defaultValue: "Showers: \(value)", comment: "City list summary field") : value)
                }

            case .snowfall:
                let snow = weather.daily?.snowfallSum?.first.flatMap { $0 } ?? weather.current.snowfall ?? 0
                if snow > 0 {
                    let value = formatSnowfall(snow)
                    parts.append(isDetails ? String(localized: "summary.snow", defaultValue: "Snow: \(value)", comment: "City list summary field") : value)
                }

            case .cloudCover:
                let cc = weather.current.cloudCover
                let value = "\(cc)%"
                parts.append(isDetails ? String(localized: "summary.cloud_cover", defaultValue: "Cloud Cover: \(value)", comment: "City list summary field") : value)

            case .pressure:
                if let pressure = weather.current.pressureMsl {
                    let value = formatPressure(pressure)
                    parts.append(isDetails ? String(localized: "summary.pressure", defaultValue: "Pressure: \(value)", comment: "City list summary field") : value)
                }

            case .visibility:
                if let vis = weather.current.visibility {
                    let value = formatVisibility(vis)
                    parts.append(isDetails ? String(localized: "summary.visibility", defaultValue: "Visibility: \(value)", comment: "City list summary field") : value)
                }

            case .uvIndex:
                // Only show during daytime
                if let isDay = weather.current.isDay, isDay == 1,
                   let uvIndex = weather.current.uvIndex {
                    let value = String(format: "%.1f", uvIndex)
                    parts.append(isDetails ? String(localized: "summary.uv_index", defaultValue: "UV Index: \(value)", comment: "City list summary field") : value)
                }

            case .dewPoint:
                if let dewPoint = weather.current.dewpoint2m {
                    let value = formatTemperature(dewPoint)
                    parts.append(isDetails ? String(localized: "summary.dew_point", defaultValue: "Dew Point: \(value)", comment: "City list summary field") : value)
                }

            case .highTemp:
                if let daily = weather.daily, !daily.temperature2mMax.isEmpty, let maxTemp = daily.temperature2mMax[0] {
                    let value = formatTemperature(maxTemp)
                    parts.append(isDetails ? String(localized: "summary.high", defaultValue: "High: \(value)", comment: "City list summary field") : value)
                }

            case .lowTemp:
                if let daily = weather.daily, !daily.temperature2mMin.isEmpty, let minTemp = daily.temperature2mMin[0] {
                    let value = formatTemperature(minTemp)
                    parts.append(isDetails ? String(localized: "summary.low", defaultValue: "Low: \(value)", comment: "City list summary field") : value)
                }

            case .sunrise:
                if let daily = weather.daily, let sunriseArray = daily.sunrise, !sunriseArray.isEmpty, let sunrise = sunriseArray[0] {
                    let value = formatTime(sunrise)
                    parts.append(isDetails ? String(localized: "summary.sunrise", defaultValue: "Sunrise: \(value)", comment: "City list summary field") : value)
                }

            case .sunset:
                if let daily = weather.daily, let sunsetArray = daily.sunset, !sunsetArray.isEmpty, let sunset = sunsetArray[0] {
                    let value = formatTime(sunset)
                    parts.append(isDetails ? String(localized: "summary.sunset", defaultValue: "Sunset: \(value)", comment: "City list summary field") : value)
                }
            }
        }

        return parts.joined(separator: " • ")
    }
    
    private func buildAccessibilityLabel() -> String {
        guard let weather = weather else {
            return String(localized: "city_row.loading_accessibility", defaultValue: "\(city.displayName), Loading", comment: "Accessibility label for a city row while weather is loading. Placeholder is the city name.")
        }
        
        // Start with city name, then temperature (always shown)
        var label = "\(city.displayName), \(formatTemperature(weather.current.temperature2m))"
        
        // Respect display mode (condensed vs details)
        let isDetails = settingsManager.settings.displayMode == .details
        
        // Build label following the exact order of weatherFields, plus special fields in their positions
        for field in settingsManager.settings.weatherFields where field.isEnabled {
            switch field.type {
            case .weatherAlerts:
                // Add alerts in order based on settings
                if let alert = highestSeverityAlert {
                    label += ", "
                    if alerts.count == 1 {
                        label += isDetails ? String(localized: "city_row.alert_single", defaultValue: "Alert: \(alert.event)", comment: "Accessibility: one active weather alert. Placeholder is the alert event name.") : alert.event
                    } else {
                        label += isDetails ? String(localized: "city_row.alerts_multiple", defaultValue: "Alerts: \(alert.event) and \(alerts.count - 1) more", comment: "Accessibility: multiple active alerts. First placeholder is the top alert event, second is the count of additional alerts.") : String(localized: "city_row.alerts_multiple_short", defaultValue: "\(alert.event) +\(alerts.count - 1)", comment: "Compact: top alert event plus count of additional alerts, e.g. 'Tornado Warning +2'")
                    }
                }
                
            case .temperature:
                // Already added after city name
                break
                
            case .conditions:
                if let weatherCode = weather.current.weatherCodeEnum {
                    label += ", "
                    label += isDetails ? String(localized: "summary.conditions", defaultValue: "Conditions: \(weatherCode.description)", comment: "City list summary field") : weatherCode.description
                }

            case .feelsLike:
                if let apparentTemp = weather.current.apparentTemperature {
                    label += ", "
                    label += isDetails ? String(localized: "summary.feels_like", defaultValue: "Feels Like: \(formatTemperature(apparentTemp))", comment: "City list summary field") : formatTemperature(apparentTemp)
                }

            case .humidity:
                if let humidity = weather.current.relativeHumidity2m {
                    label += ", "
                    label += isDetails ? String(localized: "summary.humidity", defaultValue: "Humidity: \(humidity)%", comment: "City list summary field") : "\(humidity)%"
                }

            case .windSpeed:
                if let windSpeed = weather.current.windSpeed10m {
                    label += ", "
                    label += isDetails ? String(localized: "summary.wind_speed", defaultValue: "Wind Speed: \(formatWindSpeed(windSpeed))", comment: "City list summary field") : formatWindSpeed(windSpeed)
                }

            case .windDirection:
                if let windDir = weather.current.windDirection10m {
                    label += ", "
                    label += isDetails ? String(localized: "summary.wind_direction", defaultValue: "Wind Direction: \(formatWindDirection(windDir))", comment: "City list summary field") : formatWindDirection(windDir)
                }

            case .windGusts:
                if let windGusts = weather.current.windGusts10m {
                    label += ", "
                    label += isDetails ? String(localized: "summary.wind_gusts", defaultValue: "Wind Gusts: \(formatWindSpeed(windGusts))", comment: "City list summary field") : formatWindSpeed(windGusts)
                }
                
            case .precipitation:
                let snowfall = weather.daily?.snowfallSum?.first.flatMap { $0 } ?? weather.current.snowfall ?? 0
                let precip = weather.daily?.precipitationSum?.first.flatMap { $0 } ?? weather.current.precipitation ?? 0
                if snowfall > 0 {
                    label += ", "
                    label += isDetails ? String(localized: "summary.snow", defaultValue: "Snow: \(formatSnowfall(snowfall))", comment: "City list summary field") : formatSnowfall(snowfall)
                } else if precip > 0 {
                    label += ", "
                    label += isDetails ? String(localized: "summary.rain", defaultValue: "Rain: \(formatPrecipitation(precip))", comment: "City list summary field") : formatPrecipitation(precip)
                }

            case .precipitationProbability:
                // Get from first hour of hourly data if available
                if let hourly = weather.hourly,
                   let probArray = hourly.precipitationProbability,
                   !probArray.isEmpty,
                   let prob = probArray[0], prob > 0 {
                    label += ", "
                    // Also announce expected precipitation amount for that hour
                    if let precipArray = hourly.precipitation,
                       !precipArray.isEmpty,
                       let precipAmount = precipArray[0], precipAmount > 0.0 {
                        if isDetails {
                            label += String(localized: "summary.precip_probability_expected", defaultValue: "Precipitation Probability: \(prob)%, Expected: \(formatPrecipitation(precipAmount))", comment: "Accessibility: precipitation probability with expected amount.")
                        } else {
                            label += String(localized: "summary.precip_probability_expected_short", defaultValue: "\(prob)%, \(formatPrecipitation(precipAmount))", comment: "Compact: precipitation probability percent and expected amount.")
                        }
                    } else {
                        label += isDetails ? String(localized: "summary.precip_probability_full", defaultValue: "Precipitation Probability: \(prob)%", comment: "Accessibility: precipitation probability.") : "\(prob)%"
                    }
                }

            case .rain:
                if let rain = weather.current.rain, rain > 0 {
                    label += ", "
                    label += isDetails ? String(localized: "summary.rain", defaultValue: "Rain: \(formatPrecipitation(rain))", comment: "City list summary field") : formatPrecipitation(rain)
                }

            case .showers:
                if let showers = weather.current.showers, showers > 0 {
                    label += ", "
                    label += isDetails ? String(localized: "summary.showers", defaultValue: "Showers: \(formatPrecipitation(showers))", comment: "City list summary field") : formatPrecipitation(showers)
                }

            case .snowfall:
                let snow = weather.daily?.snowfallSum?.first.flatMap { $0 } ?? weather.current.snowfall ?? 0
                if snow > 0 {
                    label += ", "
                    label += isDetails ? String(localized: "summary.snow", defaultValue: "Snow: \(formatSnowfall(snow))", comment: "City list summary field") : formatSnowfall(snow)
                }

            case .cloudCover:
                let cc = weather.current.cloudCover
                label += ", "
                label += isDetails ? String(localized: "summary.cloud_cover", defaultValue: "Cloud Cover: \(cc)%", comment: "City list summary field") : "\(cc)%"

            case .pressure:
                if let pressure = weather.current.pressureMsl {
                    label += ", "
                    label += isDetails ? String(localized: "summary.pressure", defaultValue: "Pressure: \(formatPressure(pressure))", comment: "City list summary field") : formatPressure(pressure)
                }

            case .visibility:
                if let vis = weather.current.visibility {
                    label += ", "
                    label += isDetails ? String(localized: "summary.visibility", defaultValue: "Visibility: \(formatVisibility(vis))", comment: "City list summary field") : formatVisibility(vis)
                }

            case .uvIndex:
                // Only show during daytime
                if let isDay = weather.current.isDay, isDay == 1,
                   let uvIndex = weather.current.uvIndex {
                    label += ", "
                    label += isDetails ? String(localized: "summary.uv_index", defaultValue: "UV Index: \(String(format: "%.1f", uvIndex))", comment: "City list summary field") : String(format: "%.1f", uvIndex)
                }

            case .dewPoint:
                if let dewPoint = weather.current.dewpoint2m {
                    label += ", "
                    label += isDetails ? String(localized: "summary.dew_point", defaultValue: "Dew Point: \(formatTemperature(dewPoint))", comment: "City list summary field") : formatTemperature(dewPoint)
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
                        label += isDetails ? String(localized: "summary.high_low", defaultValue: "High: \(formatTemperature(maxTemp)), Low: \(formatTemperature(minTemp))", comment: "City list summary: daily high and low temperatures.") : "\(formatTemperature(maxTemp)), \(formatTemperature(minTemp))"
                    }
                } else {
                    // Only show high temp individually
                    if let daily = weather.daily, !daily.temperature2mMax.isEmpty, let maxTemp = daily.temperature2mMax[0] {
                        label += ", "
                        label += isDetails ? String(localized: "summary.high", defaultValue: "High: \(formatTemperature(maxTemp))", comment: "City list summary field") : formatTemperature(maxTemp)
                    }
                }

            case .lowTemp:
                // Only announce low separately if NOT using combined daily high/low
                if !settingsManager.settings.showDailyHighLowInCityList {
                    if let daily = weather.daily, !daily.temperature2mMin.isEmpty, let minTemp = daily.temperature2mMin[0] {
                        label += ", "
                        label += isDetails ? String(localized: "summary.low", defaultValue: "Low: \(formatTemperature(minTemp))", comment: "City list summary field") : formatTemperature(minTemp)
                    }
                }
                // If showDailyHighLowInCityList is true, already announced with highTemp

            case .sunrise:
                if let daily = weather.daily, let sunriseArray = daily.sunrise, !sunriseArray.isEmpty, let sunrise = sunriseArray[0] {
                    label += ", "
                    label += isDetails ? String(localized: "summary.sunrise", defaultValue: "Sunrise: \(formatTime(sunrise))", comment: "City list summary field") : formatTime(sunrise)
                }

            case .sunset:
                if let daily = weather.daily, let sunsetArray = daily.sunset, !sunsetArray.isEmpty, let sunset = sunsetArray[0] {
                    label += ", "
                    label += isDetails ? String(localized: "summary.sunset", defaultValue: "Sunset: \(formatTime(sunset))", comment: "City list summary field") : formatTime(sunset)
                }
            }
        }
        
        return label
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
        let index = Int((Double(degrees) + 22.5) / 45.0) % 8
        return directions[index]
    }
    
    private func formatPrecipitation(_ mm: Double) -> String {
        let precip = settingsManager.settings.precipitationUnit.convert(mm)
        return String(format: "%.1f %@", precip, settingsManager.settings.precipitationUnit.rawValue)
    }
    
    private func formatSnowfall(_ cm: Double) -> String {
        switch settingsManager.settings.precipitationUnit {
        case .inches: return String(format: "%.1f in", cm * 0.393701)
        case .millimeters: return String(format: "%.1f cm", cm)
        }
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
    ListView(
        selectedCityForHistory: .constant(nil),
        dateOffset: 0,
        selectedDate: Date(),
        showMyLocation: false
    )
        .environmentObject(WeatherService())
        .environmentObject(SettingsManager())
        .environmentObject(MyLocationService.shared)
}
