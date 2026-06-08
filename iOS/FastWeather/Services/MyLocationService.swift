//
//  MyLocationService.swift
//  Fast Weather
//
//  Manages current-device-location city state for the My Location section.
//  Handles permission observation, staleness-based refresh, caching, and
//  "Add to My City List" with proximity-based deduplication.
//

import Foundation
import CoreLocation
import Combine
import UIKit

@MainActor
class MyLocationService: ObservableObject {
    static let shared = MyLocationService()

    // MARK: - Published State

    @Published var locationCity: City?
    @Published var isLoading: Bool = false
    @Published var permissionStatus: CLAuthorizationStatus = .notDetermined
    @Published var errorMessage: String?

    // MARK: - Private

    private let locationCityKey   = "MyLocationCity"
    private let lastRefreshKey    = "MyLocationLastRefresh"
    private let stalenessDuration: TimeInterval = 15 * 60  // 15 minutes

    private var lastRefreshDate: Date?
    private var cancellable: AnyCancellable?

    // MARK: - Init

    private init() {
        // Restore cached city and last refresh date
        if let data = UserDefaults.standard.data(forKey: locationCityKey),
           let city = try? JSONDecoder().decode(City.self, from: data) {
            locationCity = city
        }
        lastRefreshDate = UserDefaults.standard.object(forKey: lastRefreshKey) as? Date

        // Mirror permission status and auto-refresh when first granted
        permissionStatus = LocationService.shared.authorizationStatus
        cancellable = LocationService.shared.$authorizationStatus
            .receive(on: RunLoop.main)
            .sink { [weak self] status in
                self?.permissionStatus = status
                if (status == .authorizedWhenInUse || status == .authorizedAlways),
                   self?.locationCity == nil {
                    Task { await self?.refresh() }
                }
            }
    }

    // MARK: - Public Methods

    /// Requests location permission when status is undetermined.
    func requestPermissionIfNeeded() {
        permissionStatus = LocationService.shared.authorizationStatus
        if permissionStatus == .notDetermined {
            LocationService.shared.requestPermission()
        }
    }

    /// Fetches the current location and reverse-geocodes it to a detailed City name.
    /// Clears any previous error on success.
    func refresh() async {
        guard !isLoading else { return }

        permissionStatus = LocationService.shared.authorizationStatus

        guard permissionStatus == .authorizedWhenInUse || permissionStatus == .authorizedAlways else {
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let location = try await LocationService.shared.getCurrentLocation()
            let city = try await LocationService.shared.reverseGeocodeDetailed(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )
            locationCity = city
            lastRefreshDate = Date()

            if let data = try? JSONEncoder().encode(city) {
                UserDefaults.standard.set(data, forKey: locationCityKey)
            }
            UserDefaults.standard.set(lastRefreshDate, forKey: lastRefreshKey)

            AppLogger.location.info("My Location updated: \(city.displayName)")
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            AppLogger.location.error("My Location refresh failed: \(error.localizedDescription)")
        }
    }

    /// Refreshes only when the cached location is older than the staleness threshold.
    /// Called on app foreground to mirror the app's existing staleness-based refresh pattern.
    func refreshIfStale() async {
        permissionStatus = LocationService.shared.authorizationStatus
        guard permissionStatus == .authorizedWhenInUse || permissionStatus == .authorizedAlways else { return }

        let isStale: Bool
        if let last = lastRefreshDate {
            isStale = Date().timeIntervalSince(last) > stalenessDuration
        } else {
            isStale = true
        }

        if isStale {
            await refresh()
        }
    }

    /// Adds the current location city to the saved city list.
    /// Silently skips if the location is within ~5 km of an existing saved city.
    func addToMyCityList(weatherService: WeatherService) {
        guard let city = locationCity else { return }

        // Deduplicate by name: only skip if a saved city has the exact same name.
        // Coordinate proximity is intentionally not used here — a sub-locality like
        // "East Side, Madison" is meaningfully different from a saved "Madison, WI"
        // even though they are geographically close.
        let isDuplicate = weatherService.savedCities.contains { saved in
            saved.name.lowercased() == city.name.lowercased()
        }

        if !isDuplicate {
            weatherService.addCity(city)
            UIAccessibility.post(
                notification: .announcement,
                argument: "Added \(city.displayName) to your city list"
            )
            AppLogger.service.info("My Location: added \(city.displayName) to city list")
        }
    }
}
