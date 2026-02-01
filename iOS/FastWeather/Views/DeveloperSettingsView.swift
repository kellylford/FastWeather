//
//  DeveloperSettingsView.swift
//  Fast Weather
//
//  Developer settings for toggling feature flags and testing
//

import SwiftUI

struct DeveloperSettingsView: View {
    @StateObject private var featureFlags = FeatureFlags.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Feature Flags")) {
                    Toggle("Expected Precipitation", isOn: $featureFlags.radarEnabled)
                        .accessibilityLabel("Expected Precipitation feature toggle")
                        .accessibilityHint(featureFlags.radarEnabled ? "Expected Precipitation is currently enabled" : "Expected Precipitation is currently disabled")
                    
                    Toggle("Weather Around Me", isOn: $featureFlags.weatherAroundMeEnabled)
                        .accessibilityLabel("Weather Around Me feature toggle")
                        .accessibilityHint(featureFlags.weatherAroundMeEnabled ? "Weather Around Me is currently enabled" : "Weather Around Me is currently disabled")
                    
                    Toggle("WeatherKit International Alerts", isOn: $featureFlags.weatherKitAlertsEnabled)
                        .accessibilityLabel("WeatherKit International Alerts feature toggle")
                        .accessibilityHint(featureFlags.weatherKitAlertsEnabled ? "WeatherKit alerts for international cities are currently enabled. US cities use NWS." : "WeatherKit alerts are currently disabled. Only US cities will show alerts via NWS.")
                }
                
                Section(header: Text("Location Features"), footer: Text("Current location uses GPS to automatically detect your city. This requires location permission.")) {
                    HStack {
                        Text("Find My Location")
                        Spacer()
                        Image(systemName: "location.fill")
                            .foregroundColor(.green)
                    }
                    
                    Text("Available in Add City screen. Press \"Use My Current Location\" button to automatically add your current city.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section(header: Text("Alert Sources"), footer: Text("US cities always use National Weather Service for detailed alerts. When enabled, international cities use Apple WeatherKit for government weather warnings. Note: WeatherKit alert coverage is limited to select countries (Canada, parts of Europe, Japan, Australia, etc.). Not all countries are supported.")) {
                    HStack {
                        Text("US Cities")
                        Spacer()
                        Text("NWS")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("International")
                        Spacer()
                        Text(featureFlags.weatherKitAlertsEnabled ? "WeatherKit*" : "None")
                            .foregroundColor(featureFlags.weatherKitAlertsEnabled ? .green : .secondary)
                    }
                    
                    if featureFlags.weatherKitAlertsEnabled {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("* Limited Coverage")
                                .font(.caption)
                                .foregroundColor(.orange)
                            Text("WeatherKit alerts work in: Canada, UK, Germany, France, Spain, Italy, Japan, Australia, and other select countries. Russia, many Asian countries, and Africa have limited/no coverage.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                #if targetEnvironment(simulator)
                Section(header: Text("⚠️ Simulator Detected")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("WeatherKit may not work properly on iOS Simulator")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                        
                        Text("To test international alerts:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("1. Build to a real iPhone device")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("2. Ensure device is signed in to iCloud")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("3. Check console for authentication errors")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                #endif
                
                Section(header: Text("Quick Actions")) {
                    Button(action: {
                        featureFlags.enableAll()
                    }) {
                        Label("Enable All Features", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                    
                    Button(action: {
                        featureFlags.disableAll()
                    }) {
                        Label("Disable All Features", systemImage: "xmark.circle.fill")
                            .foregroundColor(.orange)
                    }
                    
                    Button(action: {
                        featureFlags.resetToDefaults()
                    }) {
                        Label("Reset to Defaults", systemImage: "arrow.counterclockwise")
                    }
                }
                
                Section(footer: Text("These settings control experimental features that are in development. Changes take effect immediately.")) {
                    EmptyView()
                }
            }
            .navigationTitle("Developer Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    DeveloperSettingsView()
}
