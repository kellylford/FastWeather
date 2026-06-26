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
            cloudCover: slice(hourly.cloudCover),
            precipitationProbability: slice(hourly.precipitationProbability),
            uvIndex: slice(hourly.uvIndex),
            windGusts10m: slice(hourly.windGusts10m),
            dewPoint2m: slice(hourly.dewPoint2m),
            snowfall: slice(hourly.snowfall)
        )
    }

    private var navigationTitle: String {
        guard let sunriseStr = daily?.sunrise?[dayIndex],
              let date = DateParser.parse(sunriseStr) else {
            return dayIndex == 0
                ? String(localized: "day_detail.title.today", defaultValue: "Today", comment: "Day detail navigation title for the current day")
                : String(localized: "day_detail.title.day_n", defaultValue: "Day \(dayIndex + 1)", comment: "Day detail navigation title; placeholder is the day number")
        }
        let df = DateFormatter()
        df.setLocalizedDateFormatFromTemplate("EEEEMMMMd")
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
            if let timingText = precipitationTimingText() {
                Divider()
                HStack(spacing: 6) {
                    Image(systemName: "drop.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .accessibilityHidden(true)
                    Text(timingText)
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                .padding(.bottom, 2)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(conditionsAccessibilityLabel)
    }

    private var conditionsAccessibilityLabel: String {
        var parts: [String] = []
        if let code = weatherCodeEnum {
            parts.append(String(localized: "day_detail.a11y.conditions",
                                defaultValue: "Conditions: \(code.description)",
                                comment: "VoiceOver label; placeholder is the weather condition description"))
        }
        if let high = daily?.temperature2mMax[dayIndex] {
            parts.append(String(localized: "day_detail.a11y.high",
                                defaultValue: "High: \(formatTemperature(high))",
                                comment: "VoiceOver label; placeholder is the high temperature"))
        }
        if let low = daily?.temperature2mMin[dayIndex] {
            parts.append(String(localized: "day_detail.a11y.low",
                                defaultValue: "Low: \(formatTemperature(low))",
                                comment: "VoiceOver label; placeholder is the low temperature"))
        }
        if let timingText = precipitationTimingText() {
            parts.append(timingText)
        }
        return parts.joined(separator: ", ")
    }

    // MARK: - Precipitation timing

    /// Returns a human-readable timing summary for precipitation on this day,
    /// e.g. "Most likely 2 PM–5 PM" or "Expected throughout the day".
    private func precipitationTimingText() -> String? {
        guard let slice = hourlySlice,
              let timeArray = slice.time else { return nil }

        let probThreshold = 40
        let amountThreshold = 1.0  // mm

        var rainyIndices: [Int] = []
        for i in 0..<timeArray.count {
            guard timeArray[i] != nil else { continue }
            let prob = (slice.precipitationProbability.flatMap { arr in i < arr.count ? arr[i] : nil } ?? nil) ?? 0
            let amount = (slice.precipitation.flatMap { arr in i < arr.count ? arr[i] : nil } ?? nil) ?? 0.0
            if prob >= probThreshold || amount >= amountThreshold {
                rainyIndices.append(i)
            }
        }

        guard !rainyIndices.isEmpty else { return nil }

        // Determine precipitation type label for natural VoiceOver reading
        let precipType: String
        if let snow = daily?.snowfallSum?[dayIndex], snow > 0 {
            precipType = String(localized: "precip.type.snow", defaultValue: "Snow", comment: "Precipitation type used in timing summary")
        } else if let rain = daily?.rainSum?[dayIndex], rain > 0 {
            precipType = String(localized: "precip.type.rain", defaultValue: "Rain", comment: "Precipitation type used in timing summary")
        } else {
            precipType = String(localized: "precip.type.precipitation", defaultValue: "Precipitation", comment: "Precipitation type used in timing summary")
        }

        if rainyIndices.count >= 8 {
            return String(localized: "precip.timing.throughout_day",
                          defaultValue: "\(precipType) expected throughout the day",
                          comment: "Precipitation timing summary; placeholder is precipitation type (Rain/Snow/Precipitation)")
        }

        // Build contiguous windows (allow 1-hour gap to merge nearby showers)
        var windows: [(start: Int, end: Int)] = []
        var windowStart = rainyIndices[0]
        var windowEnd = rainyIndices[0]
        for i in 1..<rainyIndices.count {
            if rainyIndices[i] <= rainyIndices[i - 1] + 2 {
                windowEnd = rainyIndices[i]
            } else {
                windows.append((windowStart, windowEnd))
                windowStart = rainyIndices[i]
                windowEnd = rainyIndices[i]
            }
        }
        windows.append((windowStart, windowEnd))

        func timeLabel(_ index: Int) -> String {
            guard index < timeArray.count, let s = timeArray[index] else { return "" }
            return FormatHelper.formatTimeCompact(s)
        }

        let parts = windows.prefix(2).map { w -> String in
            return w.start == w.end
                ? String(localized: "precip.timing.around_time",
                         defaultValue: "around \(timeLabel(w.start))",
                         comment: "Precipitation timing window around a single time; placeholder is a clock time")
                : String(localized: "precip.timing.time_range",
                         defaultValue: "\(timeLabel(w.start))\u{2013}\(timeLabel(w.end))",
                         comment: "Precipitation timing window range; placeholders are start and end clock times")
        }
        let joiner = String(localized: "precip.timing.join_and", defaultValue: " and ", comment: "Joins two precipitation timing windows")
        let suffix = windows.count > 2
            ? String(localized: "precip.timing.and_later", defaultValue: " and later", comment: "Suffix when there are more than two precipitation timing windows")
            : ""
        let windowText = parts.joined(separator: joiner) + suffix
        return String(localized: "precip.timing.most_likely",
                      defaultValue: "\(precipType) most likely \(windowText)",
                      comment: "Precipitation timing summary; first placeholder is precipitation type, second is the time windows")
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
        let windDir = daily?.windDirectionDominant?[dayIndex]
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
        case ..<3:  return String(localized: "uv.category.low", defaultValue: "Low", comment: "UV index category")
        case ..<6:  return String(localized: "uv.category.moderate", defaultValue: "Moderate", comment: "UV index category")
        case ..<8:  return String(localized: "uv.category.high", defaultValue: "High", comment: "UV index category")
        case ..<11: return String(localized: "uv.category.very_high", defaultValue: "Very High", comment: "UV index category")
        default:    return String(localized: "uv.category.extreme", defaultValue: "Extreme", comment: "UV index category")
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
    let label: LocalizedStringKey
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
