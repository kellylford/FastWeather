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
    @StateObject private var featureFlags = FeatureFlags.shared
    @State private var showingResetAlert = false
    @State private var showingDeveloperSettings = false
    
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
                    
                    Picker(selection: $settingsManager.settings.distanceUnit) {
                        ForEach(DistanceUnit.allCases, id: \.self) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    } label: {
                        HStack {
                            Text("Distance")
                            Spacer()
                            Text(settingsManager.settings.distanceUnit.rawValue)
                                .foregroundColor(.secondary)
                        }
                    }
                    .onChange(of: settingsManager.settings.distanceUnit) { oldValue, newValue in
                        // Convert and snap weatherAroundMeDistance to nearest nice value in new unit
                        // Must update both values atomically to prevent picker confusion
                        DispatchQueue.main.async {
                            let kilometers = oldValue.toKilometers(settingsManager.settings.weatherAroundMeDistance)
                            let convertedValue = newValue.convert(kilometers)
                            let snappedValue = newValue.snapToNearest(convertedValue)
                            settingsManager.settings.weatherAroundMeDistance = snappedValue
                            settingsManager.saveSettings()
                        }
                    }
                    .accessibilityLabel("Distance unit, currently \(settingsManager.settings.distanceUnit.rawValue)")
                    
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
                
                // Weather Around Me section
                Section(header: Text("Weather Around Me")) {
                    Picker("Default Distance", selection: $settingsManager.settings.weatherAroundMeDistance) {
                        ForEach(settingsManager.settings.distanceUnit.weatherAroundMeOptions, id: \.self) { distance in
                            Text(settingsManager.settings.distanceUnit.format(distance)).tag(distance)
                        }
                    }
                    .onChange(of: settingsManager.settings.weatherAroundMeDistance) {
                        settingsManager.saveSettings()
                    }
                    .accessibilityLabel("Default distance for Weather Around Me, currently \(settingsManager.settings.distanceUnit.format(settingsManager.settings.weatherAroundMeDistance))")
                    .accessibilityHint("Sets the default radius when viewing weather conditions around a city")
                }
                
                // Features section
                Section(header: Text("Features"),
                       footer: Text("Enable or disable app features.")) {
                    Toggle("Expected Precipitation", isOn: $featureFlags.radarEnabled)
                        .accessibilityLabel("Expected Precipitation feature")
                        .accessibilityHint("Shows precipitation forecast visualization")
                    
                    Toggle("Weather Around Me", isOn: $featureFlags.weatherAroundMeEnabled)
                        .accessibilityLabel("Weather Around Me feature")
                        .accessibilityHint("Compare weather conditions in nearby cities")
                    
                    Toggle("International Weather Alerts", isOn: $featureFlags.weatherKitAlertsEnabled)
                        .accessibilityLabel("International Weather Alerts")
                        .accessibilityHint("Enable weather alerts for international cities using Apple WeatherKit. US cities always use National Weather Service.")
                }
                
                // Display preferences section
                Section(header: Text("Display Options")) {
                    Picker(selection: $settingsManager.settings.viewMode) {
                        ForEach(ViewMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    } label: {
                        HStack {
                            Text("View Mode")
                            Spacer()
                            Text(settingsManager.settings.viewMode.rawValue)
                                .foregroundColor(.secondary)
                        }
                    }
                    .onChange(of: settingsManager.settings.viewMode) {
                        settingsManager.saveSettings()
                    }
                    .accessibilityLabel("View mode, currently \(settingsManager.settings.viewMode.rawValue)")
                    .accessibilityHint("Choose between List or Flat view")
                    
                    Picker(selection: $settingsManager.settings.displayMode) {
                        ForEach(DisplayMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    } label: {
                        HStack {
                            Text("List Content Display")
                            Spacer()
                            Text(settingsManager.settings.displayMode.rawValue)
                                .foregroundColor(.secondary)
                        }
                    }
                    .onChange(of: settingsManager.settings.displayMode) {
                        settingsManager.saveSettings()
                    }
                    .accessibilityLabel("List content display, currently \(settingsManager.settings.displayMode.rawValue)")
                    .accessibilityHint("Condensed shows values only in List view, Details shows labels with values")
                }
                
                // City List View Data
                Section(header: Text("City List View"),
                       footer: Text("Choose which data appears in your city list. Toggle to show/hide, use VoiceOver actions to reorder.")) {
                    ForEach(Array(settingsManager.settings.weatherFields.enumerated()), id: \.element.id) { index, field in
                        HStack {
                            Image(systemName: "line.3.horizontal")
                                .foregroundColor(.secondary)
                                .accessibilityHidden(true)
                            
                            Toggle(isOn: Binding(
                                get: { field.isEnabled },
                                set: { newValue in
                                    settingsManager.settings.weatherFields[index].isEnabled = newValue
                                    settingsManager.saveSettings()
                                }
                            )) {
                                Text(field.type.rawValue)
                                    .font(.body)
                            }
                            .accessibilityLabel("\(field.type.rawValue)")
                            .accessibilityHint(field.isEnabled ? "Enabled, double tap to disable" : "Disabled, double tap to enable")
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction(named: "Move Up") {
                            moveFieldUp(at: index)
                        }
                        .accessibilityAction(named: "Move Down") {
                            moveFieldDown(at: index)
                        }
                    }
                    .onMove { from, to in
                        settingsManager.settings.weatherFields.move(fromOffsets: from, toOffset: to)
                        settingsManager.saveSettings()
                    }
                    
                    // UV Index for list view
                    Toggle("UV Index", isOn: $settingsManager.settings.showUVIndex)
                        .onChange(of: settingsManager.settings.showUVIndex) {
                            settingsManager.saveSettings()
                        }
                        .accessibilityLabel("Show UV Index in city list")
                }
                
                // Today's Forecast section
                Section(header: Text("Today's Forecast"),
                       footer: Text("Configure alerts and warnings shown in the Today's Forecast summary.")) {
                    Toggle("Precipitation Alerts", isOn: $settingsManager.settings.showPrecipitationProbability)
                        .onChange(of: settingsManager.settings.showPrecipitationProbability) {
                            settingsManager.saveSettings()
                        }
                        .accessibilityLabel("Show precipitation probability alerts")
                        .accessibilityHint("Shows alert when precipitation probability exceeds 20 percent")
                    
                    Toggle("UV Warnings", isOn: $settingsManager.settings.showUVIndex)
                        .onChange(of: settingsManager.settings.showUVIndex) {
                            settingsManager.saveSettings()
                        }
                        .accessibilityLabel("Show UV index warnings")
                        .accessibilityHint("Shows warning when UV index is 6 or higher")
                    
                    Toggle("Wind Alerts", isOn: $settingsManager.settings.showWindGusts)
                        .onChange(of: settingsManager.settings.showWindGusts) {
                            settingsManager.saveSettings()
                        }
                        .accessibilityLabel("Show wind speed alerts")
                        .accessibilityHint("Shows alert when wind speed exceeds 25 kilometers per hour")
                    
                    Toggle("Daylight Duration", isOn: $settingsManager.settings.showDaylightDuration)
                        .onChange(of: settingsManager.settings.showDaylightDuration) {
                            settingsManager.saveSettings()
                        }
                        .accessibilityLabel("Show daylight duration")
                    
                    Toggle("Sunshine Duration", isOn: $settingsManager.settings.showSunshineDuration)
                        .onChange(of: settingsManager.settings.showSunshineDuration) {
                            settingsManager.saveSettings()
                        }
                        .accessibilityLabel("Show sunshine duration")
                }
                
                // Current Weather Detail Sections
                Section(header: Text("Current Weather Detail View"),
                       footer: Text("Toggle which sections appear in the current weather detail view. Use VoiceOver actions to reorder sections.")) {
                    ForEach(Array(settingsManager.settings.detailCategories.enumerated()), id: \.element.id) { index, category in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "line.3.horizontal")
                                    .foregroundColor(.secondary)
                                    .accessibilityHidden(true)
                                
                                Toggle(isOn: Binding(
                                    get: { category.isEnabled },
                                    set: { newValue in
                                        settingsManager.settings.detailCategories[index].isEnabled = newValue
                                        settingsManager.saveSettings()
                                    }
                                )) {
                                    Text(category.category.rawValue)
                                        .font(.body.weight(.semibold))
                                }
                                .accessibilityLabel("\(category.category.rawValue) section")
                                .accessibilityHint(category.isEnabled ? "Enabled, double tap to disable" : "Disabled, double tap to enable")
                            }
                            
                            // Show data items for this category
                            if category.isEnabled {
                                categoryDataItems(for: category.category)
                                    .padding(.leading, 32)
                            }
                        }
                        .accessibilityElement(children: .contain)
                        .accessibilityAction(named: "Move Up") {
                            moveCategoryUp(at: index)
                        }
                        .accessibilityAction(named: "Move Down") {
                            moveCategoryDown(at: index)
                        }
                        .accessibilityAction(named: "Move to Top") {
                            moveCategoryToTop(at: index)
                        }
                        .accessibilityAction(named: "Move to Bottom") {
                            moveCategoryToBottom(at: index)
                        }
                    }
                    .onMove { from, to in
                        settingsManager.settings.detailCategories.move(fromOffsets: from, toOffset: to)
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
                
                // Historical Weather section
                Section(header: Text("Historical Weather"),
                       footer: Text("Set how many years of historical data to retrieve. Lower values load faster.")) {
                    Picker("Years of Data", selection: $settingsManager.settings.historicalYearsBack) {
                        ForEach(1...85, id: \.self) { years in
                            Text("\(years) \(years == 1 ? "year" : "years")").tag(years)
                        }
                    }
                    .pickerStyle(.wheel)
                    .onChange(of: settingsManager.settings.historicalYearsBack) {
                        settingsManager.saveSettings()
                    }
                    .accessibilityLabel("Years of historical data, \(settingsManager.settings.historicalYearsBack) years")
                    
                    Button("Clear Historical Cache") {
                        clearHistoricalCache()
                    }
                    .accessibilityLabel("Clear all cached historical weather data")
                    .accessibilityHint("Tap to delete cached historical data for all cities")
                }
                
                // User Guide section
                Section {
                    NavigationLink(destination: UserGuideView()) {
                        HStack {
                            Image(systemName: "book.fill")
                                .foregroundColor(.blue)
                            Text("User Guide")
                        }
                    }
                    .accessibilityLabel("User Guide")
                    .accessibilityHint("Learn how to use FastWeather features")
                }
                
                // About section
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0 (build 16)")
                            .foregroundColor(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Version 1.0 build 16")
                    
                    Link("Weather Data by Open-Meteo", destination: URL(string: "https://open-meteo.com")!)
                        .accessibilityLabel("Weather data provided by Open-Meteo")
                }
                
                // Developer Settings section (hidden by default)
                Section {
                    Button(action: { showingDeveloperSettings = true }) {
                        HStack {
                            Image(systemName: "hammer.fill")
                                .foregroundColor(.orange)
                            Text("Developer Settings")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .accessibilityLabel("Developer Settings")
                    .accessibilityHint("Configure feature flags and experimental features")
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
            .onChange(of: showingResetAlert) { oldValue, newValue in
                // Flash detection: Alert should never go from true to true
                if oldValue == true && newValue == true {
                    print("⚠️ ALERT FLASH DETECTED in SettingsView reset alert!")
                }
            }
            .sheet(isPresented: $showingDeveloperSettings) {
                DeveloperSettingsView()
            }
        }
        .navigationViewStyle(.stack)
    }
    
    // MARK: - Helper Methods
    
    private func clearHistoricalCache() {
        // Clear cache for all saved cities
        for city in weatherService.savedCities {
            HistoricalWeatherCache.shared.clearCache(for: city)
        }
        UIAccessibility.post(notification: .announcement, argument: "Historical weather cache cleared for all cities")
    }
    
    private func moveCategoryUp(at index: Int) {
        guard index > 0 else { return }
        let categoryName = settingsManager.settings.detailCategories[index].category.rawValue
        let aboveCategoryName = settingsManager.settings.detailCategories[index - 1].category.rawValue
        settingsManager.settings.detailCategories.move(fromOffsets: IndexSet(integer: index), toOffset: index - 1)
        settingsManager.saveSettings()
        UIAccessibility.post(notification: .announcement, argument: "Moved \(categoryName) above \(aboveCategoryName)")
    }
    
    private func moveCategoryDown(at index: Int) {
        guard index < settingsManager.settings.detailCategories.count - 1 else { return }
        let categoryName = settingsManager.settings.detailCategories[index].category.rawValue
        let belowCategoryName = settingsManager.settings.detailCategories[index + 1].category.rawValue
        settingsManager.settings.detailCategories.move(fromOffsets: IndexSet(integer: index), toOffset: index + 2)
        settingsManager.saveSettings()
        UIAccessibility.post(notification: .announcement, argument: "Moved \(categoryName) below \(belowCategoryName)")
    }
    
    private func moveCategoryToTop(at index: Int) {
        guard index > 0 else { return }
        let categoryName = settingsManager.settings.detailCategories[index].category.rawValue
        settingsManager.settings.detailCategories.move(fromOffsets: IndexSet(integer: index), toOffset: 0)
        settingsManager.saveSettings()
        UIAccessibility.post(notification: .announcement, argument: "Moved \(categoryName) to top")
    }
    
    // MARK: - Category Data Items
    @ViewBuilder
    private func categoryDataItems(for category: DetailCategory) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            switch category {
            case .weatherAlerts:
                Text("• Active weather warnings")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
            case .currentConditions:
                Text("• Temperature, Feels Like")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("• Wind Speed, Direction")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("• Humidity, Pressure")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Toggle("Wind Gusts", isOn: $settingsManager.settings.showWindGusts)
                    .font(.caption)
                    .onChange(of: settingsManager.settings.showWindGusts) {
                        settingsManager.saveSettings()
                    }
                    .accessibilityLabel("Show wind gusts in current conditions")
                Toggle("UV Index", isOn: $settingsManager.settings.showUVIndex)
                    .font(.caption)
                    .onChange(of: settingsManager.settings.showUVIndex) {
                        settingsManager.saveSettings()
                    }
                    .accessibilityLabel("Show UV index in current conditions")
                Toggle("Dew Point", isOn: $settingsManager.settings.showDewPoint)
                    .font(.caption)
                    .onChange(of: settingsManager.settings.showDewPoint) {
                        settingsManager.saveSettings()
                    }
                    .accessibilityLabel("Show dew point in current conditions")
                
            case .precipitation:
                Text("• Current precipitation")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Toggle("Precipitation Probability", isOn: $settingsManager.settings.showPrecipitationProbability)
                    .font(.caption)
                    .onChange(of: settingsManager.settings.showPrecipitationProbability) {
                        settingsManager.saveSettings()
                    }
                    .accessibilityLabel("Show precipitation probability")
                
            case .todaysForecast:
                Text("• Automatic daily summary")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("• Sunrise, Sunset times")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Toggle("Daylight Duration", isOn: $settingsManager.settings.showDaylightDuration)
                    .font(.caption)
                    .onChange(of: settingsManager.settings.showDaylightDuration) {
                        settingsManager.saveSettings()
                    }
                    .accessibilityLabel("Show daylight duration")
                Toggle("Sunshine Duration", isOn: $settingsManager.settings.showSunshineDuration)
                    .font(.caption)
                    .onChange(of: settingsManager.settings.showSunshineDuration) {
                        settingsManager.saveSettings()
                    }
                    .accessibilityLabel("Show sunshine duration")
                
            case .hourlyForecast:
                Text("• Temperature, conditions")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("• Precipitation, wind")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
            case .dailyForecast:
                Text("• High/Low temperatures")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("• Precipitation, wind")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
            case .historicalWeather:
                Text("• Past year comparisons")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
            case .location:
                Text("• Coordinates, elevation")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func moveCategoryToBottom(at index: Int) {
        guard index < settingsManager.settings.detailCategories.count - 1 else { return }
        let categoryName = settingsManager.settings.detailCategories[index].category.rawValue
        settingsManager.settings.detailCategories.move(fromOffsets: IndexSet(integer: index), toOffset: settingsManager.settings.detailCategories.count)
        settingsManager.saveSettings()
        UIAccessibility.post(notification: .announcement, argument: "Moved \(categoryName) to bottom")
    }
    
    private func moveFieldUp(at index: Int) {
        guard index > 0 else { return }
        let fieldName = settingsManager.settings.weatherFields[index].type.rawValue
        let aboveFieldName = settingsManager.settings.weatherFields[index - 1].type.rawValue
        settingsManager.settings.weatherFields.move(fromOffsets: IndexSet(integer: index), toOffset: index - 1)
        settingsManager.saveSettings()
        UIAccessibility.post(notification: .announcement, argument: "Moved \(fieldName) above \(aboveFieldName)")
    }
    
    private func moveFieldDown(at index: Int) {
        guard index < settingsManager.settings.weatherFields.count - 1 else { return }
        let fieldName = settingsManager.settings.weatherFields[index].type.rawValue
        let belowFieldName = settingsManager.settings.weatherFields[index + 1].type.rawValue
        settingsManager.settings.weatherFields.move(fromOffsets: IndexSet(integer: index), toOffset: index + 2)
        settingsManager.saveSettings()
        UIAccessibility.post(notification: .announcement, argument: "Moved \(fieldName) below \(belowFieldName)")
    }
}

#Preview {
    SettingsView()
        .environmentObject(SettingsManager())
        .environmentObject(WeatherService())
}
