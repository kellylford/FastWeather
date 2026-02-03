//
//  FormatHelperTests.swift
//  FastWeatherTests
//
//  Unit tests for FormatHelper utility
//

import XCTest
@testable import FastWeather

final class FormatHelperTests: XCTestCase {
    
    // MARK: - formatTime Tests
    
    func testFormatTimeMorning() {
        // 6:50 AM
        let timestamp = "2026-01-18T06:50"
        let result = FormatHelper.formatTime(timestamp)
        
        XCTAssertEqual(result, "6:50 AM", "Should format morning time correctly")
    }
    
    func testFormatTimeAfternoon() {
        // 2:30 PM (14:30)
        let timestamp = "2026-01-18T14:30"
        let result = FormatHelper.formatTime(timestamp)
        
        XCTAssertEqual(result, "2:30 PM", "Should format afternoon time correctly")
    }
    
    func testFormatTimeMidnight() {
        // 12:00 AM (00:00)
        let timestamp = "2026-01-18T00:00"
        let result = FormatHelper.formatTime(timestamp)
        
        XCTAssertEqual(result, "12:00 AM", "Should format midnight correctly")
    }
    
    func testFormatTimeNoon() {
        // 12:00 PM
        let timestamp = "2026-01-18T12:00"
        let result = FormatHelper.formatTime(timestamp)
        
        XCTAssertEqual(result, "12:00 PM", "Should format noon correctly")
    }
    
    func testFormatTimeOneMinutePastMidnight() {
        // 12:01 AM (00:01)
        let timestamp = "2026-01-18T00:01"
        let result = FormatHelper.formatTime(timestamp)
        
        XCTAssertEqual(result, "12:01 AM", "Should format 12:01 AM correctly")
    }
    
    func testFormatTimeOneMinutePastNoon() {
        // 12:01 PM
        let timestamp = "2026-01-18T12:01"
        let result = FormatHelper.formatTime(timestamp)
        
        XCTAssertEqual(result, "12:01 PM", "Should format 12:01 PM correctly")
    }
    
    func testFormatTimeEvening() {
        // 9:45 PM (21:45)
        let timestamp = "2026-01-18T21:45"
        let result = FormatHelper.formatTime(timestamp)
        
        XCTAssertEqual(result, "9:45 PM", "Should format evening time correctly")
    }
    
    // MARK: - formatTimeCompact Tests
    
    func testFormatTimeCompactWithZeroMinutes() {
        // 3:00 PM should display as "3 PM"
        let timestamp = "2026-01-18T15:00"
        let result = FormatHelper.formatTimeCompact(timestamp)
        
        XCTAssertEqual(result, "3 PM", "Should omit :00 in compact format")
    }
    
    func testFormatTimeCompactWithNonZeroMinutes() {
        // 3:30 PM should stay "3:30 PM"
        let timestamp = "2026-01-18T15:30"
        let result = FormatHelper.formatTimeCompact(timestamp)
        
        XCTAssertEqual(result, "3:30 PM", "Should keep minutes when non-zero")
    }
    
    func testFormatTimeCompactMidnight() {
        // 12:00 AM should display as "12 AM"
        let timestamp = "2026-01-18T00:00"
        let result = FormatHelper.formatTimeCompact(timestamp)
        
        XCTAssertEqual(result, "12 AM", "Should format midnight compactly")
    }
    
    func testFormatTimeCompactNoon() {
        // 12:00 PM should display as "12 PM"
        let timestamp = "2026-01-18T12:00"
        let result = FormatHelper.formatTimeCompact(timestamp)
        
        XCTAssertEqual(result, "12 PM", "Should format noon compactly")
    }
    
    func testFormatTimeCompactMorningWithMinutes() {
        // 6:50 AM should stay "6:50 AM"
        let timestamp = "2026-01-18T06:50"
        let result = FormatHelper.formatTimeCompact(timestamp)
        
        XCTAssertEqual(result, "6:50 AM", "Should keep minutes in morning time")
    }
    
    // MARK: - Invalid Input Tests
    
    func testFormatTimeWithInvalidTimestamp() {
        let invalid = "not-a-timestamp"
        let result = FormatHelper.formatTime(invalid)
        
        // Should return original string when parsing fails
        XCTAssertEqual(result, invalid, "Should return original string on parse failure")
    }
    
    func testFormatTimeCompactWithInvalidTimestamp() {
        let invalid = "invalid-date"
        let result = FormatHelper.formatTimeCompact(invalid)
        
        // Should return original string when parsing fails
        XCTAssertEqual(result, invalid, "Should return original string on parse failure")
    }
    
    func testFormatTimeWithEmptyString() {
        let result = FormatHelper.formatTime("")
        XCTAssertEqual(result, "", "Should handle empty string gracefully")
    }
    
    // MARK: - Edge Cases
    
    func testFormatTimeAllHours() {
        // Test all 24 hours to ensure consistent formatting
        for hour in 0..<24 {
            let timestamp = String(format: "2026-01-18T%02d:30", hour)
            let result = FormatHelper.formatTime(timestamp)
            
            XCTAssertFalse(result.isEmpty, "Should format hour \(hour)")
            XCTAssertTrue(result.contains("AM") || result.contains("PM"), "Should include AM/PM for hour \(hour)")
        }
    }
    
    func testFormatTimeCompactAllHoursBoundaries() {
        // Test :00 omission for all hours
        for hour in 0..<24 {
            let timestamp = String(format: "2026-01-18T%02d:00", hour)
            let result = FormatHelper.formatTimeCompact(timestamp)
            
            XCTAssertFalse(result.contains(":00"), "Should omit :00 for hour \(hour)")
        }
    }
    
    // MARK: - Consistency Tests
    
    func testFormatTimeConsistency() {
        // Formatting the same timestamp multiple times should return the same result
        let timestamp = "2026-01-18T14:30"
        
        let result1 = FormatHelper.formatTime(timestamp)
        let result2 = FormatHelper.formatTime(timestamp)
        
        XCTAssertEqual(result1, result2, "Multiple formats should be consistent")
    }
    
    func testFormatTimeCompactConsistency() {
        let timestamp = "2026-01-18T15:00"
        
        let result1 = FormatHelper.formatTimeCompact(timestamp)
        let result2 = FormatHelper.formatTimeCompact(timestamp)
        
        XCTAssertEqual(result1, result2, "Multiple compact formats should be consistent")
    }
    
    // MARK: - Performance Tests
    
    func testFormatTimePerformance() {
        let timestamp = "2026-01-18T14:30"
        
        measure {
            for _ in 0..<1000 {
                _ = FormatHelper.formatTime(timestamp)
            }
        }
    }
    
    func testFormatTimeCompactPerformance() {
        let timestamp = "2026-01-18T15:00"
        
        measure {
            for _ in 0..<1000 {
                _ = FormatHelper.formatTimeCompact(timestamp)
            }
        }
    }
}
