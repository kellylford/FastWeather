//
//  CitySearchSheet.swift
//  FastWeatherMac
//
//  Created on 12/12/2025.
//  City search and selection sheet with accessibility
//

import SwiftUI

struct CitySearchSheet: View {
    @ObservedObject var cityManager: CityManager
    @Binding var isPresented: Bool
    
    @State private var searchText = ""
    @State private var searchResults: [GeocodingResult] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var hasSearched = false
    
    private var searchButtonLabel: String {
        isSearching ? "Searching" : "Search"
    }
    
    private var searchButtonHint: String {
        searchText.isEmpty ? "Enter a city name first" : "Search for \(searchText)"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
            HStack {
                Text("Search for a City")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .accessibilityAddTraits(.isHeader)
                
                Spacer()
                
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
                .accessibilityLabel("Cancel search")
            }
            .padding()
            
            Divider()
            
            // MARK: - Search Field
            VStack(alignment: .leading, spacing: 12) {
                Text("Enter city name or zip code:")
                    .font(.headline)
                
                HStack {
                    TextField("e.g., Madison, WI or London, UK", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("City search field")
                        .accessibilityHint("Enter a city name or zip code to search")
                        .onSubmit {
                            performSearch()
                        }
                    
                    Button(action: performSearch) {
                        if isSearching {
                            ProgressView()
                                .controlSize(.small)
                                .frame(width: 20, height: 20)
                        } else {
                            Image(systemName: "magnifyingglass")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(searchText.isEmpty || isSearching)
                    .accessibilityLabel(searchButtonLabel)
                    .accessibilityHint(searchButtonHint)
                }
            }
            .padding()
            
            Divider()
            
            // MARK: - Results
            if let error = errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                        .accessibilityHidden(true)
                    
                    Text("Search Error")
                        .font(.headline)
                    
                    Text(error)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Search error: \(error)")
            } else if searchResults.isEmpty && hasSearched && !isSearching {
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                        .accessibilityHidden(true)
                    
                    Text("No Results Found")
                        .font(.headline)
                    
                    Text("Try a different search term or check your spelling")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
                .accessibilityElement(children: .combine)
                .accessibilityLabel("No results found for \(searchText). Try a different search term or check your spelling.")
            } else if searchResults.isEmpty && !hasSearched {
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass.circle")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary)
                        .accessibilityHidden(true)
                    
                    Text("Search for Cities")
                        .font(.headline)
                    
                    Text("Enter a city name or zip code above to begin")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Search for cities. Enter a city name or zip code above to begin.")
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Search Results (\(searchResults.count))")
                        .font(.headline)
                        .padding(.horizontal)
                        .padding(.top, 12)
                        .accessibilityAddTraits(.isHeader)
                    
                    List(searchResults) { result in
                        Button(action: {
                            addCity(result)
                        }) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(result.cityName)
                                    .font(.body.weight(.semibold))
                                
                                if let state = result.address?.state, let country = result.address?.country {
                                    Text("\(state), \(country)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else if let country = result.address?.country {
                                    Text(country)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Text("Lat: \(result.latitude, specifier: "%.4f"), Lon: \(result.longitude, specifier: "%.4f")")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(cityAccessibilityLabel(for: result))
                        .accessibilityHint("Double-tap to add this city to your list")
                        .accessibilityAddTraits(.isButton)
                    }
                }
            }
        }
        .frame(width: 600, height: 500)
    }
    
    // MARK: - Actions
    private func performSearch() {
        guard !searchText.isEmpty, !isSearching else { return }
        
        isSearching = true
        errorMessage = nil
        hasSearched = true
        
        Task {
            do {
                let results = try await WeatherService.shared.searchCity(searchText)
                await MainActor.run {
                    searchResults = results
                    isSearching = false
                    
                    // Announce results for VoiceOver
                    if results.isEmpty {
                        NSAccessibility.post(element: NSApp.keyWindow as Any, notification: .announcementRequested, userInfo: [
                            .announcement: "No cities found for \(searchText)",
                            .priority: NSAccessibilityPriorityLevel.high
                        ])
                    } else {
                        NSAccessibility.post(element: NSApp.keyWindow as Any, notification: .announcementRequested, userInfo: [
                            .announcement: "\(results.count) cities found",
                            .priority: NSAccessibilityPriorityLevel.high
                        ])
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSearching = false
                    searchResults = []
                }
            }
        }
    }
    
    private func addCity(_ result: GeocodingResult) {
        let city = City(
            name: result.cityName,
            displayName: result.displayName,
            latitude: result.latitude,
            longitude: result.longitude,
            state: result.address?.state,
            country: result.address?.country
        )
        
        cityManager.addCity(city)
        
        // Announce addition for VoiceOver
        NSAccessibility.post(element: NSApp.keyWindow as Any, notification: .announcementRequested, userInfo: [
            .announcement: "Added \(city.displayName) to your cities",
            .priority: NSAccessibilityPriorityLevel.high
        ])
        
        isPresented = false
    }
    
    private func cityAccessibilityLabel(for result: GeocodingResult) -> String {
        var label = result.cityName
        if let state = result.address?.state, let country = result.address?.country {
            label += ", \(state), \(country)"
        } else if let country = result.address?.country {
            label += ", \(country)"
        }
        return label
    }
}

#Preview {
    CitySearchSheet(
        cityManager: CityManager(),
        isPresented: .constant(true)
    )
}
