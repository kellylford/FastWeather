//
//  AddCitySearchView.swift
//  Fast Weather
//
//  Direct city search by name or zip code
//

import SwiftUI

struct AddCitySearchView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var weatherService: WeatherService
    var initialSearchText: String = ""
    @State private var searchText = ""
    @State private var searchResults: [GeocodingResult] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search box and button
                VStack(spacing: 12) {
                    Text("Enter a city name or zip code")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    HStack(spacing: 12) {
                        TextField("City name or zip code", text: $searchText)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .submitLabel(.search)
                            .onSubmit {
                                performSearch()
                            }
                            .accessibilityLabel("City search field")
                            .accessibilityHint("Enter a city name or zip code to search")
                        
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
                        .accessibilityHint("Search for the city you entered")
                        .accessibilityLabel("Search button")
                    }
                    
                    Text("Examples: \"San Diego, CA\" or \"53703\"")
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
                        Text("No results found")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "map")
                            .font(.system(size: 64))
                            .foregroundColor(.secondary)
                        Text("Search for a city by name or zip code")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxHeight: .infinity)
                }
                
                Spacer()
            }
            .navigationTitle("Add City")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
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
    
    private func searchCity(query: String) async throws -> [GeocodingResult] {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "https://nominatim.openstreetmap.org/search?q=\(encodedQuery)&format=json&limit=10"
        
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.setValue("Fast Weather iOS App", forHTTPHeaderField: "User-Agent")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let results = try JSONDecoder().decode([NominatimResult].self, from: data)
        
        return results.map { result in
            GeocodingResult(
                id: UUID(),
                displayName: result.display_name,
                latitude: Double(result.lat) ?? 0.0,
                longitude: Double(result.lon) ?? 0.0,
                name: result.name ?? result.display_name
            )
        }
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
        
        // Remove "County" suffix if present
        if cityName.hasSuffix(" County") {
            cityName = String(cityName.dropLast(7)).trimmingCharacters(in: .whitespaces)
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
}

// MARK: - Supporting Types

struct GeocodingResult: Identifiable {
    let id: UUID
    let displayName: String
    let latitude: Double
    let longitude: Double
    let name: String
}

struct NominatimResult: Codable {
    let lat: String
    let lon: String
    let display_name: String
    let name: String?
}

#Preview {
    AddCitySearchView()
        .environmentObject(WeatherService())
}
