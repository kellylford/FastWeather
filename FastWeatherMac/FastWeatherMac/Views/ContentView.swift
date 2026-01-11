//
//  ContentView.swift
//  FastWeatherMac
//
//  Created on 12/12/2025.
//  Main view with city list and weather display
//  Full VoiceOver and accessibility support
//

import SwiftUI

struct ContentView: View {
    @StateObject private var cityManager = CityManager()
    @State private var searchText = ""
    @State private var selectedCity: City?
    @State private var showingWeatherDetail = false
    @State private var showingAddCitySheet = false
    @State private var showingLocationBrowser = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    private var addCityHint: String {
        searchText.isEmpty ? "Enter a city name first" : "Add \(searchText) to your city list"
    }
    
    private var refreshHint: String {
        selectedCity == nil ? "Select a city first" : "Refresh weather for \(selectedCity?.displayName ?? "")"
    }
    
    var body: some View {
        NavigationSplitView {
            sidebarView
        } detail: {
            detailView
        }
        .sheet(isPresented: $showingAddCitySheet) {
            CitySearchSheet(cityManager: cityManager, isPresented: $showingAddCitySheet)
        }
        .sheet(isPresented: $showingLocationBrowser) {
            LocationBrowserView(cityManager: cityManager, isPresented: $showingLocationBrowser)
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            if selectedCity == nil && !cityManager.cities.isEmpty {
                selectedCity = cityManager.cities.first
            }
        }
    }
    
    // MARK: - Sidebar View
    private var sidebarView: some View {
        VStack(spacing: 0) {
            searchSection
            Divider()
            cityListSection
        }
        .frame(minWidth: 280)
        .toolbar {
            ToolbarItemGroup {
                Button(action: { showingAddCitySheet = true }) {
                    Label("Search City", systemImage: "magnifyingglass")
                }
                .help("Search and add a new city")
                .accessibilityLabel("Search for city")
                
                Button(action: refreshSelectedCity) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Refresh weather for selected city")
                .disabled(selectedCity == nil)
                .accessibilityLabel("Refresh weather")
                .accessibilityHint(refreshHint)
                .keyboardShortcut("r", modifiers: .command)
            }
        }
    }
    
    // MARK: - Search Section
    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add New City")
                .font(.headline)
                .foregroundColor(.primary)
                .accessibilityAddTraits(.isHeader)
            
            HStack {
                TextField("Enter city name or zip code", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("City search field")
                    .accessibilityHint("Enter a city name or zip code, then press Add City button")
                    .onSubmit {
                        addCityAction()
                    }
                
                Button(action: addCityAction) {
                    Label("Add City", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(searchText.isEmpty)
                .accessibilityLabel("Add City")
                .accessibilityHint(addCityHint)
            }
            
            // Browse Cities Button
            Button(action: { showingLocationBrowser = true }) {
                Label("Browse Cities by State/Country", systemImage: "map")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Browse cities by state or country")
            .accessibilityHint("Open a dialog to browse and add multiple cities from a state or country")
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    // MARK: - City List Section
    private var cityListSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your Cities")
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.horizontal)
                .padding(.top, 12)
                .accessibilityAddTraits(.isHeader)
            
            if cityManager.cities.isEmpty {
                emptyStateView
            } else {
                cityList
            }
        }
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "cloud.sun.fill")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
                .accessibilityHidden(true)
            
            Text("No cities added yet")
                .font(.title3)
                .foregroundColor(.secondary)
            
            Text("Add a city to get started")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No cities added yet. Add a city to get started.")
    }
    
    // MARK: - City List
    private var cityList: some View {
        List(selection: $selectedCity) {
            cityListContent
        }
        .accessibilityLabel("Cities list")
        .accessibilityHint("\(cityManager.cities.count) cities. Select a city to view weather details.")
    }
    
    private var cityListContent: some View {
        ForEach(cityManager.cities) { city in
            CityRowView(city: city)
                .tag(city)
                .contextMenu {
                    removeCityButton(for: city)
                }
        }
        .onMove(perform: cityManager.moveCity)
        .onDelete(perform: deleteCity)
    }
    
    private func removeCityButton(for city: City) -> some View {
        Button(role: .destructive) {
            withAnimation {
                cityManager.removeCity(city)
                if selectedCity?.id == city.id {
                    selectedCity = cityManager.cities.first
                }
            }
        } label: {
            Label("Remove City", systemImage: "trash")
        }
        .accessibilityLabel("Remove \(city.displayName)")
    }
    
    private func deleteCity(at indexSet: IndexSet) {
        indexSet.forEach { index in
            let city = cityManager.cities[index]
            cityManager.removeCity(city)
        }
    }
    
    // MARK: - Detail View
    private var detailView: some View {
        Group {
            if let city = selectedCity {
                WeatherDetailView(city: city)
                    .id(city.id)
            } else {
                emptyDetailView
            }
        }
    }
    
    // MARK: - Empty Detail View
    private var emptyDetailView: some View {
        VStack(spacing: 20) {
            Image(systemName: "cloud.sun.fill")
                .font(.system(size: 72))
                .foregroundColor(.secondary)
                .accessibilityHidden(true)
            
            Text("Select a City")
                .font(.title)
                .foregroundColor(.secondary)
            
            Text("Choose a city from the sidebar to view its weather")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No city selected. Select a city from the sidebar to view its weather.")
    }
    
    // MARK: - Actions
    private func addCityAction() {
        guard !searchText.isEmpty else { return }
        showingAddCitySheet = true
    }
    
    private func refreshSelectedCity() {
        // Trigger refresh by updating selection
        if let city = selectedCity {
            selectedCity = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                selectedCity = city
            }
        }
    }
}

// MARK: - City Row View
struct CityRowView: View {
    let city: City
    @State private var quickWeather: String = "Loading..."
    @State private var weatherIcon: String = "cloud.fill"
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: weatherIcon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 32)
                .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(city.name)
                    .font(.body.weight(.semibold))
                    .foregroundColor(.primary)
                
                Text(quickWeather)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(city.displayName), \(quickWeather)")
        .accessibilityAddTraits(.isButton)
        .task {
            await loadQuickWeather()
        }
    }
    
    private func loadQuickWeather() async {
        do {
            let weather = try await WeatherService.shared.fetchWeather(for: city, includeHourly: false, includeDaily: false)
            let temp = Int(weather.current.temperature2m)
            let condition = weather.current.weatherCodeEnum?.description ?? "Unknown"
            
            await MainActor.run {
                quickWeather = "\(temp)°C, \(condition)"
                weatherIcon = weather.current.weatherCodeEnum?.sfSymbol ?? "cloud.fill"
            }
        } catch {
            await MainActor.run {
                quickWeather = "Unable to load"
                weatherIcon = "exclamationmark.triangle"
            }
        }
    }
}

#Preview {
    ContentView()
}
