            import WidgetKit
import SwiftUI
import AppIntents
import OSLog

private let logger = Logger(subsystem: "com.weatherfast.app.widget", category: "widget")
private let appGroupSuiteName = "group.com.weatherfast.app"

// MARK: - Saved city model (mirrors City.swift Codable format)

private struct SavedCity: Codable {
    let id: UUID
    let name: String
    let state: String?
    let country: String
    let latitude: Double
    let longitude: Double

    var displayName: String {
        if let state, !state.isEmpty {
            return (country == "United States" || country == "USA")
                ? "\(name), \(state)"
                : "\(name), \(state), \(country)"
        }
        return (country == "United States" || country == "USA") ? name : "\(name), \(country)"
    }
}

// MARK: - Shared UserDefaults helpers

private func loadSavedCities() -> [SavedCity] {
    guard let defaults = UserDefaults(suiteName: appGroupSuiteName),
          let data = defaults.data(forKey: "SavedCities"),
          let cities = try? JSONDecoder().decode([SavedCity].self, from: data)
    else { return [] }
    return cities
}

// Returns true if the user prefers Fahrenheit.
private func isFahrenheit() -> Bool {
    guard let defaults = UserDefaults(suiteName: appGroupSuiteName),
          let data = defaults.data(forKey: "AppSettings"),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let unit = json["temperatureUnit"] as? String
    else { return Locale.current.measurementSystem == .us }
    return unit == "°F"
}

private func formatTemp(_ celsius: Double, fahrenheit: Bool) -> String {
    let value = fahrenheit ? celsius * 9/5 + 32 : celsius
    return "\(Int(value.rounded()))°"
}

// MARK: - CityEntity (AppIntents)

struct CityEntity: AppEntity {
    let id: UUID
    let name: String
    let state: String?
    let country: String
    let latitude: Double
    let longitude: Double

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(displayName)")
    }

    var displayName: String {
        if let state, !state.isEmpty {
            return (country == "United States" || country == "USA")
                ? "\(name), \(state)"
                : "\(name), \(state), \(country)"
        }
        return (country == "United States" || country == "USA") ? name : "\(name), \(country)"
    }

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "City"
    static var defaultQuery = CityEntityQuery()
}

struct CityEntityQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [CityEntity] {
        loadSavedCities()
            .filter { identifiers.contains($0.id) }
            .map(\.asEntity)
    }

    func suggestedEntities() async throws -> [CityEntity] {
        loadSavedCities().map(\.asEntity)
    }

    func defaultResult() async -> CityEntity? {
        loadSavedCities().first?.asEntity
    }
}

private extension SavedCity {
    var asEntity: CityEntity {
        CityEntity(id: id, name: name, state: state, country: country,
                   latitude: latitude, longitude: longitude)
    }
}

// MARK: - Widget configuration intent

struct SelectCityIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select City"
    static var description = IntentDescription("Choose which city to display.")

    @Parameter(title: "City")
    var city: CityEntity?
}

// MARK: - Timeline entry

struct DayForecastEntry {
    let dayName: String
    let sfSymbol: String
    let highTemp: String?
    let lowTemp: String?
    let precipProbability: Int?
}

struct WeatherEntry: TimelineEntry {
    let date: Date
    let cityName: String
    let temperature: String
    let condition: String
    let sfSymbol: String
    let isDay: Bool
    let highTemp: String?
    let lowTemp: String?
    let precipProbability: Int?
    let dailyForecasts: [DayForecastEntry]
}

extension WeatherEntry {
    static var placeholder: WeatherEntry {
        WeatherEntry(date: .now, cityName: "San Francisco",
                     temperature: "68°", condition: "Partly Cloudy",
                     sfSymbol: "cloud.sun.fill", isDay: true,
                     highTemp: "72°", lowTemp: "58°", precipProbability: 20,
                     dailyForecasts: [
                         DayForecastEntry(dayName: "Today", sfSymbol: "cloud.sun.fill",  highTemp: "72°", lowTemp: "58°", precipProbability: 20),
                         DayForecastEntry(dayName: "Tue",   sfSymbol: "sun.max.fill",    highTemp: "75°", lowTemp: "60°", precipProbability: 5),
                         DayForecastEntry(dayName: "Wed",   sfSymbol: "cloud.rain.fill", highTemp: "65°", lowTemp: "54°", precipProbability: 70),
                         DayForecastEntry(dayName: "Thu",   sfSymbol: "cloud.fill",      highTemp: "68°", lowTemp: "55°", precipProbability: 30),
                         DayForecastEntry(dayName: "Fri",   sfSymbol: "sun.max.fill",    highTemp: "73°", lowTemp: "57°", precipProbability: 10),
                     ])
    }

    static var noCity: WeatherEntry {
        WeatherEntry(date: .now, cityName: "Weather Fast",
                     temperature: "--°", condition: "Add a city in the app",
                     sfSymbol: "cloud.fill", isDay: true,
                     highTemp: nil, lowTemp: nil, precipProbability: nil,
                     dailyForecasts: [])
    }
}

// MARK: - Timeline provider

struct FastWeatherTimelineProvider: AppIntentTimelineProvider {
    typealias Intent = SelectCityIntent
    typealias Entry  = WeatherEntry

    func placeholder(in context: Context) -> WeatherEntry { .placeholder }

    func snapshot(for configuration: SelectCityIntent, in context: Context) async -> WeatherEntry {
        await makeEntry(for: configuration)
    }

    func timeline(for configuration: SelectCityIntent, in context: Context) async -> Timeline<WeatherEntry> {
        let entry = await makeEntry(for: configuration)
        let next  = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now
        return Timeline(entries: [entry], policy: .after(next))
    }

    // MARK: - Private

    private func makeEntry(for configuration: SelectCityIntent) async -> WeatherEntry {
        // Resolve city: use the user-selected entity, else fall back to first saved city.
        let entity = configuration.city ?? loadSavedCities().first?.asEntity
        guard let entity else { return .noCity }

        let useFahrenheit = isFahrenheit()
        do {
            let weather = try await WidgetWeatherFetcher.fetch(
                latitude: entity.latitude,
                longitude: entity.longitude
            )
            let dailyForecasts = weather.dailyForecasts.map { day in
                DayForecastEntry(
                    dayName: day.dayName,
                    sfSymbol: day.sfSymbol,
                    highTemp: day.highCelsius.map { formatTemp($0, fahrenheit: useFahrenheit) },
                    lowTemp:  day.lowCelsius.map  { formatTemp($0, fahrenheit: useFahrenheit) },
                    precipProbability: day.precipProbability
                )
            }
            return WeatherEntry(
                date: .now,
                cityName: entity.displayName,
                temperature: formatTemp(weather.temperatureCelsius, fahrenheit: useFahrenheit),
                condition: weather.conditionText,
                sfSymbol: weather.sfSymbol,
                isDay: weather.isDay,
                highTemp: weather.highCelsius.map { formatTemp($0, fahrenheit: useFahrenheit) },
                lowTemp:  weather.lowCelsius.map  { formatTemp($0, fahrenheit: useFahrenheit) },
                precipProbability: weather.precipProbability,
                dailyForecasts: dailyForecasts
            )
        } catch {
            logger.error("Widget weather fetch failed for \(entity.displayName): \(error)")
            return WeatherEntry(
                date: .now,
                cityName: entity.displayName,
                temperature: "--°",
                condition: "Unable to load",
                sfSymbol: "exclamationmark.triangle",
                isDay: true,
                highTemp: nil, lowTemp: nil, precipProbability: nil,
                dailyForecasts: []
            )
        }
    }
}

// MARK: - Widget bundle

@main
struct FastWeatherWidgetBundle: WidgetBundle {
    var body: some Widget {
        FastWeatherSmallWidget()
        FastWeatherMediumWidget()
        FastWeatherLargeWidget()
        FastWeatherLockWidget()
    }
}

// MARK: - Small widget

struct FastWeatherSmallWidget: Widget {
    let kind = "FastWeatherSmall"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectCityIntent.self,
            provider: FastWeatherTimelineProvider()
        ) { entry in
            FastWeatherWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Weather Fast")
        .description("Current temperature and conditions for one city, with today's high and low.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Medium widget

struct FastWeatherMediumWidget: Widget {
    let kind = "FastWeatherMedium"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectCityIntent.self,
            provider: FastWeatherTimelineProvider()
        ) { entry in
            FastWeatherWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Weather Fast")
        .description("Current conditions, temperature, today's high and low, and precipitation probability for one city.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Large widget

struct FastWeatherLargeWidget: Widget {
    let kind = "FastWeatherLarge"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectCityIntent.self,
            provider: FastWeatherTimelineProvider()
        ) { entry in
            FastWeatherWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Weather Fast")
        .description("Current conditions at the top, followed by a 5-day forecast showing daily highs, lows, and precipitation chances for each day.")
        .supportedFamilies([.systemLarge])
    }
}

// MARK: - Lock screen widget

struct FastWeatherLockWidget: Widget {
    let kind = "FastWeatherLockScreen"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectCityIntent.self,
            provider: FastWeatherTimelineProvider()
        ) { entry in
            FastWeatherWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Weather Fast")
        .description("A compact display for your lock screen. The circular option shows a condition icon and temperature; the rectangular bar adds the city name and today's high and low.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}
