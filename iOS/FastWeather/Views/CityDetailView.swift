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
    @State private var cacheMetadata: CachedWeather?
    
    private var weather: WeatherData? {
        weatherService.weatherCache[city.id]
    }
    
    private func refreshWeather() async {
        isRefreshing = true
        await weatherService.fetchWeather(for: city)
        isRefreshing = false
        // Refresh cache metadata
        cacheMetadata = await weatherService.getCacheMetadata(for: city.id)
    }
    
    private func loadCacheMetadata() async {
        cacheMetadata = await weatherService.getCacheMetadata(for: city.id)
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
                    VStack(alignment: .leading, spacing: 16) {
                        // Weather summary with condition
                        if let weatherCode = daily.weatherCode?[0], let code = WeatherCode(rawValue: weatherCode) {
                            HStack(spacing: 8) {
                                Image(systemName: code.systemImageName)
                                    .font(.title2)
                                    .foregroundColor(.blue)
                                    .accessibilityHidden(true)
                                Text(code.description)
                                    .font(.headline)
                            }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("Conditions: \(code.description)")
                        }
                        
                        // Temperature range
                        if !daily.temperature2mMax.isEmpty, let maxTemp = daily.temperature2mMax[0],
                           !daily.temperature2mMin.isEmpty, let minTemp = daily.temperature2mMin[0] {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Temperature Range")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .accessibilityHidden(true)
                                HStack {
                                    Text(formatTemperature(minTemp))
                                        .font(.title3)
                                    Text("to")
                                        .foregroundColor(.secondary)
                                        .accessibilityHidden(true)
                                    Text(formatTemperature(maxTemp))
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                }
                            }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("Temperature: Low \(formatTemperature(minTemp)), High \(formatTemperature(maxTemp))")
                        }
                        
                        // Precipitation alert (only if significant)
                        if settingsManager.settings.showPrecipitationProbabilityInTodaysForecast,
                           let precipProb = daily.precipitationProbabilityMax?[0], precipProb > 20 {
                            HStack(spacing: 8) {
                                Image(systemName: "drop.fill")
                                    .foregroundColor(.blue)
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(precipProb)% chance of precipitation")
                                        .font(.subheadline)
                                        .fixedSize(horizontal: false, vertical: true)
                                    // Show snow or rain amount based on which is present (if setting enabled)
                                    if settingsManager.settings.showPrecipitationAmount {
                                        if let snowfall = daily.snowfallSum?[0], snowfall > 0 {
                                            Text("\(formatSnowfall(snowfall)) of snow expected")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .fixedSize(horizontal: false, vertical: true)
                                        } else if let rain = daily.rainSum?[0], rain > 0 {
                                            Text("\(formatPrecipitation(rain)) of rain expected")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .fixedSize(horizontal: false, vertical: true)
                                        } else if let precipSum = daily.precipitationSum?[0], precipSum > 0 {
                                            Text("\(formatPrecipitation(precipSum)) expected")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                    }
                                }
                            }
                            .padding(8)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel({
                                var label = "\(precipProb) percent chance of precipitation"
                                if settingsManager.settings.showPrecipitationAmount {
                                    if let snowfall = daily.snowfallSum?[0], snowfall > 0 {
                                        label += ", \(formatSnowfall(snowfall)) of snow expected"
                                    } else if let rain = daily.rainSum?[0], rain > 0 {
                                        label += ", \(formatPrecipitation(rain)) of rain expected"
                                    } else if let precipSum = daily.precipitationSum?[0], precipSum > 0 {
                                        label += ", \(formatPrecipitation(precipSum)) expected"
                                    }
                                }
                                return label
                            }())
                        }
                        
                        // UV warning (only if significant)
                        if settingsManager.settings.showUVIndexInTodaysForecast,
                           let uvMax = daily.uvIndexMax?[0], uvMax >= 6 {
                            let category = UVIndexCategory(uvIndex: uvMax)
                            HStack(spacing: 8) {
                                Image(systemName: "sun.max.fill")
                                    .foregroundColor(category.color)
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("UV Index: \(Int(uvMax.rounded())) (\(category.category))")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Text("Sun protection recommended")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(8)
                            .background(category.color.opacity(0.1))
                            .cornerRadius(8)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("UV Index: \(Int(uvMax.rounded())) (\(category.category)), Sun protection recommended")
                        }
                        
                        // Wind alert (only if significant)
                        if settingsManager.settings.showWindGustsInTodaysForecast,
                           let windMax = daily.windSpeed10mMax?[0], windMax > 25 {
                            HStack(spacing: 8) {
                                Image(systemName: "wind")
                                    .foregroundColor(.orange)
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Winds up to \(formatWindSpeed(windMax))")
                                        .font(.subheadline)
                                        .fixedSize(horizontal: false, vertical: true)
                                    if let windDir = daily.winddirection10mDominant?[0] {
                                        Text("From \(degreesToCardinalLong(windDir))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                            .padding(8)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel({
                                var label = "Winds up to \(formatWindSpeed(windMax))"
                                if let windDir = daily.winddirection10mDominant?[0] {
                                    label += ", From \(degreesToCardinalLong(windDir))"
                                }
                                return label
                            }())
                        }
                        
                        Divider()
                        
                        // Sun times and daylight
                        VStack(spacing: 8) {
                            if let sunriseArray = daily.sunrise, !sunriseArray.isEmpty, let sunrise = sunriseArray[0],
                               let sunsetArray = daily.sunset, !sunsetArray.isEmpty, let sunset = sunsetArray[0] {
                                HStack {
                                    HStack(spacing: 4) {
                                        Image(systemName: "sunrise.fill")
                                            .foregroundColor(.orange)
                                            .accessibilityHidden(true)
                                        Text(formatTime(sunrise))
                                            .font(.subheadline)
                                    }
                                    .accessibilityElement(children: .ignore)
                                    .accessibilityLabel("Sunrise: \(formatTime(sunrise))")
                                    
                                    Spacer()
                                    
                                    HStack(spacing: 4) {
                                        Image(systemName: "sunset.fill")
                                            .foregroundColor(.orange)
                                            .accessibilityHidden(true)
                                        Text(formatTime(sunset))
                                            .font(.subheadline)
                                    }
                                    .accessibilityElement(children: .ignore)
                                    .accessibilityLabel("Sunset: \(formatTime(sunset))")
                                }
                            }
                            
                            if settingsManager.settings.showDaylightDuration,
                               let daylight = daily.daylightDuration?[0] {
                                HStack(spacing: 4) {
                                    Image(systemName: "sun.max")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .accessibilityHidden(true)
                                    Text("\(formatDuration(daylight)) of daylight")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel("\(formatDuration(daylight)) of daylight")
                            }
                            
                            if settingsManager.settings.showSunshineDuration,
                               let sunshine = daily.sunshineDuration?[0], sunshine > 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: "sun.and.horizon")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .accessibilityHidden(true)
                                    Text("\(formatDuration(sunshine)) of sunshine")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel("\(formatDuration(sunshine)) of sunshine")
                            }
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
                    
                    // Wind Speed with Gusts (if enabled and available)
                    if let windSpeed = weather.current.windSpeed10m {
                        if settingsManager.settings.showWindGustsInCurrentConditions,
                           let windGusts = weather.current.windGusts10m,
                           let windDir = weather.current.windDirection10m {
                            DetailRow(label: "Wind", value: formatWind(speed: windSpeed, direction: windDir, gusts: windGusts, unit: settingsManager.settings.windSpeedUnit.rawValue, degreesToCardinal: degreesToCardinal))
                        } else {
                            DetailRow(label: "Wind Speed", value: formatWindSpeed(windSpeed))
                        }
                        Divider()
                    }
                    
                    if let windDir = weather.current.windDirection10m, weather.current.windSpeed10m == nil {
                        DetailRow(label: "Wind Direction", value: formatWindDirection(windDir))
                        Divider()
                    }
                    
                    // UV Index (if enabled and daytime)
                    if settingsManager.settings.showUVIndexInCurrentConditions,
                       let isDay = weather.current.isDay, isDay == 1,
                       let uvIndex = weather.current.uvIndex {
                        DetailRow(label: "UV Index", value: "\(Int(uvIndex.rounded())) (\(UVIndexCategory(uvIndex: uvIndex).category))")
                        Divider()
                    }
                    
                    // Dew Point (if enabled)
                    if settingsManager.settings.showDewPoint,
                       let dewPoint = weather.current.dewpoint2m {
                        DetailRow(label: "Dew Point", value: formatDewPoint(dewPoint, isFahrenheit: settingsManager.settings.temperatureUnit == .fahrenheit))
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
                                if let time = timeArray[index] {
                                    HourlyForecastCard(
                                        hourly: hourly,
                                        index: index,
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
                            DailyForecastRow(
                                daily: daily,
                                index: index,
                                settingsManager: settingsManager
                            )
                            
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
                    // Cache status indicator (if data is stale)
                    if let metadata = cacheMetadata, metadata.isStale {
                        HStack(spacing: 8) {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundColor(.orange)
                                .accessibilityHidden(true)
                            Text("Using cached data from \(metadata.ageDescription)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Weather data is \(metadata.ageDescription), tap refresh to update")
                    }
                    
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
        .task {
            await loadCacheMetadata()
        }
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
        let unit = settingsManager.settings.temperatureUnit == .fahrenheit ? "F" : "C"
        return String(format: "%.0f°%@", temp, unit)
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
    
    private func formatSnowfall(_ cm: Double) -> String {
        // Snow is measured in cm (API) → convert to inches for US, keep cm elsewhere
        switch settingsManager.settings.precipitationUnit {
        case .inches:
            let inches = cm * 0.393701
            return String(format: "%.1f in", inches)
        case .millimeters:
            return String(format: "%.1f cm", cm)
        }
    }
    
    private func formatPressure(_ hPa: Double) -> String {
        let pressure = settingsManager.settings.pressureUnit.convert(hPa)
        let formatString = settingsManager.settings.pressureUnit == .hPa ? "%.0f %@" : "%.2f %@"
        return String(format: formatString, pressure, settingsManager.settings.pressureUnit.rawValue)
    }
    
    private func formatVisibility(_ meters: Double) -> String {
        let km = meters / 1000.0
        let distance = settingsManager.settings.distanceUnit.convert(km)
        return settingsManager.settings.distanceUnit.format(distance, decimals: 1)
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
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

struct HourlyForecastCard: View {
    let hourly: WeatherData.HourlyWeather
    let index: Int
    @ObservedObject var settingsManager: SettingsManager
    
    private var time: String? {
        hourly.time?[index]
    }
    
    private var formattedTime: String {
        guard let time = time else { return "--" }
        return FormatHelper.formatTimeCompact(time)
    }
    
    private var weatherCodeEnum: WeatherCode? {
        guard let code = hourly.weatherCode?[index] else { return nil }
        return WeatherCode(rawValue: code)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Text(formattedTime)
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Build content based on enabled fields
            ForEach(settingsManager.settings.hourlyFields.filter { $0.isEnabled }, id: \.id) { field in
                if let content = getFieldContent(for: field.type) {
                    content
                }
            }
        }
        .frame(minWidth: 70)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(createAccessibilityLabel())
    }
    
    private func getFieldContent(for fieldType: HourlyFieldType) -> AnyView? {
        switch fieldType {
        case .temperature:
            if let temp = hourly.temperature2m?[index] {
                return AnyView(Text(formatTemperature(temp))
                    .font(.body)
                    .fontWeight(.semibold))
            }
            
        case .conditions:
            if let weatherCode = weatherCodeEnum {
                return AnyView(Image(systemName: weatherCode.systemImageName)
                    .font(.title3)
                    .foregroundColor(.blue)
                    .frame(height: 30))
            }
            
        case .precipitationProbability:
            if let prob = hourly.precipitationProbability?[index], prob > 0 {
                return AnyView(HStack(spacing: 2) {
                    Image(systemName: "drop.fill")
                        .font(.caption2)
                        .foregroundColor(.blue)
                    Text("\(prob)%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                })
            }
            
        case .precipitation:
            if let precip = hourly.precipitation?[index], precip > 0 {
                return AnyView(HStack(spacing: 2) {
                    Image(systemName: "drop.fill")
                        .font(.caption2)
                        .foregroundColor(.blue)
                    Text(formatPrecipitation(precip))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                })
            }
            
        case .uvIndex:
            if let uv = hourly.uvIndex?[index], uv > 0 {
                let category = UVIndexCategory(uvIndex: uv)
                return AnyView(Text("\(Int(uv.rounded()))")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(category.color.opacity(0.2))
                    .foregroundColor(category.color)
                    .cornerRadius(4))
            }
            
        case .windSpeed:
            if let windSpeed = hourly.windSpeed10m?[index], windSpeed > 0 {
                return AnyView(HStack(spacing: 2) {
                    Image(systemName: "wind")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(formatWindSpeed(windSpeed))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                })
            }
            
        case .windGusts:
            if let windGusts = hourly.windgusts10m?[index], windGusts > 0 {
                return AnyView(HStack(spacing: 2) {
                    Image(systemName: "wind")
                        .font(.caption2)
                        .foregroundColor(.orange)
                    Text(formatWindSpeed(windGusts))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                })
            }
            
        case .humidity:
            if let humidity = hourly.relativeHumidity2m?[index] {
                return AnyView(HStack(spacing: 2) {
                    Image(systemName: "humidity")
                        .font(.caption2)
                        .foregroundColor(.blue)
                    Text("\(humidity)%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                })
            }
            
        default:
            break
        }
        return nil
    }
    
    private func createAccessibilityLabel() -> String {
        guard let time = time else { return "No data" }
        
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
        
        var label = hourDescription
        
        // Add enabled fields to label
        for field in settingsManager.settings.hourlyFields.filter({ $0.isEnabled }) {
            if let fieldText = getFieldAccessibilityText(for: field.type) {
                label += ", \(fieldText)"
            }
        }
        
        return label
    }
    
    private func getFieldAccessibilityText(for fieldType: HourlyFieldType) -> String? {
        switch fieldType {
        case .temperature:
            if let temp = hourly.temperature2m?[index] {
                return formatTemperature(temp)
            }
            
        case .conditions:
            return weatherCodeEnum?.description
            
        case .precipitationProbability:
            if let prob = hourly.precipitationProbability?[index], prob > 0 {
                return "\(prob) percent chance of precipitation"
            }
            
        case .precipitation:
            if let precip = hourly.precipitation?[index], precip > 0 {
                return "precipitation \(formatPrecipitation(precip))"
            }
            
        case .uvIndex:
            if let uv = hourly.uvIndex?[index], uv > 0 {
                return getUVIndexDescription(uv)
            }
            
        case .windSpeed:
            if let windSpeed = hourly.windSpeed10m?[index], windSpeed > 0 {
                return "wind \(formatWindSpeed(windSpeed))"
            }
            
        case .windGusts:
            if let windGusts = hourly.windgusts10m?[index], windGusts > 0 {
                return "gusts \(formatWindSpeed(windGusts))"
            }
            
        case .humidity:
            if let humidity = hourly.relativeHumidity2m?[index] {
                return "humidity \(humidity) percent"
            }
            
        default:
            return nil
        }
        
        return nil
    }
    
    private func formatTemperature(_ celsius: Double) -> String {
        let temp = settingsManager.settings.temperatureUnit.convert(celsius)
        let unit = settingsManager.settings.temperatureUnit == .fahrenheit ? "F" : "C"
        return String(format: "%.0f°%@", temp, unit)
    }
    
    private func formatPrecipitation(_ mm: Double) -> String {
        let precip = settingsManager.settings.precipitationUnit.convert(mm)
        return String(format: "%.2f %@", precip, settingsManager.settings.precipitationUnit.rawValue)
    }
    
    private func formatWindSpeed(_ kmh: Double) -> String {
        let speed = settingsManager.settings.windSpeedUnit.convert(kmh)
        return String(format: "%.0f %@", speed, settingsManager.settings.windSpeedUnit.rawValue)
    }
}

struct DailyForecastRow: View {
    let daily: WeatherData.DailyWeather
    let index: Int
    @ObservedObject var settingsManager: SettingsManager
    
    private var sunrise: String? {
        daily.sunrise?[index]
    }
    
    private var high: Double? {
        daily.temperature2mMax[index]
    }
    
    private var low: Double? {
        daily.temperature2mMin[index]
    }
    
    private var dayName: String {
        guard let sunrise = sunrise, let date = DateParser.parse(sunrise) else { return "" }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"
        let dateString = dateFormatter.string(from: date)
        
        if index == 0 {
            return "Today, \(dateString)"
        } else if index == 1 {
            return "Tomorrow, \(dateString)"
        } else {
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "EEEE"
            let weekdayName = dayFormatter.string(from: date)
            return "\(weekdayName), \(dateString)"
        }
    }
    
    private var weatherCodeEnum: WeatherCode? {
        if let code = daily.weatherCode?[index] {
            return WeatherCode(rawValue: code)
        }
        return nil
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(dayName)
                        .font(.body)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(minWidth: 100, maxWidth: 160, alignment: .leading)
                .accessibilityHidden(true)
                
                // Conditions icon - always show if available
                if let weatherCode = weatherCodeEnum {
                    Image(systemName: weatherCode.systemImageName)
                        .font(.title3)
                        .foregroundColor(.blue)
                        .frame(width: 30, alignment: .center)
                        .accessibilityHidden(true)
                }
                
                Spacer()
                
                // Dynamic fields based on settings (compact inline display)
                ForEach(settingsManager.settings.dailyFields.filter { $0.isEnabled }, id: \.id) { field in
                    if let content = getInlineFieldContent(for: field.type) {
                        content
                            .accessibilityHidden(true)
                    }
                }
                
                // Temperatures at the end
                if isFieldEnabled(.temperatureMax) && isFieldEnabled(.temperatureMin),
                   let high = high, let low = low {
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
            }
            
            // Additional detail fields (shown below main row)
            if hasAdditionalDetails() {
                HStack(spacing: 12) {
                    ForEach(settingsManager.settings.dailyFields.filter { $0.isEnabled }, id: \.id) { field in
                        if let content = getDetailFieldContent(for: field.type) {
                            content
                                .accessibilityHidden(true)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(createAccessibilityLabel())
    }
    
    private func getInlineFieldContent(for fieldType: DailyFieldType) -> AnyView? {
        switch fieldType {
        case .precipitationProbability:
            if let prob = daily.precipitationProbabilityMax?[index], prob > 0 {
                return AnyView(HStack(spacing: 4) {
                    Image(systemName: "drop.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text("\(prob)%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(minWidth: 50))
            }
            
        case .rainSum:
            if let rain = daily.rainSum?[index], rain > 0 {
                return AnyView(HStack(spacing: 4) {
                    Image(systemName: "drop.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text(formatPrecipitation(rain))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(minWidth: 50))
            }
            
        case .snowfallSum:
            if let snow = daily.snowfallSum?[index], snow > 0 {
                return AnyView(HStack(spacing: 4) {
                    Image(systemName: "snowflake")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text(formatSnowfall(snow))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(minWidth: 50))
            }
            
        case .precipitationSum:
            if let precip = daily.precipitationSum?[index], precip > 0 {
                return AnyView(HStack(spacing: 4) {
                    Image(systemName: "drop.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text(formatPrecipitation(precip))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(minWidth: 50))
            }
            
        default:
            break
        }
        return nil
    }
    
    private func getDetailFieldContent(for fieldType: DailyFieldType) -> AnyView? {
        switch fieldType {
        case .uvIndexMax:
            if let uvMax = daily.uvIndexMax?[index], uvMax > 0 {
                let category = UVIndexCategory(uvIndex: uvMax)
                return AnyView(HStack(spacing: 4) {
                    Text("UV:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(Int(uvMax.rounded()))")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(category.color.opacity(0.2))
                        .foregroundColor(category.color)
                        .cornerRadius(4)
                })
            }
            
        case .daylightDuration:
            if let daylight = daily.daylightDuration?[index] {
                return AnyView(HStack(spacing: 4) {
                    Image(systemName: "sun.max")
                        .font(.caption2)
                    Text(formatDuration(daylight))
                        .font(.caption2)
                }
                .foregroundColor(.secondary))
            }
            
        case .sunshineDuration:
            if let sunshine = daily.sunshineDuration?[index] {
                return AnyView(HStack(spacing: 4) {
                    Image(systemName: "sun.max.fill")
                        .font(.caption2)
                    Text(formatDuration(sunshine))
                        .font(.caption2)
                }
                .foregroundColor(.secondary))
            }
            
        case .windSpeedMax:
            if let windMax = daily.windSpeed10mMax?[index], windMax > 0 {
                return AnyView(HStack(spacing: 4) {
                    Image(systemName: "wind")
                        .font(.caption2)
                    Text(formatWindSpeed(windMax))
                        .font(.caption2)
                }
                .foregroundColor(.secondary))
            }
            
        default:
            break
        }
        return nil
    }
    
    private func hasAdditionalDetails() -> Bool {
        for field in settingsManager.settings.dailyFields.filter({ $0.isEnabled }) {
            switch field.type {
            case .uvIndexMax, .daylightDuration, .sunshineDuration, .windSpeedMax:
                if getDetailFieldContent(for: field.type) != nil {
                    return true
                }
            default:
                continue
            }
        }
        return false
    }
    
    private func isFieldEnabled(_ type: DailyFieldType) -> Bool {
        settingsManager.settings.dailyFields.first(where: { $0.type == type })?.isEnabled ?? false
    }
    
    private func createAccessibilityLabel() -> String {
        var text = dayName
        
        // Add enabled fields to label
        for field in settingsManager.settings.dailyFields.filter({ $0.isEnabled }) {
            if let fieldText = getFieldAccessibilityText(for: field.type) {
                text += ", \(fieldText)"
            }
        }
        
        return text
    }
    
    private func getFieldAccessibilityText(for fieldType: DailyFieldType) -> String? {
        switch fieldType {
        case .conditions:
            return weatherCodeEnum?.description
            
        case .temperatureMax:
            if let high = high {
                return "High \(formatTemperature(high))"
            }
            
        case .temperatureMin:
            if let low = low {
                return "Low \(formatTemperature(low))"
            }
            
        case .precipitationProbability:
            if let prob = daily.precipitationProbabilityMax?[index], prob > 0 {
                return "\(prob) percent chance of precipitation"
            }
            
        case .rainSum:
            if let rain = daily.rainSum?[index], rain > 0 {
                return "\(formatPrecipitation(rain)) of rain"
            }
            
        case .snowfallSum:
            if let snow = daily.snowfallSum?[index], snow > 0 {
                return "\(formatSnowfall(snow)) of snow"
            }
            
        case .precipitationSum:
            if let precip = daily.precipitationSum?[index], precip > 0 {
                return "precipitation \(formatPrecipitation(precip))"
            }
            
        case .uvIndexMax:
            if let uvMax = daily.uvIndexMax?[index] {
                return getUVIndexDescription(uvMax)
            }
            
        case .daylightDuration:
            if let daylight = daily.daylightDuration?[index] {
                return "\(formatDuration(daylight)) of daylight"
            }
            
        case .sunshineDuration:
            if let sunshine = daily.sunshineDuration?[index] {
                return "\(formatDuration(sunshine)) of sunshine"
            }
            
        case .windSpeedMax:
            if let windMax = daily.windSpeed10mMax?[index] {
                return "max wind \(formatWindSpeed(windMax))"
            }
            
        case .sunrise:
            if let sunrise = sunrise {
                return "Sunrise \(FormatHelper.formatTime(sunrise))"
            }
            
        case .sunset:
            if let sunset = daily.sunset?[index] {
                return "Sunset \(FormatHelper.formatTime(sunset))"
            }
            
        default:
            return nil
        }
        
        return nil
    }
    
    private func formatTemperature(_ celsius: Double) -> String {
        let temp = settingsManager.settings.temperatureUnit.convert(celsius)
        let unit = settingsManager.settings.temperatureUnit == .fahrenheit ? "F" : "C"
        return String(format: "%.0f°%@", temp, unit)
    }
    
    private func formatPrecipitation(_ mm: Double) -> String {
        let precip = settingsManager.settings.precipitationUnit.convert(mm)
        return String(format: "%.1f %@", precip, settingsManager.settings.precipitationUnit.rawValue)
    }
    
    private func formatSnowfall(_ cm: Double) -> String {
        // Convert cm to mm, then to user's unit
        let mm = cm * 10
        return formatPrecipitation(mm)
    }
    
    private func formatWindSpeed(_ kmh: Double) -> String {
        let speed = settingsManager.settings.windSpeedUnit.convert(kmh)
        return String(format: "%.0f %@", speed, settingsManager.settings.windSpeedUnit.rawValue)
    }
    
    private func formatDuration(_ seconds: Double) -> String {
        let hours = Int(seconds / 3600)
        let minutes = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(hours)h"
        }
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
        .task(id: city.id) {
            guard !hasLoaded else { return }
            
            do {
                let fetchedAlerts = try await weatherService.fetchNWSAlerts(for: city)
                
                alerts = fetchedAlerts
                isLoading = false
                hasLoaded = true
            } catch {
                isLoading = false
                hasLoaded = true
            }
        }
    }
}
