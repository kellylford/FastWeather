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

// MARK: - AppSettings Version Encoding Tests (CR-1)

final class AppSettingsVersionTests: XCTestCase {

    // The version gate in SettingsManager reads settingsVersion from the stored JSON.
    // It is only meaningful if encode(to:) actually writes the key — regression guard for CR-1.
    func testSettingsVersionIsEncoded() throws {
        let data = try JSONEncoder().encode(AppSettings())
        let json = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: data) as? [String: Any],
            "Encoded settings should be a JSON object"
        )
        let storedVersion = try XCTUnwrap(
            json["settingsVersion"] as? Int,
            "encode(to:) must write settingsVersion so the version-mismatch reset can fire"
        )
        XCTAssertEqual(storedVersion, AppSettings.currentVersion,
                       "Freshly encoded settings should carry the current version")
    }

    // settingsVersion must survive a full encode/decode round-trip.
    func testSettingsVersionRoundTrips() throws {
        let data = try JSONEncoder().encode(AppSettings())
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)
        XCTAssertEqual(decoded.settingsVersion, AppSettings.currentVersion)
    }

    // A legacy blob with no settingsVersion key (all existing users) must still decode
    // — without wiping settings — defaulting to the current version.
    func testLegacyBlobWithoutVersionDecodesToCurrent() throws {
        let data = try JSONEncoder().encode(AppSettings())
        var json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "settingsVersion")
        let strippedData = try JSONSerialization.data(withJSONObject: json)

        let decoded = try JSONDecoder().decode(AppSettings.self, from: strippedData)
        XCTAssertEqual(decoded.settingsVersion, AppSettings.currentVersion,
                       "A versionless legacy blob should decode as the current version, not crash")
    }
}

// MARK: - Safe Array Access Tests (CR-3)

final class SafeArrayAccessTests: XCTestCase {

    func testValueAtReturnsElementInRange() {
        let arr: [Double?] = [10.0, 20.0, 30.0]
        XCTAssertEqual(arr.value(at: 0), 10.0)
        XCTAssertEqual(arr.value(at: 2), 30.0)
    }

    func testValueAtReturnsNilOutOfRange() {
        let arr: [Double?] = [10.0]
        XCTAssertNil(arr.value(at: 1), "Out-of-range index must return nil, not trap")
        XCTAssertNil(arr.value(at: 15), "Far-out-of-range index (e.g. a partial daily response) must return nil")
    }

    func testValueAtReturnsNilForNegativeIndex() {
        let arr: [Double?] = [10.0]
        XCTAssertNil(arr.value(at: -1))
    }

    func testValueAtOnEmptyArray() {
        let arr: [String?] = []
        XCTAssertNil(arr.value(at: 0), "Empty companion array (shorter than the master) must not trap")
    }

    func testValueAtPreservesStoredNil() {
        let arr: [Double?] = [nil, 5.0]
        // Element exists but is nil — value(at:) returns that nil, distinct from out-of-range nil.
        XCTAssertNil(arr.value(at: 0))
        XCTAssertEqual(arr.value(at: 1), 5.0)
    }
}

// MARK: - TTLCache Tests (review finding 4)

final class TTLCacheTests: XCTestCase {

    func testReturnsValueWithinTTL() {
        let cache = TTLCache<String, Int>(ttl: 100)
        cache.set(42, for: "a")
        XCTAssertEqual(cache.value(for: "a"), 42)
    }

    func testMissingKeyReturnsNil() {
        let cache = TTLCache<String, Int>(ttl: 100)
        XCTAssertNil(cache.value(for: "absent"))
    }

    func testExpiredEntryReturnsNil() {
        // ttl 0 → any entry is already older than its window.
        let cache = TTLCache<String, String>(ttl: 0)
        cache.set("stale", for: "k")
        XCTAssertNil(cache.value(for: "k"), "Entry past its TTL must not be served")
    }

    func testOverwriteRefreshesValue() {
        let cache = TTLCache<String, Int>(ttl: 100)
        cache.set(1, for: "k")
        cache.set(2, for: "k")
        XCTAssertEqual(cache.value(for: "k"), 2)
    }
}

// MARK: - Alert Fetch Failure-vs-Empty Tests (product review #1)

/// Stubs the network so alert fetches can be driven deterministically.
final class StubURLProtocol: URLProtocol {
    // Serialized by XCTest's serial test execution; reset in tearDown.
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let handler = StubURLProtocol.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    override func stopLoading() {}
}

final class AlertFetchTests: XCTestCase {

    private let usCity = City(name: "Testville", state: "KS", country: "United States",
                              latitude: 39.0, longitude: -98.0)

    private func stubbedSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: config)
    }

    override func tearDown() {
        StubURLProtocol.handler = nil
        super.tearDown()
    }

    // A server error must THROW so the UI shows "couldn't check for alerts" — never a false
    // "No active alerts". This is the core of product-review fix #1.
    func testServerErrorThrowsInsteadOfReportingNoAlerts() async {
        StubURLProtocol.handler = { req in
            (HTTPURLResponse(url: req.url!, statusCode: 503, httpVersion: nil, headerFields: nil)!, Data())
        }
        let service = await MainActor.run { WeatherService() }
        await MainActor.run { service.alertsURLSession = stubbedSession() }
        do {
            _ = try await service.fetchNWSAlerts(for: usCity)
            XCTFail("A 503 must throw (couldn't check), not resolve to an empty 'no alerts' list")
        } catch {
            // expected
        }
    }

    // A network failure (no connectivity) must likewise throw.
    func testNetworkFailureThrows() async {
        StubURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
        let service = await MainActor.run { WeatherService() }
        await MainActor.run { service.alertsURLSession = stubbedSession() }
        do {
            _ = try await service.fetchNWSAlerts(for: usCity)
            XCTFail("A network failure must throw so the UI can distinguish it from 'no alerts'")
        } catch {
            // expected
        }
    }

    // A genuine empty 200 response IS "no active alerts" and must NOT throw.
    func testEmptySuccessReturnsNoAlerts() async throws {
        StubURLProtocol.handler = { req in
            (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
             Data(#"{"features":[]}"#.utf8))
        }
        let service = await MainActor.run { WeatherService() }
        await MainActor.run { service.alertsURLSession = stubbedSession() }
        let alerts = try await service.fetchNWSAlerts(for: usCity)
        XCTAssertTrue(alerts.isEmpty, "An empty 200 is a genuine 'no active alerts', not a failure")
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
