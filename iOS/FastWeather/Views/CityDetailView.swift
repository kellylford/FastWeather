//
//  CityDetailView.swift
//  Fast Weather
//
//  Detailed weather view for a city
//

import SwiftUI

struct CityDetailView: View {
    let city: City
    @EnvironmentObject var weatherService: WeatherService
    @EnvironmentObject var settingsManager: SettingsManager
    @StateObject private var featureFlags = FeatureFlags.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingHistoricalWeather = false
    @State private var showingRadar = false
    @State private var showingWeatherAroundMe = false
    @State private var selectedAlert: WeatherAlert?
    @State private var showingRemoveConfirmation = false
    @State private var removalCityName = "" // Captured at trigger time to prevent dialog flashing
    @State private var isRefreshing = false
    
    private var weather: WeatherData? {
        weatherService.weatherCache[city.id]
    }
    
    private func refreshWeather() async {
        isRefreshing = true
        await weatherService.fetchWeather(for: city)
        isRefreshing = false
    }
    
    private func isCategoryEnabled(_ category: DetailCategory) -> Bool {
        return settingsManager.settings.detailCategories.first(where: { $0.category == category })?.isEnabled ?? true
    }
    
    @ViewBuilder
    private func detailSection(for category: DetailCategory, weather: WeatherData) -> some View {
        switch category {
        case .todaysForecast:
            if let daily = weather.daily {
                GroupBox(label: Label("Today's Forecast", systemImage: "calendar")) {
                    VStack(spacing: 12) {
                        if !daily.temperature2mMax.isEmpty, let maxTemp = daily.temperature2mMax[0] {
                            DetailRow(label: "High", value: formatTemperature(maxTemp))
                            Divider()
                        }
                        if !daily.temperature2mMin.isEmpty, let minTemp = daily.temperature2mMin[0] {
                            DetailRow(label: "Low", value: formatTemperature(minTemp))
                            Divider()
                        }
                        if let sunriseArray = daily.sunrise, !sunriseArray.isEmpty, let sunrise = sunriseArray[0] {
                            DetailRow(label: "Sunrise", value: formatTime(sunrise))
                            Divider()
                        }
                        if let sunsetArray = daily.sunset, !sunsetArray.isEmpty, let sunset = sunsetArray[0] {
                            DetailRow(label: "Sunset", value: formatTime(sunset))
                        }
                    }
                    .padding(.vertical, 8)
                }
                .padding(.horizontal)
                .accessibilityElement(children: .contain)
            }
            
        case .currentConditions:
            GroupBox(label: Label("Current Conditions", systemImage: "thermometer")) {
                VStack(spacing: 12) {
                    if let humidity = weather.current.relativeHumidity2m {
                        DetailRow(label: "Humidity", value: "\(humidity)%")
                        Divider()
                    }
                    if let windSpeed = weather.current.windSpeed10m {
                        DetailRow(label: "Wind Speed", value: formatWindSpeed(windSpeed))
                        Divider()
                    }
                    if let windDir = weather.current.windDirection10m {
                        DetailRow(label: "Wind Direction", value: formatWindDirection(windDir))
                        Divider()
                    }
                    if let pressure = weather.current.pressureMsl {
                        DetailRow(label: "Pressure", value: formatPressure(pressure))
                        Divider()
                    }
                    if let visibility = weather.current.visibility {
                        DetailRow(label: "Visibility", value: formatVisibility(visibility))
                        Divider()
                    }
                    DetailRow(label: "Cloud Cover", value: "\(weather.current.cloudCover)%")
                }
                .padding(.vertical, 8)
            }
            .padding(.horizontal)
            .accessibilityElement(children: .contain)
            
        case .precipitation:
            GroupBox(label: Label("Precipitation", systemImage: "cloud.rain")) {
                VStack(spacing: 12) {
                    if let precip = weather.current.precipitation {
                        DetailRow(label: "Total", value: formatPrecipitation(precip))
                        Divider()
                    }
                    if let rain = weather.current.rain {
                        DetailRow(label: "Rain", value: formatPrecipitation(rain))
                        Divider()
                    }
                    if let showers = weather.current.showers {
                        DetailRow(label: "Showers", value: formatPrecipitation(showers))
                        Divider()
                    }
                    if let snow = weather.current.snowfall {
                        DetailRow(label: "Snowfall", value: formatPrecipitation(snow))
                    }
                }
                .padding(.vertical, 8)
            }
            .padding(.horizontal)
            .accessibilityElement(children: .contain)
            
        case .hourlyForecast:
            if let hourly = weather.hourly,
               let timeArray = hourly.time,
               !timeArray.isEmpty,
               let tempArray = hourly.temperature2m,
               let weatherCodeArray = hourly.weatherCode,
               let precipArray = hourly.precipitation {
                GroupBox(label: Label("24-Hour Forecast", systemImage: "clock")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            let currentHourIndex = findCurrentHourIndex(in: timeArray)
                            let startIndex = currentHourIndex >= 0 ? currentHourIndex : 0
                            let endIndex = min(startIndex + 24, timeArray.count)
                            
                            ForEach(startIndex..<endIndex, id: \.self) { index in
                                if let time = timeArray[index],
                                   let temperature = tempArray[index],
                                   let weatherCode = weatherCodeArray[index],
                                   let precipitation = precipArray[index] {
                                    HourlyForecastCard(
                                        time: time,
                                        temperature: temperature,
                                        weatherCode: weatherCode,
                                        precipitation: precipitation,
                                        settingsManager: settingsManager
                                    )
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                }
                .padding(.horizontal)
            }
            
        case .dailyForecast:
            if let daily = weather.daily, daily.temperature2mMax.count > 1 {
                GroupBox(label: Label("16-Day Forecast", systemImage: "calendar")) {
                    VStack(spacing: 0) {
                        ForEach(0..<min(16, daily.temperature2mMax.count), id: \.self) { index in
                            if let high = daily.temperature2mMax[index],
                               let low = daily.temperature2mMin[index],
                               let sunriseArray = daily.sunrise,
                               let sunrise = sunriseArray[index] {
                                DailyForecastRow(
                                    dayIndex: index,
                                    sunrise: sunrise,
                                    high: high,
                                    low: low,
                                    weatherCode: daily.weatherCode?[index],
                                    precipitation: daily.precipitationSum?[index],
                                    settingsManager: settingsManager
                                )
                            }
                            
                            if index < min(15, daily.temperature2mMax.count - 1) {
                                Divider()
                                    .padding(.leading)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                .padding(.horizontal)
            }
            
        case .historicalWeather:
            EmptyView() // Historical weather moved to separate screen
            
        case .weatherAlerts:
            // Weather alerts section (US only)
            WeatherAlertsSection(city: city, selectedAlert: $selectedAlert)
                .onAppear {
                    print("🔶 WeatherAlerts category appeared for \(city.name)")
                }
            
        case .location:
            GroupBox(label: Label("Location", systemImage: "mappin.and.ellipse")) {
                VStack(spacing: 12) {
                    DetailRow(label: "City", value: city.name)
                    if let state = city.state {
                        Divider()
                        DetailRow(label: "State", value: state)
                    }
                    Divider()
                    DetailRow(label: "Country", value: city.country)
                    Divider()
                    DetailRow(label: "Coordinates", value: String(format: "%.4f, %.4f", city.latitude, city.longitude))
                }
                .padding(.vertical, 8)
            }
            .padding(.horizontal)
            .accessibilityElement(children: .contain)
        }
    }
    
    var body: some View {
        let _ = print("🟢 CityDetailView body called for \(city.name), selectedAlert: \(selectedAlert?.event ?? "nil")")
        ScrollView {
            VStack(spacing: 24) {
                if let weather = weather {
                    // Main weather display
                    VStack(spacing: 16) {
                        // Current temperature - read first after city name
                        Text(formatTemperature(weather.current.temperature2m))
                            .font(.system(size: 72, weight: .bold))
                            .accessibilityLabel("Current temperature \(formatTemperature(weather.current.temperature2m))")
                        
                        // Temperature and condition
                        if let weatherCode = weather.current.weatherCodeEnum {
                            Image(systemName: weatherCode.systemImageName)
                                .font(.system(size: 80))
                                .foregroundColor(.blue)
                                .accessibilityHidden(true)
                            
                            Text(weatherCode.description)
                                .font(.title2)
                                .accessibilityLabel("Conditions: \(weatherCode.description)")
                        }
                        
                        if let apparentTemp = weather.current.apparentTemperature {
                            Text("Feels like \(formatTemperature(apparentTemp))")
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    
                    // Actions Menu
                    Menu {
                        Button(action: {
                            Task {
                                await refreshWeather()
                            }
                        }) {
                            Label("Refresh Weather", systemImage: "arrow.clockwise")
                        }
                        
                        Divider()
                        
                        Button(action: { showingHistoricalWeather = true }) {
                            Label("View Historical Weather", systemImage: "clock.arrow.circlepath")
                        }
                        
                        if featureFlags.radarEnabled {
                            Button(action: { showingRadar = true }) {
                                Label("Expected Precipitation", systemImage: "cloud.rain")
                            }
                        }
                        
                        if featureFlags.weatherAroundMeEnabled {
                            Button(action: { showingWeatherAroundMe = true }) {
                                Label("Weather Around Me", systemImage: "location.circle")
                            }
                        }
                        
                        Divider()
                        
                        Button(role: .destructive, action: { 
                            removalCityName = city.name
                            showingRemoveConfirmation = true 
                        }) {
                            Label("Remove City", systemImage: "trash")
                        }
                    } label: {
                        HStack {
                            Image(systemName: "ellipsis.circle")
                                .font(.title2)
                            Text("Actions")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .accessibilityLabel("Actions menu")
                    .accessibilityHint("Opens menu with options to refresh weather, view historical weather, precipitation forecast, weather around me, and remove city")
                    
                    // Dynamically render detail sections based on settings order
                    let _ = print("📊 Detail categories: \(settingsManager.settings.detailCategories.map { "\($0.category)=\($0.isEnabled)" }.joined(separator: ", "))")
                    ForEach(settingsManager.settings.detailCategories) { categoryField in
                        if categoryField.isEnabled {
                            detailSection(for: categoryField.category, weather: weather)
                        }
                    }
                    
                } else {
                    ProgressView("Loading weather data...")
                        .padding()
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(city.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await refreshWeather()
        }
        .sheet(isPresented: $showingHistoricalWeather) {
            NavigationView {
                HistoricalWeatherView(city: city)
                    .navigationTitle("Historical Weather")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showingHistoricalWeather = false
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $showingRadar) {
            NavigationView {
                RadarView(city: city)
                    .environmentObject(settingsManager)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showingRadar = false
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $showingWeatherAroundMe) {
            NavigationView {
                WeatherAroundMeView(city: city, defaultDistance: settingsManager.settings.weatherAroundMeDistance)
                    .environmentObject(settingsManager)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showingWeatherAroundMe = false
                            }
                        }
                    }
            }
        }
        .sheet(item: $selectedAlert) { alert in
            AlertDetailView(alert: alert)
        }
        .confirmationDialog(
            "Remove \(removalCityName)?",
            isPresented: $showingRemoveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                dismiss()
                // Defer removal until after dismiss animation completes to avoid UICollectionView crash
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    weatherService.removeCity(city)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This city will be removed from your list.")
        }
        .onChange(of: showingRemoveConfirmation) { oldValue, newValue in
            // Flash detection: Alert should never go from true to true
            if oldValue == true && newValue == true {
                print("⚠️ ALERT FLASH DETECTED in CityDetailView confirmation dialog!")
            }
        }
    }
    
    private func formatTemperature(_ celsius: Double) -> String {
        let temp = settingsManager.settings.temperatureUnit.convert(celsius)
        return String(format: "%.0f%@", temp, settingsManager.settings.temperatureUnit.rawValue)
    }
    
    private func formatWindSpeed(_ kmh: Double) -> String {
        let speed = settingsManager.settings.windSpeedUnit.convert(kmh)
        return String(format: "%.1f %@", speed, settingsManager.settings.windSpeedUnit.rawValue)
    }
    
    private func formatWindDirection(_ degrees: Int) -> String {
        let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let index = Int((Double(degrees) / 45.0).rounded()) % 8
        return "\(directions[index]) (\(degrees)°)"
    }
    
    private func formatPrecipitation(_ mm: Double) -> String {
        let precip = settingsManager.settings.precipitationUnit.convert(mm)
        return String(format: "%.2f %@", precip, settingsManager.settings.precipitationUnit.rawValue)
    }
    
    private func formatPressure(_ hPa: Double) -> String {
        let pressure = settingsManager.settings.pressureUnit.convert(hPa)
        let formatString = settingsManager.settings.pressureUnit == .hPa ? "%.0f %@" : "%.2f %@"
        return String(format: formatString, pressure, settingsManager.settings.pressureUnit.rawValue)
    }
    
    private func formatVisibility(_ meters: Double) -> String {
        let miles = meters * 0.000621371
        return String(format: "%.1f mi", miles)
    }
    
    private func formatTime(_ isoString: String) -> String {
        FormatHelper.formatTime(isoString)
    }
    
    private func findCurrentHourIndex(in times: [String?]) -> Int {
        let now = Date()
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: now)
        
        // Parse each time and find the one matching or after current hour
        for (index, timeString) in times.enumerated() {
            guard let timeString = timeString else { continue }
            if let time = DateParser.parse(timeString) {
                let hour = calendar.component(.hour, from: time)
                if hour >= currentHour {
                    return index
                }
            }
        }
        
        return 0 // Fallback to start if not found
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

struct HourlyForecastCard: View {
    let time: String
    let temperature: Double
    let weatherCode: Int
    let precipitation: Double
    let settingsManager: SettingsManager
    
    private var formattedTime: String {
        FormatHelper.formatTimeCompact(time)
    }
    
    private var weatherCodeEnum: WeatherCode? {
        WeatherCode(rawValue: weatherCode)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Text(formattedTime)
                .font(.caption)
                .foregroundColor(.secondary)
            
            if let weatherCode = weatherCodeEnum {
                Image(systemName: weatherCode.systemImageName)
                    .font(.title3)
                    .foregroundColor(.blue)
                    .frame(height: 30)
            }
            
            Text(formatTemperature(temperature))
                .font(.body)
                .fontWeight(.semibold)
            
            if precipitation > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "drop.fill")
                        .font(.caption2)
                        .foregroundColor(.blue)
                    Text(formatPrecipitation(precipitation))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(width: 70)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(createAccessibilityLabel())
    }
    
    private func createAccessibilityLabel() -> String {
        // Extract hour for more natural speech
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        var hourDescription = formattedTime
        if let date = formatter.date(from: time) {
            let calendar = Calendar.current
            let hour = calendar.component(.hour, from: date)
            let minute = calendar.component(.minute, from: date)
            let ampm = hour < 12 ? "AM" : "PM"
            let hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
            hourDescription = minute > 0 ? "\(hour12):\(String(format: "%02d", minute)) \(ampm)" : "\(hour12) \(ampm)"
        }
        
        var label = "\(hourDescription), \(formatTemperature(temperature))"
        if let weatherCode = weatherCodeEnum {
            label += ", \(weatherCode.description)"
        }
        if precipitation > 0 {
            label += ", precipitation \(formatPrecipitation(precipitation))"
        }
        return label
    }
    
    private func formatTemperature(_ celsius: Double) -> String {
        let temp = settingsManager.settings.temperatureUnit.convert(celsius)
        return String(format: "%.0f%@", temp, settingsManager.settings.temperatureUnit.rawValue)
    }
    
    private func formatPrecipitation(_ mm: Double) -> String {
        let precip = settingsManager.settings.precipitationUnit.convert(mm)
        return String(format: "%.2f %@", precip, settingsManager.settings.precipitationUnit.rawValue)
    }
}

struct DailyForecastRow: View {
    let dayIndex: Int
    let sunrise: String
    let high: Double
    let low: Double
    let weatherCode: Int?
    let precipitation: Double?
    let settingsManager: SettingsManager
    
    private var dayName: String {
        guard let date = DateParser.parse(sunrise) else { return "" }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"
        let dateString = dateFormatter.string(from: date)
        
        if dayIndex == 0 {
            return "Today, \(dateString)"
        } else if dayIndex == 1 {
            return "Tomorrow, \(dateString)"
        } else {
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "EEEE"
            let weekdayName = dayFormatter.string(from: date)
            return "\(weekdayName), \(dateString)"
        }
    }
    
    private var weatherCodeEnum: WeatherCode? {
        if let code = weatherCode {
            return WeatherCode(rawValue: code)
        }
        return nil
    }
    
    private var accessibilityText: String {
        var text = "\(dayName)"
        if let weatherCode = weatherCodeEnum {
            text += ", \(weatherCode.description)"
        }
        text += ", High \(formatTemperature(high)), Low \(formatTemperature(low))"
        if let precip = precipitation, precip > 0 {
            text += ", precipitation \(formatPrecipitation(precip))"
        }
        return text
    }
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(dayName)
                    .font(.body)
            }
            .frame(width: 140, alignment: .leading)
            .accessibilityHidden(true)
            
            if let weatherCode = weatherCodeEnum {
                Image(systemName: weatherCode.systemImageName)
                    .font(.title3)
                    .foregroundColor(.blue)
                    .frame(width: 30)
                    .accessibilityHidden(true)
            }
            
            Spacer()
            
            if let precip = precipitation, precip > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "drop.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text(formatPrecipitation(precip))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(width: 60)
                .accessibilityHidden(true)
            }
            
            HStack(spacing: 8) {
                Text(formatTemperature(low))
                    .font(.body)
                    .foregroundColor(.secondary)
                
                Text(formatTemperature(high))
                    .font(.body)
                    .fontWeight(.semibold)
            }
            .accessibilityHidden(true)
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }
    
    private func formatTemperature(_ celsius: Double) -> String {
        let temp = settingsManager.settings.temperatureUnit.convert(celsius)
        return String(format: "%.0f%@", temp, settingsManager.settings.temperatureUnit.rawValue)
    }
    
    private func formatPrecipitation(_ mm: Double) -> String {
        let precip = settingsManager.settings.precipitationUnit.convert(mm)
        return String(format: "%.2f %@", precip, settingsManager.settings.precipitationUnit.rawValue)
    }
}

// MARK: - Weather Alerts Section
struct WeatherAlertsSection: View {
    let city: City
    @Binding var selectedAlert: WeatherAlert?
    @EnvironmentObject var weatherService: WeatherService
    @State private var alerts: [WeatherAlert] = []
    @State private var isLoading = true
    @State private var hasLoaded = false  // Prevent re-fetching on every appear
    
    var body: some View {
        GroupBox(label: Label("Weather Alerts", systemImage: "exclamationmark.triangle.fill")) {
            VStack(spacing: 12) {
                if isLoading {
                    ProgressView("Checking for alerts...")
                        .frame(minHeight: 60)  // Consistent height to prevent layout shift
                        .padding()
                } else if alerts.isEmpty {
                    Text("No active alerts")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(minHeight: 60)  // Match loading height
                        .padding()
                } else {
                    ForEach(alerts) { alert in
                        Button(action: {
                            print("🔔 Alert button tapped: \(alert.event)")
                            selectedAlert = alert
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Image(systemName: alert.severity.iconName)
                                            .foregroundColor(alert.severity.color)
                                        Text(alert.event)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                    }
                                    
                                    Text(alert.headline)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 4)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(alert.severity.rawValue.capitalized) alert: \(alert.event)")
                        .accessibilityHint("Double tap to view alert details")
                        
                        if alert.id != alerts.last?.id {
                            Divider()
                        }
                    }
                }
            }
            .padding(.vertical, 8)
            .animation(.easeInOut(duration: 0.2), value: isLoading)  // Smooth transition
        }
        .padding(.horizontal)
        .accessibilityElement(children: .contain)
        .task(id: city.id) {  // Use .task instead of .onAppear, re-run only if city changes
            guard !hasLoaded else { return }
            
            print("🔵 WeatherAlertsSection loading for \(city.name)")
            do {
                print("📱 Fetching alerts for \(city.name)...")
                let fetchedAlerts = try await weatherService.fetchNWSAlerts(for: city)
                print("✅ Fetched \(fetchedAlerts.count) alerts for \(city.name)")
                
                alerts = fetchedAlerts
                isLoading = false
                hasLoaded = true
            } catch {
                print("❌ Failed to fetch alerts for \(city.name): \(error)")
                isLoading = false
                hasLoaded = true
            }
        }
    }
}
