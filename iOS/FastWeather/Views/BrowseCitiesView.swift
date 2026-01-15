//
//  BrowseCitiesView.swift
//  FastWeather
//
//  View for browsing cities by state (US) or country (International)
//

import SwiftUI

struct BrowseCitiesView: View {
    @StateObject private var cityDataService = CityDataService()
    @State private var selectedRegionType: RegionType = .us
    
    enum RegionType: String, CaseIterable {
        case us = "United States"
        case international = "International"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Picker("Region", selection: $selectedRegionType) {
                    ForEach(RegionType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                .accessibilityLabel("Select region to browse")
                
                switch selectedRegionType {
                case .us:
                    USStatesListView(cityDataService: cityDataService)
                case .international:
                    CountriesListView(cityDataService: cityDataService)
                }
            }
            .navigationTitle("Browse Cities")
        }
        .navigationViewStyle(.stack)
    }
}

struct USStatesListView: View {
    @ObservedObject var cityDataService: CityDataService
    @State private var selectedState: String = ""
    @State private var showingStatePicker = false
    
    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Select a State")
                    .font(.headline)
                    .padding(.horizontal)
                
                Button(action: {
                    showingStatePicker = true
                }) {
                    HStack {
                        Text(selectedState.isEmpty ? "Choose a state..." : selectedState)
                            .foregroundColor(selectedState.isEmpty ? .secondary : .primary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                .accessibilityLabel(selectedState.isEmpty ? "Choose a state" : "Selected state: \(selectedState)")
                .accessibilityHint("Double tap to see list of states")
                .sheet(isPresented: $showingStatePicker) {
                    NavigationView {
                        List {
                            if cityDataService.usStates.isEmpty {
                                Text("Loading states...")
                                    .foregroundColor(.secondary)
                            } else {
                                ForEach(cityDataService.usStates, id: \.self) { state in
                                    Button(action: {
                                        selectedState = state
                                        showingStatePicker = false
                                    }) {
                                        HStack {
                                            Text(state)
                                                .foregroundColor(.primary)
                                            Spacer()
                                            if selectedState == state {
                                                Image(systemName: "checkmark")
                                                    .foregroundColor(.accentColor)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .navigationTitle("Select State")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    showingStatePicker = false
                                }
                            }
                        }
                    }
                }
                
                Text("\(cityDataService.usStates.count) states available")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
            .padding(.top)
            
            if !selectedState.isEmpty {
                StateCitiesView(state: selectedState, cityDataService: cityDataService)
            } else {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "map")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary)
                    Text("Select a state to view cities")
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
        }
    }
}

struct CountriesListView: View {
    @ObservedObject var cityDataService: CityDataService
    @State private var selectedCountry: String = ""
    @State private var showingCountryPicker = false
    
    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Select a Country")
                    .font(.headline)
                    .padding(.horizontal)
                
                Button(action: {
                    showingCountryPicker = true
                }) {
                    HStack {
                        Text(selectedCountry.isEmpty ? "Choose a country..." : selectedCountry)
                            .foregroundColor(selectedCountry.isEmpty ? .secondary : .primary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                .accessibilityLabel(selectedCountry.isEmpty ? "Choose a country" : "Selected country: \(selectedCountry)")
                .accessibilityHint("Double tap to see list of countries")
                .sheet(isPresented: $showingCountryPicker) {
                    NavigationView {
                        List {
                            if cityDataService.countries.isEmpty {
                                Text("Loading countries...")
                                    .foregroundColor(.secondary)
                            } else {
                                ForEach(cityDataService.countries, id: \.self) { country in
                                    Button(action: {
                                        selectedCountry = country
                                        showingCountryPicker = false
                                    }) {
                                        HStack {
                                            Text(country)
                                                .foregroundColor(.primary)
                                            Spacer()
                                            if selectedCountry == country {
                                                Image(systemName: "checkmark")
                                                    .foregroundColor(.accentColor)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .navigationTitle("Select Country")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    showingCountryPicker = false
                                }
                            }
                        }
                    }
                }
                
                Text("\(cityDataService.countries.count) countries available")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
            .padding(.top)
            
            if !selectedCountry.isEmpty {
                CountryCitiesView(country: selectedCountry, cityDataService: cityDataService)
            } else {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "globe")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary)
                    Text("Select a country to view cities")
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
        }
    }
}