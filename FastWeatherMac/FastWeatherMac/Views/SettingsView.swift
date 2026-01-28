//
//  SettingsView.swift
//  FastWeatherMac
//
//  Created on 12/12/2025.
//  Settings view for preferences
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("useMetricDefault") private var useMetric = true
    @AppStorage("enableVoiceOverDescriptions") private var enableVoiceOverDescriptions = true
    @AppStorage("showWeatherAlerts") private var showWeatherAlerts = true
    @StateObject private var featureFlags = FeatureFlags.shared
    @State private var showingDeveloperSettings = false
    
    var body: some View {
        TabView {
            // MARK: - General Settings
            Form {
                Section {
                    Text("Units")
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    
                    Picker("Temperature:", selection: $useMetric) {
                        Text("Celsius (°C)").tag(true)
                        Text("Fahrenheit (°F)").tag(false)
                    }
                    .pickerStyle(.radioGroup)
                    .accessibilityLabel("Temperature unit")
                    .accessibilityValue(useMetric ? "Celsius" : "Fahrenheit")
                }
                
                Section {
                    Text("Notifications")
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    
                    Toggle("Show weather alerts", isOn: $showWeatherAlerts)
                        .accessibilityLabel("Show weather alerts")
                        .accessibilityHint("Enable to receive weather alerts and warnings")
                }
                
                Section {
                    Text("Developer")
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    
                    Button(action: {
                        showingDeveloperSettings = true
                    }) {
                        HStack {
                            Label("Developer Settings", systemImage: "wrench.and.screwdriver.fill")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Developer Settings")
                    .accessibilityHint("Configure feature flags and experimental features")
                }
            }
            .padding(20)
            .frame(width: 450, height: 400)
            .sheet(isPresented: $showingDeveloperSettings) {
                DeveloperSettingsView()
            }
            .tabItem {
                Text("General")
            }
            .accessibilityElement(children: .contain)
            
            // MARK: - Accessibility Settings
            Form {
                Section {
                    Text("VoiceOver")
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    
                    Toggle("Enhanced weather descriptions", isOn: $enableVoiceOverDescriptions)
                        .accessibilityLabel("Enhanced weather descriptions for VoiceOver")
                        .accessibilityHint("Provides more detailed weather descriptions for screen readers")
                    
                    Text("When enabled, weather information includes additional context for better comprehension with VoiceOver.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                
                Section {
                    Text("Keyboard Navigation")
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        KeyboardShortcutRow(key: "⌘R", description: "Refresh weather")
                        KeyboardShortcutRow(key: "⌘N", description: "Add new city")
                        KeyboardShortcutRow(key: "Delete", description: "Remove selected city")
                        KeyboardShortcutRow(key: "⌘?", description: "Show help")
                        KeyboardShortcutRow(key: "⌘,", description: "Open settings")
                    }
                }
            }
            .padding(20)
            .frame(width: 450, height: 300)
            .tabItem {
                Text("Accessibility")
            }
            .accessibilityElement(children: .contain)
            
            // MARK: - About
            VStack(spacing: 16) {
                Image(systemName: "cloud.sun.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.accentColor)
                    .accessibilityHidden(true)
                
                Text("FastWeather for Mac")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Version 1.0.0")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Divider()
                    .padding(.vertical, 8)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("A fast, accessible weather application for macOS")
                        .multilineTextAlignment(.center)
                    
                    Text("Features:")
                        .font(.headline)
                        .padding(.top, 8)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        BulletPoint("Full VoiceOver support")
                        BulletPoint("WCAG 2.2 AA compliant")
                        BulletPoint("Keyboard navigation")
                        BulletPoint("High contrast support")
                        BulletPoint("Dynamic Type support")
                    }
                    
                    Text("Data provided by Open-Meteo.com (CC BY 4.0)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
                .frame(maxWidth: 350)
            }
            .padding(20)
            .frame(width: 450, height: 300)
            .tabItem {
                Text("About")
            }
            .accessibilityElement(children: .contain)
        }
    }
}

struct KeyboardShortcutRow: View {
    let key: String
    let description: String
    
    var body: some View {
        HStack {
            Text(key)
                .font(.system(.body, design: .monospaced))
                .padding(4)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(4)
            
            Text(description)
                .foregroundColor(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(description): press \(key)")
    }
}

struct BulletPoint: View {
    let text: String
    
    init(_ text: String) {
        self.text = text
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
            Text(text)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    SettingsView()
}
