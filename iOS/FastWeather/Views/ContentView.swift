//
//  ContentView.swift
//  Fast Weather
//
//  Main view with tab navigation
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var weatherService: WeatherService
    @EnvironmentObject var settingsManager: SettingsManager
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab = 0
    @State private var hasStartedWeatherFetch = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            MyCitiesView()
                .tabItem {
                    Label("My Cities", systemImage: "list.bullet")
                }
                .tag(0)
                .accessibilityLabel("My Cities")
                .accessibilityHint("Tab 1 of 3")
                .accessibilityAddTraits(.isButton)
            
            BrowseCitiesView()
                .tabItem {
                    Label("Browse", systemImage: "magnifyingglass")
                }
                .tag(1)
                .accessibilityLabel("Browse Cities")
                .accessibilityHint("Tab 2 of 3")
                .accessibilityAddTraits(.isButton)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(2)
                .accessibilityLabel("Settings")
                .accessibilityHint("Tab 3 of 3")
                .accessibilityAddTraits(.isButton)
        }
        .accessibilityElement(children: .contain)
        .task {
            // Start weather fetch as early as possible - don't wait for MyCitiesView
            guard !hasStartedWeatherFetch else { return }
            hasStartedWeatherFetch = true
            await weatherService.refreshAllWeather()
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Refresh when returning to foreground, but only after the initial load
            // has already run. The 10-minute in-memory cache means brief background
            // trips are free — fetchWeatherForDate returns early if data is still fresh.
            guard newPhase == .active, hasStartedWeatherFetch else { return }
            Task {
                await weatherService.refreshAllWeather()
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(WeatherService())
        .environmentObject(SettingsManager())
}
