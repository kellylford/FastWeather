//
//  MyDataConfigView.swift
//  Fast Weather
//
//  Configuration view for the user's custom "My Data" section.
//  Allows browsing all Open-Meteo current-condition parameters by category,
//  previewing live values, and adding/removing data points.
//

import SwiftUI

struct MyDataConfigView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var weatherService: WeatherService
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedCategory: MyDataCategory = .temperature
    @State private var previewCityIndex: Int = 0
    @State private var previewWeather: WeatherData?
    @State private var isLoadingPreview: Bool = false
    @State private var showResetConfirmation: Bool = false
    
    private var previewCity: City? {
        guard !weatherService.savedCities.isEmpty,
              previewCityIndex < weatherService.savedCities.count else {
            return weatherService.savedCities.first
        }
        return weatherService.savedCities[previewCityIndex]
    }
    
    private var addedParameterKeys: Set<String> {
        Set(settingsManager.settings.myDataFields.map { $0.parameter.rawValue })
    }
    
    private var enabledFieldCount: Int {
        settingsManager.settings.myDataFields.filter { $0.isEnabled }.count
    }
    
    var body: some View {
        NavigationView {
            Form {
                // City picker for live preview
                if !weatherService.savedCities.isEmpty {
                    Section(header: Text("Preview City"),
                            footer: Text("Select a city to preview live data values. Your My Data configuration applies to all cities.")) {
                        Picker(selection: $previewCityIndex) {
                            ForEach(weatherService.savedCities.indices, id: \.self) { index in
                                Text(weatherService.savedCities[index].displayName)
                                    .tag(index)
                            }
                        } label: {
                            HStack {
                                Text("City")
                                Spacer()
                                if let city = previewCity {
                                    Text(city.displayName)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .accessibilityLabel("Preview city: \(previewCity?.displayName ?? "None")")
                        .accessibilityHint("Choose a city to see live data values while configuring")
                        .onChange(of: previewCityIndex) {
                            Task { await loadPreviewWeather() }
                        }
                    }
                } else {
                    Section {
                        Text("Add cities first to preview live data values.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Category picker
                Section(header: Text("Data Category")) {
                    Picker(selection: $selectedCategory) {
                        ForEach(MyDataCategory.allCases, id: \.self) { category in
                            Text(category.displayName).tag(category)
                        }
                    } label: {
                        HStack {
                            Text("Category")
                            Spacer()
                            Text(selectedCategory.displayName)
                                .foregroundColor(.secondary)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityLabel("Data category: \(selectedCategory.displayName)")
                    .accessibilityHint("Choose a category to browse available data points")
                }
                
                // Parameters for selected category
                Section(header: Text(selectedCategory.displayName),
                        footer: Text("\(enabledFieldCount) data point\(enabledFieldCount == 1 ? "" : "s") selected")) {
                    let parameters = MyDataParameter.parameters(for: selectedCategory)
                    ForEach(parameters, id: \.self) { parameter in
                        parameterRow(for: parameter)
                    }
                }
                
                // Summary of selected items
                if !settingsManager.settings.myDataFields.isEmpty {
                    Section(header: Text("Selected Data Points")) {
                        ForEach(settingsManager.settings.myDataFields) { field in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(field.parameter.displayName)
                                        .font(.subheadline)
                                    Text(field.parameter.category.displayName)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Button(action: {
                                    removeParameter(field.parameter)
                                }) {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                        .imageScale(.large)
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel("Remove \(field.parameter.displayName)")
                                .accessibilityHint("Double tap to remove this data point from My Data")
                            }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("\(field.parameter.displayName), \(field.parameter.category.displayName), added")
                            .accessibilityAction(named: "Remove") {
                                removeParameter(field.parameter)
                            }
                        }
                        
                        Button(role: .destructive, action: {
                            showResetConfirmation = true
                        }) {
                            Label("Remove All", systemImage: "trash")
                        }
                        .accessibilityLabel("Remove all selected data points")
                        .accessibilityHint("Removes all data points from My Data section")
                    }
                }
            }
            .navigationTitle("My Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(role: .destructive, action: {
                        showResetConfirmation = true
                    }) {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                    }
                    .disabled(settingsManager.settings.myDataFields.isEmpty)
                    .accessibilityLabel("Reset My Data")
                    .accessibilityHint("Removes all data points from My Data section")
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        // Auto-enable the My Data section if user added data points
                        if !settingsManager.settings.myDataFields.isEmpty {
                            if let idx = settingsManager.settings.detailCategories.firstIndex(where: { $0.category == .myData }) {
                                if !settingsManager.settings.detailCategories[idx].isEnabled {
                                    settingsManager.settings.detailCategories[idx].isEnabled = true
                                    settingsManager.saveSettings()
                                }
                            }
                        }
                        dismiss()
                    }
                }
            }
            .confirmationDialog(
                "Reset My Data",
                isPresented: $showResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Remove All Data Points", role: .destructive) {
                    // Defer removal to next run loop to ensure dialog dismissal completes
                    DispatchQueue.main.async {
                        removeAllParameters()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                let count = settingsManager.settings.myDataFields.count
                Text("This will remove all \(count) data point\(count == 1 ? "" : "s") from My Data.")
            }
            .task {
                await loadPreviewWeather()
            }
        }
    }
    
    // MARK: - Parameter Row
    
    @ViewBuilder
    private func parameterRow(for parameter: MyDataParameter) -> some View {
        let isAdded = addedParameterKeys.contains(parameter.rawValue)
        
        Button(action: {
            if isAdded {
                removeParameter(parameter)
            } else {
                addParameter(parameter)
            }
        }) {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(parameter.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text(parameter.explanation)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer(minLength: 12)
                
                Button(action: {
                    if isAdded {
                        removeParameter(parameter)
                    } else {
                        addParameter(parameter)
                    }
                }) {
                    Image(systemName: isAdded ? "minus.circle.fill" : "plus.circle.fill")
                        .foregroundColor(isAdded ? .red : .green)
                        .imageScale(.large)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.borderless)
            }
            
            // Live value preview
            if let value = currentValue(for: parameter) {
                HStack(spacing: 4) {
                    Text("Current:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(MyDataFormatHelper.format(
                        parameter: parameter,
                        value: value,
                        settings: settingsManager.settings
                    ))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.accentColor)
                }
            } else if isLoadingPreview {
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Loading...")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(for: parameter, isAdded: isAdded))
        .accessibilityHint(isAdded ? "Double tap to remove from My Data" : "Double tap to add to My Data")
    }
    
    // MARK: - Data Access
    
    /// Get the current value for a parameter from the preview weather data
    private func currentValue(for parameter: MyDataParameter) -> Double? {
        guard let weather = previewWeather else { return nil }
        let current = weather.current
        
        // First check named properties for already-decoded fields
        switch parameter {
        case .temperature2m: return current.temperature2m
        case .apparentTemperature: return current.apparentTemperature
        case .relativeHumidity2m: return current.relativeHumidity2m.map { Double($0) }
        case .dewPoint2m: return current.dewpoint2m
        case .windSpeed10m: return current.windSpeed10m
        case .windDirection10m: return current.windDirection10m.map { Double($0) }
        case .windGusts10m: return current.windGusts10m
        case .precipitation: return current.precipitation
        case .rain: return current.rain
        case .showers: return current.showers
        case .snowfall: return current.snowfall
        case .pressureMsl: return current.pressureMsl
        case .cloudCover: return Double(current.cloudCover)
        case .visibility: return current.visibility
        case .weatherCode: return Double(current.weatherCode)
        case .isDay: return current.isDay.map { Double($0) }
        case .uvIndex: return current.uvIndex
        default:
            // Fall back to dynamic myDataValues dict
            return current.myDataValues?[parameter.apiKey]
        }
    }
    
    // MARK: - Actions
    
    private func addParameter(_ parameter: MyDataParameter) {
        guard !addedParameterKeys.contains(parameter.rawValue) else { return }
        settingsManager.settings.myDataFields.append(
            MyDataField(parameter: parameter, isEnabled: true)
        )
        settingsManager.saveSettings()
        UIAccessibility.post(notification: .announcement, argument: "\(parameter.displayName) added to My Data")
        
        // Refresh weather to include new parameter in API call
        if let city = previewCity {
            Task { await loadPreviewWeather(forceRefresh: true) }
            // Also refresh all cities so the new data is available
            Task {
                for savedCity in weatherService.savedCities {
                    await weatherService.fetchWeather(for: savedCity)
                }
            }
        }
    }
    
    private func removeParameter(_ parameter: MyDataParameter) {
        withAnimation {
            var updatedFields = settingsManager.settings.myDataFields
            updatedFields.removeAll { $0.parameter == parameter }
            settingsManager.settings.myDataFields = updatedFields
            settingsManager.saveSettings()
        }
        UIAccessibility.post(notification: .announcement, argument: "\(parameter.displayName) removed from My Data")
    }
    
    private func removeAllParameters() {
        withAnimation {
            settingsManager.settings.myDataFields = []
            settingsManager.saveSettings()
        }
        UIAccessibility.post(notification: .announcement, argument: "All data points removed from My Data")
    }
    
    // MARK: - Preview Weather Loading
    
    private func loadPreviewWeather(forceRefresh: Bool = false) async {
        guard let city = previewCity else { return }
        
        isLoadingPreview = true
        
        // Check existing cache first
        let cacheKey = WeatherCacheKey(cityId: city.id, dateOffset: 0)
        if !forceRefresh, let cached = weatherService.weatherCache[cacheKey] {
            previewWeather = cached
            isLoadingPreview = false
            return
        }
        
        // Fetch fresh data
        await weatherService.fetchWeather(for: city)
        previewWeather = weatherService.weatherCache[cacheKey]
        isLoadingPreview = false
    }
    
    // MARK: - Accessibility
    
    private func accessibilityLabel(for parameter: MyDataParameter, isAdded: Bool) -> String {
        var label = "\(parameter.displayName). \(parameter.explanation)."
        
        if let value = currentValue(for: parameter) {
            let formatted = MyDataFormatHelper.format(
                parameter: parameter,
                value: value,
                settings: settingsManager.settings
            )
            label += " Current value: \(formatted)."
        }
        
        label += isAdded ? " Added to My Data." : " Not added."
        return label
    }
}

#Preview {
    MyDataConfigView()
        .environmentObject(SettingsManager())
        .environmentObject(WeatherService())
}
