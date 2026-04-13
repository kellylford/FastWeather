//
//  ServicePersistenceTests.swift
//  FastWeatherTests
//
//  Regression tests for critical service paths: persistence, data integrity,
//  and cache behaviour. These guard against silent data loss bugs like
//  swallowed try? errors or unbounded cache growth.
//

import XCTest
@testable import WeatherFast

// MARK: - WeatherService Persistence Tests

final class WeatherServicePersistenceTests: XCTestCase {

    private let citiesKey = "SavedCities"

    override func setUp() {
        super.setUp()
        // Clean slate for each test
        UserDefaults.standard.removeObject(forKey: citiesKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: citiesKey)
        super.tearDown()
    }

    // Corrupted bytes in UserDefaults should not crash the app; service falls
    // back to default cities and the in-memory list is non-empty.
    func testCorruptedCityDataDoesNotCrashApp() async {
        UserDefaults.standard.set(Data("not valid json".utf8), forKey: citiesKey)

        let service = await MainActor.run { WeatherService() }
        let count = await MainActor.run { service.savedCities.count }

        XCTAssertGreaterThan(count, 0, "App should seed default cities when stored data is corrupt")
    }

    // Entirely missing key => first-launch path should also yield default cities.
    func testMissingCityKeyYieldsDefaultCities() async {
        let service = await MainActor.run { WeatherService() }
        let count = await MainActor.run { service.savedCities.count }

        XCTAssertGreaterThan(count, 0, "First-launch initialisation should seed default cities")
    }
}

// MARK: - SettingsManager Persistence Tests

final class SettingsManagerPersistenceTests: XCTestCase {

    private let settingsKey = "AppSettings"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: settingsKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: settingsKey)
        super.tearDown()
    }

    // Storing garbage bytes should not cause a crash; app falls back to defaults.
    func testCorruptedSettingsDataDoesNotCrashApp() throws {
        UserDefaults.standard.set(Data("not valid json".utf8), forKey: settingsKey)

        let manager = SettingsManager()

        // Default temperature unit is celsius; just verify we got something back.
        XCTAssertNotNil(manager.settings, "SettingsManager should recover from corrupt data")
    }

    // Round-trip: save then reload should preserve the setting value.
    func testSettingsRoundTrip() throws {
        let manager = SettingsManager()
        manager.settings.temperatureUnit = .fahrenheit
        manager.saveSettings()

        let reloaded = SettingsManager()
        XCTAssertEqual(reloaded.settings.temperatureUnit, .fahrenheit,
                       "Temperature unit should survive a settings round-trip")
    }
}

// MARK: - BrowseFavoritesService Persistence Tests

final class BrowseFavoritesServicePersistenceTests: XCTestCase {

    private let favoritesKey = "BrowseFavorites"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: favoritesKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: favoritesKey)
        super.tearDown()
    }

    func testCorruptedFavoritesDataDoesNotCrashApp() async {
        UserDefaults.standard.set(Data("not valid json".utf8), forKey: favoritesKey)

        let service = await MainActor.run { BrowseFavoritesService() }
        let count = await MainActor.run { service.favorites.count }

        // Should start with an empty list, not crash.
        XCTAssertEqual(count, 0,
                       "Service should start with empty favorites when stored data is corrupt")
    }

    func testFavoritesRoundTrip() async {
        let service = await MainActor.run { BrowseFavoritesService() }
        await MainActor.run { service.add(name: "Wisconsin", regionType: .us, sortOrder: .nameAZ) }

        let reloaded = await MainActor.run { BrowseFavoritesService() }
        let count = await MainActor.run { reloaded.favorites.count }
        let name = await MainActor.run { reloaded.favorites.first?.name }

        XCTAssertEqual(count, 1, "Favourite should persist across service instances")
        XCTAssertEqual(name, "Wisconsin")
    }
}

// MARK: - BrowseSortOrder Model Tests

final class BrowseSortOrderModelTests: XCTestCase {

    // BrowseSortOrder lives in the Models layer — confirm it can be encoded/decoded
    // without importing any View type.
    func testBrowseSortOrderEncodingRoundTrip() throws {
        let original = BrowseSortOrder.northSouth

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BrowseSortOrder.self, from: data)

        XCTAssertEqual(decoded, original,
                       "BrowseSortOrder should survive JSON encode/decode round-trip")
    }

    func testAllCasesHaveValidSystemImages() {
        for order in BrowseSortOrder.allCases {
            XCTAssertFalse(order.systemImage.isEmpty,
                           "\(order.rawValue) should have a non-empty system image name")
        }
    }
}
