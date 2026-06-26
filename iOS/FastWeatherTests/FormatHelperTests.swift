//
//  FormatHelperTests.swift
//  FastWeatherTests
//
//  Unit tests for FormatHelper utility
//

import XCTest
@testable import WeatherFast

final class FormatHelperTests: XCTestCase {

    // Pin the formatting locale so these assertions are deterministic regardless of the
    // machine's region. Production passes Locale.current.
    private let enUS = Locale(identifier: "en_US")

    // MARK: - formatTime Tests
    
    func testFormatTimeMorning() {
        // 6:50 AM
        let timestamp = "2026-01-18T06:50"
        let result = FormatHelper.formatTime(timestamp, locale: enUS)
        
        XCTAssertEqual(result, "6:50 AM", "Should format morning time correctly")
    }
    
    func testFormatTimeAfternoon() {
        // 2:30 PM (14:30)
        let timestamp = "2026-01-18T14:30"
        let result = FormatHelper.formatTime(timestamp, locale: enUS)
        
        XCTAssertEqual(result, "2:30 PM", "Should format afternoon time correctly")
    }
    
    func testFormatTimeMidnight() {
        // 12:00 AM (00:00)
        let timestamp = "2026-01-18T00:00"
        let result = FormatHelper.formatTime(timestamp, locale: enUS)
        
        XCTAssertEqual(result, "12:00 AM", "Should format midnight correctly")
    }
    
    func testFormatTimeNoon() {
        // 12:00 PM
        let timestamp = "2026-01-18T12:00"
        let result = FormatHelper.formatTime(timestamp, locale: enUS)
        
        XCTAssertEqual(result, "12:00 PM", "Should format noon correctly")
    }
    
    func testFormatTimeOneMinutePastMidnight() {
        // 12:01 AM (00:01)
        let timestamp = "2026-01-18T00:01"
        let result = FormatHelper.formatTime(timestamp, locale: enUS)
        
        XCTAssertEqual(result, "12:01 AM", "Should format 12:01 AM correctly")
    }
    
    func testFormatTimeOneMinutePastNoon() {
        // 12:01 PM
        let timestamp = "2026-01-18T12:01"
        let result = FormatHelper.formatTime(timestamp, locale: enUS)
        
        XCTAssertEqual(result, "12:01 PM", "Should format 12:01 PM correctly")
    }
    
    func testFormatTimeEvening() {
        // 9:45 PM (21:45)
        let timestamp = "2026-01-18T21:45"
        let result = FormatHelper.formatTime(timestamp, locale: enUS)
        
        XCTAssertEqual(result, "9:45 PM", "Should format evening time correctly")
    }
    
    // MARK: - formatTimeCompact Tests
    
    func testFormatTimeCompactWithZeroMinutes() {
        // 3:00 PM should display as "3 PM"
        let timestamp = "2026-01-18T15:00"
        let result = FormatHelper.formatTimeCompact(timestamp, locale: enUS)
        
        XCTAssertEqual(result, "3 PM", "Should omit :00 in compact format")
    }
    
    func testFormatTimeCompactWithNonZeroMinutes() {
        // 3:30 PM should stay "3:30 PM"
        let timestamp = "2026-01-18T15:30"
        let result = FormatHelper.formatTimeCompact(timestamp, locale: enUS)
        
        XCTAssertEqual(result, "3:30 PM", "Should keep minutes when non-zero")
    }
    
    func testFormatTimeCompactMidnight() {
        // 12:00 AM should display as "12 AM"
        let timestamp = "2026-01-18T00:00"
        let result = FormatHelper.formatTimeCompact(timestamp, locale: enUS)
        
        XCTAssertEqual(result, "12 AM", "Should format midnight compactly")
    }
    
    func testFormatTimeCompactNoon() {
        // 12:00 PM should display as "12 PM"
        let timestamp = "2026-01-18T12:00"
        let result = FormatHelper.formatTimeCompact(timestamp, locale: enUS)
        
        XCTAssertEqual(result, "12 PM", "Should format noon compactly")
    }
    
    func testFormatTimeCompactMorningWithMinutes() {
        // 6:50 AM should stay "6:50 AM"
        let timestamp = "2026-01-18T06:50"
        let result = FormatHelper.formatTimeCompact(timestamp, locale: enUS)
        
        XCTAssertEqual(result, "6:50 AM", "Should keep minutes in morning time")
    }
    
    // MARK: - Invalid Input Tests
    
    func testFormatTimeWithInvalidTimestamp() {
        let invalid = "not-a-timestamp"
        let result = FormatHelper.formatTime(invalid, locale: enUS)
        
        // Should return original string when parsing fails
        XCTAssertEqual(result, invalid, "Should return original string on parse failure")
    }
    
    func testFormatTimeCompactWithInvalidTimestamp() {
        let invalid = "invalid-date"
        let result = FormatHelper.formatTimeCompact(invalid, locale: enUS)
        
        // Should return original string when parsing fails
        XCTAssertEqual(result, invalid, "Should return original string on parse failure")
    }
    
    func testFormatTimeWithEmptyString() {
        let result = FormatHelper.formatTime("", locale: enUS)
        XCTAssertEqual(result, "", "Should handle empty string gracefully")
    }
    
    // MARK: - Edge Cases
    
    func testFormatTimeAllHours() {
        // Test all 24 hours to ensure consistent formatting
        for hour in 0..<24 {
            let timestamp = String(format: "2026-01-18T%02d:30", hour)
            let result = FormatHelper.formatTime(timestamp, locale: enUS)
            
            XCTAssertFalse(result.isEmpty, "Should format hour \(hour)")
            XCTAssertTrue(result.contains("AM") || result.contains("PM"), "Should include AM/PM for hour \(hour)")
        }
    }
    
    func testFormatTimeCompactAllHoursBoundaries() {
        // Test :00 omission for all hours
        for hour in 0..<24 {
            let timestamp = String(format: "2026-01-18T%02d:00", hour)
            let result = FormatHelper.formatTimeCompact(timestamp, locale: enUS)
            
            XCTAssertFalse(result.contains(":00"), "Should omit :00 for hour \(hour)")
        }
    }
    
    // MARK: - Consistency Tests
    
    func testFormatTimeConsistency() {
        // Formatting the same timestamp multiple times should return the same result
        let timestamp = "2026-01-18T14:30"
        
        let result1 = FormatHelper.formatTime(timestamp, locale: enUS)
        let result2 = FormatHelper.formatTime(timestamp, locale: enUS)
        
        XCTAssertEqual(result1, result2, "Multiple formats should be consistent")
    }
    
    func testFormatTimeCompactConsistency() {
        let timestamp = "2026-01-18T15:00"
        
        let result1 = FormatHelper.formatTimeCompact(timestamp, locale: enUS)
        let result2 = FormatHelper.formatTimeCompact(timestamp, locale: enUS)
        
        XCTAssertEqual(result1, result2, "Multiple compact formats should be consistent")
    }
    
    // MARK: - Locale Awareness Tests

    func testFormatTimeGermanUses24Hour() {
        // 2:30 PM in a 24-hour locale is "14:30" with no AM/PM marker.
        let de = Locale(identifier: "de_DE")
        let result = FormatHelper.formatTime("2026-01-18T14:30", locale: de)

        XCTAssertEqual(result, "14:30", "German locale should use 24-hour time")
        XCTAssertFalse(result.contains("PM"), "German locale should not include AM/PM")
        XCTAssertFalse(result.contains("AM"), "German locale should not include AM/PM")
    }

    func testFormatTimeGermanMorning() {
        let de = Locale(identifier: "de_DE")
        let result = FormatHelper.formatTime("2026-01-18T06:50", locale: de)

        XCTAssertEqual(result, "06:50", "German locale should zero-pad the 24-hour value")
    }

    func testFormatTimeDiffersByLocale() {
        // The same instant should format differently in a 12h vs 24h locale.
        let de = Locale(identifier: "de_DE")
        let enResult = FormatHelper.formatTime("2026-01-18T21:45", locale: enUS)
        let deResult = FormatHelper.formatTime("2026-01-18T21:45", locale: de)

        XCTAssertEqual(enResult, "9:45 PM")
        XCTAssertEqual(deResult, "21:45")
        XCTAssertNotEqual(enResult, deResult, "Output should be locale-dependent")
    }

    // MARK: - Performance Tests
    
    func testFormatTimePerformance() {
        let timestamp = "2026-01-18T14:30"
        
        measure {
            for _ in 0..<1000 {
                _ = FormatHelper.formatTime(timestamp, locale: enUS)
            }
        }
    }
    
    func testFormatTimeCompactPerformance() {
        let timestamp = "2026-01-18T15:00"
        
        measure {
            for _ in 0..<1000 {
                _ = FormatHelper.formatTimeCompact(timestamp, locale: enUS)
            }
        }
    }
}
