//
//  SettingsView.swift
//  Fast Weather
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
                    Picker(selection: $settingsManager.settings.temperatureUnit) {
                        ForEach(TemperatureUnit.allCases, id: \.self) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    } label: {
                        HStack {
                            Text("Temperature")
                            Spacer()
                            Text(settingsManager.settings.temperatureUnit.rawValue)
                                .foregroundColor(.secondary)
                        }
                    }
                    .onChange(of: settingsManager.settings.temperatureUnit) {
                        settingsManager.saveSettings()
                    }
                    .accessibilityLabel("Temperature unit, currently \(settingsManager.settings.temperatureUnit.rawValue)")
                    
                    Picker(selection: $settingsManager.settings.windSpeedUnit) {
                        ForEach(WindSpeedUnit.allCases, id: \.self) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    } label: {
                        HStack {
                            Text("Wind Speed")
                            Spacer()
                            Text(settingsManager.settings.windSpeedUnit.rawValue)
                                .foregroundColor(.secondary)
                        }
                    }
                    .onChange(of: settingsManager.settings.windSpeedUnit) {
                        settingsManager.saveSettings()
                    }
                    .accessibilityLabel("Wind speed unit, currently \(settingsManager.settings.windSpeedUnit.rawValue)")
                    
                    Picker(selection: $settingsManager.settings.precipitationUnit) {
                        ForEach(PrecipitationUnit.allCases, id: \.self) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    } label: {
                        HStack {
                            Text("Precipitation")
                            Spacer()
                            Text(settingsManager.settings.precipitationUnit.rawValue)
                                .foregroundColor(.secondary)
                        }
                    }
                    .onChange(of: settingsManager.settings.precipitationUnit) {
                        settingsManager.saveSettings()
                    }
                    .accessibilityLabel("Precipitation unit, currently \(settingsManager.settings.precipitationUnit.rawValue)")
                    
                    Picker(selection: $settingsManager.settings.pressureUnit) {
                        ForEach(PressureUnit.allCases, id: \.self) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    } label: {
                        HStack {
                            Text("Pressure")
                            Spacer()
                            Text(settingsManager.settings.pressureUnit.rawValue)
                                .foregroundColor(.secondary)
                        }
                    }
                    .onChange(of: settingsManager.settings.pressureUnit) {
                        settingsManager.saveSettings()
                    }
                    .accessibilityLabel("Pressure unit, currently \(settingsManager.settings.pressureUnit.rawValue)")
                }
                
                // Display preferences section
                Section(header: Text("Display Mode")) {
                    Picker("Display Mode", selection: $settingsManager.settings.displayMode) {
                        ForEach(DisplayMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .onChange(of: settingsManager.settings.displayMode) {
                        settingsManager.saveSettings()
                    }
                    .accessibilityLabel("Weather display mode")
                    .accessibilityHint("Condensed shows values only, Details shows labels with values")
                }
                .listRowSeparator(.visible)
                
                // Weather fields section with reordering
                Section(header: Text("Weather Fields"),
                       footer: Text("Drag to reorder. City info is always shown first. Toggle to show/hide each field.")) {
                    ForEach($settingsManager.settings.weatherFields) { $field in
                        HStack {
                            Image(systemName: "line.3.horizontal")
                                .foregroundColor(.secondary)
                                .accessibilityHidden(true)
                            
                            Toggle(isOn: $field.isEnabled) {
                                Text(field.type.rawValue)
                                    .font(.body)
                            }
                            .onChange(of: field.isEnabled) {
                                settingsManager.saveSettings()
                            }
                            .accessibilityLabel("\(field.type.rawValue)")
                            .accessibilityHint(field.isEnabled ? "Enabled, double tap to disable" : "Disabled, double tap to enable")
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(.isButton)
                    }
                    .onMove { from, to in
                        settingsManager.settings.weatherFields.move(fromOffsets: from, toOffset: to)
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
            .toolbar {
                EditButton()
                    .accessibilityLabel("Edit weather fields order")
                    .accessibilityHint("Tap to enable reordering of weather fields")
            }
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
