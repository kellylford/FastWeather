//
//  FastWeatherApp.swift
//  FastWeather
//
//  Created on 2026
//

import SwiftUI

@main
struct FastWeatherApp: App {
    @StateObject private var weatherService = WeatherService()
    @StateObject private var settingsManager = SettingsManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(weatherService)
                .environmentObject(settingsManager)
        }
    }
}
