//
//  MyCitiesView.swift
//  Weather Fast
//
//  View for displaying saved cities with three view options: Flat, Table, List
//

import SwiftUI

struct MyCitiesView: View {
    @EnvironmentObject var weatherService: WeatherService
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var showingSettings = false
    @State private var showingAddCity = false
    @State private var quickSearchText = ""
    @FocusState private var isSearchFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Quick search field at top
                HStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search for a city or zip code", text: $quickSearchText)
                            .textFieldStyle(.plain)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .focused($isSearchFieldFocused)
                            .accessibilityLabel("Quick city search")
                            .accessibilityHint("Enter city name or zip code to search")
                            .accessibilityValue(quickSearchText.isEmpty ? "Empty" : quickSearchText)
                        
                        if !quickSearchText.isEmpty {
                            Button(action: {
                                quickSearchText = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .accessibilityLabel("Clear search")
                        }
                    }
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    
                    Button(action: {
                        showingAddCity = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                    .accessibilityLabel("Add City")
                    .accessibilityHint("Opens advanced search to add a new city")
                }
                .padding()
                .background(Color(.systemBackground))
                .onSubmit {
                    if !quickSearchText.isEmpty {
                        showingAddCity = true
                    }
                }
                
                Divider()
                
                Group {
                    if weatherService.savedCities.isEmpty {
                        EmptyStateView()
                    } else {
                        viewContent
                    }
                }
            }
            .navigationTitle("Weather Fast")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Picker("View Style", selection: $settingsManager.settings.defaultView) {
                            ForEach(ViewType.allCases, id: \.self) { viewType in
                                Label(viewType.rawValue, systemImage: iconForViewType(viewType))
                                    .tag(viewType)
                            }
                        }
                        .onChange(of: settingsManager.settings.defaultView) {
                            settingsManager.saveSettings()
                        }
                        
                        Divider()
                        
                        Button(action: {
                            Task {
                                await weatherService.refreshAllWeather()
                            }
                        }) {
                            Label("Refresh All", systemImage: "arrow.clockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .accessibilityLabel("Options Menu")
                    }
                }
            }
            .sheet(isPresented: $showingAddCity) {
                AddCitySearchView(initialSearchText: quickSearchText)
            }
            .refreshable {
                await weatherService.refreshAllWeather()
            }
        }
        .navigationViewStyle(.stack)
    }
    
    @ViewBuilder
    private var viewContent: some View {
        switch settingsManager.settings.defaultView {
        case .flat:
            FlatView()
        case .table:
            TableView()
        case .list:
            ListView()
        }
    }
    
    private func iconForViewType(_ viewType: ViewType) -> String {
        switch viewType {
        case .flat: return "square.grid.2x2"
        case .table: return "tablecells"
        case .list: return "list.bullet"
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
