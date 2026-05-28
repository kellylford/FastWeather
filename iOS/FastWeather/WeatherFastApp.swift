//
//  WeatherFastApp.swift
//  Fast Weather
//
//  Created on 2026
//

import SwiftUI

@main
struct FastWeatherApp: App {
    @StateObject private var weatherService = WeatherService()
    @StateObject private var settingsManager = SettingsManager()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        iCloudSyncService.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(weatherService)
                .environmentObject(settingsManager)
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        iCloudSyncService.shared.synchronize()
                    }
                }
        }
    }
}
