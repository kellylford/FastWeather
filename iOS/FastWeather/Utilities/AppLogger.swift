import OSLog

/// Centralised logging for FastWeather using structured `os.Logger`.
///
/// Usage:
/// ```swift
/// AppLogger.service.error("Failed to decode saved cities: \(error)")
/// AppLogger.network.debug("Fetching weather for \(city.name)")
/// ```
enum AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.fastweather"

    /// General weather/alert/marine service operations.
    static let service = Logger(subsystem: subsystem, category: "service")

    /// Network requests and response handling.
    static let network = Logger(subsystem: subsystem, category: "network")

    /// Persistence: UserDefaults encode/decode, JSON serialisation.
    static let persistence = Logger(subsystem: subsystem, category: "persistence")

    /// Location and geocoding operations.
    static let location = Logger(subsystem: subsystem, category: "location")
}
