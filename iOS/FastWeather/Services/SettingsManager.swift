//
//  SettingsManager.swift
//  Weather Fast
//
//  Manager for app settings and preferences
//

import Foundation
import Combine

class SettingsManager: ObservableObject {
    @Published var settings: AppSettings
    
    private let userDefaultsKey = "AppSettings"
    
    init() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let settings = try? JSONDecoder().decode(AppSettings.self, from: data) {
            self.settings = settings
        } else {
            self.settings = AppSettings()
        }
    }
    
    func saveSettings() {
        if let encoded = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }
    
    func resetToDefaults() {
        settings = AppSettings()
        saveSettings()
    }
}
