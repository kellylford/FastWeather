//
//  AddCitySearchView.swift
//  Fast Weather
//
//  Direct city search by name or zip code
//

import SwiftUI
import CoreLocation
import MapKit

struct AddCitySearchView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var weatherService: WeatherService
    @StateObject private var locationService = LocationService.shared
    @StateObject private var featureFlags = FeatureFlags.shared
    var initialSearchText: String = ""
    @State private var searchText = ""
    @State private var searchResults: [GeocodingResult] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var showingLocationPermissionAlert = false
    @State private var isGettingLocation = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search box and button
                VStack(spacing: 12) {
                    Text("Enter a city, ZIP code, street address, or location name")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Current Location Button
                    Button(action: {
                        getCurrentLocation()
                    }) {
                        HStack(spacing: 8) {
                            if isGettingLocation {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "location.fill")
                            }
                            Text("Use My Current Location")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isGettingLocation || isSearching)
                    .accessibilityLabel("Use my current location")
                    .accessibilityHint("Automatically detects your location using GPS. Requires location permission.")
                    
                    // Divider with "OR"
                    HStack {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.3))
                            .frame(height: 1)
                        
                        Text("OR")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                        
                        Rectangle()
                            .fill(Color.secondary.opacity(0.3))
                            .frame(height: 1)
                    }
                    .padding(.vertical, 4)
                    .accessibilityHidden(true)
                    
                    HStack(spacing: 12) {
                        TextField("City, ZIP code, address, or place name", text: $searchText)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .submitLabel(.search)
                            .onSubmit {
                                performSearch()
                            }
                            .accessibilityLabel("Location search field")
                            .accessibilityHint("Enter a city, ZIP code, street address, or location name")
                        
                        Button(action: {
                            performSearch()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "magnifyingglass")
                                Text("Search")
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(searchText.isEmpty || isSearching)
                        .accessibilityLabel("Search")
                        .accessibilityHint("Search for the location you entered")
                    }
                    
                    Text("Examples: \"San Diego, CA\", \"53703\", or \"University of Wisconsin\"")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
                .background(Color(.systemGroupedBackground))
                
                Divider()
                
                // Search results
                if isSearching {
                    ProgressView("Searching...")
                        .padding()
                } else if let error = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)
                        Text(error)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else if !searchResults.isEmpty {
                    List {
                        ForEach(searchResults) { result in
                            Button(action: {
                                addCity(result)
                            }) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(result.displayName)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                        .lineLimit(2)
                                        .truncationMode(.tail)
                                    
                                    Text(String(format: "%.4f, %.4f", result.latitude, result.longitude))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .accessibilityLabel("\(result.displayName), coordinates \(String(format: "%.4f, %.4f", result.latitude, result.longitude))")
                        }
                    }
                    .listStyle(.plain)
                } else if !searchText.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                            .accessibilityHidden(true)
                        Text("No results found")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "map")
                            .font(.system(size: 64))
                            .foregroundColor(.secondary)
                            .accessibilityHidden(true)
                        Text("Search for a city, ZIP code, street address, or location name")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxHeight: .infinity)
                }
                
                Spacer()
            }
            .navigationTitle("Add Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Location Permission Required", isPresented: $showingLocationPermissionAlert) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("To use your current location, please enable location access in Settings > Privacy > Location Services.")
            }
            .onAppear {
                if !initialSearchText.isEmpty {
                    searchText = initialSearchText
                    performSearch()
                }
            }
            .onChange(of: searchText) {
                if searchText.isEmpty {
                    searchResults = []
                    errorMessage = nil
                } else {
                    // Debounce search: wait for user to stop typing
                    Task {
                        // Store current text to compare later
                        let currentText = searchText
                        // Wait 500ms
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        // Only search if text hasn't changed
                        if currentText == searchText && !searchText.isEmpty {
                            performSearch()
                        }
                    }
                }
            }
        }
    }
    
    private func performSearch() {
        guard !searchText.isEmpty else { return }
        
        isSearching = true
        errorMessage = nil
        searchResults = []
        
        Task {
            do {
                let results = try await searchCity(query: searchText)
                await MainActor.run {
                    searchResults = results
                    isSearching = false
                    if results.isEmpty {
                        errorMessage = "No cities found. Try a different search term."
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Search failed: \(error.localizedDescription)"
                    isSearching = false
                }
            }
        }
    }
    
    // ZIP codes → CLGeocoder (returns precise area centroid)
    // Everything else → MKLocalSearch (full Apple Maps POI database: universities, airports, etc.)
    private func searchCity(query: String) async throws -> [GeocodingResult] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        if trimmed.range(of: "^\\d{5}$", options: .regularExpression) != nil {
            return try await searchWithGeocoder(query: trimmed)
        }
        return try await searchWithLocalSearch(query: trimmed)
    }

    private func searchWithLocalSearch(query: String) async throws -> [GeocodingResult] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        let search = MKLocalSearch(request: request)
        let response: MKLocalSearch.Response = try await withCheckedThrowingContinuation { continuation in
            search.start { response, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let response {
                    continuation.resume(returning: response)
                } else {
                    continuation.resume(throwing: NSError(domain: "MKLocalSearch", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "No results"]))
                }
            }
        }
        return response.mapItems.compactMap { item in
            buildResult(
                itemName: item.name,
                locality: item.placemark.locality,
                adminArea: item.placemark.administrativeArea,
                thoroughfare: item.placemark.thoroughfare,
                country: item.placemark.country,
                isoCode: item.placemark.isoCountryCode,
                location: item.placemark.location
            )
        }
    }

    private func searchWithGeocoder(query: String) async throws -> [GeocodingResult] {
        let geocoder = CLGeocoder()
        let placemarks = try await geocoder.geocodeAddressString(query)
        return placemarks.compactMap { placemark in
            buildResult(
                itemName: placemark.name,
                locality: placemark.locality,
                adminArea: placemark.administrativeArea,
                thoroughfare: placemark.thoroughfare,
                country: placemark.country,
                isoCode: placemark.isoCountryCode,
                location: placemark.location
            )
        }
    }

    // Shared naming logic for both search paths.
    // City struct is unchanged — both old and new app versions decode each other's synced
    // cities correctly. This flag only affects how new search results are labelled.
    private func buildResult(itemName: String?, locality: String?, adminArea: String?,
                             thoroughfare: String?, country: String?, isoCode: String?,
                             location: CLLocation?) -> GeocodingResult? {
        guard let location else { return nil }

        let normalizedCountry = CountryNames.normalize(country, isoCode: isoCode)

        let specificName: String?
        if featureFlags.specificPlaceNamesEnabled,
           let name = itemName, let city = locality, name != city {
            if name == thoroughfare {
                // Street name — combine with city ("Williamson St, Madison")
                specificName = "\(name), \(city)"
            } else if name.range(of: "^\\d", options: .regularExpression) != nil {
                // Full address starting with house number — use street + city, drop number
                specificName = thoroughfare.map { "\($0), \(city)" } ?? "\(name), \(city)"
            } else {
                // Named place (airport, university, landmark) — include city so
                // "Memorial Union" stores as "Memorial Union, Madison" not just "Memorial Union"
                specificName = "\(name), \(city)"
            }
        } else {
            specificName = nil
        }

        let primaryName = specificName ?? locality ?? itemName ?? "Unknown"

        // City is already embedded in specificName for all three cases above,
        // so only append state and country.
        var displayParts: [String] = [primaryName]
        if let area = adminArea { displayParts.append(area) }
        if let c = normalizedCountry { displayParts.append(c) }

        return GeocodingResult(
            id: UUID(),
            displayName: displayParts.joined(separator: ", "),
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            name: primaryName
        )
    }
    
    private func addCity(_ result: GeocodingResult) {
        // Parse display name to extract clean city, state, country
        let components = result.displayName.components(separatedBy: ", ")
        
        // Clean city name - remove any zip codes or county suffixes
        var cityName = result.name
        
        // If the name is just a zip code, extract the actual city from displayName
        if cityName.range(of: "^\\d{5}$", options: .regularExpression) != nil {
            // Name is just a zip code
            // DisplayName format: "53718, Madison, Dane County, Wisconsin, United States"
            // So city is at index 1, not 0
            if components.count > 1 {
                cityName = components[1]
            } else if !components.isEmpty {
                cityName = components[0]
            }
        }
        
        // Remove zip code if present within the name (e.g., "54935, Fond du Lac")
        if let zipRange = cityName.range(of: "\\d{5},?\\s*", options: .regularExpression) {
            cityName = cityName.replacingCharacters(in: zipRange, with: "").trimmingCharacters(in: .whitespaces)
        }

        // Extract state and country intelligently
        var state: String? = nil
        var country = "Unknown"
        
        // Look for US states (2-letter codes or full names)
        let usStates = ["AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "FL", "GA", "HI", "ID", "IL", "IN", "IA", "KS", "KY", "LA", "ME", "MD", "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ", "NM", "NY", "NC", "ND", "OH", "OK", "OR", "PA", "RI", "SC", "SD", "TN", "TX", "UT", "VT", "VA", "WA", "WV", "WI", "WY"]
        
        for component in components {
            let trimmed = component.trimmingCharacters(in: .whitespaces)
            
            // Check if it's a US state code
            if usStates.contains(trimmed) {
                state = trimmed
                country = "United States"
                break
            }
            
            // Check for country indicators
            if trimmed == "United States" || trimmed == "USA" {
                country = "United States"
            } else if trimmed.count > 2 && !usStates.contains(trimmed) && components.last == trimmed {
                // Last component is likely the country if it's not a state
                country = trimmed
            }
        }
        
        // If we found US but no state, try to extract state from components
        if country == "United States" && state == nil && components.count > 2 {
            // Second to last component might be the state
            let potentialState = components[components.count - 2].trimmingCharacters(in: .whitespaces)
            if usStates.contains(potentialState) {
                state = potentialState
            } else if components.count > 3 {
                // Try one more back
                let anotherPotentialState = components[components.count - 3].trimmingCharacters(in: .whitespaces)
                if usStates.contains(anotherPotentialState) {
                    state = anotherPotentialState
                }
            }
        }
        
        let city = City(
            name: cityName,
            state: state,
            country: country,
            latitude: result.latitude,
            longitude: result.longitude
        )
        
        weatherService.addCity(city)
        
        // Announce to VoiceOver
        UIAccessibility.post(notification: .announcement, argument: "\(city.displayName) added to My Cities")
        
        dismiss()
    }
    
    // MARK: - Current Location
    
    private func getCurrentLocation() {
        // Check authorization status first
        if locationService.authorizationStatus == .denied || locationService.authorizationStatus == .restricted {
            showingLocationPermissionAlert = true
            return
        }
        
        isGettingLocation = true
        errorMessage = nil
        searchResults = [] // Clear any previous search results
        
        Task {
            do {
                let city = try await locationService.getCurrentLocationAsCity()
                
                await MainActor.run {
                    isGettingLocation = false
                    
                    // Add the city to saved cities
                    weatherService.addCity(city)
                    
                    // Announce to VoiceOver
                    UIAccessibility.post(
                        notification: .announcement,
                        argument: "Current location detected: \(city.displayName). City added to My Cities."
                    )
                    
                    dismiss()
                }
            } catch LocationError.permissionDenied {
                await MainActor.run {
                    isGettingLocation = false
                    showingLocationPermissionAlert = true
                }
            } catch {
                await MainActor.run {
                    isGettingLocation = false
                    errorMessage = "Unable to get current location: \(error.localizedDescription)"
                    
                    // Announce error to VoiceOver
                    UIAccessibility.post(
                        notification: .announcement,
                        argument: errorMessage ?? "Location error"
                    )
                }
            }
        }
    }
}

// MARK: - Supporting Types

struct GeocodingResult: Identifiable {
    let id: UUID
    let displayName: String
    let latitude: Double
    let longitude: Double
    let name: String
}

#Preview {
    AddCitySearchView()
        .environmentObject(WeatherService())
}
