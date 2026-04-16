//
//  TableView.swift
//  Fast Weather
//
//  Proper accessible data table — third view mode alongside Flat and List.
//
//  Architecture:
//    • Visual layer: SwiftUI VStack of HStack rows inside a ScrollView,
//      marked .accessibilityHidden(true). Sighted users see and interact with this.
//    • Accessibility layer: AccessibleDataTable overlay (from AccessibleTableBridge.swift)
//      positioned on top with .allowsHitTesting(false). VoiceOver sees only this.
//
//  VoiceOver experience:
//    • Swipe right across a row: "San Diego — row header" → "72°F — row 2, col 2 of 5,
//      Temperature, San Diego" — city name announced as context, not repeated per-cell.
//    • Swipe down a column: column header ("Temperature") read as persistent context.
//    • VoiceOver rotor: "Table navigation" for direct column jumping.
//    • Double-tap city name cell: navigates to city detail view.
//
//  Sighted-user interaction:
//    • Tap row: navigate to CityDetailView.
//    • Long-press row: context menu with Remove, Move Up/Down, Historical Weather.
//    • Scroll vertically for many cities.
//

import SwiftUI
import UIKit

// MARK: - Scroll offset preference key
// Tracks ScrollView offset so the accessibility overlay recalculates
// VoiceOver focus-rectangle positions after the user scrolls.
private struct TableScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

// MARK: - TableView

struct TableView: View {
    @EnvironmentObject var weatherService: WeatherService
    @EnvironmentObject var settingsManager: SettingsManager
    @Binding var selectedCityForHistory: City?
    let dateOffset: Int
    let selectedDate: Date

    @State private var scrollOffset: CGFloat = 0
    @State private var navigationTarget: City?

    // Minimum city column width — city names won't be squeezed below this.
    private static let cityColumnMinWidth: CGFloat = 120
    // Leading padding applied to city column text.
    private static let cityLeadingPad: CGFloat = 12

    /// Compute per-data-column width from the available container width.
    /// Minimum 56pt (fits "72°F"), maximum 90pt (fits "29.92 inHg").
    private func columnWidth(containerWidth: CGFloat, columnCount: Int) -> CGFloat {
        guard columnCount > 0 else { return 64 }
        let available = containerWidth
            - Self.cityColumnMinWidth
            - Self.cityLeadingPad
        let computed = available / CGFloat(columnCount)
        return min(max(computed, 56), 90)
    }

    // MARK: - Column configuration

    /// Top 5 enabled weather fields, excluding weather alerts (shown separately).
    private var activeColumns: [WeatherField] {
        Array(settingsManager.settings.weatherFields
            .filter { $0.isEnabled && $0.type != .weatherAlerts }
            .prefix(5))
    }

    /// Short labels for visual column headers — must fit in dataColumnWidth.
    private func shortName(for type: WeatherFieldType) -> String {
        switch type {
        case .temperature:               return "Temp"
        case .conditions:                return "Sky"
        case .feelsLike:                 return "Feels"
        case .humidity:                  return "Humid"
        case .windSpeed:                 return "Wind"
        case .windDirection:             return "Dir"
        case .windGusts:                 return "Gusts"
        case .precipitation:             return "Precip"
        case .precipitationProbability:  return "POP"
        case .rain:                      return "Rain"
        case .showers:                   return "Shower"
        case .snowfall:                  return "Snow"
        case .cloudCover:                return "Cloud"
        case .pressure:                  return "Press"
        case .visibility:                return "Vis"
        case .uvIndex:                   return "UV"
        case .dewPoint:                  return "Dew"
        case .highTemp:                  return "High"
        case .lowTemp:                   return "Low"
        case .sunrise:                   return "Rise"
        case .sunset:                    return "Set"
        case .weatherAlerts:             return ""
        }
    }

    // MARK: - Weather data helpers

    private func cachedWeather(for city: City) -> WeatherData? {
        let key = WeatherCacheKey(cityId: city.id, dateOffset: dateOffset)
        return weatherService.weatherCache[key]
    }

    private func displayValue(for fieldType: WeatherFieldType, city: City) -> String {
        guard let weather = cachedWeather(for: city) else { return "…" }
        guard let (_, value) = getFieldLabelAndValue(for: fieldType, weather: weather, showLabel: false) else { return "—" }
        return value
    }

    // MARK: - Accessibility data

    private func accessibilityHeaders(columns: [WeatherField]) -> [String] {
        ["City"] + columns.map { $0.type.rawValue }
    }

    private func accessibilityRows(cities: [City], columns: [WeatherField]) -> [[String]] {
        cities.map { city in
            [city.displayName] + columns.map { displayValue(for: $0.type, city: city) }
        }
    }

    // MARK: - Body

    var body: some View {
        let cities = weatherService.savedCities
        let columns = activeColumns

        GeometryReader { geo in
            let colWidth = columnWidth(containerWidth: geo.size.width, columnCount: columns.count)
            let a11yHeaders = accessibilityHeaders(columns: columns)
            let a11yRows = accessibilityRows(cities: cities, columns: columns)
            let activationHandlers: [() -> Bool] = cities.map { city in
                { [self] in
                    DispatchQueue.main.async { self.navigationTarget = city }
                    return true
                }
            }

        ScrollView {
            VStack(spacing: 0) {

                // ── Visual column header row ──────────────────────────────
                HStack(spacing: 0) {
                    Text("City")
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, Self.cityLeadingPad)
                    ForEach(columns) { field in
                        Text(shortName(for: field.type))
                            .font(.caption.bold())
                            .frame(width: colWidth, alignment: .trailing)
                            .padding(.trailing, 6)
                    }
                }
                .frame(height: 36)
                .background(Color.secondary.opacity(0.12))

                Divider()

                // ── Visual data rows ──────────────────────────────────────
                ForEach(Array(cities.enumerated()), id: \.element.id) { idx, city in
                    Button {
                        navigationTarget = city
                    } label: {
                        HStack(spacing: 0) {
                            Text(city.displayName)
                                .font(.subheadline)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.leading, Self.cityLeadingPad)

                            let cacheKeyForCity = WeatherCacheKey(cityId: city.id, dateOffset: dateOffset)
                            if weatherService.failedCacheKeys.contains(cacheKeyForCity) {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.secondary)
                                    .frame(width: colWidth * CGFloat(max(1, columns.count)))
                                    .accessibilityLabel("Unable to load weather")
                            } else if cachedWeather(for: city) == nil {
                                ProgressView()
                                    .frame(width: colWidth * CGFloat(max(1, columns.count)))
                            } else {
                                ForEach(columns) { field in
                                    Text(displayValue(for: field.type, city: city))
                                        .font(.caption.monospacedDigit())
                                        .lineLimit(1)
                                        .frame(width: colWidth, alignment: .trailing)
                                        .padding(.trailing, 6)
                                }
                            }
                        }
                        .frame(height: 44)
                        .background(idx % 2 == 0 ? Color.clear : Color.secondary.opacity(0.05))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            withAnimation {
                                weatherService.removeCity(city)
                                UIAccessibility.post(notification: .announcement,
                                                     argument: "Removed \(city.displayName)")
                            }
                        } label: {
                            Label("Remove City", systemImage: "trash")
                        }

                        if idx > 0 {
                            Button { moveCityUp(at: idx) } label: {
                                Label("Move Up", systemImage: "arrow.up")
                            }
                        }
                        if idx < cities.count - 1 {
                            Button { moveCityDown(at: idx) } label: {
                                Label("Move Down", systemImage: "arrow.down")
                            }
                        }
                        Button {
                            selectedCityForHistory = city
                        } label: {
                            Label("View Historical Weather", systemImage: "calendar")
                        }
                    }

                    if idx < cities.count - 1 {
                        Divider().padding(.leading, 12)
                    }
                }
            }
            // Visual layer hidden from VoiceOver; the overlay is what VoiceOver navigates.
            .accessibilityHidden(true)
            // Track scroll position so the accessibility overlay recalculates
            // focus-rectangle screen coordinates as the user scrolls.
            .background(
                GeometryReader { geo in
                    Color.clear.preference(
                        key: TableScrollOffsetKey.self,
                        value: geo.frame(in: .named("tableScroll")).minY
                    )
                }
            )
            // Accessibility overlay: invisible UIKit view exposing full table
            // semantics. scrollOffset being state causes this to rebuild whenever
            // the user scrolls, keeping VoiceOver focus-frame positions accurate.
            .overlay(
                AccessibleDataTable(
                    headers: a11yHeaders,
                    rows: a11yRows,
                    rowActivationHandlers: activationHandlers
                )
                .allowsHitTesting(false)
            )
        }
        .coordinateSpace(name: "tableScroll")
        .onPreferenceChange(TableScrollOffsetKey.self) { scrollOffset = $0 }
        .navigationDestination(item: $navigationTarget) { city in
            CityDetailView(city: city, dateOffset: dateOffset, selectedDate: selectedDate)
        }
        } // end GeometryReader
    }

    // MARK: - Move

    private func moveCityUp(at index: Int) {
        guard index > 0 else { return }
        let cityName = weatherService.savedCities[index].displayName
        let aboveName = weatherService.savedCities[index - 1].displayName
        weatherService.moveCity(from: IndexSet(integer: index), to: index - 1)
        UIAccessibility.post(notification: .announcement,
                             argument: "Moved \(cityName) above \(aboveName)")
    }

    private func moveCityDown(at index: Int) {
        guard index < weatherService.savedCities.count - 1 else { return }
        let cityName = weatherService.savedCities[index].displayName
        let belowName = weatherService.savedCities[index + 1].displayName
        weatherService.moveCity(from: IndexSet(integer: index), to: index + 2)
        UIAccessibility.post(notification: .announcement,
                             argument: "Moved \(cityName) below \(belowName)")
    }

    // MARK: - Field value helper

    private func getFieldLabelAndValue(for fieldType: WeatherFieldType, weather: WeatherData, showLabel: Bool) -> (String, String)? {
        switch fieldType {
        case .weatherAlerts:
            return nil

        case .temperature:
            return (showLabel ? "Temperature" : "", formatTemperature(weather.current.temperature2m))

        case .conditions:
            guard let weatherCode = weather.current.weatherCodeEnum else { return nil }
            return (showLabel ? "Conditions" : "", weatherCode.description)

        case .feelsLike:
            guard let apparentTemp = weather.current.apparentTemperature else { return nil }
            return (showLabel ? "Feels Like" : "", formatTemperature(apparentTemp))

        case .humidity:
            guard let humidity = weather.current.relativeHumidity2m else { return nil }
            return (showLabel ? "Humidity" : "", "\(humidity)%")

        case .windSpeed:
            guard let windSpeed = weather.current.windSpeed10m else { return nil }
            return (showLabel ? "Wind Speed" : "", formatWindSpeed(windSpeed))

        case .windDirection:
            guard let windDir = weather.current.windDirection10m else { return nil }
            return (showLabel ? "Wind Direction" : "", formatWindDirection(windDir))

        case .windGusts:
            guard let windGusts = weather.current.windGusts10m else { return nil }
            return (showLabel ? "Wind Gusts" : "", formatWindSpeed(windGusts))

        case .precipitation:
            let snowfall = weather.daily?.snowfallSum?.first.flatMap { $0 } ?? weather.current.snowfall ?? 0
            let precip = weather.daily?.precipitationSum?.first.flatMap { $0 } ?? weather.current.precipitation ?? 0
            if snowfall > 0 {
                return (showLabel ? "Snow" : "", formatSnowfall(snowfall))
            }
            guard precip > 0 else { return nil }
            return (showLabel ? "Rain" : "", formatPrecipitation(precip))

        case .precipitationProbability:
            guard let hourly = weather.hourly,
                  let probArray = hourly.precipitationProbability,
                  !probArray.isEmpty,
                  let prob = probArray[0], prob > 0 else { return nil }
            var value = "\(prob)%"
            if let precipArray = hourly.precipitation,
               !precipArray.isEmpty,
               let precipAmount = precipArray[0], precipAmount > 0.0 {
                value += " (\(formatPrecipitation(precipAmount)))"
            }
            return (showLabel ? "Precip Probability" : "", value)

        case .rain:
            guard let rain = weather.current.rain, rain > 0 else { return nil }
            return (showLabel ? "Rain" : "", formatPrecipitation(rain))

        case .showers:
            guard let showers = weather.current.showers, showers > 0 else { return nil }
            return (showLabel ? "Showers" : "", formatPrecipitation(showers))

        case .snowfall:
            let snow = weather.daily?.snowfallSum?.first.flatMap { $0 } ?? weather.current.snowfall ?? 0
            guard snow > 0 else { return nil }
            return (showLabel ? "Snow" : "", formatSnowfall(snow))

        case .cloudCover:
            let cc = weather.current.cloudCover
            return (showLabel ? "Cloud Cover" : "", "\(cc)%")

        case .pressure:
            guard let pressure = weather.current.pressureMsl else { return nil }
            return (showLabel ? "Pressure" : "", formatPressure(pressure))

        case .visibility:
            guard let vis = weather.current.visibility else { return nil }
            return (showLabel ? "Visibility" : "", formatVisibility(vis))

        case .uvIndex:
            guard let isDay = weather.current.isDay, isDay == 1,
                  let uvIndex = weather.current.uvIndex else { return nil }
            return (showLabel ? "UV Index" : "", String(format: "%.1f", uvIndex))

        case .dewPoint:
            guard let dewPoint = weather.current.dewpoint2m else { return nil }
            return (showLabel ? "Dew Point" : "", formatTemperature(dewPoint))

        case .highTemp:
            guard let daily = weather.daily, !daily.temperature2mMax.isEmpty,
                  let maxTemp = daily.temperature2mMax[0] else { return nil }
            return (showLabel ? "High" : "", formatTemperature(maxTemp))

        case .lowTemp:
            guard let daily = weather.daily, !daily.temperature2mMin.isEmpty,
                  let minTemp = daily.temperature2mMin[0] else { return nil }
            return (showLabel ? "Low" : "", formatTemperature(minTemp))

        case .sunrise:
            guard let daily = weather.daily,
                  let sunriseArray = daily.sunrise, !sunriseArray.isEmpty,
                  let sunrise = sunriseArray[0] else { return nil }
            return (showLabel ? "Sunrise" : "", formatTime(sunrise))

        case .sunset:
            guard let daily = weather.daily,
                  let sunsetArray = daily.sunset, !sunsetArray.isEmpty,
                  let sunset = sunsetArray[0] else { return nil }
            return (showLabel ? "Sunset" : "", formatTime(sunset))
        }
    }

    // MARK: - Formatting

    private func formatTemperature(_ celsius: Double) -> String {
        let temp = settingsManager.settings.temperatureUnit.convert(celsius)
        let unit = settingsManager.settings.temperatureUnit == .fahrenheit ? "F" : "C"
        return String(format: "%.0f°%@", temp, unit)
    }

    private func formatWindSpeed(_ kmh: Double) -> String {
        let speed = settingsManager.settings.windSpeedUnit.convert(kmh)
        return String(format: "%.0f %@", speed, settingsManager.settings.windSpeedUnit.rawValue)
    }

    private func formatWindDirection(_ degrees: Int) -> String {
        let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let index = Int((Double(degrees) / 45.0).rounded()) % 8
        return directions[index]
    }

    private func formatPrecipitation(_ mm: Double) -> String {
        let precip = settingsManager.settings.precipitationUnit.convert(mm)
        return String(format: "%.1f %@", precip, settingsManager.settings.precipitationUnit.rawValue)
    }

    private func formatSnowfall(_ cm: Double) -> String {
        switch settingsManager.settings.precipitationUnit {
        case .inches:      return String(format: "%.1f in", cm * 0.393701)
        case .millimeters: return String(format: "%.1f cm", cm)
        }
    }

    private func formatPressure(_ hPa: Double) -> String {
        let pressure = settingsManager.settings.pressureUnit.convert(hPa)
        return String(format: "%.1f %@", pressure, settingsManager.settings.pressureUnit.rawValue)
    }

    private func formatVisibility(_ meters: Double) -> String {
        let distance = settingsManager.settings.distanceUnit.convert(meters / 1000.0)
        return String(format: "%.1f %@", distance, settingsManager.settings.distanceUnit.rawValue)
    }

    private func formatTime(_ isoString: String) -> String {
        guard let date = DateParser.parse(isoString) else { return isoString }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}


