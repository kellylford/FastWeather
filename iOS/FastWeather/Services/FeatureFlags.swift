//
//  FeatureFlags.swift
//  Fast Weather
//
//  Feature flags for controlling visibility of in-development features
//

import Foundation

/// Manages feature flags for controlling app features
/// Use this to hide features in development without needing separate branches
class FeatureFlags: ObservableObject {
    static let shared = FeatureFlags()
    
    // MARK: - Feature Flags
    
    /// Enable/disable precipitation forecast feature (in development)
    /// Set to true to show expected precipitation button and functionality
    @Published var radarEnabled: Bool {
        didSet {
            UserDefaults.standard.set(radarEnabled, forKey: "feature_radar_enabled")
        }
    }
    
    /// Enable/disable weather around me feature (in development)
    /// Set to true to show regional weather comparison button and functionality
    @Published var weatherAroundMeEnabled: Bool {
        didSet {
            UserDefaults.standard.set(weatherAroundMeEnabled, forKey: "feature_weather_around_me_enabled")
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        // Load saved feature flag states
        self.radarEnabled = UserDefaults.standard.bool(forKey: "feature_radar_enabled")
        self.weatherAroundMeEnabled = UserDefaults.standard.bool(forKey: "feature_weather_around_me_enabled")
        
        // Default values (if first launch or not set)
        // Change these to true/false to enable/disable features during development
        if !UserDefaults.standard.contains(key: "feature_radar_enabled") {
            self.radarEnabled = false  // Disabled by default - set to true to test
        }
        if !UserDefaults.standard.contains(key: "feature_weather_around_me_enabled") {
            self.weatherAroundMeEnabled = false  // Disabled by default - set to true to test
        }
    }
    
    // MARK: - Helper Methods
    
    /// Reset all feature flags to defaults
    func resetToDefaults() {
        radarEnabled = false
        weatherAroundMeEnabled = false
        print("🔧 Feature flags reset to defaults")
    }
    
    /// Enable all features (for testing)
    func enableAll() {
        radarEnabled = true
        weatherAroundMeEnabled = true
        print("🔧 All features enabled")
    }
    
    /// Disable all features (for release)
    func disableAll() {
        radarEnabled = false
        weatherAroundMeEnabled = false
        print("🔧 All features disabled")
    }
}

// MARK: - UserDefaults Extension
extension UserDefaults {
    func contains(key: String) -> Bool {
        return object(forKey: key) != nil
    }
}
