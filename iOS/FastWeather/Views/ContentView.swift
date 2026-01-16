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
                .accessibilityLabel("My Cities Tab")
            
            BrowseCitiesView()
                .tabItem {
                    Label("Browse", systemImage: "magnifyingglass")
                }
                .tag(1)
                .accessibilityLabel("Browse Cities Tab")
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(2)
                .accessibilityLabel("Settings Tab")
        }
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    ContentView()
        .environmentObject(WeatherService())
        .environmentObject(SettingsManager())
}
