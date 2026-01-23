//
//  MyCitiesView.swift
//  Fast Weather
//
//  View for displaying saved cities with three view options: Flat, Table, List
//

import SwiftUI

struct MyCitiesView: View {
    @EnvironmentObject var weatherService: WeatherService
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var showingSettings = false
    @State private var showingAddCity = false
    @State private var selectedCityForHistory: City?
    @State private var selectedCityForDetail: City?
    
    var body: some View {
        NavigationStack {
            Group {
                if weatherService.savedCities.isEmpty {
                    EmptyStateView()
                } else {
                    switch settingsManager.settings.viewMode {
                    case .list:
                        ListView(selectedCityForHistory: $selectedCityForHistory)
                    case .flat:
                        FlatView(selectedCityForHistory: $selectedCityForHistory, selectedCityForDetail: $selectedCityForDetail)
                    }
                }
            }
            .navigationTitle("Fast Weather")
            .navigationDestination(item: $selectedCityForHistory) { city in
                HistoricalWeatherView(city: city, autoLoadToday: settingsManager.settings.viewMode == .list)
                    .navigationTitle("Historical Weather")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .navigationDestination(item: $selectedCityForDetail) { city in
                CityDetailView(city: city)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddCity = true
                    }) {
                        Label("Add City", systemImage: "plus")
                    }
                    .accessibilityLabel("Add City")
                    .accessibilityHint("Opens search to add a new city")
                }
            }
            .sheet(isPresented: $showingAddCity) {
                AddCitySearchView(initialSearchText: "")
            }
            .refreshable {
                await weatherService.refreshAllWeather()
            }
        }
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "cloud.sun.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)
                .accessibilityHidden(true)
            
            Text("No Cities Added")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Browse cities to add your first location")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No cities added. Browse cities to add your first location")
    }
}

#Preview {
    MyCitiesView()
        .environmentObject(WeatherService())
        .environmentObject(SettingsManager())
}
