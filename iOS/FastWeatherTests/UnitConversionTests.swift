//
//  UnitConversionTests.swift
//  FastWeatherTests
//
//  Tests for temperature, wind, precipitation, pressure unit conversions
//

import XCTest
@testable import FastWeather

final class UnitConversionTests: XCTestCase {
    
    // MARK: - Temperature Conversion Tests
    
    func testTemperatureConversionToFahrenheit() {
        let unit = TemperatureUnit.fahrenheit
        
        // Freezing point
        XCTAssertEqual(unit.convert(0), 32, accuracy: 0.01, "0°C should be 32°F")
        
        // Boiling point
        XCTAssertEqual(unit.convert(100), 212, accuracy: 0.01, "100°C should be 212°F")
        
        // Room temperature
        XCTAssertEqual(unit.convert(20), 68, accuracy: 0.01, "20°C should be 68°F")
        
        // Below freezing
        XCTAssertEqual(unit.convert(-40), -40, accuracy: 0.01, "-40°C should be -40°F")
    }
    
    func testTemperatureConversionToCelsius() {
        let unit = TemperatureUnit.celsius
        
        // Celsius to Celsius should be identity
        XCTAssertEqual(unit.convert(0), 0, accuracy: 0.01)
        XCTAssertEqual(unit.convert(100), 100, accuracy: 0.01)
        XCTAssertEqual(unit.convert(-273.15), -273.15, accuracy: 0.01) // Absolute zero
    }
    
    // MARK: - Wind Speed Conversion Tests
    
    func testWindSpeedConversionToMPH() {
        let unit = WindSpeedUnit.mph
        
        // 100 km/h to mph
        XCTAssertEqual(unit.convert(100), 62.1371, accuracy: 0.01)
        
        // 50 km/h to mph
        XCTAssertEqual(unit.convert(50), 31.0686, accuracy: 0.01)
        
        // Zero
        XCTAssertEqual(unit.convert(0), 0, accuracy: 0.01)
    }
    
    func testWindSpeedConversionToKMH() {
        let unit = WindSpeedUnit.kmh
        
        // km/h to km/h should be identity
        XCTAssertEqual(unit.convert(100), 100, accuracy: 0.01)
        XCTAssertEqual(unit.convert(0), 0, accuracy: 0.01)
    }
    
    // MARK: - Precipitation Conversion Tests
    
    func testPrecipitationConversionToInches() {
        let unit = PrecipitationUnit.inches
        
        // 25.4 mm = 1 inch (exactly)
        XCTAssertEqual(unit.convert(25.4), 1.0, accuracy: 0.01)
        
        // 50.8 mm = 2 inches
        XCTAssertEqual(unit.convert(50.8), 2.0, accuracy: 0.01)
        
        // Zero
        XCTAssertEqual(unit.convert(0), 0, accuracy: 0.01)
        
        // Small amount
        XCTAssertEqual(unit.convert(1), 0.0393701, accuracy: 0.0001)
    }
    
    func testPrecipitationConversionToMillimeters() {
        let unit = PrecipitationUnit.millimeters
        
        // mm to mm should be identity
        XCTAssertEqual(unit.convert(25.4), 25.4, accuracy: 0.01)
        XCTAssertEqual(unit.convert(0), 0, accuracy: 0.01)
    }
    
    // MARK: - Pressure Conversion Tests
    
    func testPressureConversionToInHg() {
        let unit = PressureUnit.inHg
        
        // Standard atmospheric pressure: 1013.25 hPa ≈ 29.92 inHg
        XCTAssertEqual(unit.convert(1013.25), 29.92, accuracy: 0.01)
        
        // Zero
        XCTAssertEqual(unit.convert(0), 0, accuracy: 0.01)
    }
    
    func testPressureConversionToMMHg() {
        let unit = PressureUnit.mmHg
        
        // Standard atmospheric pressure: 1013.25 hPa ≈ 760 mmHg
        XCTAssertEqual(unit.convert(1013.25), 760, accuracy: 1.0)
    }
    
    func testPressureConversionToHPa() {
        let unit = PressureUnit.hPa
        
        // hPa to hPa should be identity
        XCTAssertEqual(unit.convert(1013.25), 1013.25, accuracy: 0.01)
        XCTAssertEqual(unit.convert(0), 0, accuracy: 0.01)
    }
    
    // MARK: - Distance Conversion Tests
    
    func testDistanceConversionToMiles() {
        let unit = DistanceUnit.miles
        
        // 1.60934 km = 1 mile (exactly)
        XCTAssertEqual(unit.convert(1.60934), 1.0, accuracy: 0.01)
        
        // 100 km to miles
        XCTAssertEqual(unit.convert(100), 62.1371, accuracy: 0.01)
        
        // Zero
        XCTAssertEqual(unit.convert(0), 0, accuracy: 0.01)
    }
    
    func testDistanceConversionToKilometers() {
        let unit = DistanceUnit.kilometers
        
        // km to km should be identity
        XCTAssertEqual(unit.convert(100), 100, accuracy: 0.01)
        XCTAssertEqual(unit.convert(0), 0, accuracy: 0.01)
    }
    
    func testDistanceToKilometersConversion() {
        let milesUnit = DistanceUnit.miles
        let kmUnit = DistanceUnit.kilometers
        
        // 1 mile to km
        XCTAssertEqual(milesUnit.toKilometers(1), 1.60934, accuracy: 0.01)
        
        // 1 km to km (identity)
        XCTAssertEqual(kmUnit.toKilometers(1), 1.0, accuracy: 0.01)
    }
    
    // MARK: - Edge Cases
    
    func testNegativeValuesHandledCorrectly() {
        // Temperature can be negative
        let tempUnit = TemperatureUnit.fahrenheit
        XCTAssertEqual(tempUnit.convert(-10), 14, accuracy: 0.01, "-10°C should be 14°F")
        
        // Wind, precipitation, pressure should not be negative in practice,
        // but conversions should still work mathematically
        let windUnit = WindSpeedUnit.mph
        XCTAssertEqual(windUnit.convert(-10), -6.21371, accuracy: 0.01)
    }
    
    func testVeryLargeValuesHandledCorrectly() {
        let tempUnit = TemperatureUnit.fahrenheit
        XCTAssertEqual(tempUnit.convert(1000), 1832, accuracy: 0.01)
        
        let windUnit = WindSpeedUnit.mph
        XCTAssertEqual(windUnit.convert(500), 310.686, accuracy: 0.01)
    }
}
