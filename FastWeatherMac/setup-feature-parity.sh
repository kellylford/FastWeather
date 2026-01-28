#!/bin/bash
# FastWeatherMac Feature Parity Setup Script
# This script copies and adapts iOS files to macOS

echo "🚀 FastWeatherMac Feature Parity Setup"
echo "======================================="

IOS_PATH="/Users/kellyford/Documents/GitHub/FastWeather/iOS/FastWeather"
MAC_PATH="/Users/kellyford/Documents/GitHub/FastWeather/FastWeatherMac/FastWeatherMac"

# Create necessary directories
mkdir -p "$MAC_PATH/Services"
mkdir -p "$MAC_PATH/Models"
mkdir -p "$MAC_PATH/Views"

echo "📁 Copying service files..."

# Copy services (these work identically on both platforms)
cp "$IOS_PATH/Services/RadarService.swift" "$MAC_PATH/Services/"
cp "$IOS_PATH/Services/RegionalWeatherService.swift" "$MAC_PATH/Services/"
cp "$IOS_PATH/Services/DirectionalCityService.swift" "$MAC_PATH/Services/"
cp "$IOS_PATH/Services/HistoricalWeatherCache.swift" "$MAC_PATH/Services/"

echo "📋 Copying model files..."

# Copy models (platform-independent)
cp "$IOS_PATH/Models/Settings.swift" "$MAC_PATH/Models/"

echo "🖼️  Copying view files..."

# Copy views (may need minor UIKit -> AppKit adaptations)
cp "$IOS_PATH/Views/RadarView.swift" "$MAC_PATH/Views/"
cp "$IOS_PATH/Views/WeatherAroundMeView.swift" "$MAC_PATH/Views/"
cp "$IOS_PATH/Views/HistoricalWeatherView.swift" "$MAC_PATH/Views/"
cp "$IOS_PATH/Views/DeveloperSettingsView.swift" "$MAC_PATH/Views/"

echo "🔧 Performing platform-specific replacements..."

# Replace UIKit references with AppKit equivalents
find "$MAC_PATH/Views" -name "*.swift" -exec sed -i '' 's/UIColor/NSColor/g' {} \;
find "$MAC_PATH/Views" -name "*.swift" -exec sed -i '' 's/uiColor/nsColor/g' {} \;

echo "✅ Files copied successfully!"
echo ""
echo "📝 Next steps:"
echo "1. Open FastWeatherMac.xcodeproj in Xcode"
echo "2. Add the new files to your project (File > Add Files to...)"
echo "3. Review FEATURE_PARITY_GUIDE.md for integration steps"
echo "4. Update FastWeatherMacApp.swift to inject environment objects"
echo "5. Update ContentView.swift to add view mode switching"
echo "6. Update WeatherDetailView.swift to add new feature buttons"
echo ""
echo "🧪 Testing:"
echo "Run the app and enable features in Developer Settings"

