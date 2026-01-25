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
                    BulletPoint("Tap the **+** button on the My Cities tab")
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
                    BulletPoint("**Swipe left** on a city to remove it")
                    BulletPoint("**Tap** a city to see detailed weather")
                    BulletPoint("**Pull down** to refresh all cities")
                    BulletPoint("Change view: **List**, **Table**, or **Flat** cards")
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
                    BulletPoint("Tap **+** to add interesting cities")
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
                    BulletPoint("**Daily forecast** for 7 days")
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
                    BulletPoint("**View Historical Weather** - See past weather data")
                    BulletPoint("**Expected Precipitation** - Rainfall forecast (if enabled)")
                    BulletPoint("**Weather Around Me** - Regional weather comparison (if enabled)")
                    BulletPoint("**Remove City** - Delete from your list")
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
                    BulletPoint("**View Mode** - List, Table, or Flat cards")
                    BulletPoint("**Display Mode** - Condensed or Expanded")
                    BulletPoint("**Weather Fields** - Show/hide and reorder")
                    BulletPoint("**Detail Categories** - Customize detail view")
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
                    BulletPoint("**Double-tap** city in browse to view without adding")
                    BulletPoint("**Pull to refresh** works on all city lists")
                    BulletPoint("**Swipe actions** available in List and Table views")
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
