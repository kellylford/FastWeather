//
//  WeatherDetailView.swift
//  FastWeatherMac
//
//  Created on 12/12/2025.
//  Detailed weather view with full accessibility
//

import SwiftUI

struct WeatherDetailView: View {
    let city: City
    @State private var weatherData: WeatherResponse?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var useMetric = true
    @EnvironmentObject var featureFlags: FeatureFlags
    @EnvironmentObject var settingsManager: SettingsManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if isLoading {
                    ProgressView("Loading weather data...")
                        .controlSize(.large)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityLabel("Loading weather data for \(city.displayName)")
                } else if let error = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.red)
                            .accessibilityHidden(true)
                        
                        Text("Error Loading Weather")
                            .font(.title2)
                            .foregroundColor(.primary)
                        
                        Text(error)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Retry") {
                            Task {
                                await loadWeather()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityLabel("Retry loading weather")
                    }
                    .padding()
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Error loading weather: \(error). Tap retry button to try again.")
                } else if let weather = weatherData {
                    VStack(alignment: .leading, spacing: 24) {
                        // MARK: - Header
                        VStack(spacing: 8) {
                            Text(city.displayName)
                                .font(.title)
                                .fontWeight(.bold)
                                .accessibilityAddTraits(.isHeader)
                            
                            Text("Last updated: \(formatTime(weather.current.time))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(city.displayName), Last updated: \(formatTime(weather.current.time))")
                        
                        Divider()
                        
                        // MARK: - Feature-Flagged Sections
                        
                        // Expected Precipitation (Radar)
                        if featureFlags.radarEnabled {
                            NavigationLink(destination: RadarView(city: city).environmentObject(settingsManager)) {
                                HStack {
                                    Image(systemName: "cloud.rain.fill")
                                        .font(.title3)
                                        .foregroundColor(.blue)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Expected Precipitation")
                                            .font(.headline)
                                        Text("Minute-by-minute forecast")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color(nsColor: .controlBackgroundColor))
                                .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Expected Precipitation")
                            .accessibilityHint("View minute-by-minute precipitation forecast")
                        }
                        
                        // Weather Around Me
                        if featureFlags.weatherAroundMeEnabled {
                            NavigationLink(destination: WeatherAroundMeView(city: city, defaultDistance: settingsManager.settings.weatherAroundMeDistance).environmentObject(settingsManager)) {
                                HStack {
                                    Image(systemName: "location.circle.fill")
                                        .font(.title3)
                                        .foregroundColor(.green)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Weather Around Me")
                                            .font(.headline)
                                        Text("Regional weather comparison")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color(nsColor: .controlBackgroundColor))
                                .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Weather Around Me")
                            .accessibilityHint("View weather in surrounding areas")
                        }
                        
                        // Historical Weather
                        HistoricalWeatherView(city: city)
                            .environmentObject(WeatherService.shared)
                            .environmentObject(settingsManager)
                        
                        Divider()
                        
                        // MARK: - Current Weather
                        CurrentWeatherCard(weather: weather.current, useMetric: useMetric)
                        
                        // MARK: - Hourly Forecast
                        if let hourly = weather.hourly {
                            HourlyForecastCard(hourly: hourly, useMetric: useMetric)
                        }
                        
                        // MARK: - Daily Forecast
                        if let daily = weather.daily {
                            DailyForecastCard(daily: daily, useMetric: useMetric)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle(city.name)
        .toolbar {
            ToolbarItem {
                Toggle(isOn: $useMetric) {
                    Label(useMetric ? "Metric" : "Imperial", systemImage: "thermometer")
                }
                .help("Toggle between metric and imperial units")
                .accessibilityLabel(useMetric ? "Using metric units" : "Using imperial units")
                .accessibilityHint("Toggle to switch between metric and imperial units")
            }
        }
        .task {
            await loadWeather()
        }
    }
    
    private func loadWeather() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let weather = try await WeatherService.shared.fetchWeather(for: city)
            await MainActor.run {
                weatherData = weather
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    private func formatTime(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: isoString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return isoString
    }
}

// MARK: - Current Weather Card
struct CurrentWeatherCard: View {
    let weather: CurrentWeather
    let useMetric: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Current Conditions")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
            }
            
            HStack(alignment: .top, spacing: 20) {
                // Temperature and Icon
                VStack(spacing: 8) {
                    Image(systemName: weather.weatherCodeEnum?.sfSymbol ?? "cloud.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.accentColor)
                        .accessibilityLabel(weather.weatherCodeEnum?.description ?? "Weather icon")
                    
                    Text(formatTemperature(weather.temperature2m))
                        .font(.system(size: 48, weight: .bold))
                        .accessibilityLabel("Temperature: \(formatTemperature(weather.temperature2m))")
                    
                    Text(weather.weatherCodeEnum?.description ?? "Unknown")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
                
                // Weather Details Grid
                VStack(alignment: .leading, spacing: 12) {
                    WeatherDetailRow(
                        label: "Feels Like",
                        value: formatTemperature(weather.apparentTemperature),
                        icon: "thermometer"
                    )
                    
                    WeatherDetailRow(
                        label: "Humidity",
                        value: "\(weather.relativeHumidity2m)%",
                        icon: "humidity.fill"
                    )
                    
                    WeatherDetailRow(
                        label: "Wind",
                        value: "\(formatWindSpeed(weather.windSpeed10m)) \(weather.windDirectionDescription)",
                        icon: "wind"
                    )
                    
                    WeatherDetailRow(
                        label: "Visibility",
                        value: formatDistance(weather.visibility),
                        icon: "eye.fill"
                    )
                    
                    if weather.precipitation > 0 {
                        WeatherDetailRow(
                            label: "Precipitation",
                            value: formatPrecipitation(weather.precipitation),
                            icon: "drop.fill"
                        )
                    }
                    
                    WeatherDetailRow(
                        label: "Cloud Cover",
                        value: "\(weather.cloudCover)%",
                        icon: "cloud.fill"
                    )
                    
                    WeatherDetailRow(
                        label: "Pressure",
                        value: formatPressure(weather.pressureMsl),
                        icon: "gauge"
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .accessibilityElement(children: .contain)
    }
    
    // MARK: - Formatting Helpers
    private func formatTemperature(_ temp: Double) -> String {
        if useMetric {
            return "\(Int(temp))°C"
        } else {
            let fahrenheit = temp * 9/5 + 32
            return "\(Int(fahrenheit))°F"
        }
    }
    
    private func formatWindSpeed(_ speed: Double) -> String {
        if useMetric {
            return "\(Int(speed)) km/h"
        } else {
            let mph = speed * 0.621371
            return "\(Int(mph)) mph"
        }
    }
    
    private func formatDistance(_ meters: Double) -> String {
        if useMetric {
            let km = meters / 1000
            return String(format: "%.1f km", km)
        } else {
            let miles = meters * 0.000621371
            return String(format: "%.1f mi", miles)
        }
    }
    
    private func formatPrecipitation(_ mm: Double) -> String {
        if useMetric {
            return "\(Int(mm)) mm"
        } else {
            let inches = mm * 0.0393701
            return String(format: "%.2f in", inches)
        }
    }
    
    private func formatPressure(_ hpa: Double) -> String {
        if useMetric {
            return "\(Int(hpa)) hPa"
        } else {
            let inHg = hpa * 0.02953
            return String(format: "%.2f inHg", inHg)
        }
    }
}

// MARK: - Weather Detail Row
struct WeatherDetailRow: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 24)
                .accessibilityHidden(true)
            
            Text(label + ":")
                .foregroundColor(.secondary)
            
            Text(value)
                .fontWeight(.medium)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

// MARK: - Hourly Forecast Card
struct HourlyForecastCard: View {
    let hourly: HourlyWeather
    let useMetric: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Hourly Forecast")
                .font(.title2)
                .fontWeight(.semibold)
                .accessibilityAddTraits(.isHeader)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(0..<min(12, hourly.time.count), id: \.self) { index in
                        HourlyForecastItem(
                            time: hourly.time[index],
                            temp: hourly.temperature2m[index],
                            weatherCode: hourly.weathercode[index],
                            useMetric: useMetric
                        )
                    }
                }
                .padding(.horizontal, 4)
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Hourly forecast for the next 12 hours")
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct HourlyForecastItem: View {
    let time: String
    let temp: Double
    let weatherCode: Int
    let useMetric: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            Text(formatHour(time))
                .font(.caption)
                .foregroundColor(.secondary)
            
            Image(systemName: WeatherCode(rawValue: weatherCode)?.sfSymbol ?? "cloud.fill")
                .font(.title3)
                .foregroundColor(.accentColor)
                .accessibilityLabel(WeatherCode(rawValue: weatherCode)?.description ?? "Weather")
            
            Text(formatTemp(temp))
                .font(.body.weight(.semibold))
        }
        .frame(width: 60)
        .padding(8)
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(formatHour(time)): \(formatTemp(temp)), \(WeatherCode(rawValue: weatherCode)?.description ?? "Unknown conditions")")
    }
    
    private func formatHour(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: isoString) {
            let hourFormatter = DateFormatter()
            hourFormatter.dateFormat = "ha"
            return hourFormatter.string(from: date)
        }
        return ""
    }
    
    private func formatTemp(_ temp: Double) -> String {
        if useMetric {
            return "\(Int(temp))°"
        } else {
            let fahrenheit = temp * 9/5 + 32
            return "\(Int(fahrenheit))°"
        }
    }
}

// MARK: - Daily Forecast Card
struct DailyForecastCard: View {
    let daily: DailyWeather
    let useMetric: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("7-Day Forecast")
                .font(.title2)
                .fontWeight(.semibold)
                .accessibilityAddTraits(.isHeader)
            
            VStack(spacing: 12) {
                ForEach(0..<min(7, daily.time.count), id: \.self) { index in
                    DailyForecastItem(
                        date: daily.time[index],
                        weatherCode: daily.weathercode[index],
                        high: daily.temperature2mMax[index],
                        low: daily.temperature2mMin[index],
                        precipSum: daily.precipitationSum[index],
                        useMetric: useMetric
                    )
                    
                    if index < min(6, daily.time.count - 1) {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("7-day forecast")
    }
}

struct DailyForecastItem: View {
    let date: String
    let weatherCode: Int
    let high: Double
    let low: Double
    let precipSum: Double
    let useMetric: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            Text(formatDate(date))
                .font(.body)
                .frame(width: 80, alignment: .leading)
            
            Image(systemName: WeatherCode(rawValue: weatherCode)?.sfSymbol ?? "cloud.fill")
                .font(.title3)
                .foregroundColor(.accentColor)
                .frame(width: 32)
                .accessibilityLabel(WeatherCode(rawValue: weatherCode)?.description ?? "Weather")
            
            Text(WeatherCode(rawValue: weatherCode)?.description ?? "Unknown")
                .font(.body)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 8) {
                Text(formatTemp(high))
                    .font(.body.weight(.semibold))
                
                Text("/")
                    .foregroundColor(.secondary)
                
                Text(formatTemp(low))
                    .foregroundColor(.secondary)
            }
            .frame(width: 80, alignment: .trailing)
            
            if precipSum > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "drop.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .accessibilityHidden(true)
                    Text(formatPrecip(precipSum))
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .frame(width: 60, alignment: .trailing)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }
    
    private var accessibilityDescription: String {
        var desc = "\(formatDate(date)): \(WeatherCode(rawValue: weatherCode)?.description ?? "Unknown conditions"). High \(formatTemp(high)), Low \(formatTemp(low))"
        if precipSum > 0 {
            desc += ", Precipitation: \(formatPrecip(precipSum))"
        }
        return desc
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "EEE, MMM d"
            return displayFormatter.string(from: date)
        }
        return dateString
    }
    
    private func formatTemp(_ temp: Double) -> String {
        if useMetric {
            return "\(Int(temp))°"
        } else {
            let fahrenheit = temp * 9/5 + 32
            return "\(Int(fahrenheit))°"
        }
    }
    
    private func formatPrecip(_ mm: Double) -> String {
        if useMetric {
            return "\(Int(mm))mm"
        } else {
            let inches = mm * 0.0393701
            return String(format: "%.1f\"", inches)
        }
    }
}

#Preview {
    WeatherDetailView(city: City(name: "Madison", displayName: "Madison, WI", latitude: 43.074761, longitude: -89.3837613))
}
