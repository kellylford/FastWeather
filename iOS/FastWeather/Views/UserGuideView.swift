//
//  UserGuideView.swift
//  Fast Weather
//
//  User guide with comprehensive instructions for using the app
//

import SwiftUI

struct UserGuideView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Welcome to FastWeather")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Your accessible, feature-rich weather companion")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 8)
                
                // Getting Started
                GuideSection(
                    icon: "plus.circle.fill",
                    title: "Getting Started",
                    color: .green
                ) {
                    Text("Add cities to track their weather:")
                    BulletPoint("Activate the **+** (Add City) button on the My Cities tab")
                    BulletPoint("Enter a city name or ZIP code")
                    BulletPoint("Select from search results")
                    BulletPoint("Or browse cities by state/country")
                }
                
                // My Cities Tab
                GuideSection(
                    icon: "list.bullet",
                    title: "My Cities Tab",
                    color: .blue
                ) {
                    Text("View and manage your saved cities:")
                    BulletPoint("**Swipe left** on a city to remove it, or use the **VoiceOver actions menu**")
                    BulletPoint("**Activate** a city to see detailed weather")
                    BulletPoint("**Pull down** to refresh all cities")
                    BulletPoint("Change view: **List** or **Flat** cards")
                }
                
                // Browse Cities Tab
                GuideSection(
                    icon: "map.fill",
                    title: "Browse Cities",
                    color: .purple
                ) {
                    Text("Discover weather in new locations:")
                    BulletPoint("Browse by **U.S. States** or **International** countries")
                    BulletPoint("Navigate through states/countries → cities")
                    BulletPoint("View weather without adding to your list")
                    BulletPoint("Activate the **+** (Add City) button to add interesting cities")
                }
                
                // City Detail View
                GuideSection(
                    icon: "info.circle.fill",
                    title: "City Detail View",
                    color: .orange
                ) {
                    Text("Explore comprehensive weather information:")
                    BulletPoint("**Current conditions** with temperature, humidity, wind")
                    BulletPoint("**Hourly forecast** for next 24 hours")
                    BulletPoint("**Daily forecast** for 16 days")
                    BulletPoint("**Actions menu** for historical data and more")
                    BulletPoint("**Weather alerts** when active (U.S. only)")
                }
                
                // Actions Menu
                GuideSection(
                    icon: "ellipsis.circle.fill",
                    title: "Actions Menu",
                    color: .indigo
                ) {
                    Text("Access additional features from city detail:")
                    BulletPoint("**Refresh** - Update weather data")
                    BulletPoint("**View Historical Weather** - See past weather data")
                    BulletPoint("**Expected Precipitation** - Rainfall forecast (if enabled)")
                    BulletPoint("**Weather Around Me** - Regional weather comparison (if enabled)")
                    BulletPoint("**Remove City** - Delete from your list")
                }
                
                // Weather Around Me & Directional Explorer
                GuideSection(
                    icon: "location.circle.fill",
                    title: "Weather Around Me",
                    color: .purple
                ) {
                    Text("See weather in cities around you in all directions. This feature helps you understand regional weather patterns and plan trips.")
                        .padding(.bottom, 4)
                    
                    Text("**What You'll See:**")
                        .fontWeight(.semibold)
                        .padding(.top, 8)
                    BulletPoint("**Regional Overview** - Weather in 8 directions (N, NE, E, SE, S, SW, W, NW)")
                    BulletPoint("**Distance** - How far each city is from your selected city")
                    BulletPoint("**Current Weather** - Temperature and conditions for each city")
                    
                    Text("**Exploring Along a Direction:**")
                        .fontWeight(.semibold)
                        .padding(.top, 8)
                    Text("Tap any direction to explore cities along that path. For example, tap \"North\" to see all cities north of your location.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .padding(.leading, 16)
                        .padding(.bottom, 4)
                    
                    BulletPoint("**Pick a Direction** - Choose N, NE, E, SE, S, SW, W, or NW from the picker")
                    BulletPoint("**Navigate Cities** - Swipe up for cities farther away, swipe down for closer cities")
                    BulletPoint("**Visual Buttons** - Use \"Closer\" and \"Farther\" buttons to move between cities")
                    BulletPoint("**View All** - Tap \"List All\" to see all cities in that direction at once")
                    
                    Text("**First Time Loading:**")
                        .fontWeight(.semibold)
                        .padding(.top, 8)
                    Text("Finding cities along a direction may take 10-20 seconds the first time, but results are cached for instant access next time. The app searches every 10 miles along your chosen direction to find nearby cities.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .padding(.leading, 16)
                        .padding(.bottom, 4)
                    
                    Text("**Tips:**")
                        .fontWeight(.semibold)
                        .padding(.top, 8)
                    BulletPoint("Increase \"Max Distance\" in settings to see cities farther away")
                    BulletPoint("Use VoiceOver swipe gestures to quickly explore city by city")
                    BulletPoint("Weather data is prefetched as you navigate for smooth scrolling")
                }
                
                // Historical Weather
                GuideSection(
                    icon: "clock.arrow.circlepath",
                    title: "Historical Weather",
                    color: .brown
                ) {
                    Text("Explore weather from the past:")
                    BulletPoint("**Single Day** - View specific date's weather")
                    BulletPoint("**Multi-Year** - Compare across years")
                    BulletPoint("**Daily Browse** - Scroll through month view")
                    BulletPoint("Data available back to 1940 for most locations")
                }
                
                // Settings
                GuideSection(
                    icon: "gearshape.fill",
                    title: "Settings",
                    color: .gray
                ) {
                    Text("Customize your experience:")
                    BulletPoint("**Units** - °F/°C, mph/km/h, inches/mm")
                    BulletPoint("**View Mode** - List or Flat cards")
                    BulletPoint("**Display Mode** - Condensed or Expanded")
                    BulletPoint("**Weather Fields** - Show/hide and reorder")
                    BulletPoint("**Detail Categories** - Customize detail view")
                }
                
                // Icons & Graphics
                GuideSection(
                    icon: "photo.fill",
                    title: "Icons & Graphics",
                    color: .pink
                ) {
                    Text("Visual icons used throughout the app with VoiceOver equivalents:")
                    
                    Text("**Tab Bar Icons:**")
                        .fontWeight(.semibold)
                        .padding(.top, 8)
                    BulletPoint("**List icon** - My Cities tab (VoiceOver: \"My Cities\")")
                    BulletPoint("**Magnifying glass** - Browse tab (VoiceOver: \"Browse Cities\")")
                    BulletPoint("**Gear** - Settings tab (VoiceOver: \"Settings\")")
                    
                    Text("**Weather Condition Icons:**")
                        .fontWeight(.semibold)
                        .padding(.top, 8)
                    BulletPoint("**Sun** - Clear sky (VoiceOver: condition name)")
                    BulletPoint("**Cloud with sun** - Partly cloudy")
                    BulletPoint("**Cloud** - Overcast")
                    BulletPoint("**Cloud with rain** - Rain")
                    BulletPoint("**Cloud with snow** - Snow")
                    BulletPoint("**Cloud with lightning** - Thunderstorm")
                    BulletPoint("**Fog cloud** - Fog or mist")
                    Text("VoiceOver announces: \"Weather condition: [description]\"")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 16)
                    
                    Text("**Weather Alert Icons:**")
                        .fontWeight(.semibold)
                        .padding(.top, 8)
                    BulletPoint("**Filled warning triangle** - Extreme/Severe/Moderate alerts (red/orange/yellow)")
                    BulletPoint("**Filled circle with exclamation** - Minor alerts (blue)")
                    BulletPoint("**Circle with exclamation** - Unknown severity (gray)")
                    Text("VoiceOver announces: \"Weather alert: [event name]\" with severity level")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 16)
                    
                    Text("**Action & Navigation Icons:**")
                        .fontWeight(.semibold)
                        .padding(.top, 8)
                    BulletPoint("**Plus circle** - Add city (VoiceOver: \"Add City\")")
                    BulletPoint("**Circular arrows** - Refresh (VoiceOver: \"Refresh\" or \"Refresh weather\")")
                    BulletPoint("**Three dots circle** - Actions menu (VoiceOver: \"Actions\")")
                    BulletPoint("**Chevron right** - Navigate forward (VoiceOver: included in item name)")
                    BulletPoint("**Chevron down** - Expand menu (VoiceOver: \"[State/Country name]\")")
                    BulletPoint("**Map pin** - Location/browse (VoiceOver: \"Browse by state or country\")")
                    BulletPoint("**Book** - User guide (VoiceOver: \"User Guide\")")
                    BulletPoint("**Hammer** - Developer settings (VoiceOver: \"Developer Settings\")")
                    
                    Text("**Data Visualization Icons:**")
                        .fontWeight(.semibold)
                        .padding(.top, 8)
                    BulletPoint("**Droplet** - Precipitation amount (VoiceOver: \"Precipitation: [amount]\")")
                    BulletPoint("**Up arrow** - High temperature (VoiceOver: \"High: [temperature]\")")
                    BulletPoint("**Down arrow** - Low temperature (VoiceOver: \"Low: [temperature]\")")
                    BulletPoint("**Compass arrows** - Wind direction (VoiceOver: \"Wind from [direction]\")")
                    BulletPoint("**Clock** - Time/timestamp (VoiceOver: formatted time)")
                    BulletPoint("**Calendar with clock** - Historical weather (VoiceOver: \"View historical weather\")")
                    
                    Text("**Status Icons:**")
                        .fontWeight(.semibold)
                        .padding(.top, 8)
                    BulletPoint("**Warning triangle** - Error or unavailable (VoiceOver: describes issue)")
                    BulletPoint("**Checkmark** - Selected item (VoiceOver: \"Selected\")")
                    BulletPoint("**Sort arrows** - Reorder indicator (VoiceOver: \"Reorder\" or drag hint)")
                    
                    Text("**Important:** All icons are decorative only. VoiceOver users receive full information through text labels and announcements. You never need to see icons to use the app.")
                        .font(.callout)
                        .foregroundColor(.orange)
                        .padding(.top, 8)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 12)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    
                    Text("**Expected Precipitation Timeline:**")
                        .fontWeight(.semibold)
                        .padding(.top, 8)
                    Text("The Expected Precipitation feature displays a visual timeline showing precipitation forecasts for each time interval. This timeline is visible on screen for sighted users but is hidden from VoiceOver. The same data is available through the audio graph below the timeline, which provides both audio tones (representing precipitation intensity) and individual data points you can explore by swiping. The audio graph format is more efficient for non-visual exploration than reading through a long list of time entries.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .padding(.leading, 16)
                }
                
                // Accessibility
                GuideSection(
                    icon: "accessibility",
                    title: "Accessibility",
                    color: .teal
                ) {
                    Text("FastWeather is designed for VoiceOver users:")
                    BulletPoint("**Complete VoiceOver support** - All features accessible")
                    BulletPoint("**Descriptive labels** - Clear, context-aware announcements")
                    BulletPoint("**Logical navigation** - Efficient screen reader flow")
                    BulletPoint("**Dynamic Type** - Text scales with system settings")
                    BulletPoint("**High contrast** - Readable in all conditions")
                }
                
                // Tips & Tricks
                GuideSection(
                    icon: "lightbulb.fill",
                    title: "Tips & Tricks",
                    color: .yellow
                ) {
                    BulletPoint("**Reorder weather fields** in Settings → Weather Fields")
                    BulletPoint("**Drag to reorder** detail categories in Settings")
                    BulletPoint("**Activate** a city in browse to view without adding")
                    BulletPoint("**Pull to refresh** works on all city lists")
                    BulletPoint("**Swipe actions** or **VoiceOver actions menu** available in List view")
                    BulletPoint("**Historical years** can be configured in Settings")
                }
                
                // Data Sources
                GuideSection(
                    icon: "cloud.sun.fill",
                    title: "Weather Data",
                    color: .cyan
                ) {
                    Text("FastWeather uses reliable, free data sources:")
                    BulletPoint("**Open-Meteo** - Current and forecast weather")
                    BulletPoint("**Historical Archive** - Weather back to 1940")
                    BulletPoint("**NWS Alerts** - U.S. weather warnings (when available)")
                    BulletPoint("**OpenStreetMap** - City geocoding")
                    Text("No API keys required. No data tracking.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                
                // Footer
                VStack(spacing: 12) {
                    Divider()
                    
                    Text("Need more help?")
                        .font(.headline)
                    
                    Text("FastWeather is designed to be intuitive. Explore the app and discover features as you use it. Most actions are available through standard iOS gestures and VoiceOver commands.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Text("Version 1.0")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
            .padding()
        }
        .navigationTitle("User Guide")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Supporting Views

struct GuideSection<Content: View>: View {
    let icon: String
    let title: String
    let color: Color
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .accessibilityHidden(true)
                
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            
            VStack(alignment: .leading, spacing: 8) {
                content
            }
            .font(.body)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

struct BulletPoint: View {
    let text: LocalizedStringKey
    
    init(_ text: LocalizedStringKey) {
        self.text = text
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundColor(.accentColor)
                .accessibilityHidden(true)
            Text(text)
        }
    }
}

#Preview {
    NavigationView {
        UserGuideView()
    }
}
