//
//  LocationBrowserView.swift
//  FastWeatherMac
//
//  Browse cities by US State or Country
//  Provides quick access to pre-geocoded cities
//

import SwiftUI

// MARK: - Cached City Data Models
struct CachedCity: Codable, Identifiable {
    let name: String
    let state: String?
    let country: String
    let lat: Double
    let lon: Double
    
    var id: String { "\(name)_\(lat)_\(lon)" }
    
    var displayName: String {
        var parts = [name]
        if let state = state, !state.isEmpty {
            parts.append(state)
        }
        parts.append(country)
        return parts.joined(separator: ", ")
    }
}

typealias USCitiesCache = [String: [CachedCity]]
typealias InternationalCitiesCache = [String: [CachedCity]]

// MARK: - Location Browser View
struct LocationBrowserView: View {
    @ObservedObject var cityManager: CityManager
    @Binding var isPresented: Bool
    
    @State private var selectedTab = 0
    @State private var selectedState: String = ""
    @State private var selectedCountry: String = ""
    @State private var citiesForLocation: [CachedCity] = []
    @State private var selectedCities: Set<String> = []
    @State private var usCitiesCache: USCitiesCache?
    @State private var intlCitiesCache: InternationalCitiesCache?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var usStates: [String] {
        usCitiesCache?.keys.sorted() ?? []
    }
    
    var countries: [String] {
        intlCitiesCache?.keys.sorted() ?? []
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Browse Cities by Location")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Done") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            if isLoading {
                loadingView
            } else if let error = errorMessage {
                errorView(error)
            } else {
                contentView
            }
        }
        .frame(width: 700, height: 600)
        .onAppear {
            loadCachedData()
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading city data...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Error View
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            Text("Error Loading Data")
                .font(.headline)
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Content View
    private var contentView: some View {
        VStack(spacing: 0) {
            // Tab Selector
            Picker("Location Type", selection: $selectedTab) {
                Text("U.S. States").tag(0)
                Text("International").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()
            .onChange(of: selectedTab) { _ in
                clearSelection()
            }
            
            Divider()
            
            // Location Picker
            locationPicker
            
            Divider()
            
            // Cities List
            if !citiesForLocation.isEmpty {
                citiesList
            } else {
                emptySelectionView
            }
        }
    }
    
    // MARK: - Location Picker
    private var locationPicker: some View {
        HStack {
            if selectedTab == 0 {
                // US States
                Picker("State:", selection: $selectedState) {
                    Text("-- Select a State --").tag("")
                    ForEach(usStates, id: \.self) { state in
                        Text(state).tag(state)
                    }
                }
                .frame(maxWidth: 300)
                .onChange(of: selectedState) { newState in
                    loadCitiesForState(newState)
                }
            } else {
                // International
                Picker("Country:", selection: $selectedCountry) {
                    Text("-- Select a Country --").tag("")
                    ForEach(countries, id: \.self) { country in
                        Text(country).tag(country)
                    }
                }
                .frame(maxWidth: 300)
                .onChange(of: selectedCountry) { newCountry in
                    loadCitiesForCountry(newCountry)
                }
            }
            
            Spacer()
            
            if !citiesForLocation.isEmpty {
                Button(selectedCities.count == citiesForLocation.count ? "Deselect All" : "Select All") {
                    toggleSelectAll()
                }
            }
        }
        .padding()
    }
    
    // MARK: - Cities List
    private var citiesList: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Select cities to add (\(selectedCities.count) selected):")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top)
            
            List(citiesForLocation, selection: $selectedCities) { city in
                Toggle(isOn: Binding(
                    get: { selectedCities.contains(city.id) },
                    set: { isSelected in
                        if isSelected {
                            selectedCities.insert(city.id)
                        } else {
                            selectedCities.remove(city.id)
                        }
                    }
                )) {
                    Text(city.displayName)
                        .font(.body)
                }
                .toggleStyle(.checkbox)
                .tag(city.id)
            }
            .listStyle(.plain)
            
            Divider()
            
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Add Selected Cities") {
                    addSelectedCities()
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedCities.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
    }
    
    // MARK: - Empty Selection View
    private var emptySelectionView: some View {
        VStack(spacing: 16) {
            Image(systemName: "map")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(selectedTab == 0 ? "Select a state to view cities" : "Select a country to view cities")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Actions
    private func loadCachedData() {
        isLoading = true
        errorMessage = nil
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // Load US Cities
                if let usURL = Bundle.main.url(forResource: "us-cities-cached", withExtension: "json") {
                    let usData = try Data(contentsOf: usURL)
                    let decoder = JSONDecoder()
                    let decoded = try decoder.decode(USCitiesCache.self, from: usData)
                    
                    DispatchQueue.main.async {
                        self.usCitiesCache = decoded
                    }
                }
                
                // Load International Cities
                if let intlURL = Bundle.main.url(forResource: "international-cities-cached", withExtension: "json") {
                    let intlData = try Data(contentsOf: intlURL)
                    let decoder = JSONDecoder()
                    let decoded = try decoder.decode(InternationalCitiesCache.self, from: intlData)
                    
                    DispatchQueue.main.async {
                        self.intlCitiesCache = decoded
                    }
                }
                
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = "Could not load city data files: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func loadCitiesForState(_ state: String) {
        guard !state.isEmpty, let cities = usCitiesCache?[state] else {
            citiesForLocation = []
            selectedCities.removeAll()
            return
        }
        citiesForLocation = cities
        selectedCities.removeAll()
    }
    
    private func loadCitiesForCountry(_ country: String) {
        guard !country.isEmpty, let cities = intlCitiesCache?[country] else {
            citiesForLocation = []
            selectedCities.removeAll()
            return
        }
        citiesForLocation = cities
        selectedCities.removeAll()
    }
    
    private func clearSelection() {
        selectedState = ""
        selectedCountry = ""
        citiesForLocation = []
        selectedCities.removeAll()
    }
    
    private func toggleSelectAll() {
        if selectedCities.count == citiesForLocation.count {
            selectedCities.removeAll()
        } else {
            selectedCities = Set(citiesForLocation.map { $0.id })
        }
    }
    
    private func addSelectedCities() {
        let citiesToAdd = citiesForLocation.filter { selectedCities.contains($0.id) }
        var addedCount = 0
        
        for cachedCity in citiesToAdd {
            // Check if city already exists
            let alreadyExists = cityManager.cities.contains { existingCity in
                existingCity.latitude == cachedCity.lat &&
                existingCity.longitude == cachedCity.lon
            }
            
            if !alreadyExists {
                let newCity = City(
                    name: cachedCity.name,
                    displayName: cachedCity.displayName,
                    latitude: cachedCity.lat,
                    longitude: cachedCity.lon,
                    state: cachedCity.state,
                    country: cachedCity.country
                )
                cityManager.addCity(newCity)
                addedCount += 1
            }
        }
        
        isPresented = false
    }
}

#Preview {
    LocationBrowserView(
        cityManager: CityManager(),
        isPresented: .constant(true)
    )
}
