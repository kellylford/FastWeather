//
//  AddCitySearchView.swift
//  FastWeather
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
                            .accessibilityValue(searchText.isEmpty ? "Empty" : searchText)
                        
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
        request.setValue("FastWeather iOS App", forHTTPHeaderField: "User-Agent")
        
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
        // Parse display name to extract city, state, country
        let components = result.displayName.components(separatedBy: ", ")
        let cityName = result.name
        let state = components.count > 1 ? components[1] : nil
        let country = components.last ?? "Unknown"
        
        let city = City(
            name: cityName,
            state: state,
            country: country,
            latitude: result.latitude,
            longitude: result.longitude
        )
        
        weatherService.addCity(city)
        
        // Announce to VoiceOver
        UIAccessibility.post(notification: .announcement, argument: "\(cityName) added to My Cities")
        
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
