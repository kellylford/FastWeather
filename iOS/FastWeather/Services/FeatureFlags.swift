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
    
    /// Enable/disable user guide link in settings
    /// Set to true to show user guide link in settings
    @Published var userGuideEnabled: Bool {
        didSet {
            UserDefaults.standard.set(userGuideEnabled, forKey: "feature_user_guide_enabled")
        }
    }
    
    /// Enable/disable WeatherKit alerts for international cities
    /// When enabled, uses Apple WeatherKit for alerts in non-US cities
    /// US cities continue to use NWS for more detailed alerts
    @Published var weatherKitAlertsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(weatherKitAlertsEnabled, forKey: "feature_weatherkit_alerts_enabled")
        }
    }
    
    /// Enable/disable My Data custom section in city detail view
    /// When enabled, users can configure a custom data section with any Open-Meteo parameter
    @Published var myDataEnabled: Bool {
        didSet {
            UserDefaults.standard.set(myDataEnabled, forKey: "feature_my_data_enabled")
        }
    }
    
    /// Enable/disable Table view mode on the home screen
    /// Off by default — Table view has text clipping issues and is an experimental layout.
    /// When disabled the Table option is hidden from the View Mode picker in Settings.
    @Published var tableViewEnabled: Bool {
        didSet {
            UserDefaults.standard.set(tableViewEnabled, forKey: "feature_table_view_enabled")
        }
    }
    
    /// Use WeatherKit daily snow totals instead of Open-Meteo snowfall_sum.
    /// Off by default. When on, WeatherKit daily snowfallAmount (cm) overwrites
    /// the Open-Meteo value after each fetch. Falls back to Open-Meteo on error.
    @Published var weatherKitSnowEnabled: Bool {
        didSet {
            UserDefaults.standard.set(weatherKitSnowEnabled, forKey: "feature_weatherkit_snow_enabled")
        }
    }

    /// Use WeatherKit radar-quality minute-by-minute nowcast for Expected Precipitation.
    /// On by default. When disabled, all cities fall back to Open-Meteo NWP regardless
    /// of country — restoring the pre-WeatherKit nowcast experience.
    @Published var weatherKitNowcastEnabled: Bool {
        didSet {
            UserDefaults.standard.set(weatherKitNowcastEnabled, forKey: "feature_weatherkit_nowcast_enabled")
        }
    }

    /// Show specific place names (airports, universities, streets) instead of just the city name.
    /// On by default. When disabled, all searches fall back to the locality-only label ("Madison, WI")
    /// regardless of what was searched. Does not affect cities already saved.
    @Published var specificPlaceNamesEnabled: Bool {
        didSet {
            UserDefaults.standard.set(specificPlaceNamesEnabled, forKey: "feature_specific_place_names_enabled")
        }
    }

    /// Enable/disable the My Location section on the city list.
    /// On by default. When disabled, the entire My Location feature is hidden regardless of the
    /// user-facing setting in Settings > My Location.
    @Published var myLocationEnabled: Bool {
        didSet {
            UserDefaults.standard.set(myLocationEnabled, forKey: "feature_my_location_enabled")
        }
    }

    /// Show a concise "Next Hour" precipitation narration at the top of Expected Precipitation.
    /// On by default. Plain-language summary ("Rain starting in about 11 minutes, lasting about
    /// 35 minutes") derived from the same minute-by-minute data already fetched.
    @Published var nextHourNarrationEnabled: Bool {
        didSet {
            UserDefaults.standard.set(nextHourNarrationEnabled, forKey: "feature_next_hour_narration_enabled")
        }
    }

    /// Show the "Storm Approach" card — accessible radar replacement that samples a ring of
    /// surrounding points to report which direction precipitation is coming from, its estimated
    /// motion, arrival time, and impact on nearby saved cities. On by default.
    @Published var stormApproachEnabled: Bool {
        didSet {
            UserDefaults.standard.set(stormApproachEnabled, forKey: "feature_storm_approach_enabled")
        }
    }

    /// Nowcast information-architecture refinements. OFF by default so users see no change.
    /// When on: the precipitation screen is renamed "Next Hour" and becomes purely temporal
    /// (the older wind-inferred "nearest precipitation" block is hidden, since Storm Approach in
    /// Weather Around Me does direction better), and a tappable Next Hour one-liner appears on the
    /// main city detail screen.
    @Published var nowcastRefinementsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(nowcastRefinementsEnabled, forKey: "feature_nowcast_refinements_enabled")
        }
    }

    /// Weather Around Me accuracy improvements. When on, Storm Approach uses mid-level steering
    /// winds (not surface wind or pure centroid) for storm motion, reports a confidence level and
    /// hedges its wording accordingly, samples a denser ring, and labels precipitation type
    /// (rain/snow) per nearby town. When off, Storm Approach behaves as originally shipped.
    @Published var weatherAroundMeImprovementsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(weatherAroundMeImprovementsEnabled, forKey: "feature_wam_improvements_enabled")
        }
    }

    /// Free public-domain NWS NEXRAD radar map (MapKit tile overlay, US coverage) inside Weather
    /// Around Me. Provides an actual radar image that VoiceOver image recognition / on-device AI
    /// can describe. On by default.
    @Published var weatherRadarMapEnabled: Bool {
        didSet {
            UserDefaults.standard.set(weatherRadarMapEnabled, forKey: "feature_weather_radar_map_enabled")
        }
    }

    // MARK: - AI Radar Description (iOS 27+ Foundation Models)

    /// Use Apple's Foundation Models framework (LanguageModelSession + custom prompt + Attachment)
    /// to send the NWS radar image directly to the on-device model with the custom QuickRadar
    /// prompt. The model sees the image and describes precipitation, intensity, storm structure,
    /// and warning polygons — the same quality as the QuickRadar experiment, but on-device.
    /// Requires iOS 27.0+ and Apple Intelligence. OFF by default so the shipped behavior
    /// (image-only accessibility label) is unchanged until you turn this on in Developer Settings.
    @Published var foundationModelsRadarEnabled: Bool {
        didSet {
            UserDefaults.standard.set(foundationModelsRadarEnabled, forKey: "feature_foundation_models_radar_enabled")
        }
    }

    // MARK: - AI Radar Description sub-features

    /// Use @Generable structured output for the radar description so the model returns a typed
    /// RadarAnalysis (hasPrecipitation, intensity, direction, hasWarnings, description) instead
    /// of free text. Eliminates regex direction parsing in cross-validation. Requires iOS 27+
    /// and foundationModelsRadarEnabled. OFF by default.
    @Published var radarStructuredOutputEnabled: Bool {
        didSet {
            UserDefaults.standard.set(radarStructuredOutputEnabled, forKey: "feature_radar_structured_output_enabled")
        }
    }

    /// On-device two-frame movement detection. Downloads the NWS RIDGE animated loop, extracts
    /// the first and last frames, and sends both to LanguageModelSession with a comparison prompt
    /// to infer storm motion. A third independent motion estimate to cross-validate against Storm
    /// Approach. Requires iOS 27+ and foundationModelsRadarEnabled. OFF by default.
    @Published var radarTwoFrameMovementEnabled: Bool {
        didSet {
            UserDefaults.standard.set(radarTwoFrameMovementEnabled, forKey: "feature_radar_two_frame_movement_enabled")
        }
    }

    /// Which model to use for the radar description.
    /// "on-device" = SystemLanguageModel (runs on the Neural Engine, private, free)
    /// "cloud" = PrivateCloudComputeLanguageModel (larger model, Apple's cloud, privacy-preserving)
    /// "auto" = tries on-device first, falls back to cloud if vision isn't supported
    /// Defaults to "auto". Only applies when foundationModelsRadarEnabled is on.
    @Published var radarModelPath: String {
        didSet {
            UserDefaults.standard.set(radarModelPath, forKey: "feature_radar_model_path")
        }
    }

    /// Detail level for the radar description prompt. "brief" = one sentence, "standard" = the
    /// QuickRadar prompt, "detailed" = full meteorological analysis. Defaults to "standard".
    /// Only applies when foundationModelsRadarEnabled is on.
    @Published var radarDescriptionDetailLevel: String {
        didSet {
            UserDefaults.standard.set(radarDescriptionDetailLevel, forKey: "feature_radar_description_detail_level")
        }
    }

    // MARK: - Initialization
    
    private init() {
        // Load saved feature flag states
        self.radarEnabled = UserDefaults.standard.bool(forKey: "feature_radar_enabled")
        self.weatherAroundMeEnabled = UserDefaults.standard.bool(forKey: "feature_weather_around_me_enabled")
        self.userGuideEnabled = UserDefaults.standard.bool(forKey: "feature_user_guide_enabled")
        self.weatherKitAlertsEnabled = UserDefaults.standard.bool(forKey: "feature_weatherkit_alerts_enabled")
        self.myDataEnabled = UserDefaults.standard.bool(forKey: "feature_my_data_enabled")
        self.tableViewEnabled = UserDefaults.standard.bool(forKey: "feature_table_view_enabled")
        self.weatherKitSnowEnabled = UserDefaults.standard.bool(forKey: "feature_weatherkit_snow_enabled")
        self.weatherKitNowcastEnabled = UserDefaults.standard.bool(forKey: "feature_weatherkit_nowcast_enabled")
        self.specificPlaceNamesEnabled = UserDefaults.standard.bool(forKey: "feature_specific_place_names_enabled")
        self.myLocationEnabled = UserDefaults.standard.bool(forKey: "feature_my_location_enabled")
        self.nextHourNarrationEnabled = UserDefaults.standard.bool(forKey: "feature_next_hour_narration_enabled")
        self.stormApproachEnabled = UserDefaults.standard.bool(forKey: "feature_storm_approach_enabled")
        self.nowcastRefinementsEnabled = UserDefaults.standard.bool(forKey: "feature_nowcast_refinements_enabled")
        self.weatherAroundMeImprovementsEnabled = UserDefaults.standard.bool(forKey: "feature_wam_improvements_enabled")
        self.weatherRadarMapEnabled = UserDefaults.standard.bool(forKey: "feature_weather_radar_map_enabled")
        self.foundationModelsRadarEnabled = UserDefaults.standard.bool(forKey: "feature_foundation_models_radar_enabled")
        self.radarStructuredOutputEnabled = UserDefaults.standard.bool(forKey: "feature_radar_structured_output_enabled")
        self.radarTwoFrameMovementEnabled = UserDefaults.standard.bool(forKey: "feature_radar_two_frame_movement_enabled")
        self.radarModelPath = UserDefaults.standard.string(forKey: "feature_radar_model_path") ?? "auto"
        self.radarDescriptionDetailLevel = UserDefaults.standard.string(forKey: "feature_radar_description_detail_level") ?? "standard"

        // Default values (if first launch or not set)
        // All features enabled by default for production
        if !UserDefaults.standard.contains(key: "feature_radar_enabled") {
            self.radarEnabled = true  // Enabled by default
        }
        if !UserDefaults.standard.contains(key: "feature_weather_around_me_enabled") {
            self.weatherAroundMeEnabled = true  // Enabled by default
        }
        if !UserDefaults.standard.contains(key: "feature_user_guide_enabled") {
            self.userGuideEnabled = true  // Enabled by default
        }
        if !UserDefaults.standard.contains(key: "feature_weatherkit_alerts_enabled") {
            self.weatherKitAlertsEnabled = true  // Enabled by default for international alerts
        }
        if !UserDefaults.standard.contains(key: "feature_my_data_enabled") {
            self.myDataEnabled = true  // Enabled by default
        }
        if !UserDefaults.standard.contains(key: "feature_table_view_enabled") {
            self.tableViewEnabled = false  // Disabled by default — experimental layout
        }
        if !UserDefaults.standard.contains(key: "feature_weatherkit_snow_enabled") {
            self.weatherKitSnowEnabled = true  // On by default
        }
        if !UserDefaults.standard.contains(key: "feature_weatherkit_nowcast_enabled") {
            self.weatherKitNowcastEnabled = true  // On by default
        }
        if !UserDefaults.standard.contains(key: "feature_specific_place_names_enabled") {
            self.specificPlaceNamesEnabled = true  // On by default
        }
        if !UserDefaults.standard.contains(key: "feature_my_location_enabled") {
            self.myLocationEnabled = true  // On by default
        }
        if !UserDefaults.standard.contains(key: "feature_next_hour_narration_enabled") {
            self.nextHourNarrationEnabled = true  // On by default
        }
        if !UserDefaults.standard.contains(key: "feature_storm_approach_enabled") {
            self.stormApproachEnabled = true  // On by default
        }
        if !UserDefaults.standard.contains(key: "feature_nowcast_refinements_enabled") {
            self.nowcastRefinementsEnabled = true  // On by default — Storm Approach does direction better
        }
        if !UserDefaults.standard.contains(key: "feature_wam_improvements_enabled") {
            self.weatherAroundMeImprovementsEnabled = true  // On by default
        }
        if !UserDefaults.standard.contains(key: "feature_weather_radar_map_enabled") {
            self.weatherRadarMapEnabled = true  // On by default
        }
        // AI radar description features — OFF by default so the shipped behavior
        // (image-only accessibility label) is unchanged until toggled in Developer Settings.
        if !UserDefaults.standard.contains(key: "feature_foundation_models_radar_enabled") {
            self.foundationModelsRadarEnabled = false
        }
        if !UserDefaults.standard.contains(key: "feature_radar_structured_output_enabled") {
            self.radarStructuredOutputEnabled = false
        }
        if !UserDefaults.standard.contains(key: "feature_radar_two_frame_movement_enabled") {
            self.radarTwoFrameMovementEnabled = false
        }
        if !UserDefaults.standard.contains(key: "feature_radar_cloud_model_enabled") {
            self.radarModelPath = "auto"
        }
        if !UserDefaults.standard.contains(key: "feature_radar_description_detail_level") {
            self.radarDescriptionDetailLevel = "standard"
        }
    }
    
    // MARK: - Helper Methods
    
    /// Reset all feature flags to defaults
    func resetToDefaults() {
        radarEnabled = true
        weatherAroundMeEnabled = true
        userGuideEnabled = true
        weatherKitAlertsEnabled = true
        myDataEnabled = true
        tableViewEnabled = false
        weatherKitSnowEnabled = true
        weatherKitNowcastEnabled = true
        specificPlaceNamesEnabled = true
        myLocationEnabled = true
        nextHourNarrationEnabled = true
        stormApproachEnabled = true
        nowcastRefinementsEnabled = true
        weatherAroundMeImprovementsEnabled = true
        weatherRadarMapEnabled = true
        // AI radar description features default OFF (shipped behavior = Vision fallback)
        foundationModelsRadarEnabled = false
        radarStructuredOutputEnabled = false
        radarTwoFrameMovementEnabled = false
        radarModelPath = "auto"
        radarDescriptionDetailLevel = "standard"
        debugLog("🔧 Feature flags reset to defaults")
    }
    
    /// Enable all features (for testing)
    func enableAll() {
        radarEnabled = true
        weatherAroundMeEnabled = true
        userGuideEnabled = true
        weatherKitAlertsEnabled = true
        myDataEnabled = true
        tableViewEnabled = true
        weatherKitSnowEnabled = true
        weatherKitNowcastEnabled = true
        specificPlaceNamesEnabled = true
        myLocationEnabled = true
        nextHourNarrationEnabled = true
        stormApproachEnabled = true
        nowcastRefinementsEnabled = true
        weatherAroundMeImprovementsEnabled = true
        weatherRadarMapEnabled = true
        foundationModelsRadarEnabled = true
        radarStructuredOutputEnabled = true
        radarTwoFrameMovementEnabled = true
        radarModelPath = "auto"
        radarDescriptionDetailLevel = "standard"
        debugLog("🔧 All features enabled")
    }

    func disableAll() {
        radarEnabled = false
        weatherAroundMeEnabled = false
        userGuideEnabled = false
        weatherKitAlertsEnabled = false
        myDataEnabled = false
        tableViewEnabled = false
        weatherKitSnowEnabled = false
        weatherKitNowcastEnabled = false
        specificPlaceNamesEnabled = false
        myLocationEnabled = false
        nextHourNarrationEnabled = false
        stormApproachEnabled = false
        nowcastRefinementsEnabled = false
        weatherAroundMeImprovementsEnabled = false
        weatherRadarMapEnabled = false
        foundationModelsRadarEnabled = false
        radarStructuredOutputEnabled = false
        radarTwoFrameMovementEnabled = false
        radarModelPath = "auto"
        radarDescriptionDetailLevel = "standard"
        debugLog("🔧 All features disabled")
    }
}

// MARK: - UserDefaults Extension
extension UserDefaults {
    func contains(key: String) -> Bool {
        return object(forKey: key) != nil
    }
}
