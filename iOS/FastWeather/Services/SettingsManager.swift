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

    private static let userDefaultsKey = "AppSettings"
    private static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: AppGroup.suiteName) ?? .standard
    }

    private static func migrateToAppGroupIfNeeded() {
        let migrationKey = "settingsAppGroupMigration_v1"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           sharedDefaults.data(forKey: userDefaultsKey) == nil {
            sharedDefaults.set(data, forKey: userDefaultsKey)
        }
        UserDefaults.standard.set(true, forKey: migrationKey)
    }

    init() {
        Self.migrateToAppGroupIfNeeded()
        let sharedDefaults = Self.sharedDefaults
        let userDefaultsKey = Self.userDefaultsKey
        // Check settings version first to avoid decoding crashes from structure changes
        if let data = sharedDefaults.data(forKey: userDefaultsKey) {
            // Try to extract just the version number without fully decoding
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let savedVersion = json["settingsVersion"] as? Int {
                if savedVersion != AppSettings.currentVersion {
                    // Version mismatch - clear old data to prevent decoding crashes
                    debugLog("⚠️ Settings version mismatch (saved: v\(savedVersion), current: v\(AppSettings.currentVersion))")
                    debugLog("🔄 Clearing old settings and resetting to defaults")
                    sharedDefaults.removeObject(forKey: userDefaultsKey)
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
                sharedDefaults.removeObject(forKey: userDefaultsKey)
                self.settings = AppSettings()
            }
        } else {
            // No saved settings - use defaults
            self.settings = AppSettings()
        }

        observeCloudSettingsChanges()
    }
    
    func saveSettings() {
        do {
            let encoded = try JSONEncoder().encode(settings)
            Self.sharedDefaults.set(encoded, forKey: Self.userDefaultsKey)
            iCloudSyncService.shared.pushSettings(settings)
        } catch {
            AppLogger.persistence.error("Failed to save settings: \(error)")
        }
    }

    func resetToDefaults() {
        settings = AppSettings()
        saveSettings()
    }

    // MARK: - iCloud Sync

    private func observeCloudSettingsChanges() {
        NotificationCenter.default.addObserver(
            forName: .iCloudSettingsDidChangeExternally,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyRemoteSettings()
        }
    }

    func applyRemoteSettings() {
        guard let remote = iCloudSyncService.shared.pullSettings(),
              remote.settingsVersion == AppSettings.currentVersion else { return }
        settings = remote
        do {
            let encoded = try JSONEncoder().encode(remote)
            Self.sharedDefaults.set(encoded, forKey: Self.userDefaultsKey)
            debugLog("iCloud: applied remote settings")
        } catch {
            AppLogger.persistence.error("Failed to save remote settings locally: \(error)")
        }
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
    /// Recent iOS versions insert a narrow no-break space (U+202F) before AM/PM in some locales
    /// (e.g. en_US). The app has always displayed a plain ASCII space there, so normalize the
    /// Unicode spaces back to a regular space for a stable, predictable rendering. 24-hour locales
    /// have no day period and are unaffected.
    private static func normalizingSpaces(_ s: String) -> String {
        s.replacingOccurrences(of: "\u{202F}", with: " ")
         .replacingOccurrences(of: "\u{00A0}", with: " ")
    }

    /// Formats an ISO8601 timestamp to a locale-aware short time (e.g., "6:50 AM" in en_US,
    /// "06:50" in de_DE). The user's system setting decides 12h vs 24h.
    /// - Parameters:
    ///   - isoString: ISO8601 formatted time string (e.g., "2026-01-18T06:50")
    ///   - locale: Locale to format for. Defaults to `.current`; tests pass an explicit locale.
    /// - Returns: Formatted time string in the locale's short time style.
    static func formatTime(_ isoString: String, locale: Locale = .current) -> String {
        guard let date = DateParser.parse(isoString) else {
            debugLog("⚠️ FormatHelper.formatTime failed to parse: '\(isoString)'")
            return isoString // Return original if parsing fails
        }

        let timeFormatter = DateFormatter()
        timeFormatter.locale = locale
        // Template "jmm" yields the locale's hour:minute pattern (12h with AM/PM in en_US,
        // 24h in de_DE, etc.). Using a template (vs. timeStyle) keeps en_US output as a plain
        // ASCII space before AM/PM, matching the app's long-standing format.
        timeFormatter.dateFormat = DateFormatter.dateFormat(fromTemplate: "jmm", options: 0, locale: locale)
            ?? "h:mm a"
        return normalizingSpaces(timeFormatter.string(from: date))
    }

    /// Formats an ISO8601 timestamp to a locale-aware short time, omitting minutes when they are :00
    /// (e.g., "3 PM" in en_US, "15 Uhr" in de_DE). Locale decides 12h/24h and the minute separator.
    /// - Parameters:
    ///   - isoString: ISO8601 formatted time string
    ///   - locale: Locale to format for. Defaults to `.current`; tests pass an explicit locale.
    /// - Returns: Compact, locale-aware time string.
    static func formatTimeCompact(_ isoString: String, locale: Locale = .current) -> String {
        guard let date = DateParser.parse(isoString) else {
            debugLog("⚠️ FormatHelper.formatTimeCompact failed to parse: '\(isoString)'")
            return isoString
        }

        // Build a locale-correct skeleton: hour-only when the minute is 0, otherwise hour+minutes.
        // "j" = locale's hour with day-period as appropriate; "jmm" = hour:minutes.
        var calendar = Calendar.current
        calendar.locale = locale
        let minute = calendar.component(.minute, from: date)
        let template = (minute == 0) ? "j" : "jmm"

        let timeFormatter = DateFormatter()
        timeFormatter.locale = locale
        timeFormatter.dateFormat = DateFormatter.dateFormat(fromTemplate: template, options: 0, locale: locale)
            ?? (minute == 0 ? "h a" : "h:mm a")
        return normalizingSpaces(timeFormatter.string(from: date))
    }
}
