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

    /// Use WeatherKit's observation/nowcast-informed current condition instead of Open-Meteo's
    /// model `weather_code` for "now". On by default. Fixes cases like a thunderstorm code
    /// showing while it's dry. Applies to today's conditions only (forecasts stay Open-Meteo);
    /// unmappable WeatherKit conditions fall back to the Open-Meteo code. See #73.
    @Published var weatherKitConditionsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(weatherKitConditionsEnabled, forKey: "feature_weatherkit_conditions_enabled")
        }
    }

    /// Extend the WeatherKit condition overlay to the hourly and daily forecast (not just "now").
    /// On by default. Within WeatherKit's horizon (~10 days) each forecast hour/day uses
    /// WeatherKit's condition translated to WMO; hours/days WeatherKit doesn't cover, unmappable
    /// conditions, and days 11–16 keep the Open-Meteo code. Fixes the phantom-thunderstorm code
    /// (95/96/99 with ~0 precip) appearing in the 24-hour and 16-day forecasts. See #74.
    @Published var weatherKitForecastConditionsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(weatherKitForecastConditionsEnabled, forKey: "feature_weatherkit_forecast_conditions_enabled")
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

    // MARK: - Nowcasting (Storm Approach & Next Hour)

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
    /// motion, arrival time, and impact on nearby saved cities and towns. On by default.
    @Published var stormApproachEnabled: Bool {
        didSet {
            UserDefaults.standard.set(stormApproachEnabled, forKey: "feature_storm_approach_enabled")
        }
    }

    /// Nowcast information-architecture refinements. When on: the precipitation screen is
    /// renamed "Next Hour" and becomes purely temporal (the older wind-inferred "nearest
    /// precipitation" block is hidden, since Storm Approach in Weather Around Me does direction
    /// better), and a tappable Next Hour one-liner appears on the main city detail screen.
    @Published var nowcastRefinementsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(nowcastRefinementsEnabled, forKey: "feature_nowcast_refinements_enabled")
        }
    }

    /// Weather Around Me accuracy improvements. When on, Storm Approach uses mid-level steering
    /// winds (not surface wind or pure centroid) for storm motion, reports a confidence level and
    /// hedges its wording accordingly, samples a denser ring, and labels precipitation type
    /// (rain/snow) per nearby town. When off, Storm Approach uses centroid tracking only.
    @Published var weatherAroundMeImprovementsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(weatherAroundMeImprovementsEnabled, forKey: "feature_wam_improvements_enabled")
        }
    }

    /// Single centre authority + intensity floor (docs/NOWCAST_CENTRE_AUTHORITY_SPEC.md).
    /// When on: WeatherKit minute data only counts as precipitation at >= 0.2 mm/h (kills the
    /// radar phantoms measured at 0.05-0.07 mm/h without touching real rain at 3.6+ mm/h), and
    /// Storm Approach's "at your location" state reads the same floored WeatherKit nowcast the
    /// Next Hour narration uses — the two cards cannot contradict each other about whether it
    /// is raining on the user. Off restores the previous two-source behavior.
    @Published var nowcastCentreAuthorityEnabled: Bool {
        didSet {
            UserDefaults.standard.set(nowcastCentreAuthorityEnabled, forKey: "feature_nowcast_centre_authority_enabled")
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
        self.weatherKitConditionsEnabled = UserDefaults.standard.bool(forKey: "feature_weatherkit_conditions_enabled")
        self.weatherKitForecastConditionsEnabled = UserDefaults.standard.bool(forKey: "feature_weatherkit_forecast_conditions_enabled")
        self.specificPlaceNamesEnabled = UserDefaults.standard.bool(forKey: "feature_specific_place_names_enabled")
        self.myLocationEnabled = UserDefaults.standard.bool(forKey: "feature_my_location_enabled")
        self.nextHourNarrationEnabled = UserDefaults.standard.bool(forKey: "feature_next_hour_narration_enabled")
        self.stormApproachEnabled = UserDefaults.standard.bool(forKey: "feature_storm_approach_enabled")
        self.nowcastRefinementsEnabled = UserDefaults.standard.bool(forKey: "feature_nowcast_refinements_enabled")
        self.weatherAroundMeImprovementsEnabled = UserDefaults.standard.bool(forKey: "feature_wam_improvements_enabled")
        self.nowcastCentreAuthorityEnabled = UserDefaults.standard.bool(forKey: "feature_nowcast_centre_authority_enabled")

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
        if !UserDefaults.standard.contains(key: "feature_weatherkit_conditions_enabled") {
            self.weatherKitConditionsEnabled = true  // On by default
        }
        if !UserDefaults.standard.contains(key: "feature_weatherkit_forecast_conditions_enabled") {
            self.weatherKitForecastConditionsEnabled = true  // On by default
        }
        if !UserDefaults.standard.contains(key: "feature_specific_place_names_enabled") {
            self.specificPlaceNamesEnabled = true  // On by default
        }
        if !UserDefaults.standard.contains(key: "feature_my_location_enabled") {
            self.myLocationEnabled = true  // On by default
        }
        // Nowcasting features — on by default on this testing branch so they're visible.
        if !UserDefaults.standard.contains(key: "feature_next_hour_narration_enabled") {
            self.nextHourNarrationEnabled = true
        }
        if !UserDefaults.standard.contains(key: "feature_storm_approach_enabled") {
            self.stormApproachEnabled = true
        }
        if !UserDefaults.standard.contains(key: "feature_nowcast_refinements_enabled") {
            self.nowcastRefinementsEnabled = true
        }
        if !UserDefaults.standard.contains(key: "feature_wam_improvements_enabled") {
            self.weatherAroundMeImprovementsEnabled = true
        }
        if !UserDefaults.standard.contains(key: "feature_nowcast_centre_authority_enabled") {
            self.nowcastCentreAuthorityEnabled = true
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
        weatherKitConditionsEnabled = true
        weatherKitForecastConditionsEnabled = true
        specificPlaceNamesEnabled = true
        myLocationEnabled = true
        nextHourNarrationEnabled = true
        stormApproachEnabled = true
        nowcastRefinementsEnabled = true
        weatherAroundMeImprovementsEnabled = true
        nowcastCentreAuthorityEnabled = true
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
        weatherKitConditionsEnabled = true
        weatherKitForecastConditionsEnabled = true
        specificPlaceNamesEnabled = true
        myLocationEnabled = true
        nextHourNarrationEnabled = true
        stormApproachEnabled = true
        nowcastRefinementsEnabled = true
        weatherAroundMeImprovementsEnabled = true
        nowcastCentreAuthorityEnabled = true
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
        weatherKitConditionsEnabled = false
        weatherKitForecastConditionsEnabled = false
        specificPlaceNamesEnabled = false
        myLocationEnabled = false
        nextHourNarrationEnabled = false
        stormApproachEnabled = false
        nowcastRefinementsEnabled = false
        weatherAroundMeImprovementsEnabled = false
        nowcastCentreAuthorityEnabled = false
        debugLog("🔧 All features disabled")
    }
}

// MARK: - UserDefaults Extension
extension UserDefaults {
    func contains(key: String) -> Bool {
        return object(forKey: key) != nil
    }
}
