//
//  ContentView.swift
//  Weather Fast
//
//  Main view with tab navigation
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var weatherService: WeatherService
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var selectedTab = 0
    
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
    }
}

#Preview {
    ContentView()
        .environmentObject(WeatherService())
        .environmentObject(SettingsManager())
}
