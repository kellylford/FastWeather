//
//  RadarView.swift
//  Fast Weather
//
//  Radar view with accessible precipitation nowcasting
//  Provides both visual radar display and text-based interpretation for accessibility
//

import SwiftUI
import Charts
#if canImport(WeatherKit)
import WeatherKit
#endif

/// Holds WeatherKit attribution URLs for display.
struct WeatherAttributionData {
    let legalPageURL: URL
    let markLightURL: URL
    let markDarkURL: URL
    let serviceName: String
}

struct RadarView: View {
    let city: City
    @EnvironmentObject var settingsManager: SettingsManager
    @Environment(\.colorScheme) var colorScheme
    @State private var radarData: RadarData?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var lastUpdated: Date?
    @State private var weatherKitAttribution: WeatherAttributionData?
    
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
            attributionView
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
        let title = radar.dataSource == .weatherKit ? "1-Hour Forecast" : "2-Hour Forecast"
        return GroupBox(label: Label(title, systemImage: "clock")) {
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
        // Use WeatherKit 60-minute data when available, otherwise map the 7 coarse intervals.
        let displayData: [ChartPoint]
        if let wkData = radar.chartData {
            displayData = wkData
        } else {
            let intervals = [0, 15, 30, 45, 60, 90, 120]
            displayData = radar.timeline.enumerated().map { (i, tp) in
                ChartPoint(
                    minute: i < intervals.count ? intervals[i] : i * 15,
                    precipitationMmPerHr: tp.precipitationMmPerHr,
                    condition: tp.condition
                )
            }
        }

        let isMinuteData = radar.chartData != nil
        let maxIntensity = displayData.map { $0.precipitationMmPerHr }.max() ?? 0
        let yMax = max(2.0, maxIntensity * 1.3)
        let axisValues = isMinuteData ? [0, 15, 30, 45, 60] : displayData.map { $0.minute }
        let title = isMinuteData ? "Next 60 Minutes" : "Next 2 Hours"
        // Accessibility uses a sparser set of points so VoiceOver has a manageable number.
        let accessibilityPoints = isMinuteData
            ? displayData.filter { [0, 5, 10, 15, 20, 30, 45, 60].contains($0.minute) }
            : displayData

        return GroupBox(label: Label("Precipitation Graph", systemImage: "chart.line.uptrend.xyaxis")) {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.subheadline.bold())

                Chart(displayData, id: \.minute) { point in
                    AreaMark(
                        x: .value("Minute", point.minute),
                        y: .value("mm/hr", max(0, point.precipitationMmPerHr))
                    )
                    .foregroundStyle(LinearGradient(
                        colors: [.blue.opacity(0.55), .blue.opacity(0.08)],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("Minute", point.minute),
                        y: .value("mm/hr", max(0, point.precipitationMmPerHr))
                    )
                    .foregroundStyle(.blue)
                    .interpolationMethod(.catmullRom)
                }
                .chartXAxis {
                    AxisMarks(values: axisValues) { value in
                        if let minute = value.as(Int.self) {
                            AxisValueLabel {
                                Text(minute == 0 ? "Now" : "\(minute)")
                                    .font(.caption2)
                            }
                        }
                        AxisGridLine()
                    }
                }
                .chartYAxis(.hidden)
                .chartYScale(domain: 0...yMax)
                .frame(height: 100)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Precipitation chart showing \(title.lowercased()). Swipe up or down with VoiceOver to hear the chart as audio tones.")
            }
            .padding(.vertical, 8)
        }
        .accessibilityRepresentation {
            Chart(accessibilityPoints, id: \.minute) { point in
                BarMark(
                    x: .value("Time", point.minute == 0 ? "Now" : "\(point.minute) min"),
                    y: .value("Intensity", max(0, point.precipitationMmPerHr))
                )
                .accessibilityLabel(point.minute == 0 ? "Now" : "\(point.minute) minutes")
                .accessibilityValue(point.condition)
            }
            .accessibilityLabel(isMinuteData
                ? "Minute-by-minute precipitation for the next hour. Swipe to explore time points."
                : "Precipitation intensity over next 2 hours. Swipe to explore individual time points."
            )
        }
    }

    // MARK: - Data Loading
    private func loadRadarData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let data = try await RadarService.shared.fetchPrecipitationNowcast(for: city)

            var attribution: WeatherAttributionData? = nil
            #if canImport(WeatherKit)
            if #available(iOS 16.0, *), data.dataSource == .weatherKit {
                let wkAttr = try await WeatherKit.WeatherService.shared.attribution
                attribution = WeatherAttributionData(
                    legalPageURL: wkAttr.legalPageURL,
                    markLightURL: wkAttr.combinedMarkLightURL,
                    markDarkURL: wkAttr.combinedMarkDarkURL,
                    serviceName: wkAttr.serviceName
                )
            }
            #endif

            await MainActor.run {
                self.radarData = data
                self.lastUpdated = Date()
                self.isLoading = false
                self.weatherKitAttribution = attribution
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

    // MARK: - Attribution View

    /// Shows the Apple Weather mark + legal link when using WeatherKit,
    /// or the Open-Meteo credit otherwise. Apple requires displaying the mark
    /// and linking to the legal attribution page.
    @ViewBuilder
    private var attributionView: some View {
        if let attribution = weatherKitAttribution {
            Link(destination: attribution.legalPageURL) {
                AsyncImage(url: colorScheme == .dark ? attribution.markDarkURL : attribution.markLightURL) { image in
                    image
                        .resizable()
                        .scaledToFit()
                } placeholder: {
                    Text(attribution.serviceName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(height: 14)
            }
            .accessibilityLabel("\(attribution.serviceName) weather data provider")
        } else {
            Text("Precipitation nowcast data by Open-Meteo.com")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// Data models are defined in RadarService.swift

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
