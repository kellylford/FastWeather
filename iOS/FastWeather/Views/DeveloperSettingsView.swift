//
//  DeveloperSettingsView.swift
//  Fast Weather
//
//  Developer settings for toggling feature flags and testing
//

import SwiftUI

struct DeveloperSettingsView: View {
    @StateObject private var featureFlags = FeatureFlags.shared
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var weatherService: WeatherService
    @Environment(\.dismiss) private var dismiss
    @State private var showingMyDataConfig = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Feature Flags")) {

                    Toggle("My Location Section", isOn: $featureFlags.myLocationEnabled)
                        .accessibilityLabel("My Location feature toggle")
                        .accessibilityHint(featureFlags.myLocationEnabled ? "My Location is enabled. A My Location section appears on the city list when the user setting is also on." : "My Location is disabled globally. The My Location section will not appear regardless of user settings.")

                    Toggle("Specific Place Names", isOn: $featureFlags.specificPlaceNamesEnabled)
                        .accessibilityLabel("Specific Place Names feature toggle")
                        .accessibilityHint(featureFlags.specificPlaceNamesEnabled ? "Specific place names are enabled. Searching for an airport or university shows its full name instead of just the city." : "Specific place names are disabled. All searches label the result by city name only.")

                    Toggle("WeatherKit International Alerts", isOn: $featureFlags.weatherKitAlertsEnabled)
                        .accessibilityLabel("WeatherKit International Alerts feature toggle")
                        .accessibilityHint(featureFlags.weatherKitAlertsEnabled ? "WeatherKit alerts for international cities are currently enabled. US cities use NWS." : "WeatherKit alerts are currently disabled. Only US cities will show alerts via NWS.")
                    
                    Toggle("My Data Custom Section", isOn: $featureFlags.myDataEnabled)
                        .accessibilityLabel("My Data custom section feature toggle")
                        .accessibilityHint(featureFlags.myDataEnabled ? "My Data section is enabled. You can add custom data points to city detail views." : "My Data section is disabled and will not appear in city detail views.")
                    
                    Toggle("WeatherKit Snow Totals", isOn: $featureFlags.weatherKitSnowEnabled)
                        .accessibilityLabel("WeatherKit Snow Totals feature toggle")
                        .accessibilityHint(featureFlags.weatherKitSnowEnabled ? "WeatherKit snow is enabled. Daily snow totals come from Apple WeatherKit instead of Open-Meteo." : "WeatherKit snow is disabled. Daily snow totals use Open-Meteo. Enable to test WeatherKit accuracy on lake-effect snow events.")
                        .onChange(of: featureFlags.weatherKitSnowEnabled) {
                            weatherService.clearWeatherCache()
                            Task { await weatherService.refreshAllWeather() }
                        }

                    Toggle("WeatherKit Expected Precipitation", isOn: $featureFlags.weatherKitNowcastEnabled)
                        .accessibilityLabel("WeatherKit Expected Precipitation feature toggle")
                        .accessibilityHint(featureFlags.weatherKitNowcastEnabled ? "WeatherKit nowcast is enabled. Expected Precipitation uses radar-quality minute-by-minute data from Apple WeatherKit for supported countries." : "WeatherKit nowcast is disabled. Expected Precipitation uses Open-Meteo NWP for all cities, restoring the older experience.")

                    Toggle("Next Hour Narration", isOn: $featureFlags.nextHourNarrationEnabled)
                        .accessibilityLabel("Next Hour Narration feature toggle")
                        .accessibilityHint(featureFlags.nextHourNarrationEnabled ? "Next Hour narration is enabled. Expected Precipitation shows a one-sentence summary such as rain starting in about 11 minutes, lasting about 35 minutes." : "Next Hour narration is disabled. Expected Precipitation shows only the timeline and graph.")

                    Toggle("Storm Approach", isOn: $featureFlags.stormApproachEnabled)
                        .accessibilityLabel("Storm Approach feature toggle")
                        .accessibilityHint(featureFlags.stormApproachEnabled ? "Storm Approach is enabled. Weather Around Me shows, at the top, which direction precipitation is coming from, its motion, arrival time, nearby towns it is over or heading for, and the effect on your saved cities." : "Storm Approach is disabled. Weather Around Me shows only the regional temperature and condition comparison, as before.")

                    Toggle("Nowcast Refinements", isOn: $featureFlags.nowcastRefinementsEnabled)
                        .accessibilityLabel("Nowcast Refinements feature toggle")
                        .accessibilityHint(featureFlags.nowcastRefinementsEnabled ? "Refinements are enabled. The Expected Precipitation feature is renamed Next Hour and shows only timing, a tappable Next Hour summary appears on the city screen, and the older wind-based direction block is hidden because Weather Around Me now does direction better." : "Refinements are disabled. Everything behaves exactly as before: the feature is called Expected Precipitation and shows its original summary, with no Next Hour line on the city screen.")

                    Toggle("Weather Around Me Improvements", isOn: $featureFlags.weatherAroundMeImprovementsEnabled)
                        .accessibilityLabel("Weather Around Me Improvements feature toggle")
                        .accessibilityHint(featureFlags.weatherAroundMeImprovementsEnabled ? "Improvements are enabled. Storm Approach uses mid-level steering winds for storm motion, reports a confidence level and hedges its wording, samples a denser ring of points, and labels rain or snow per nearby town." : "Improvements are disabled. Storm Approach uses its original coarser estimate.")

                    Toggle("Weather Radar Map", isOn: $featureFlags.weatherRadarMapEnabled)
                        .accessibilityLabel("Weather Radar Map feature toggle")
                        .accessibilityHint(featureFlags.weatherRadarMapEnabled ? "Radar map is enabled. Weather Around Me offers a free NWS NEXRAD radar map, United States coverage, that you can have VoiceOver or on-device AI describe." : "Radar map is disabled and the radar map button is hidden in Weather Around Me.")

                    Toggle("Enable Table View", isOn: $featureFlags.tableViewEnabled)
                        .accessibilityLabel("Enable Table View feature toggle")
                        .accessibilityHint(featureFlags.tableViewEnabled ? "Table view is enabled. Table option will appear in the View Mode picker in Settings." : "Table view is disabled. Table option will not appear in the View Mode picker in Settings.")
                        .onChange(of: featureFlags.tableViewEnabled) {
                            // If table view is being disabled and user is currently in table mode, switch to list
                            if !featureFlags.tableViewEnabled && settingsManager.settings.viewMode == .table {
                                settingsManager.settings.viewMode = .list
                                settingsManager.saveSettings()
                            }
                        }
                }

                // MARK: - AI Radar Description (iOS 27+ Foundation Models)
                Section(header: Text("AI Radar Description (iOS 27+)"),
                        footer: Text("These features use Apple's Foundation Models framework to send the NWS radar image directly to the on-device model with a custom prompt — the same approach the QuickRadar experiment proved works, but entirely on-device. Requires iOS 27 or later and Apple Intelligence. When off, the app shows the radar image with an accessibility label and lets VoiceOver describe it natively.")) {

                    Toggle("Foundation Models Radar", isOn: $featureFlags.foundationModelsRadarEnabled)
                        .accessibilityLabel("Foundation Models Radar feature toggle")
                        .accessibilityHint(featureFlags.foundationModelsRadarEnabled ? "Foundation Models radar description is enabled. The radar image is sent to Apple's on-device Language Model with a custom radar prompt — the model sees the image and describes precipitation, intensity, storm structure, and warnings. Requires iOS 27 and Apple Intelligence." : "Foundation Models radar description is disabled. The app shows the radar image with an accessibility label and lets VoiceOver describe it natively, as shipped.")

                    if featureFlags.foundationModelsRadarEnabled {
                        Toggle("Structured Output (@Generable)", isOn: $featureFlags.radarStructuredOutputEnabled)
                            .accessibilityLabel("Structured Output feature toggle")
                            .accessibilityHint(featureFlags.radarStructuredOutputEnabled ? "Structured output is enabled. The model returns a typed RadarAnalysis with precipitation, intensity, direction, and warnings fields instead of free text. Cross-validation uses the typed direction field." : "Structured output is disabled. The model returns free text and cross-validation parses direction from it.")

                        Toggle("Two-Frame Movement", isOn: $featureFlags.radarTwoFrameMovementEnabled)
                            .accessibilityLabel("Two-Frame Movement feature toggle")
                            .accessibilityHint(featureFlags.radarTwoFrameMovementEnabled ? "Two-frame movement is enabled. The app downloads two radar frames about an hour apart and asks the model to infer storm movement — a third independent motion estimate to cross-validate against Storm Approach." : "Two-frame movement is disabled. Only single-frame radar descriptions are used.")

                        Picker("Model Path", selection: $featureFlags.radarModelPath) {
                            Text("Auto").tag("auto")
                            Text("On-Device").tag("on-device")
                            Text("Private Cloud").tag("cloud")
                        }
                        .accessibilityLabel("Model path")
                        .accessibilityHint("Controls which AI model processes the radar image. Auto tries on-device first and falls back to cloud. On-Device runs on the Neural Engine, private and free. Private Cloud uses Apple's larger cloud model, privacy-preserving.")

                        Picker("Detail Level", selection: $featureFlags.radarDescriptionDetailLevel) {
                            Text("Brief").tag("brief")
                            Text("Standard").tag("standard")
                            Text("Detailed").tag("detailed")
                        }
                        .accessibilityLabel("Radar description detail level")
                        .accessibilityHint("Controls how detailed the radar description prompt is. Brief is one sentence, Standard is the QuickRadar prompt, Detailed is a full meteorological analysis.")
                    }
                }
                
                // My Data configuration
                if featureFlags.myDataEnabled {
                    Section(header: Text("My Data"),
                            footer: Text("Configure a custom section in the city detail view with any available weather data point from the Open-Meteo API.")) {
                        Button(action: { showingMyDataConfig = true }) {
                            HStack {
                                Image(systemName: "chart.bar.doc.horizontal")
                                    .foregroundColor(.accentColor)
                                    .accessibilityHidden(true)
                                Text("My Data")
                                Spacer()
                                let count = settingsManager.settings.myDataFields.filter { $0.isEnabled }.count
                                if count > 0 {
                                    Text("\(count) data point\(count == 1 ? "" : "s")")
                                        .foregroundColor(.secondary)
                                        .font(.subheadline)
                                }
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .accessibilityHidden(true)
                            }
                        }
                        .accessibilityLabel("My Data configuration")
                        .accessibilityHint("Opens the My Data configuration screen to add or remove custom data points")
                    }
                }
                
                Section(header: Text("Location Features"), footer: Text("Current location uses GPS to automatically detect your city. This requires location permission.")) {
                    HStack {
                        Text("Find My Location")
                        Spacer()
                        Image(systemName: "location.fill")
                            .foregroundColor(.green)
                    }
                    
                    Text("Available in Add Location screen. Press \"Use My Current Location\" button to automatically add your current location.")
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
                
                Section(footer: Text("These settings control experimental features that are in development. Changes take effect immediately. Note: Expected Precipitation, Weather Around Me, and Historical Weather settings are now in the main Settings screen.")) {
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
            .sheet(isPresented: $showingMyDataConfig) {
                MyDataConfigView()
                    .environmentObject(settingsManager)
                    .environmentObject(weatherService)
            }
        }
    }
}

#Preview {
    DeveloperSettingsView()
        .environmentObject(SettingsManager())
        .environmentObject(WeatherService())
}
