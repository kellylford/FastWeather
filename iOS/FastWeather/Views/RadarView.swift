//
//  RadarView.swift
//  Fast Weather
//
//  Radar view with accessible precipitation nowcasting
//  Provides both visual radar display and text-based interpretation for accessibility
//

import SwiftUI
import Charts

struct RadarView: View {
    let city: City
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var radarData: RadarData?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var lastUpdated: Date?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error)
                } else if let radar = radarData {
                    radarContent(radar)
                }
            }
            .padding()
        }
        .navigationTitle("Expected Precipitation")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    Task { await loadRadarData() }
                }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .accessibilityLabel("Refresh precipitation data")
            }
        }
        .task {
            await loadRadarData()
        }
        .refreshable {
            await loadRadarData()
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading precipitation forecast...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading precipitation forecast")
    }
    
    // MARK: - Error View
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.orange)
                .accessibilityHidden(true)
            
            Text("Unable to Load Forecast")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: {
                Task { await loadRadarData() }
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
        .accessibilityLabel("Unable to load precipitation forecast. \(message). Tap Try Again to reload.")
    }
    
    // MARK: - Radar Content
    private func radarContent(_ radar: RadarData) -> some View {
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
            
            // Summary Card - Most important info first for accessibility
            radarSummaryCard(radar)
            
            // Timeline View
            radarTimelineView(radar)
            
            // Visual Radar Map with Audio Graph support
            radarMapView(radar)
            
            // Data Attribution
            Text("Precipitation nowcast data by Open-Meteo.com")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top)
        }
    }
    
    // MARK: - Precipitation Summary Card
    private func radarSummaryCard(_ radar: RadarData) -> some View {
        GroupBox(label: Label("Precipitation Summary", systemImage: "cloud.rain")) {
            VStack(alignment: .leading, spacing: 12) {
                Text(radar.currentStatus)
                    .font(.headline)
                
                if let nearest = radar.nearestPrecipitation {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Nearest Precipitation:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        DetailRow(label: "Distance", value: "\(formatDistance(nearest.distanceMiles)) to the \(nearest.direction)")
                        DetailRow(label: "Type", value: nearest.type)
                        DetailRow(label: "Intensity", value: nearest.intensity)
                        DetailRow(label: "Movement", value: "\(nearest.movementDirection) at \(nearest.speedMph) mph")
                        
                        if let arrival = nearest.arrivalEstimate {
                            DetailRow(label: "Arrival", value: arrival)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(radarSummaryAccessibilityLabel(radar))
    }
    
    // MARK: - Timeline View
    private func radarTimelineView(_ radar: RadarData) -> some View {
        GroupBox(label: Label("2-Hour Timeline", systemImage: "clock")) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(radar.timeline, id: \.time) { timepoint in
                    HStack {
                        Text(timepoint.time)
                            .font(.subheadline.bold())
                            .frame(width: 100, alignment: .leading)
                        
                        Text(timepoint.condition)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if timepoint != radar.timeline.last {
                        Divider()
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .accessibilityHidden(true)
    }
    
    // MARK: - Radar Map View (Visual)
    private func radarMapView(_ radar: RadarData) -> some View {
        GroupBox(label: Label("Precipitation Graph", systemImage: "chart.line.uptrend.xyaxis")) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Next 2 Hours")
                    .font(.subheadline.bold())
                
                // Simple visual representation of precipitation intensity over time
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(Array(radar.timeline.enumerated()), id: \.offset) { index, point in
                        VStack(spacing: 4) {
                            Rectangle()
                                .fill(precipitationColor(for: point.condition))
                                .frame(width: 40, height: precipitationHeight(for: point.condition))
                            
                            Text(point.time)
                                .font(.caption2)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                        }
                    }
                }
                .frame(height: 150)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Precipitation graph showing next 2 hours. Swipe up or down with VoiceOver to hear the chart as audio tones.")
            }
            .padding(.vertical, 8)
        }
        .accessibilityRepresentation {
            // Audio Graph representation with descriptive labels instead of numbers
            Chart(radar.timeline, id: \.time) { point in
                BarMark(
                    x: .value("Time", point.time),
                    y: .value("Intensity", precipitationValue(for: point.condition))
                )
                .accessibilityLabel(point.time)
                .accessibilityValue(point.condition)
            }
            .accessibilityLabel("Precipitation intensity over next 2 hours. Swipe to explore individual time points.")
        }
    }
    
    private func precipitationColor(for condition: String) -> Color {
        if condition.contains("Clear") || condition.contains("No data") {
            return .gray.opacity(0.2)
        } else if condition.contains("Light") {
            return .blue.opacity(0.5)
        } else if condition.contains("Moderate") {
            return .blue.opacity(0.7)
        } else if condition.contains("Heavy") {
            return .blue
        } else {
            return .blue.opacity(0.3)
        }
    }
    
    private func precipitationHeight(for condition: String) -> CGFloat {
        if condition.contains("Clear") || condition.contains("No data") {
            return 10
        } else if condition.contains("Light") {
            return 50
        } else if condition.contains("Moderate") {
            return 100
        } else if condition.contains("Heavy") {
            return 140
        } else {
            return 30
        }
    }
    
    // MARK: - Data Loading
    private func loadRadarData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let data = try await RadarService.shared.fetchPrecipitationNowcast(for: city)
            
            await MainActor.run {
                self.radarData = data
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
    
    // MARK: - Helper for formatting last updated time
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
    
    // MARK: - Helper for Chart Data
    private func precipitationValue(for condition: String) -> Double {
        if condition.contains("Clear") || condition.contains("No data") {
            return 0
        } else if condition.contains("Light") {
            return 3
        } else if condition.contains("Moderate") {
            return 6
        } else if condition.contains("Heavy") {
            return 9
        } else {
            return 1
        }
    }
    
    // MARK: - Accessibility Labels
    private func radarSummaryAccessibilityLabel(_ radar: RadarData) -> String {
        var label = "Precipitation Summary. \(radar.currentStatus)."
        
        if let nearest = radar.nearestPrecipitation {
            label += " Nearest precipitation: \(nearest.type), \(formatDistance(nearest.distanceMiles)) to the \(nearest.direction), "
            label += "moving \(nearest.movementDirection) at \(formatSpeed(nearest.speedMph))."
            if let arrival = nearest.arrivalEstimate {
                label += " Expected arrival: \(arrival)."
            }
        }
        
        return label
    }
    
    private func timelineAccessibilityLabel(_ timeline: [TimelinePoint]) -> String {
        var label = "2-hour precipitation timeline. "
        for point in timeline {
            label += "\(point.time): \(point.condition). "
        }
        return label
    }
    
    // MARK: - Formatting Helpers
    private func formatDistance(_ miles: Int) -> String {
        let km = Double(miles) / 0.621371
        let distance = settingsManager.settings.distanceUnit == .miles ? Double(miles) : km
        return settingsManager.settings.distanceUnit.format(distance)
    }
    
    private func formatSpeed(_ mph: Int) -> String {
        let kmh = Double(mph) / 0.621371
        let speed = settingsManager.settings.windSpeedUnit.convert(kmh)
        return "\(Int(speed)) \(settingsManager.settings.windSpeedUnit.rawValue)"
    }
}

// MARK: - Data Models

struct RadarData {
    let currentStatus: String
    let nearestPrecipitation: NearestPrecipitation?
    let directionalSectors: [DirectionalSector]
    let timeline: [TimelinePoint]
}

struct NearestPrecipitation {
    let distanceMiles: Int
    let direction: String
    let type: String
    let intensity: String
    let movementDirection: String
    let speedMph: Int
    let arrivalEstimate: String?
}

struct DirectionalSector: Equatable {
    let direction: String
    let status: String
}

struct TimelinePoint: Equatable {
    let time: String
    let condition: String
}

#Preview {
    NavigationView {
        RadarView(city: City(
            id: UUID(),
            name: "San Diego",
            state: "California",
            country: "United States",
            latitude: 32.7157,
            longitude: -117.1611
        ))
        .environmentObject(SettingsManager())
    }
}
