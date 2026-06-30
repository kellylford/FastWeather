//
//  LocationService.swift
//  Fast Weather
//
//  Service for accessing device location and reverse geocoding
//  WCAG 2.2 AA compliant with full accessibility support
//

import Foundation
import CoreLocation
import Combine

/// Service for managing device location and reverse geocoding
@MainActor
class LocationService: NSObject, ObservableObject {
    // MARK: - Published Properties
    
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentLocation: CLLocation?
    @Published var isLocating: Bool = false
    @Published var locationError: String?
    
    // MARK: - Private Properties
    
    private let locationManager = CLLocationManager()
    // Main-actor isolated — only ever read/written on the main actor (see delegate methods below).
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?
    // Resumed by locationManagerDidChangeAuthorization when the user answers the permission prompt.
    private var authContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?
    
    // MARK: - Singleton
    
    static let shared = LocationService()
    
    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer // City-level accuracy is sufficient
        authorizationStatus = locationManager.authorizationStatus
    }
    
    // MARK: - Public Methods
    
    /// Requests location permission from user
    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    /// Requests permission and awaits the user's response via the authorization-change
    /// delegate, with a timeout fallback so it can never hang. Replaces the old fixed
    /// 500ms sleep that returned a false "permission denied" when the user was slow to tap.
    private func requestAuthorizationAndWait() async -> CLAuthorizationStatus {
        if authorizationStatus != .notDetermined { return authorizationStatus }
        // If a prompt is already awaiting a response, don't start another.
        if authContinuation != nil { return authorizationStatus }
        requestPermission()
        return await withCheckedContinuation { (continuation: CheckedContinuation<CLAuthorizationStatus, Never>) in
            self.authContinuation = continuation
            // Timeout: if the delegate never fires, resume with whatever status we have.
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 10_000_000_000) // 10s
                if let cont = self.authContinuation {
                    self.authContinuation = nil
                    cont.resume(returning: self.authorizationStatus)
                }
            }
        }
    }

    /// Gets the current device location
    /// - Returns: CLLocation object with coordinates
    /// - Throws: LocationError if location cannot be determined
    func getCurrentLocation() async throws -> CLLocation {
        // Check authorization status
        if authorizationStatus != .authorizedWhenInUse && authorizationStatus != .authorizedAlways {
            if authorizationStatus == .notDetermined {
                // Wait for the user's actual response to the permission prompt instead of a
                // fixed 500ms sleep that often fired before they tapped Allow (false denial).
                let status = await requestAuthorizationAndWait()
                if status != .authorizedWhenInUse && status != .authorizedAlways {
                    throw LocationError.permissionDenied
                }
            } else {
                throw LocationError.permissionDenied
            }
        }
        
        // Guard against a second request while one is already in-flight.
        // Two concurrent callers would overwrite each other's continuation, causing a crash.
        guard locationContinuation == nil else {
            throw LocationError.requestInProgress
        }
        
        isLocating = true
        locationError = nil
        
        defer {
            isLocating = false
        }
        
        // Request single location update.
        // The continuation is stored on the main actor; delegate callbacks
        // dispatch back to @MainActor before consuming it.
        return try await withCheckedThrowingContinuation { continuation in
            self.locationContinuation = continuation
            self.locationManager.requestLocation()
        }
    }
    
    /// Reverse geocodes coordinates to get city information
    /// - Parameters:
    ///   - latitude: Latitude coordinate
    ///   - longitude: Longitude coordinate
    /// - Returns: City object with name, state, country
    /// - Throws: Error if geocoding fails
    func reverseGeocode(latitude: Double, longitude: Double) async throws -> City {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        let geocoder = CLGeocoder()
        
        let placemarks = try await geocoder.reverseGeocodeLocation(location)
        
        guard let placemark = placemarks.first else {
            throw LocationError.geocodingFailed
        }
        
        // Extract city information
        let cityName = placemark.locality ?? placemark.name ?? "Current Location"
        let state = placemark.administrativeArea
        let country = placemark.country ?? "Unknown"
        
        return City(
            name: cityName,
            state: state,
            country: country,
            latitude: latitude,
            longitude: longitude
        )
    }
    
    /// Convenience method to get current location and convert to City
    /// - Returns: City object for current location
    /// - Throws: LocationError if location cannot be determined
    func getCurrentLocationAsCity() async throws -> City {
        let location = try await getCurrentLocation()
        return try await reverseGeocodeDetailed(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
    }

    /// Reverse geocodes coordinates to a City using sub-locality for more specific display names.
    /// Returns names like "Mission District, San Francisco" when sub-locality data is available,
    /// falling back to locality + state/country otherwise.
    func reverseGeocodeDetailed(latitude: Double, longitude: Double) async throws -> City {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        let geocoder = CLGeocoder()

        let placemarks = try await geocoder.reverseGeocodeLocation(location)

        guard let placemark = placemarks.first else {
            throw LocationError.geocodingFailed
        }

        let subLocality = placemark.subLocality
        let locality    = placemark.locality
        let adminArea   = placemark.administrativeArea
        let country     = placemark.country ?? "Unknown"

        let cityName: String
        let cityState: String?

        if let sub = subLocality, !sub.isEmpty, let loc = locality, !loc.isEmpty {
            // e.g. "Mission District, San Francisco" — omit state to avoid over-qualification
            cityName  = "\(sub), \(loc)"
            cityState = nil
        } else {
            cityName  = locality ?? placemark.name ?? "Current Location"
            cityState = adminArea
        }

        return City(
            name: cityName,
            state: cityState,
            country: country,
            latitude: latitude,
            longitude: longitude
        )
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
            // Resume a pending getCurrentLocation() that's waiting on the permission prompt.
            if manager.authorizationStatus != .notDetermined, let cont = authContinuation {
                authContinuation = nil
                cont.resume(returning: manager.authorizationStatus)
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        
        Task { @MainActor in
            currentLocation = location
            // Resume and clear the continuation on the main actor so that reads
            // and writes to locationContinuation are always serialized.
            locationContinuation?.resume(returning: location)
            locationContinuation = nil
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let locationError = error as? CLError
        
        let errorMessage: String
        switch locationError?.code {
        case .denied:
            errorMessage = "Location access denied. Enable in Settings > Privacy > Location Services."
        case .network:
            errorMessage = "Network error. Check your internet connection."
        case .locationUnknown:
            errorMessage = "Unable to determine location. Try again."
        default:
            errorMessage = "Location error: \(error.localizedDescription)"
        }
        
        Task { @MainActor in
            self.locationError = errorMessage
            locationContinuation?.resume(throwing: LocationError.locationUnavailable(errorMessage))
            locationContinuation = nil
        }
    }
}

// MARK: - Location Errors

enum LocationError: LocalizedError {
    case permissionDenied
    case locationUnavailable(String)
    case geocodingFailed
    case requestInProgress
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Location permission is required. Please enable location access in Settings > Privacy > Location Services."
        case .locationUnavailable(let message):
            return message
        case .geocodingFailed:
            return "Unable to determine city name for your location. Please try searching manually."
        case .requestInProgress:
            return "A location request is already in progress. Please wait."
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .permissionDenied:
            return "Go to Settings > Privacy > Location Services and enable location for Weather Fast."
        case .locationUnavailable:
            return "Make sure Location Services are enabled and you have a good signal. Try again in a moment."
        case .geocodingFailed:
            return "You can still add cities by searching for them manually."
        case .requestInProgress:
            return nil
        }
    }
}
