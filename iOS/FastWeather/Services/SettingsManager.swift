//
//  SettingsManager.swift
//  Fast Weather
//
//  Manager for app settings and preferences
//

import Foundation
import Combine

class SettingsManager: ObservableObject {
    @Published var settings: AppSettings
    
    private let userDefaultsKey = "AppSettings"
    
    init() {
        // Try to load saved settings
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey) {
            do {
                self.settings = try JSONDecoder().decode(AppSettings.self, from: data)
            } catch {
                // Decoding failed - likely due to Settings structure change
                // Clear corrupted data and use defaults
                print("⚠️ Failed to decode settings (structure changed): \(error)")
                print("🔄 Resetting to default settings")
                UserDefaults.standard.removeObject(forKey: userDefaultsKey)
                self.settings = AppSettings()
            }
        } else {
            // No saved settings - use defaults
            self.settings = AppSettings()
        }
    }
    
    func saveSettings() {
        if let encoded = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
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
    /// Parses Open-Meteo date/time strings to Date objects
    /// - Parameter isoString: Date/time string from Open-Meteo API (e.g., "2026-01-18T06:50")
    /// - Returns: Parsed Date object, or nil if parsing fails
    static func parse(_ isoString: String) -> Date? {
        // Primary: Open-Meteo's specific format "yyyy-MM-dd'T'HH:mm"
        let primaryFormatter = DateFormatter()
        primaryFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        
        if let date = primaryFormatter.date(from: isoString) {
            return date
        }
        
        // Fallback: Try ISO8601DateFormatter with various options
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var parsedDate = iso8601Formatter.date(from: isoString)
        
        if parsedDate == nil {
            iso8601Formatter.formatOptions = [.withInternetDateTime]
            parsedDate = iso8601Formatter.date(from: isoString)
        }
        
        if parsedDate == nil {
            iso8601Formatter.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime]
            parsedDate = iso8601Formatter.date(from: isoString)
        }
        
        if parsedDate == nil {
            print("⚠️ DateParser failed to parse: '\(isoString)'")
        }
        
        return parsedDate
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
            print("⚠️ FormatHelper.formatTime failed to parse: '\(isoString)'")
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
