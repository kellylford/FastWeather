//
//  WeatherAroundMeView.swift
//  Fast Weather
//
//  Regional weather comparison showing conditions in all directions
//  Provides "big picture" weather context for accessibility
//

import SwiftUI
import CoreLocation

struct WeatherAroundMeView: View {
    let city: City
    let defaultDistance: Double
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var weatherService: WeatherService
    @State private var regionalWeather: RegionalWeatherData?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var lastUpdated: Date?
    @State private var distanceMiles: Double
    
    // Directional Explorer state
    @State private var selectedDirection: CardinalDirection = .north
    @State private var citiesInDirection: [DirectionalCityInfo] = []
    @State private var currentCityIndex: Int = 0
    @State private var showingAllCities = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var directionalWeatherData: [UUID: (temp: Double, condition: String, windDirection: Double, windSpeed: Double, pressure: Double, alerts: [WeatherAlert])] = [:]
    @State private var isLoadingCities = false
    @State private var showingSettings = false
    // Shared WeatherService instance so batchFetchWeatherBasic cache is reused across all city fetches
    @State private var directionalWeatherService = WeatherService()
    
    init(city: City, defaultDistance: Double = 150) {
        self.city = city
        self.defaultDistance = defaultDistance
        _distanceMiles = State(initialValue: defaultDistance)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Distance Picker
                VStack(spacing: 8) {
                    HStack {
                        Text("Distance")
                            .font(.headline)
                        Spacer()
                    }
                    
                    Picker("Distance Radius", selection: $distanceMiles) {
                        ForEach(settingsManager.settings.distanceUnit.weatherAroundMeOptions, id: \.self) { distance in
                            Text(settingsManager.settings.distanceUnit.format(distance)).tag(distance)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 100)
                    .accessibilityLabel("Distance radius")
                    .accessibilityValue(settingsManager.settings.distanceUnit.format(distanceMiles))
                    .accessibilityHint("Select the radius for surrounding weather data. Options range from \(Int(settingsManager.settings.distanceUnit.weatherAroundMeOptions.first ?? 0)) to \(Int(settingsManager.settings.distanceUnit.weatherAroundMeOptions.last ?? 0)) \(settingsManager.settings.distanceUnit.rawValue).")
                    .onChange(of: distanceMiles) {
                        Task { await loadRegionalWeather() }
                    }
                }
                .padding()
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(12)
                
                if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error)
                } else if let regional = regionalWeather {
                    regionalContent(regional)
                }
            }
            .padding()
        }
        .navigationTitle("Weather Around Me")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    Button(action: {
                        showingSettings = true
                    }) {
                        Label("Settings", systemImage: "gearshape")
                    }
                    .accessibilityLabel("Weather Around Me Settings")
                    .accessibilityValue(currentExplorationModeDescription())
                    .accessibilityHint("Opens settings sheet. Swipe up or down to cycle through exploration modes.")
                    .accessibilityAdjustableAction { direction in
                        switch direction {
                        case .increment:
                            cycleExplorationMode(forward: true)
                        case .decrement:
                            cycleExplorationMode(forward: false)
                        @unknown default:
                            break
                        }
                    }
                    
                    Button(action: {
                        Task { await loadRegionalWeather() }
                    }) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .accessibilityLabel("Refresh regional weather data")
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            WeatherAroundMeSettingsSheet()
                .environmentObject(settingsManager)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onChange(of: settingsManager.settings.weatherAroundMeExplorationMode) {
            loadCitiesInDirection()
        }
        .onChange(of: settingsManager.settings.weatherAroundMeArcWidth) {
            loadCitiesInDirection()
        }
        .onChange(of: settingsManager.settings.weatherAroundMeCorridorWidth) {
            loadCitiesInDirection()
        }
        .task {
            await loadRegionalWeather()
        }
        .refreshable {
            await loadRegionalWeather()
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading regional weather...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading regional weather")
    }
    
    // MARK: - Error View
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.orange)
                .accessibilityHidden(true)
            
            Text("Unable to Load Regional Weather")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: {
                Task { await loadRegionalWeather() }
            }) {
                Label("Try Again", systemImage: "arrow.clockwise")
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Unable to load regional weather. \(message). Tap Try Again to reload.")
    }
    
    // MARK: - Regional Content
    private func regionalContent(_ regional: RegionalWeatherData) -> some View {
        VStack(spacing: 24) {
            // Last updated timestamp
            if let lastUpdated = lastUpdated {
                HStack {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Updated \(formatLastUpdated(lastUpdated))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Data last updated \(formatLastUpdated(lastUpdated))")
            }
            
            // Your Location
            currentLocationCard(regional.center)
            
            // Regional Summary
            regionalSummaryCard(regional)
            
            // Directional Weather Cards
            directionalWeatherSection(regional)
            
            // Directional Explorer
            directionalExplorerSection()
            
            // Data Attribution
            Text("Weather data by Open-Meteo.com")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top)
        }
    }
    
    // MARK: - Current Location Card
    private func currentLocationCard(_ location: DirectionalLocation) -> some View {
        GroupBox(label: Label("Your Location", systemImage: "location.fill")) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(city.name)
                            .font(.title2.bold())
                        if let condition = location.condition {
                            Text(condition)
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    if let temp = location.temperature {
                        Text(formatTemperature(temp))
                            .font(.system(size: 48, weight: .light))
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(currentLocationAccessibilityLabel(location))
    }
    
    // MARK: - Directional Weather Section
    private func directionalWeatherSection(_ regional: RegionalWeatherData) -> some View {
        GroupBox(label: Label("Surrounding Areas", systemImage: "compass")) {
            VStack(spacing: 12) {
                ForEach(regional.directions, id: \.direction) { location in
                    directionalWeatherRow(location)
                    
                    if location.direction != regional.directions.last?.direction {
                        Divider()
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Weather in surrounding areas")
    }
    
    private func directionalWeatherRow(_ location: DirectionalLocation) -> some View {
        let actualDistance = calculateDistance(from: city, to: location)
        
        return NavigationLink(destination: AroundMeCityDetailView(city: cityFromDirectional(location))) {
            HStack {
                // Direction icon and label
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: directionIcon(location.direction))
                            .font(.title3)
                            .foregroundColor(.accentColor)
                            .frame(width: 30)
                            .accessibilityHidden(true)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(location.direction)
                                .font(.headline)
                            
                            if let locationName = location.locationName {
                                Text("\(locationName) (\(settingsManager.settings.distanceUnit.format(Double(actualDistance))))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text(settingsManager.settings.distanceUnit.format(Double(actualDistance)))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    if let condition = location.condition {
                        Text(condition)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Temperature
                if let temp = location.temperature {
                    Text(formatTemperature(temp))
                        .font(.title3.weight(.semibold))
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(directionalAccessibilityLabel(location))
        .accessibilityHint("Double tap to view full weather detail for this location")
    }
    
    // MARK: - City Construction Helpers
    
    /// Construct a City from a DirectionalLocation (surrounding areas overview row)
    private func cityFromDirectional(_ location: DirectionalLocation) -> City {
        City(
            name: location.locationName ?? "\(location.direction) of \(city.name)",
            state: nil,
            country: city.country,  // inherit center city's country for displayName formatting
            latitude: location.latitude,
            longitude: location.longitude
        )
    }
    
    /// Construct a City from a DirectionalCityInfo (directional explorer stepper)
    private func cityFromDirectionalInfo(_ info: DirectionalCityInfo) -> City {
        City(
            name: info.name,
            state: info.state,
            country: info.country,
            latitude: info.latitude,
            longitude: info.longitude
        )
    }
    
    // MARK: - Directional Explorer Section
    private func directionalExplorerSection() -> some View {
        GroupBox(label: Label("Explore Direction", systemImage: "location.north.line")) {
            VStack(spacing: 16) {
                // Direction Picker
                Picker("Direction", selection: $selectedDirection) {
                    ForEach(CardinalDirection.allCases, id: \.self) { direction in
                        HStack {
                            Image(systemName: direction.icon)
                                .accessibilityHidden(true)
                            Text(direction.rawValue)
                        }
                        .tag(direction)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 120)
                .accessibilityLabel("Select direction to explore")
                .accessibilityValue(selectedDirection.rawValue)
                .onChange(of: selectedDirection) {
                    UIAccessibility.post(notification: .announcement, argument: selectedDirection.rawValue)
                    loadCitiesInDirection()
                }
                
                Divider()
                
                // City Explorer
                if isLoadingCities {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Finding cities along bearing...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .accessibilityLabel("Loading cities in \(selectedDirection.rawValue) direction")
                } else if citiesInDirection.isEmpty {
                    Text("No cities found in this direction")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    cityExplorerView
                }
            }
            .padding(.vertical, 8)
        }
        .accessibilityElement(children: .contain)
        .task {
            loadCitiesInDirection()
        }
    }
    
    private var cityExplorerView: some View {
        VStack(spacing: 12) {
            // Current city display
            if citiesInDirection.indices.contains(currentCityIndex) {
                let currentCity = citiesInDirection[currentCityIndex]
                
                VStack(spacing: 8) {
                    Text(currentCity.displayName(relativeTo: city.country))
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    
                    // Weather info if available
                    if let weather = directionalWeatherData[currentCity.id] {
                        HStack(spacing: 8) {
                            Text(formatTemperature(weather.temp))
                                .font(.title2.weight(.semibold))
                            Text(weather.condition)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        ProgressView()
                            .accessibilityLabel("Loading weather")
                    }
                    
                    Text(formatDistanceFromMiles(currentCity.distanceMiles))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("\(currentCityIndex + 1) of \(citiesInDirection.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(10)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("City explorer")
                .accessibilityValue(cityExplorerAccessibilityLabel(currentCity))
                .accessibilityHint("Swipe up for farther cities, swipe down for closer cities. Activate to view full weather detail.")
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment:
                        // Swipe up = next farther city
                        if currentCityIndex < citiesInDirection.count - 1 {
                            currentCityIndex += 1
                        }
                    case .decrement:
                        // Swipe down = next closer city
                        if currentCityIndex > 0 {
                            currentCityIndex -= 1
                        }
                    @unknown default:
                        break
                    }
                }
                .task(id: currentCity.id) {
                    await loadWeatherForCity(currentCity)
                }
                .onChange(of: currentCityIndex) {
                    // Prefetch next batch when user navigates
                    Task {
                        await prefetchWeatherData()
                    }
                }
                
                // View full detail for this city
                NavigationLink(destination: AroundMeCityDetailView(city: cityFromDirectionalInfo(currentCity))) {
                    Label("View Full Detail", systemImage: "info.circle")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
            }
            
            // Navigation buttons (visual alternative)
            HStack(spacing: 20) {
                Button(action: {
                    if currentCityIndex > 0 {
                        currentCityIndex -= 1
                    }
                }) {
                    Label("Closer", systemImage: "chevron.down")
                }
                .disabled(currentCityIndex == 0)
                
                Button(action: showAllCities) {
                    Label("List All", systemImage: "list.bullet")
                }
                
                Button(action: {
                    if currentCityIndex < citiesInDirection.count - 1 {
                        currentCityIndex += 1
                    }
                }) {
                    Label("Farther", systemImage: "chevron.up")
                }
                .disabled(currentCityIndex == citiesInDirection.count - 1)
            }
            .buttonStyle(.bordered)
        }
        .alert(alertTitle, isPresented: $showingAllCities) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .onChange(of: showingAllCities) { oldValue, newValue in
            // Flash detection: Alert should never go from true to true
            if oldValue == true && newValue == true {
                debugLog("⚠️ ALERT FLASH DETECTED in WeatherAroundMeView cities alert!")
            }
        }
    }
    
    // MARK: - Regional Summary Card
    private func regionalSummaryCard(_ regional: RegionalWeatherData) -> some View {
        GroupBox(label: Label("Regional Summary", systemImage: "text.alignleft")) {
            VStack(alignment: .leading, spacing: 12) {
                if let summary = generateRegionalSummary(regional) {
                    Text(summary)
                        .font(.body)
                } else {
                    Text("Similar conditions in all directions")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 8)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Regional summary: \(generateRegionalSummary(regional) ?? "Similar conditions in all directions")")
    }
    
    // MARK: - Data Loading
    private func loadRegionalWeather() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let data = try await RegionalWeatherService.shared.fetchRegionalWeather(for: city, distanceMiles: distanceMiles)
            
            await MainActor.run {
                self.regionalWeather = data
                self.lastUpdated = Date()
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func directionIcon(_ direction: String) -> String {
        switch direction {
        case "North": return "arrow.up"
        case "Northeast": return "arrow.up.right"
        case "East": return "arrow.right"
        case "Southeast": return "arrow.down.right"
        case "South": return "arrow.down"
        case "Southwest": return "arrow.down.left"
        case "West": return "arrow.left"
        case "Northwest": return "arrow.up.left"
        default: return "location"
        }
    }
    
    private func formatTemperature(_ celsius: Double) -> String {
        let temp = settingsManager.settings.temperatureUnit.convert(celsius)
        let unit = settingsManager.settings.temperatureUnit == .fahrenheit ? "F" : "C"
        return String(format: "%.0f°%@", temp, unit)
    }
    
    /// Convert a miles value to the user's preferred distance unit and format it
    private func formatDistanceFromMiles(_ miles: Double) -> String {
        let km = miles * 1.60934
        let value = settingsManager.settings.distanceUnit.convert(km)
        return settingsManager.settings.distanceUnit.format(value)
    }
    
    /// Calculate actual distance between center city and directional location in user's preferred unit
    private func calculateDistance(from center: City, to location: DirectionalLocation) -> Int {
        let centerLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)
        let targetLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
        let distanceMeters = centerLocation.distance(from: targetLocation)
        let distanceKm = distanceMeters / 1000.0
        let distanceInUnit = settingsManager.settings.distanceUnit.convert(distanceKm)
        return Int(distanceInUnit.rounded())
    }
    
    private func loadCitiesInDirection() {
        isLoadingCities = true
        Task {
            citiesInDirection = await DirectionalCityService.shared.findCities(
                from: city,
                direction: selectedDirection,
                maxDistance: distanceMiles,
                explorationMode: settingsManager.settings.weatherAroundMeExplorationMode,
                arcWidth: settingsManager.settings.weatherAroundMeArcWidth,
                corridorWidth: settingsManager.settings.weatherAroundMeCorridorWidth
            )
            currentCityIndex = 0
            isLoadingCities = false
            // Clear old weather data
            directionalWeatherData.removeAll()
            
            // Prefetch weather for first batch of cities
            await prefetchWeatherData()
        }
    }
    
    private func loadWeatherForCity(_ cityInfo: DirectionalCityInfo) async {
        guard directionalWeatherData[cityInfo.id] == nil else { return }
        do {
            // Fetch weather and alerts concurrently
            let tempCity = City(
                name: cityInfo.name,
                state: cityInfo.state,
                country: cityInfo.country,
                latitude: cityInfo.latitude,
                longitude: cityInfo.longitude
            )
            
            async let weatherTask = directionalWeatherService.fetchWeatherBasic(
                latitude: cityInfo.latitude,
                longitude: cityInfo.longitude
            )
            async let alertsTask = weatherService.fetchNWSAlerts(for: tempCity)
            
            let (weather, alerts) = try await (weatherTask, alertsTask)
            
            let temp = weather.current.temperature2m
            let condition = weather.current.weatherCodeEnum?.description ?? "Unknown"
            let windDir = Double(weather.current.windDirection10m ?? 0)
            let windSpd = weather.current.windSpeed10m ?? 0
            let press = weather.current.pressureMsl ?? 1013.25
            
            await MainActor.run {
                directionalWeatherData[cityInfo.id] = (
                    temp: temp,
                    condition: condition,
                    windDirection: windDir,
                    windSpeed: windSpd,
                    pressure: press,
                    alerts: alerts
                )
            }
        } catch {
            debugLog("⚠️ Failed to load weather for \(cityInfo.name): \(error)")
        }
    }
    
    /// Fetch weather for all cities in the direction list in parallel using a single shared WeatherService.
    private func prefetchWeatherData() async {
        let pending = citiesInDirection.filter { directionalWeatherData[$0.id] == nil }
        guard !pending.isEmpty else { return }
        
        let locations = pending.map { (latitude: $0.latitude, longitude: $0.longitude) }
        let weatherBatch = await directionalWeatherService.batchFetchWeatherBasic(for: locations)
        
        // Fetch alerts for all cities concurrently
        let alertsTasks = pending.map { cityInfo -> (UUID, Task<[WeatherAlert], Error>) in
            let tempCity = City(
                name: cityInfo.name,
                state: cityInfo.state,
                country: cityInfo.country,
                latitude: cityInfo.latitude,
                longitude: cityInfo.longitude
            )
            let task = Task {
                try await weatherService.fetchNWSAlerts(for: tempCity)
            }
            return (cityInfo.id, task)
        }
        
        // Collect alerts results
        var alertsMap: [UUID: [WeatherAlert]] = [:]
        for (id, task) in alertsTasks {
            do {
                alertsMap[id] = try await task.value
            } catch {
                alertsMap[id] = []
            }
        }
        
        await MainActor.run {
            for cityInfo in pending {
                let key = "\(cityInfo.latitude),\(cityInfo.longitude)"
                if let weather = weatherBatch[key] {
                    let temp = weather.current.temperature2m
                    let condition = weather.current.weatherCodeEnum?.description ?? "Unknown"
                    let windDir = Double(weather.current.windDirection10m ?? 0)
                    let windSpd = weather.current.windSpeed10m ?? 0
                    let press = weather.current.pressureMsl ?? 1013.25
                    let alerts = alertsMap[cityInfo.id] ?? []
                    directionalWeatherData[cityInfo.id] = (
                        temp: temp,
                        condition: condition,
                        windDirection: windDir,
                        windSpeed: windSpd,
                        pressure: press,
                        alerts: alerts
                    )
                }
            }
        }
    }
    
    private func showAllCities() {
        // Capture values at the moment the alert is triggered to prevent flashing
        alertTitle = "Cities to the \(selectedDirection.rawValue)"
        alertMessage = citiesInDirection.map { cityInfo in
            "\(cityInfo.displayName(relativeTo: city.country)) (~\(formatDistanceFromMiles(cityInfo.distanceMiles)))"
        }.joined(separator: "\n")
        showingAllCities = true
    }
    
    private func formatLastUpdated(_ date: Date) -> String {
        let now = Date()
        let interval = now.timeIntervalSince(date)
        
        if interval < 60 {
            return "just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes) minute\(minutes == 1 ? "" : "s") ago"
        } else {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "at \(formatter.string(from: date))"
        }
    }
    
    private func generateRegionalSummary(_ regional: RegionalWeatherData) -> String? {
        // Analyze temperature and precipitation patterns
        var summary: [String] = []
        
        // Temperature comparison
        if let centerTemp = regional.center.temperature {
            let warmerDirs = regional.directions.filter { ($0.temperature ?? centerTemp) > centerTemp + 5 }
            let colderDirs = regional.directions.filter { ($0.temperature ?? centerTemp) < centerTemp - 5 }
            
            if !warmerDirs.isEmpty {
                let dirs = warmerDirs.map { $0.direction.lowercased() }.joined(separator: ", ")
                summary.append("Warmer to the \(dirs)")
            }
            if !colderDirs.isEmpty {
                let dirs = colderDirs.map { $0.direction.lowercased() }.joined(separator: ", ")
                summary.append("Colder to the \(dirs)")
            }
        }
        
        // Precipitation patterns
        let precipDirs = regional.directions.filter { $0.condition?.lowercased().contains("rain") == true || $0.condition?.lowercased().contains("snow") == true }
        if !precipDirs.isEmpty {
            let dirs = precipDirs.map { $0.direction.lowercased() }.joined(separator: ", ")
            summary.append("Precipitation to the \(dirs)")
        }
        
        return summary.isEmpty ? nil : summary.joined(separator: ". ")
    }
    
    // MARK: - Accessibility Labels
    
    private func currentLocationAccessibilityLabel(_ location: DirectionalLocation) -> String {
        var label = "Your location: \(city.name)"
        if let temp = location.temperature {
            label += ", \(formatTemperature(temp))"
        }
        if let condition = location.condition {
            label += ", \(condition)"
        }
        return label
    }
    
    private func directionalAccessibilityLabel(_ location: DirectionalLocation) -> String {
        let actualDistance = calculateDistance(from: city, to: location)
        var label = "\(location.direction)"
        if let locationName = location.locationName {
            label += ", near \(locationName), \(actualDistance) \(settingsManager.settings.distanceUnit.rawValue)"
        } else {
            label += ", \(actualDistance) \(settingsManager.settings.distanceUnit.rawValue)"
        }
        if let temp = location.temperature {
            label += ", \(formatTemperature(temp))"
        }
        if let condition = location.condition {
            label += ", \(condition)"
        }
        return label
    }
    
    private func cityExplorerAccessibilityLabel(_ cityInfo: DirectionalCityInfo) -> String {
        // Waypoints with a real geocoded name are announced as cities.
        // Only fallback distance labels (e.g. "~30 mi South") use "Weather point".
        let isDistanceFallback = cityInfo.isWaypoint && cityInfo.name.hasPrefix("~")
        var label = isDistanceFallback
            ? "Weather point: \(cityInfo.displayName(relativeTo: city.country)), "
            : "\(cityInfo.displayName(relativeTo: city.country)), "
        
        // Add distance from origin
        label += "\(formatDistanceFromMiles(cityInfo.distanceMiles))"
        
        // Add bearing if enabled
        if settingsManager.settings.showWeatherAroundMeBearing {
            label += ", \(Int(cityInfo.bearing.rounded())) degrees"
        }
        
        // Add perpendicular offset if enabled
        if settingsManager.settings.showWeatherAroundMeOffsetDistance {
            label += ", \(cityInfo.offsetDescription(distanceUnit: settingsManager.settings.distanceUnit))"
        }
        
        // Add weather data if available
        if let weather = directionalWeatherData[cityInfo.id] {
            label += ", \(formatTemperature(weather.temp)), \(weather.condition)"
            
            // Add weather alerts if enabled
            if settingsManager.settings.showWeatherAroundMeAlerts, !weather.alerts.isEmpty {
                let highestSeverityAlert = weather.alerts.min(by: { $0.severity.sortOrder < $1.severity.sortOrder })
                if let alert = highestSeverityAlert {
                    label += ", "
                    if weather.alerts.count == 1 {
                        label += "Alert: \(alert.event)"
                    } else {
                        label += "Alerts: \(alert.event) and \(weather.alerts.count - 1) more"
                    }
                }
            }
            
            // Add weather movement if enabled
            if settingsManager.settings.showWeatherAroundMeMovement {
                let movement = WeatherMovementAnalyzer.movementDescription(
                    windDirection: weather.windDirection,
                    windSpeed: weather.windSpeed,
                    windSpeedUnit: settingsManager.settings.windSpeedUnit,
                    bearingToLocation: cityInfo.bearing,
                    locationName: nil // Don't repeat city name
                )
                label += ", \(movement)"
            }
            
            // Add pressure trend if enabled
            if settingsManager.settings.showWeatherAroundMePressureTrends {
                // Compare to previous city in list (or skip if first city)
                if currentCityIndex > 0, currentCityIndex < citiesInDirection.count {
                    let previousCity = citiesInDirection[currentCityIndex - 1]
                    if let previousWeather = directionalWeatherData[previousCity.id] {
                        let pressureDiff = weather.pressure - previousWeather.pressure
                        let pressureTrend: String
                        if abs(pressureDiff) < 1.0 {
                            pressureTrend = "Pressure steady"
                        } else if pressureDiff > 0 {
                            pressureTrend = "Pressure rising \(String(format: "%.1f", abs(pressureDiff))) hPa"
                        } else {
                            pressureTrend = "Pressure falling \(String(format: "%.1f", abs(pressureDiff))) hPa"
                        }
                        label += ", \(pressureTrend)"
                    }
                }
            }
        }
        
        // Add position in list
        label += ", \(currentCityIndex + 1) of \(citiesInDirection.count)"
        
        return label
    }
    
    // MARK: - VoiceOver Exploration Mode Cycling
    
    /// Returns a description of the current exploration mode for VoiceOver
    private func currentExplorationModeDescription() -> String {
        if settingsManager.settings.weatherAroundMeExplorationMode == .arc {
            return "Arc mode, \(settingsManager.settings.weatherAroundMeArcWidth.displayName)"
        } else {
            return "Corridor mode, \(Int(settingsManager.settings.weatherAroundMeCorridorWidth.rawValue)) miles"
        }
    }
    
    /// Cycles through exploration mode combinations in a fixed order
    /// Order: Corridor 10→20→30→50, then Arc Narrow→Standard→Medium→Wide, then wraps
    private func cycleExplorationMode(forward: Bool) {
        let allModes: [(ExplorationMode, ArcWidth?, CorridorWidth?)] = [
            (.straightLine, nil, .ten),
            (.straightLine, nil, .twenty),
            (.straightLine, nil, .thirty),
            (.straightLine, nil, .fifty),
            (.arc, .narrow, nil),
            (.arc, .standard, nil),
            (.arc, .medium, nil),
            (.arc, .wide, nil)
        ]
        
        // Find current index
        let currentIndex: Int
        if settingsManager.settings.weatherAroundMeExplorationMode == .straightLine {
            switch settingsManager.settings.weatherAroundMeCorridorWidth {
            case .ten: currentIndex = 0
            case .twenty: currentIndex = 1
            case .thirty: currentIndex = 2
            case .fifty: currentIndex = 3
            }
        } else {
            switch settingsManager.settings.weatherAroundMeArcWidth {
            case .narrow: currentIndex = 4
            case .standard: currentIndex = 5
            case .medium: currentIndex = 6
            case .wide: currentIndex = 7
            }
        }
        
        // Calculate next index with wrapping
        let nextIndex: Int
        if forward {
            nextIndex = (currentIndex + 1) % allModes.count
        } else {
            nextIndex = (currentIndex - 1 + allModes.count) % allModes.count
        }
        
        // Apply new settings
        let (mode, arcWidth, corridorWidth) = allModes[nextIndex]
        settingsManager.settings.weatherAroundMeExplorationMode = mode
        if let arc = arcWidth {
            settingsManager.settings.weatherAroundMeArcWidth = arc
        }
        if let corridor = corridorWidth {
            settingsManager.settings.weatherAroundMeCorridorWidth = corridor
        }
        settingsManager.saveSettings()
        
        // Announce the change
        let announcement = currentExplorationModeDescription()
        UIAccessibility.post(notification: .announcement, argument: announcement)
    }
}

// MARK: - Data Models

struct RegionalWeatherData {
    let center: DirectionalLocation
    let directions: [DirectionalLocation]
}

struct DirectionalLocation {
    let direction: String
    let latitude: Double
    let longitude: Double
    let temperature: Double?
    let condition: String?
    let locationName: String?
}

/// Destination view for Weather Around Me city rows.
/// Mirrors BrowseCityDetailDestination — fetches full weather on appear so
/// CityDetailView can display all sections including the Add button.
private struct AroundMeCityDetailView: View {
    @State private var city: City
    @EnvironmentObject var weatherService: WeatherService
    
    init(city: City) {
        _city = State(initialValue: city)
    }
    
    var body: some View {
        CityDetailView(city: city)
            .task {
                await weatherService.fetchWeatherForDate(for: city, dateOffset: 0)
            }
    }
}

// MARK: - Settings Sheet

struct WeatherAroundMeSettingsSheet: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Picker("Exploration Mode", selection: $settingsManager.settings.weatherAroundMeExplorationMode) {
                        Text(ExplorationMode.arc.rawValue).tag(ExplorationMode.arc)
                        Text(ExplorationMode.straightLine.rawValue).tag(ExplorationMode.straightLine)
                    }
                    .accessibilityHint(settingsManager.settings.weatherAroundMeExplorationMode.description)
                } header: {
                    Text("Search Pattern")
                } footer: {
                    Text(settingsManager.settings.weatherAroundMeExplorationMode.description)
                }
                
                if settingsManager.settings.weatherAroundMeExplorationMode == .arc {
                    Section {
                        Picker("Arc Width", selection: $settingsManager.settings.weatherAroundMeArcWidth) {
                            Text(ArcWidth.narrow.displayName).tag(ArcWidth.narrow)
                            Text(ArcWidth.standard.displayName).tag(ArcWidth.standard)
                            Text(ArcWidth.medium.displayName).tag(ArcWidth.medium)
                            Text(ArcWidth.wide.displayName).tag(ArcWidth.wide)
                        }
                        .accessibilityHint(settingsManager.settings.weatherAroundMeArcWidth.description)
                    } header: {
                        Text("Arc Width")
                    } footer: {
                        Text(settingsManager.settings.weatherAroundMeArcWidth.description)
                    }
                } else {
                    Section {
                        Picker("Corridor Width", selection: $settingsManager.settings.weatherAroundMeCorridorWidth) {
                            Text("\(Int(CorridorWidth.ten.rawValue)) miles").tag(CorridorWidth.ten)
                            Text("\(Int(CorridorWidth.twenty.rawValue)) miles").tag(CorridorWidth.twenty)
                            Text("\(Int(CorridorWidth.thirty.rawValue)) miles").tag(CorridorWidth.thirty)
                            Text("\(Int(CorridorWidth.fifty.rawValue)) miles").tag(CorridorWidth.fifty)
                        }
                    } header: {
                        Text("Corridor Width")
                    } footer: {
                        Text("Width of the straight-line corridor (±\(Int(settingsManager.settings.weatherAroundMeCorridorWidth.rawValue / 2)) miles from center line)")
                    }
                }
                
                Section {
                    Toggle("Show Distance from Center Line", isOn: $settingsManager.settings.showWeatherAroundMeOffsetDistance)
                        .accessibilityHint("Show how far east or west cities are from the center line")
                    
                    Toggle("Show Bearing", isOn: $settingsManager.settings.showWeatherAroundMeBearing)
                        .accessibilityHint("Show compass bearing for each city (e.g., '145 degrees')")
                    
                    Toggle("Show Weather Movement", isOn: $settingsManager.settings.showWeatherAroundMeMovement)
                        .accessibilityHint("Announce if weather is approaching, moving away, or parallel")
                    
                    Toggle("Show Pressure Trends", isOn: $settingsManager.settings.showWeatherAroundMePressureTrends)
                        .accessibilityHint("Compare pressure between consecutive cities")
                    
                    Toggle("Show Weather Alerts", isOn: $settingsManager.settings.showWeatherAroundMeAlerts)
                        .accessibilityHint("Announce severe weather alerts for each city")
                } header: {
                    Text("Information Display")
                } footer: {
                    Text("Control which information is announced when stepping through cities")
                }
            }
            .navigationTitle("Weather Around Me")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        WeatherAroundMeView(city: City(
            id: UUID(),
            name: "Madison",
            state: "Wisconsin",
            country: "United States",
            latitude: 43.0731,
            longitude: -89.4012
        ))
        .environmentObject(SettingsManager())
        .environmentObject(WeatherService())
    }
}
