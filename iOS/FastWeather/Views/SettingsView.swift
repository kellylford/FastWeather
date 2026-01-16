//
//  SettingsView.swift
//  Weather Fast
//
//  Settings and preferences view
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var weatherService: WeatherService
    @State private var showingResetAlert = false
    
    var body: some View {
        NavigationView {
            Form {
                // Units section
                Section(header: Text("Units")) {
                    Picker("Temperature", selection: $settingsManager.settings.temperatureUnit) {
                        ForEach(TemperatureUnit.allCases, id: \.self) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                    .onChange(of: settingsManager.settings.temperatureUnit) {
                        settingsManager.saveSettings()
                    }
                    .accessibilityLabel("Temperature unit")
                    
                    Picker("Wind Speed", selection: $settingsManager.settings.windSpeedUnit) {
                        ForEach(WindSpeedUnit.allCases, id: \.self) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                    .onChange(of: settingsManager.settings.windSpeedUnit) {
                        settingsManager.saveSettings()
                    }
                    .accessibilityLabel("Wind speed unit")
                    
                    Picker("Precipitation", selection: $settingsManager.settings.precipitationUnit) {
                        ForEach(PrecipitationUnit.allCases, id: \.self) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                    .onChange(of: settingsManager.settings.precipitationUnit) {
                        settingsManager.saveSettings()
                    }
                    .accessibilityLabel("Precipitation unit")
                }
                
                // Display preferences section
                Section(header: Text("Display Preferences")) {
                    Picker("Default View", selection: $settingsManager.settings.defaultView) {
                        ForEach(ViewType.allCases, id: \.self) { viewType in
                            Text(viewType.rawValue).tag(viewType)
                        }
                    }
                    .onChange(of: settingsManager.settings.defaultView) {
                        settingsManager.saveSettings()
                    }
                    .accessibilityLabel("Default view type")
                }
                
                // City list fields section
                Section(header: Text("City List Fields"),
                       footer: Text("Select which information to display in the city list")) {
                    Toggle("Temperature", isOn: $settingsManager.settings.showTemperature)
                        .onChange(of: settingsManager.settings.showTemperature) {
                            settingsManager.saveSettings()
                        }
                    
                    Toggle("Conditions", isOn: $settingsManager.settings.showConditions)
                        .onChange(of: settingsManager.settings.showConditions) {
                            settingsManager.saveSettings()
                        }
                    
                    Toggle("Feels Like", isOn: $settingsManager.settings.showFeelsLike)
                        .onChange(of: settingsManager.settings.showFeelsLike) {
                            settingsManager.saveSettings()
                        }
                    
                    Toggle("Humidity", isOn: $settingsManager.settings.showHumidity)
                        .onChange(of: settingsManager.settings.showHumidity) {
                            settingsManager.saveSettings()
                        }
                    
                    Toggle("Wind Speed", isOn: $settingsManager.settings.showWindSpeed)
                        .onChange(of: settingsManager.settings.showWindSpeed) {
                            settingsManager.saveSettings()
                        }
                    
                    Toggle("Wind Direction", isOn: $settingsManager.settings.showWindDirection)
                        .onChange(of: settingsManager.settings.showWindDirection) {
                            settingsManager.saveSettings()
                        }
                    
                    Toggle("High Temperature", isOn: $settingsManager.settings.showHighTemp)
                        .onChange(of: settingsManager.settings.showHighTemp) {
                            settingsManager.saveSettings()
                        }
                    
                    Toggle("Low Temperature", isOn: $settingsManager.settings.showLowTemp)
                        .onChange(of: settingsManager.settings.showLowTemp) {
                            settingsManager.saveSettings()
                        }
                    
                    Toggle("Sunrise", isOn: $settingsManager.settings.showSunrise)
                        .onChange(of: settingsManager.settings.showSunrise) {
                            settingsManager.saveSettings()
                        }
                    
                    Toggle("Sunset", isOn: $settingsManager.settings.showSunset)
                        .onChange(of: settingsManager.settings.showSunset) {
                            settingsManager.saveSettings()
                        }
                }
                
                // Data management section
                Section(header: Text("Data Management")) {
                    Button("Clear All Cities") {
                        showingResetAlert = true
                    }
                    .foregroundColor(.red)
                    .accessibilityLabel("Clear all saved cities")
                    
                    Button("Reset Settings to Default") {
                        settingsManager.resetToDefaults()
                    }
                    .accessibilityLabel("Reset all settings to default values")
                }
                
                // About section
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Version 1.0.0")
                    
                    Link("Weather Data by Open-Meteo", destination: URL(string: "https://open-meteo.com")!)
                        .accessibilityLabel("Weather data provided by Open-Meteo")
                }
            }
            .navigationTitle("Settings")
            .alert("Clear All Cities", isPresented: $showingResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    weatherService.savedCities.removeAll()
                    weatherService.weatherCache.removeAll()
                }
            } message: {
                Text("Are you sure you want to remove all saved cities? This action cannot be undone.")
            }
        }
        .navigationViewStyle(.stack)
    }
}

#Preview {
    SettingsView()
        .environmentObject(SettingsManager())
        .environmentObject(WeatherService())
}
