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
    nonisolated(unsafe) private var locationContinuation: CheckedContinuation<CLLocation, Error>?
    
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
    
    /// Gets the current device location
    /// - Returns: CLLocation object with coordinates
    /// - Throws: LocationError if location cannot be determined
    func getCurrentLocation() async throws -> CLLocation {
        // Check authorization status
        if authorizationStatus != .authorizedWhenInUse && authorizationStatus != .authorizedAlways {
            if authorizationStatus == .notDetermined {
                requestPermission()
                // Wait a moment for user to grant permission
                try await Task.sleep(nanoseconds: 500_000_000)
                
                // Check again after delay
                if authorizationStatus != .authorizedWhenInUse && authorizationStatus != .authorizedAlways {
                    throw LocationError.permissionDenied
                }
            } else {
                throw LocationError.permissionDenied
            }
        }
        
        isLocating = true
        locationError = nil
        
        defer {
            isLocating = false
        }
        
        // Request single location update
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
        return try await reverseGeocode(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        
        Task { @MainActor in
            currentLocation = location
        }
        locationContinuation?.resume(returning: location)
        locationContinuation = nil
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
        }
        locationContinuation?.resume(throwing: LocationError.locationUnavailable(errorMessage))
        locationContinuation = nil
    }
}

// MARK: - Location Errors

enum LocationError: LocalizedError {
    case permissionDenied
    case locationUnavailable(String)
    case geocodingFailed
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Location permission is required. Please enable location access in Settings > Privacy > Location Services."
        case .locationUnavailable(let message):
            return message
        case .geocodingFailed:
            return "Unable to determine city name for your location. Please try searching manually."
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .permissionDenied:
            return "Go to Settings > Privacy > Location Services and enable location for Fast Weather."
        case .locationUnavailable:
            return "Make sure Location Services are enabled and you have a good signal. Try again in a moment."
        case .geocodingFailed:
            return "You can still add cities by searching for them manually."
        }
    }
}
