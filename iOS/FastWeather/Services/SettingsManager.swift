//
//  SettingsManager.swift
//  Fast Weather
//
//  Manager for app settings and preferences
//

import Foundation
import Combine

/// Debug-only logging. Compiled out entirely in Release builds; the message
/// closure is never evaluated, so there is zero runtime cost.
@inline(__always)
func debugLog(_ message: @autoclosure () -> String) {
    #if DEBUG
    print(message())
    #endif
}

class SettingsManager: ObservableObject {
    @Published var settings: AppSettings
    
    private let userDefaultsKey = "AppSettings"
    
    init() {
        // Check settings version first to avoid decoding crashes from structure changes
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey) {
            // Try to extract just the version number without fully decoding
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let savedVersion = json["settingsVersion"] as? Int {
                if savedVersion != AppSettings.currentVersion {
                    // Version mismatch - clear old data to prevent decoding crashes
                    debugLog("⚠️ Settings version mismatch (saved: v\(savedVersion), current: v\(AppSettings.currentVersion))")
                    debugLog("🔄 Clearing old settings and resetting to defaults")
                    UserDefaults.standard.removeObject(forKey: userDefaultsKey)
                    self.settings = AppSettings()
                    return
                }
            }
            
            // Version matches or couldn't determine - try to decode
            do {
                self.settings = try JSONDecoder().decode(AppSettings.self, from: data)
            } catch {
                // Decoding failed - likely due to Settings structure change
                // Clear corrupted data and use defaults
                debugLog("⚠️ Failed to decode settings (structure changed): \(error)")
                debugLog("🔄 Resetting to default settings")
                UserDefaults.standard.removeObject(forKey: userDefaultsKey)
                self.settings = AppSettings()
            }
        } else {
            // No saved settings - use defaults
            self.settings = AppSettings()
        }
    }
    
    func saveSettings() {
        do {
            let encoded = try JSONEncoder().encode(settings)
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        } catch {
            AppLogger.persistence.error("Failed to save settings: \(error)")
        }
    }
    
    func resetToDefaults() {
        settings = AppSettings()
        saveSettings()
    }
}

// MARK: - DateParser
/// Centralized date/time parsing for Open-Meteo API responses
/// Open-Meteo uses the format "2026-01-18T06:50" (no timezone, no seconds)
struct DateParser {
    // Static formatters: DateFormatter is expensive to allocate. Creating one per parse()
    // call costs ~768 allocations for a single 16-day hourly fetch (384 timestamps × 2).
    // en_US_POSIX locale is the Apple-recommended safeguard for fixed-format date strings —
    // without it, non-Gregorian device locales (Arabic, Hebrew, Thai Buddhist, etc.) may
    // misinterpret the numeric fields and silently return nil.
    private static let openMeteoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private static let iso8601InternetFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let iso8601Internet: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let iso8601Full: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime]
        return f
    }()

    /// Parses Open-Meteo date/time strings to Date objects
    /// - Parameter isoString: Date/time string from Open-Meteo API (e.g., "2026-01-18T06:50")
    /// - Returns: Parsed Date object, or nil if parsing fails
    static func parse(_ isoString: String) -> Date? {
        // Primary: Open-Meteo's specific format "yyyy-MM-dd'T'HH:mm"
        if let date = openMeteoFormatter.date(from: isoString) {
            return date
        }

        // Fallback: standard ISO8601 variants (e.g. strings with timezone offsets)
        if let date = iso8601InternetFractional.date(from: isoString) { return date }
        if let date = iso8601Internet.date(from: isoString) { return date }
        if let date = iso8601Full.date(from: isoString) { return date }

        debugLog("⚠️ DateParser failed to parse: '\(isoString)'")
        return nil
    }

    /// Parses an Open-Meteo timestamp treating the string as local time in the given timezone.
    /// Use this overload when you need an absolute Date (UTC) for time comparisons —
    /// e.g. finding the first future hourly entry for a city in a different timezone.
    static func parse(_ isoString: String, in timeZone: TimeZone) -> Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = timeZone
        return f.date(from: isoString)
    }
}

// MARK: - FormatHelper
/// Centralized formatting utilities for dates, times, and weather data
struct FormatHelper {
    /// Formats an ISO8601 timestamp to 12-hour time format (e.g., "6:50 AM" or "3 PM")
    /// - Parameter isoString: ISO8601 formatted time string (e.g., "2026-01-18T06:50")
    /// - Returns: Formatted time string in 12-hour format with AM/PM
    static func formatTime(_ isoString: String) -> String {
        guard let date = DateParser.parse(isoString) else {
            debugLog("⚠️ FormatHelper.formatTime failed to parse: '\(isoString)'")
            return isoString // Return original if parsing fails
        }
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        return timeFormatter.string(from: date)
    }
    
    /// Formats an ISO8601 timestamp to 12-hour time format, omitting minutes if :00
    /// - Parameter isoString: ISO8601 formatted time string
    /// - Returns: Formatted time string (e.g., "3 PM" instead of "3:00 PM")
    static func formatTimeCompact(_ isoString: String) -> String {
        let fullTime = formatTime(isoString)
        if fullTime.contains(":00") {
            return fullTime.replacingOccurrences(of: ":00", with: "")
        }
        return fullTime
    }
}
