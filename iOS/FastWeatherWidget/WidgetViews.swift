import SwiftUI
import WidgetKit

// MARK: - Entry view router

struct FastWeatherWidgetEntryView: View {
    var entry: WeatherEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemSmall:       SmallWidgetView(entry: entry)
        case .systemMedium:      MediumWidgetView(entry: entry)
        case .systemLarge:       LargeWidgetView(entry: entry)
        case .accessoryCircular: CircularWidgetView(entry: entry)
        case .accessoryRectangular: RectangularWidgetView(entry: entry)
        default:                 SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Small widget (home screen)

struct SmallWidgetView: View {
    let entry: WeatherEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.cityName)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
                .foregroundStyle(.secondary)

            Spacer()

            Image(systemName: entry.sfSymbol)
                .font(.system(size: 32))
                .symbolRenderingMode(.multicolor)
                .accessibilityHidden(true)

            Text(entry.temperature)
                .font(.system(size: 36, weight: .semibold, design: .rounded))
                .minimumScaleFactor(0.8)

            Text(entry.condition)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if let high = entry.highTemp, let low = entry.lowTemp {
                Text("H:\(high)  L:\(low)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        var parts = [entry.cityName, entry.temperature, entry.condition]
        if let high = entry.highTemp, let low = entry.lowTemp {
            parts.append("High \(high), Low \(low)")
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Medium widget (home screen)

struct MediumWidgetView: View {
    let entry: WeatherEntry

    var body: some View {
        HStack(spacing: 16) {
            // Left: icon + temp
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.cityName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Spacer()

                Image(systemName: entry.sfSymbol)
                    .font(.system(size: 40))
                    .symbolRenderingMode(.multicolor)
                    .accessibilityHidden(true)

                Text(entry.temperature)
                    .font(.system(size: 42, weight: .semibold, design: .rounded))
                    .minimumScaleFactor(0.7)
            }
            .frame(maxHeight: .infinity, alignment: .leading)

            Divider()

            // Right: detail stack
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.condition)
                    .font(.subheadline)
                    .lineLimit(2)

                if let high = entry.highTemp, let low = entry.lowTemp {
                    Label("H:\(high)  L:\(low)", systemImage: "thermometer")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let pct = entry.precipProbability {
                    Label("\(pct)% rain", systemImage: "drop.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(entry.date, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxHeight: .infinity, alignment: .leading)
        }
        .padding(14)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        var parts = [entry.cityName, entry.temperature, entry.condition]
        if let high = entry.highTemp, let low = entry.lowTemp {
            parts.append("High \(high), Low \(low)")
        }
        if let pct = entry.precipProbability {
            parts.append("\(pct)% chance of rain")
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Circular lock screen / StandBy widget

struct CircularWidgetView: View {
    let entry: WeatherEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Image(systemName: entry.sfSymbol)
                    .font(.system(size: 14))
                    .accessibilityHidden(true)
                Text(entry.temperature)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .minimumScaleFactor(0.7)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(entry.cityName), \(entry.temperature), \(entry.condition)")
    }
}

// MARK: - Rectangular lock screen widget

struct RectangularWidgetView: View {
    let entry: WeatherEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: entry.sfSymbol)
                    .font(.caption)
                    .accessibilityHidden(true)
                Text(entry.cityName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Spacer()
                Text(entry.temperature)
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            HStack(spacing: 4) {
                Text(entry.condition)
                    .font(.caption2)
                    .lineLimit(1)
                if let high = entry.highTemp, let low = entry.lowTemp {
                    Spacer()
                    Text("H:\(high) L:\(low)")
                        .font(.caption2)
                }
            }
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(entry.cityName), \(entry.temperature), \(entry.condition)")
    }
}

// MARK: - Large home screen widget (current conditions + 5-day forecast)

struct LargeWidgetView: View {
    let entry: WeatherEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── Current conditions ─────────────────────────────────────────
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.cityName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(1)

                    Text(entry.condition)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if let high = entry.highTemp, let low = entry.lowTemp {
                        Text("H:\(high)  L:\(low)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let pct = entry.precipProbability {
                        Label("\(pct)% rain", systemImage: "drop.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Image(systemName: entry.sfSymbol)
                        .font(.system(size: 36))
                        .symbolRenderingMode(.multicolor)
                        .accessibilityHidden(true)
                    Text(entry.temperature)
                        .font(.system(size: 42, weight: .semibold, design: .rounded))
                        .minimumScaleFactor(0.7)
                }
            }
            .padding(.bottom, 10)

            Divider()
                .padding(.bottom, 8)

            // ── 5-day forecast ─────────────────────────────────────────────
            if entry.dailyForecasts.isEmpty {
                Spacer()
                Text("Forecast unavailable")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                VStack(spacing: 6) {
                    ForEach(entry.dailyForecasts.prefix(5), id: \.dayName) { day in
                        ForecastRow(day: day)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(largeAccessibilityLabel)
    }

    private var largeAccessibilityLabel: String {
        var parts = [entry.cityName, entry.temperature, entry.condition]
        if let high = entry.highTemp, let low = entry.lowTemp {
            parts.append("High \(high), Low \(low)")
        }
        if let pct = entry.precipProbability {
            parts.append("\(pct)% chance of rain")
        }
        let forecastParts = entry.dailyForecasts.prefix(5).compactMap { day -> String? in
            guard let high = day.highTemp, let low = day.lowTemp else { return day.dayName }
            var label = "\(day.dayName): H \(high) L \(low)"
            if let pct = day.precipProbability, pct >= 20 {
                label += ", \(pct)% chance of rain"
            }
            return label
        }
        parts.append(contentsOf: forecastParts)
        return parts.joined(separator: ". ")
    }
}

// MARK: - Forecast row (used inside LargeWidgetView)

private struct ForecastRow: View {
    let day: DayForecastEntry

    var body: some View {
        HStack(spacing: 0) {
            // Day name — fixed width so all rows align
            Text(day.dayName)
                .font(.subheadline)
                .fontWeight(day.dayName == "Today" ? .semibold : .regular)
                .frame(width: 46, alignment: .leading)

            // Weather icon
            Image(systemName: day.sfSymbol)
                .font(.subheadline)
                .symbolRenderingMode(.multicolor)
                .frame(width: 24)
                .accessibilityHidden(true)

            // Rain probability (always reserve space so icons line up)
            Group {
                if let pct = day.precipProbability, pct >= 20 {
                    Label("\(pct)%", systemImage: "drop.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("")
                        .font(.caption2)
                }
            }
            .frame(width: 50, alignment: .leading)

            Spacer()

            // Low temperature
            if let low = day.lowTemp {
                Text(low)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(width: 36, alignment: .trailing)
            }

            // High temperature
            if let high = day.highTemp {
                Text(high)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .frame(width: 36, alignment: .trailing)
            }
        }
    }
}
