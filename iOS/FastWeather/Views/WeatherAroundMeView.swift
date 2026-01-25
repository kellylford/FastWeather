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
    @State private var directionalWeatherData: [UUID: (temp: Double, condition: String)] = [:]
    
    let distanceOptions: [Double] = [50, 100, 150, 200, 250, 300, 350]
    
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
                        ForEach(distanceOptions, id: \.self) { distance in
                            Text("\(Int(distance)) miles").tag(distance)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 100)
                    .accessibilityLabel("Distance radius")
                    .accessibilityValue("\(Int(distanceMiles)) miles")
                    .accessibilityHint("Select the radius for surrounding weather data. Options range from 50 to 350 miles.")
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
                Button(action: {
                    Task { await loadRegionalWeather() }
                }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .accessibilityLabel("Refresh regional weather data")
            }
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
            
            // Directional Weather Cards
            directionalWeatherSection(regional)
            
            // Directional Explorer
            directionalExplorerSection()
            
            // Regional Summary
            regionalSummaryCard(regional)
            
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
        
        return HStack {
            // Direction icon and label
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: directionIcon(location.direction))
                        .font(.title3)
                        .foregroundColor(.accentColor)
                        .frame(width: 30)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(location.direction)
                            .font(.headline)
                        
                        if let locationName = location.locationName {
                            Text("\(locationName) (~\(actualDistance) mi)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("~\(actualDistance) mi")
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel(directionalAccessibilityLabel(location))
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
                    loadCitiesInDirection()
                }
                
                Divider()
                
                // City Explorer
                if citiesInDirection.isEmpty {
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
                    Text(currentCity.displayName)
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
                    
                    Text("~\(Int(currentCity.distanceMiles)) mi")
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
                .accessibilityLabel(cityExplorerAccessibilityLabel(currentCity))
                .accessibilityHint("Swipe up for farther cities, swipe down for closer cities")
                .accessibilityAddTraits([.isButton])
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
        .alert("Cities to the \(selectedDirection.rawValue)", isPresented: $showingAllCities) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(allCitiesList())
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
            print("🔄 Loading regional weather for \(city.name) at \(distanceMiles) miles...")
            let data = try await RegionalWeatherService.shared.fetchRegionalWeather(for: city, distanceMiles: distanceMiles)
            
            print("✅ Received regional weather data:")
            print("   Center: \(data.center.direction) - locationName: \(data.center.locationName ?? "nil")")
            for direction in data.directions {
                print("   \(direction.direction): locationName = \(direction.locationName ?? "nil")")
            }
            
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
        return String(format: "%.0f%@", temp, settingsManager.settings.temperatureUnit.rawValue)
    }
    
    /// Calculate actual distance between center city and directional location in miles
    private func calculateDistance(from center: City, to location: DirectionalLocation) -> Int {
        let centerLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)
        let targetLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
        let distanceMeters = centerLocation.distance(from: targetLocation)
        let distanceMiles = distanceMeters * 0.000621371
        return Int(distanceMiles.rounded())
    }
    
    private func loadCitiesInDirection() {
        citiesInDirection = DirectionalCityService.shared.findCities(
            from: city,
            direction: selectedDirection,
            maxDistance: distanceMiles
        )
        currentCityIndex = 0
        // Clear old weather data
        directionalWeatherData.removeAll()
    }
    
    private func loadWeatherForCity(_ cityInfo: DirectionalCityInfo) async {
        // Don't reload if we already have data
        guard directionalWeatherData[cityInfo.id] == nil else { return }
        
        do {
            let weatherService = WeatherService()
            let weather = try await weatherService.fetchWeatherBasic(
                latitude: cityInfo.latitude,
                longitude: cityInfo.longitude
            )
            
            let temp = weather.current.temperature2m
            let condition = weather.current.weatherCodeEnum?.description ?? "Unknown"
            
            await MainActor.run {
                directionalWeatherData[cityInfo.id] = (temp: temp, condition: condition)
            }
        } catch {
            // Silently fail for individual cities
            print("Failed to load weather for \(cityInfo.name): \(error)")
        }
    }
    
    private func showAllCities() {
        showingAllCities = true
    }
    
    private func allCitiesList() -> String {
        citiesInDirection.map { city in
            "\(city.displayName) (~\(Int(city.distanceMiles)) mi)"
        }.joined(separator: "\n")
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
            label += ", near \(locationName), approximately \(actualDistance) miles"
        } else {
            label += ", approximately \(actualDistance) miles"
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
        var label = "\(cityInfo.displayName), "
        if let weather = directionalWeatherData[cityInfo.id] {
            label += "\(formatTemperature(weather.temp)), \(weather.condition), "
        }
        label += "approximately \(Int(cityInfo.distanceMiles)) miles, \(currentCityIndex + 1) of \(citiesInDirection.count)"
        return label
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
    }
}
