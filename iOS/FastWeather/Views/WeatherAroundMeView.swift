//
//  WeatherAroundMeView.swift
//  Fast Weather
//
//  Regional weather comparison showing conditions in all directions
//  Provides "big picture" weather context for accessibility
//

import SwiftUI

struct WeatherAroundMeView: View {
    let city: City
    let defaultDistance: Double
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var regionalWeather: RegionalWeatherData?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var lastUpdated: Date?
    @State private var distanceMiles: Double
    
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
        HStack {
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
                            Text(locationName)
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
        var label = "\(location.direction)"
        if let locationName = location.locationName {
            label += ", near \(locationName)"
        }
        if let temp = location.temperature {
            label += ", \(formatTemperature(temp))"
        }
        if let condition = location.condition {
            label += ", \(condition)"
        }
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
