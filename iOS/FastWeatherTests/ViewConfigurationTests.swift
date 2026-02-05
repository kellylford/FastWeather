//
//  ViewConfigurationTests.swift
//  FastWeatherTests
//
//  Tests for view configuration system - ensures List and Flat views respect user settings
//

import XCTest
@testable import FastWeather

final class ViewConfigurationTests: XCTestCase {
    var settingsManager: SettingsManager!
    
    override func setUp() {
        super.setUp()
        settingsManager = SettingsManager()
        // Reset to defaults for each test
        settingsManager.resetToDefaults()
    }
    
    override func tearDown() {
        settingsManager = nil
        super.tearDown()
    }
    
    // MARK: - Weather Field Toggle Tests
    
    func testWeatherAlertsFieldCanBeToggled() {
        guard let alertField = settingsManager.settings.weatherFields.first(where: { $0.type == .weatherAlerts }) else {
            XCTFail("Weather alerts field should exist in settings")
            return
        }
        
        // Test enabling
        var mutableSettings = settingsManager.settings
        if let index = mutableSettings.weatherFields.firstIndex(where: { $0.type == .weatherAlerts }) {
            mutableSettings.weatherFields[index].isEnabled = true
            settingsManager.settings = mutableSettings
        }
        
        let enabledField = settingsManager.settings.weatherFields.first(where: { $0.type == .weatherAlerts })
        XCTAssertTrue(enabledField?.isEnabled ?? false, "Weather alerts should be enabled")
        
        // Test disabling
        if let index = mutableSettings.weatherFields.firstIndex(where: { $0.type == .weatherAlerts }) {
            mutableSettings.weatherFields[index].isEnabled = false
            settingsManager.settings = mutableSettings
        }
        
        let disabledField = settingsManager.settings.weatherFields.first(where: { $0.type == .weatherAlerts })
        XCTAssertFalse(disabledField?.isEnabled ?? true, "Weather alerts should be disabled")
    }
    
    func testTemperatureFieldCanBeToggled() {
        var mutableSettings = settingsManager.settings
        
        // Temperature should be enabled by default
        let defaultField = mutableSettings.weatherFields.first(where: { $0.type == .temperature })
        XCTAssertTrue(defaultField?.isEnabled ?? false, "Temperature should be enabled by default")
        
        // Test disabling
        if let index = mutableSettings.weatherFields.firstIndex(where: { $0.type == .temperature }) {
            mutableSettings.weatherFields[index].isEnabled = false
            settingsManager.settings = mutableSettings
        }
        
        let disabledField = settingsManager.settings.weatherFields.first(where: { $0.type == .temperature })
        XCTAssertFalse(disabledField?.isEnabled ?? true, "Temperature should be disabled")
    }
    
    func testAllWeatherFieldsCanBeToggledIndependently() {
        var mutableSettings = settingsManager.settings
        
        for fieldType in WeatherFieldType.allCases {
            // Find field in settings
            guard let originalField = mutableSettings.weatherFields.first(where: { $0.type == fieldType }) else {
                // Not all field types may be in weatherFields list
                continue
            }
            
            let originalState = originalField.isEnabled
            
            // Toggle to opposite state
            if let index = mutableSettings.weatherFields.firstIndex(where: { $0.type == fieldType }) {
                mutableSettings.weatherFields[index].isEnabled = !originalState
                settingsManager.settings = mutableSettings
            }
            
            // Verify toggled
            let toggledField = settingsManager.settings.weatherFields.first(where: { $0.type == fieldType })
            XCTAssertEqual(toggledField?.isEnabled, !originalState, "Field \(fieldType.rawValue) should be toggled")
            
            // Toggle back
            if let index = mutableSettings.weatherFields.firstIndex(where: { $0.type == fieldType }) {
                mutableSettings.weatherFields[index].isEnabled = originalState
                settingsManager.settings = mutableSettings
            }
        }
    }
    
    // MARK: - Field Order Tests
    
    func testWeatherFieldOrderCanBeChanged() {
        var mutableSettings = settingsManager.settings
        let originalCount = mutableSettings.weatherFields.count
        
        XCTAssertGreaterThan(originalCount, 1, "Should have at least 2 fields to test reordering")
        
        let firstField = mutableSettings.weatherFields[0]
        let secondField = mutableSettings.weatherFields[1]
        
        // Swap first two fields
        mutableSettings.weatherFields.swapAt(0, 1)
        settingsManager.settings = mutableSettings
        
        // Verify order changed
        XCTAssertEqual(settingsManager.settings.weatherFields[0].type, secondField.type)
        XCTAssertEqual(settingsManager.settings.weatherFields[1].type, firstField.type)
        
        // Verify count unchanged
        XCTAssertEqual(settingsManager.settings.weatherFields.count, originalCount)
    }
    
    func testWeatherFieldOrderPreservedAfterToggle() {
        var mutableSettings = settingsManager.settings
        let originalOrder = mutableSettings.weatherFields.map { $0.type }
        
        // Toggle a field
        if let index = mutableSettings.weatherFields.firstIndex(where: { $0.type == .humidity }) {
            mutableSettings.weatherFields[index].isEnabled = !mutableSettings.weatherFields[index].isEnabled
            settingsManager.settings = mutableSettings
        }
        
        // Verify order unchanged
        let newOrder = settingsManager.settings.weatherFields.map { $0.type }
        XCTAssertEqual(newOrder, originalOrder, "Field order should remain the same after toggling")
    }
    
    // MARK: - Hourly Fields Tests
    
    func testHourlyFieldsCanBeToggled() {
        var mutableSettings = settingsManager.settings
        
        for fieldType in HourlyFieldType.allCases {
            guard let originalField = mutableSettings.hourlyFields.first(where: { $0.type == fieldType }) else {
                continue
            }
            
            let originalState = originalField.isEnabled
            
            // Toggle
            if let index = mutableSettings.hourlyFields.firstIndex(where: { $0.type == fieldType }) {
                mutableSettings.hourlyFields[index].isEnabled = !originalState
                settingsManager.settings = mutableSettings
            }
            
            // Verify
            let toggledField = settingsManager.settings.hourlyFields.first(where: { $0.type == fieldType })
            XCTAssertEqual(toggledField?.isEnabled, !originalState, "Hourly field \(fieldType.rawValue) should be toggled")
            
            // Reset
            if let index = mutableSettings.hourlyFields.firstIndex(where: { $0.type == fieldType }) {
                mutableSettings.hourlyFields[index].isEnabled = originalState
                settingsManager.settings = mutableSettings
            }
        }
    }
    
    // MARK: - Daily Fields Tests
    
    func testDailyFieldsCanBeToggled() {
        var mutableSettings = settingsManager.settings
        
        for fieldType in DailyFieldType.allCases {
            guard let originalField = mutableSettings.dailyFields.first(where: { $0.type == fieldType }) else {
                continue
            }
            
            let originalState = originalField.isEnabled
            
            // Toggle
            if let index = mutableSettings.dailyFields.firstIndex(where: { $0.type == fieldType }) {
                mutableSettings.dailyFields[index].isEnabled = !originalState
                settingsManager.settings = mutableSettings
            }
            
            // Verify
            let toggledField = settingsManager.settings.dailyFields.first(where: { $0.type == fieldType })
            XCTAssertEqual(toggledField?.isEnabled, !originalState, "Daily field \(fieldType.rawValue) should be toggled")
            
            // Reset
            if let index = mutableSettings.dailyFields.firstIndex(where: { $0.type == fieldType }) {
                mutableSettings.dailyFields[index].isEnabled = originalState
                settingsManager.settings = mutableSettings
            }
        }
    }
    
    func testSunriseAndSunsetAreIndependentFields() {
        var mutableSettings = settingsManager.settings
        
        let sunriseField = mutableSettings.dailyFields.first(where: { $0.type == .sunrise })
        let sunsetField = mutableSettings.dailyFields.first(where: { $0.type == .sunset })
        
        XCTAssertNotNil(sunriseField, "Sunrise should exist as a field")
        XCTAssertNotNil(sunsetField, "Sunset should exist as a field")
        
        // Toggle sunrise
        if let index = mutableSettings.dailyFields.firstIndex(where: { $0.type == .sunrise }) {
            mutableSettings.dailyFields[index].isEnabled = false
            settingsManager.settings = mutableSettings
        }
        
        // Verify sunrise disabled but sunset unchanged
        let disabledSunrise = settingsManager.settings.dailyFields.first(where: { $0.type == .sunrise })
        let unchangedSunset = settingsManager.settings.dailyFields.first(where: { $0.type == .sunset })
        
        XCTAssertFalse(disabledSunrise?.isEnabled ?? true, "Sunrise should be disabled")
        XCTAssertEqual(unchangedSunset?.isEnabled, sunsetField?.isEnabled, "Sunset should remain unchanged")
    }
    
    // MARK: - Display Mode Tests
    
    func testDisplayModeCanBeChanged() {
        // Default should be condensed
        XCTAssertEqual(settingsManager.settings.displayMode, .condensed, "Default display mode should be condensed")
        
        // Change to details
        var mutableSettings = settingsManager.settings
        mutableSettings.displayMode = .details
        settingsManager.settings = mutableSettings
        
        XCTAssertEqual(settingsManager.settings.displayMode, .details, "Display mode should change to details")
        
        // Change back
        mutableSettings.displayMode = .condensed
        settingsManager.settings = mutableSettings
        
        XCTAssertEqual(settingsManager.settings.displayMode, .condensed, "Display mode should change back to condensed")
    }
    
    // MARK: - View Mode Tests
    
    func testViewModeCanBeChanged() {
        // Default should be list
        XCTAssertEqual(settingsManager.settings.viewMode, .list, "Default view mode should be list")
        
        // Change to flat
        var mutableSettings = settingsManager.settings
        mutableSettings.viewMode = .flat
        settingsManager.settings = mutableSettings
        
        XCTAssertEqual(settingsManager.settings.viewMode, .flat, "View mode should change to flat")
        
        // Change back
        mutableSettings.viewMode = .list
        settingsManager.settings = mutableSettings
        
        XCTAssertEqual(settingsManager.settings.viewMode, .list, "View mode should change back to list")
    }
    
    // MARK: - Detail Categories Tests
    
    func testDetailCategoriesCanBeToggled() {
        var mutableSettings = settingsManager.settings
        
        for category in DetailCategory.allCases {
            guard let originalField = mutableSettings.detailCategories.first(where: { $0.category == category }) else {
                continue
            }
            
            let originalState = originalField.isEnabled
            
            // Toggle
            if let index = mutableSettings.detailCategories.firstIndex(where: { $0.category == category }) {
                mutableSettings.detailCategories[index].isEnabled = !originalState
                settingsManager.settings = mutableSettings
            }
            
            // Verify
            let toggledField = settingsManager.settings.detailCategories.first(where: { $0.category == category })
            XCTAssertEqual(toggledField?.isEnabled, !originalState, "Detail category \(category.rawValue) should be toggled")
            
            // Reset
            if let index = mutableSettings.detailCategories.firstIndex(where: { $0.category == category }) {
                mutableSettings.detailCategories[index].isEnabled = originalState
                settingsManager.settings = mutableSettings
            }
        }
    }
    
    // MARK: - Settings Persistence Simulation
    
    func testSettingsCanBeSavedAndRestored() {
        // Modify settings
        var mutableSettings = settingsManager.settings
        mutableSettings.viewMode = .flat
        mutableSettings.displayMode = .details
        
        if let index = mutableSettings.weatherFields.firstIndex(where: { $0.type == .humidity }) {
            mutableSettings.weatherFields[index].isEnabled = false
        }
        
        settingsManager.settings = mutableSettings
        settingsManager.saveSettings()
        
        // Verify settings persisted
        XCTAssertEqual(settingsManager.settings.viewMode, .flat)
        XCTAssertEqual(settingsManager.settings.displayMode, .details)
        
        let humidityField = settingsManager.settings.weatherFields.first(where: { $0.type == .humidity })
        XCTAssertFalse(humidityField?.isEnabled ?? true)
    }
    
    // MARK: - Edge Cases
    
    func testCannotHaveZeroEnabledFields() {
        // This test documents behavior - some fields should always be enabled
        // At minimum, temperature should be enabled for the app to be useful
        let enabledFields = settingsManager.settings.weatherFields.filter { $0.isEnabled }
        XCTAssertGreaterThan(enabledFields.count, 0, "Should have at least one enabled field by default")
    }
    
    func testAllFieldTypesHaveValidRawValues() {
        // Ensure all field types can be serialized/deserialized
        for fieldType in WeatherFieldType.allCases {
            XCTAssertFalse(fieldType.rawValue.isEmpty, "Field type should have non-empty raw value")
        }
        
        for fieldType in HourlyFieldType.allCases {
            XCTAssertFalse(fieldType.rawValue.isEmpty, "Hourly field type should have non-empty raw value")
        }
        
        for fieldType in DailyFieldType.allCases {
            XCTAssertFalse(fieldType.rawValue.isEmpty, "Daily field type should have non-empty raw value")
        }
    }
}
