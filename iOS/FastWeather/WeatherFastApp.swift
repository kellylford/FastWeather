//
//  WeatherFastApp.swift
//  Weather Fast
//
//  Created on 2026
//

import SwiftUI

@main
struct WeatherFastApp: App {
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
