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
                    
                    Toggle("Show User Guide", isOn: $featureFlags.userGuideEnabled)
                        .accessibilityLabel("User Guide link toggle")
                        .accessibilityHint(featureFlags.userGuideEnabled ? "User Guide link is currently shown in settings" : "User Guide link is currently hidden")
                }
                
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
