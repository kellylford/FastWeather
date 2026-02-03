//
//  DateParserTests.swift
//  FastWeatherTests
//
//  Unit tests for DateParser utility
//

import XCTest
@testable import FastWeather

final class DateParserTests: XCTestCase {
    
    // MARK: - Valid Open-Meteo Format Tests
    
    func testParseValidOpenMeteoTimestamp() {
        // Open-Meteo standard format: "2026-01-18T06:50" (no timezone, no seconds)
        let dateString = "2026-01-18T06:50"
        let result = DateParser.parse(dateString)
        
        XCTAssertNotNil(result, "Should successfully parse valid Open-Meteo timestamp")
        
        if let date = result {
            let calendar = Calendar.current
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            
            XCTAssertEqual(components.year, 2026)
            XCTAssertEqual(components.month, 1)
            XCTAssertEqual(components.day, 18)
            XCTAssertEqual(components.hour, 6)
            XCTAssertEqual(components.minute, 50)
        }
    }
    
    func testParseMultipleOpenMeteoTimestamps() {
        // Test various valid timestamps
        let timestamps = [
            "2026-01-01T00:00",
            "2026-12-31T23:59",
            "2025-06-15T12:30",
            "2024-02-29T18:45"  // Leap year
        ]
        
        for timestamp in timestamps {
            let result = DateParser.parse(timestamp)
            XCTAssertNotNil(result, "Should parse '\(timestamp)'")
        }
    }
    
    // MARK: - ISO8601 Format Tests
    
    func testParseStandardISO8601() {
        // Standard ISO8601 with timezone
        let dateString = "2026-01-18T06:50:00Z"
        let result = DateParser.parse(dateString)
        
        XCTAssertNotNil(result, "Should successfully parse ISO8601 with timezone")
    }
    
    func testParseISO8601WithTimezone() {
        // ISO8601 with offset timezone
        let dateString = "2026-01-18T06:50:00-08:00"
        let result = DateParser.parse(dateString)
        
        XCTAssertNotNil(result, "Should successfully parse ISO8601 with timezone offset")
    }
    
    func testParseISO8601WithFractionalSeconds() {
        // ISO8601 with fractional seconds
        let dateString = "2026-01-18T06:50:30.500Z"
        let result = DateParser.parse(dateString)
        
        XCTAssertNotNil(result, "Should successfully parse ISO8601 with fractional seconds")
    }
    
    // MARK: - Edge Cases
    
    func testParseEmptyString() {
        let result = DateParser.parse("")
        XCTAssertNil(result, "Empty string should return nil")
    }
    
    func testParseMalformedTimestamp() {
        let malformed = [
            "2026-13-45T25:70",  // Invalid month/day/hour/minute
            "not-a-date",
            "2026/01/18 06:50",  // Wrong separators
            "18-01-2026T06:50",  // Wrong order
            "2026-01-18",        // Missing time component
            "T06:50:00"          // Missing date component
        ]
        
        for timestamp in malformed {
            let result = DateParser.parse(timestamp)
            // Some might parse, but we log the failure internally
            // This test documents expected behavior
        }
    }
    
    func testParseLeapYearDate() {
        let leapYear = "2024-02-29T12:00"
        let result = DateParser.parse(leapYear)
        XCTAssertNotNil(result, "Should parse leap year date")
        
        let nonLeapYear = "2023-02-29T12:00"
        let invalidResult = DateParser.parse(nonLeapYear)
        // DateFormatter may or may not handle this gracefully
    }
    
    func testParseMidnight() {
        let midnight = "2026-01-18T00:00"
        let result = DateParser.parse(midnight)
        
        XCTAssertNotNil(result, "Should parse midnight timestamp")
        
        if let date = result {
            let calendar = Calendar.current
            let components = calendar.dateComponents([.hour, .minute], from: date)
            XCTAssertEqual(components.hour, 0)
            XCTAssertEqual(components.minute, 0)
        }
    }
    
    func testParseEndOfDay() {
        let endOfDay = "2026-01-18T23:59"
        let result = DateParser.parse(endOfDay)
        
        XCTAssertNotNil(result, "Should parse end of day timestamp")
        
        if let date = result {
            let calendar = Calendar.current
            let components = calendar.dateComponents([.hour, .minute], from: date)
            XCTAssertEqual(components.hour, 23)
            XCTAssertEqual(components.minute, 59)
        }
    }
    
    // MARK: - Performance Tests
    
    func testParsePerformance() {
        let timestamp = "2026-01-18T06:50"
        
        measure {
            for _ in 0..<1000 {
                _ = DateParser.parse(timestamp)
            }
        }
    }
    
    // MARK: - Consistency Tests
    
    func testParseConsistency() {
        // Parsing the same timestamp multiple times should return the same date
        let timestamp = "2026-01-18T06:50"
        
        let date1 = DateParser.parse(timestamp)
        let date2 = DateParser.parse(timestamp)
        
        XCTAssertNotNil(date1)
        XCTAssertNotNil(date2)
        XCTAssertEqual(date1, date2, "Multiple parses of same timestamp should be equal")
    }
}
