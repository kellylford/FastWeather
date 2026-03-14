//
//  DayDetailView.swift
//  Fast Weather
//
//  Focused detail view for a single day in the 16-day forecast.
//  Shows the 24-hour hourly breakdown, daily totals, wind/UV, and astronomy.
//  All data is sliced from the already-cached full WeatherData — no additional API calls.
//

import SwiftUI

struct DayDetailView: View {
    let city: City
    let dayIndex: Int            // 0 = today, 1 = tomorrow, ... 15
    let weather: WeatherData
    @ObservedObject var settingsManager: SettingsManager

    // MARK: - Computed helpers

    private var daily: WeatherData.DailyWeather? { weather.daily }

    /// The 24 hourly entries for this specific day (indices dayIndex*24 ..< dayIndex*24+24).
    private var hourlySlice: WeatherData.HourlyWeather? {
        guard let hourly = weather.hourly else { return nil }
        let startIdx = dayIndex * 24
        guard let timeArray = hourly.time, startIdx < timeArray.count else { return nil }
        let endIdx = min(startIdx + 24, timeArray.count)
        let range = startIdx..<endIdx

        func slice<T>(_ arr: [T?]?) -> [T?]? {
            guard let arr = arr, arr.count > startIdx else { return nil }
            return Array(arr[range])
        }

        return WeatherData.HourlyWeather(
            time: slice(hourly.time),
            temperature2m: slice(hourly.temperature2m),
            weatherCode: slice(hourly.weatherCode),
            precipitation: slice(hourly.precipitation),
            relativeHumidity2m: slice(hourly.relativeHumidity2m),
            windSpeed10m: slice(hourly.windSpeed10m),
            cloudcover: slice(hourly.cloudcover),
            precipitationProbability: slice(hourly.precipitationProbability),
            uvIndex: slice(hourly.uvIndex),
            windgusts10m: slice(hourly.windgusts10m),
            dewpoint2m: slice(hourly.dewpoint2m),
            snowfall: slice(hourly.snowfall)
        )
    }

    private var navigationTitle: String {
        guard let sunriseStr = daily?.sunrise?[dayIndex],
              let date = DateParser.parse(sunriseStr) else {
            return dayIndex == 0 ? "Today" : "Day \(dayIndex + 1)"
        }
        let df = DateFormatter()
        df.dateFormat = "EEEE, MMMM d"
        return df.string(from: date)
    }

    private var weatherCodeEnum: WeatherCode? {
        guard let code = daily?.weatherCode?[dayIndex] else { return nil }
        return WeatherCode(rawValue: code)
    }

    // MARK: - Format helpers (mirror CityDetailView helpers using settingsManager)

    private func formatTemperature(_ celsius: Double) -> String {
        let temp = settingsManager.settings.temperatureUnit.convert(celsius)
        let unit = settingsManager.settings.temperatureUnit == .fahrenheit ? "F" : "C"
        return String(format: "%.0f°%@", temp, unit)
    }

    private func formatPrecipitation(_ mm: Double) -> String {
        let precip = settingsManager.settings.precipitationUnit.convert(mm)
        return String(format: "%.2f %@", precip, settingsManager.settings.precipitationUnit.rawValue)
    }

    private func formatSnowfall(_ cm: Double) -> String {
        switch settingsManager.settings.precipitationUnit {
        case .inches:
            return String(format: "%.1f in", cm * 0.393701)
        case .millimeters:
            return String(format: "%.1f cm", cm)
        }
    }

    private func formatWindSpeed(_ kmh: Double) -> String {
        let speed = settingsManager.settings.windSpeedUnit.convert(kmh)
        return String(format: "%.0f %@", speed, settingsManager.settings.windSpeedUnit.rawValue)
    }

    private func formatWindDirection(_ degrees: Int) -> String {
        let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let idx = Int((Double(degrees) / 45.0).rounded()) % 8
        return directions[idx]
    }

    private func formatDuration(_ seconds: Double) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        return m > 0 ? "\(h)h \(m)m" : "\(h)h"
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                conditionsCard
                hourlyForecastSection
                precipitationSection
                windAndUVSection
                astronomySection
            }
            .padding()
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(uiColor: .systemGroupedBackground))
    }

    // MARK: - Conditions card

    @ViewBuilder
    private var conditionsCard: some View {
        GroupBox(label: Label("Conditions", systemImage: "cloud.sun")) {
            HStack(alignment: .center, spacing: 16) {
                if let code = weatherCodeEnum {
                    Image(systemName: code.systemImageName)
                        .font(.system(size: 44))
                        .foregroundColor(.blue)
                        .accessibilityHidden(true)
                }

                VStack(alignment: .leading, spacing: 4) {
                    if let code = weatherCodeEnum {
                        Text(code.description)
                            .font(.headline)
                    }

                    if let high = daily?.temperature2mMax[dayIndex],
                       let low = daily?.temperature2mMin[dayIndex] {
                        HStack(spacing: 12) {
                            Label {
                                Text(formatTemperature(high))
                                    .fontWeight(.semibold)
                            } icon: {
                                Image(systemName: "thermometer.high")
                                    .foregroundColor(.orange)
                                    .accessibilityHidden(true)
                            }
                            Label {
                                Text(formatTemperature(low))
                                    .foregroundColor(.secondary)
                            } icon: {
                                Image(systemName: "thermometer.low")
                                    .foregroundColor(.blue)
                                    .accessibilityHidden(true)
                            }
                        }
                        .font(.subheadline)
                    }
                }

                Spacer()
            }
            .padding(.vertical, 4)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(conditionsAccessibilityLabel)
    }

    private var conditionsAccessibilityLabel: String {
        var parts: [String] = []
        if let code = weatherCodeEnum {
            parts.append("Conditions: \(code.description)")
        }
        if let high = daily?.temperature2mMax[dayIndex] {
            parts.append("High: \(formatTemperature(high))")
        }
        if let low = daily?.temperature2mMin[dayIndex] {
            parts.append("Low: \(formatTemperature(low))")
        }
        return parts.joined(separator: ", ")
    }

    // MARK: - 24-Hour Forecast

    @ViewBuilder
    private var hourlyForecastSection: some View {
        if let slice = hourlySlice, let timeArray = slice.time, !timeArray.isEmpty {
            GroupBox(label: Label("24-Hour Forecast", systemImage: "clock")) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(0..<timeArray.count, id: \.self) { localIdx in
                            if timeArray[localIdx] != nil {
                                HourlyForecastCard(
                                    hourly: slice,
                                    index: localIdx,
                                    settingsManager: settingsManager
                                )
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: - Precipitation

    @ViewBuilder
    private var precipitationSection: some View {
        let prob = daily?.precipitationProbabilityMax?[dayIndex]
        let precipSum = daily?.precipitationSum?[dayIndex]
        let rainSum = daily?.rainSum?[dayIndex]
        let snowSum = daily?.snowfallSum?[dayIndex]

        let hasAny = (prob ?? 0) > 0 || (precipSum ?? 0) > 0 || (rainSum ?? 0) > 0 || (snowSum ?? 0) > 0

        if hasAny {
            GroupBox(label: Label("Precipitation", systemImage: "drop")) {
                VStack(spacing: 0) {
                    if let prob = prob, prob > 0 {
                        DayDetailRow(
                            icon: "drop.fill", iconColor: .blue,
                            label: "Probability",
                            value: "\(prob)%"
                        )
                    }
                    if let snow = snowSum, snow > 0 {
                        Divider().padding(.leading, 40)
                        DayDetailRow(
                            icon: "snowflake", iconColor: .blue,
                            label: "Snowfall",
                            value: formatSnowfall(snow)
                        )
                    }
                    if let rain = rainSum, rain > 0 {
                        Divider().padding(.leading, 40)
                        DayDetailRow(
                            icon: "drop.fill", iconColor: .cyan,
                            label: "Rain",
                            value: formatPrecipitation(rain)
                        )
                    }
                    if let total = precipSum, total > 0 {
                        // Only show total if it differs from rain alone (mixed precip)
                        let rainMm = rainSum ?? 0
                        let snowMm = (snowSum ?? 0) * 10  // cm → mm liquid equivalent
                        let hasDistinctTotal = abs(total - rainMm - snowMm) > 0.5
                        if hasDistinctTotal || (rainSum == nil && snowSum == nil) {
                            Divider().padding(.leading, 40)
                            DayDetailRow(
                                icon: "cloud.rain", iconColor: .secondary,
                                label: "Total",
                                value: formatPrecipitation(total)
                            )
                        }
                    }
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: - Wind & UV

    @ViewBuilder
    private var windAndUVSection: some View {
        let wind = daily?.windSpeed10mMax?[dayIndex]
        let windDir = daily?.winddirection10mDominant?[dayIndex]
        let uv = daily?.uvIndexMax?[dayIndex]

        if wind != nil || uv != nil {
            GroupBox(label: Label("Wind & UV", systemImage: "wind")) {
                VStack(spacing: 0) {
                    if let wind = wind {
                        DayDetailRow(
                            icon: "wind", iconColor: .secondary,
                            label: "Max Wind",
                            value: windDir != nil
                                ? "\(formatWindSpeed(wind)) \(formatWindDirection(windDir!))"
                                : formatWindSpeed(wind)
                        )
                    }
                    if let uv = uv, wind != nil {
                        Divider().padding(.leading, 40)
                        DayDetailRow(
                            icon: "sun.max", iconColor: .orange,
                            label: "Max UV Index",
                            value: String(format: "%.0f", uv),
                            badge: uvCategory(uv)
                        )
                    } else if let uv = uv {
                        DayDetailRow(
                            icon: "sun.max", iconColor: .orange,
                            label: "Max UV Index",
                            value: String(format: "%.0f", uv),
                            badge: uvCategory(uv)
                        )
                    }
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    private func uvCategory(_ uv: Double) -> String? {
        switch uv {
        case ..<3:  return "Low"
        case ..<6:  return "Moderate"
        case ..<8:  return "High"
        case ..<11: return "Very High"
        default:    return "Extreme"
        }
    }

    // MARK: - Astronomy

    @ViewBuilder
    private var astronomySection: some View {
        let sunriseStr = daily?.sunrise?[dayIndex]
        let sunsetStr  = daily?.sunset?[dayIndex]
        let daylight   = daily?.daylightDuration?[dayIndex]
        let sunshine   = daily?.sunshineDuration?[dayIndex]

        if sunriseStr != nil || sunsetStr != nil || daylight != nil {
            GroupBox(label: Label("Astronomy", systemImage: "sun.horizon")) {
                VStack(spacing: 0) {
                    if let str = sunriseStr {
                        DayDetailRow(
                            icon: "sunrise.fill", iconColor: .orange,
                            label: "Sunrise",
                            value: FormatHelper.formatTime(str)
                        )
                    }
                    if let str = sunsetStr {
                        if sunriseStr != nil { Divider().padding(.leading, 40) }
                        DayDetailRow(
                            icon: "sunset.fill", iconColor: .orange,
                            label: "Sunset",
                            value: FormatHelper.formatTime(str)
                        )
                    }
                    if let dl = daylight {
                        Divider().padding(.leading, 40)
                        DayDetailRow(
                            icon: "clock", iconColor: .secondary,
                            label: "Daylight",
                            value: formatDuration(dl)
                        )
                    }
                    if let ss = sunshine {
                        Divider().padding(.leading, 40)
                        DayDetailRow(
                            icon: "sun.max.fill", iconColor: .yellow,
                            label: "Sunshine",
                            value: formatDuration(ss)
                        )
                    }
                }
            }
            .accessibilityElement(children: .combine)
        }
    }
}

// MARK: - DayDetailRow helper

private struct DayDetailRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String
    var badge: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(iconColor)
                .frame(width: 24, alignment: .center)
                .accessibilityHidden(true)

            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)

            if let badge = badge {
                Text(badge)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.15))
                    .foregroundColor(.orange)
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 10)
    }
}
