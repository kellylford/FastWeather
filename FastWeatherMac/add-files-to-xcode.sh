#!/bin/bash
# add-files-to-xcode.sh
# Helper script to list files that need to be manually added to Xcode

echo "📦 Files Ready for Xcode Integration"
echo "======================================"
echo ""
echo "The following files have been created and need to be added to your Xcode project:"
echo ""

echo "📁 FastWeatherMac/Services/"
echo "  ✓ FeatureFlags.swift (already created in correct location)"
echo "  ✓ SettingsManager.swift (already created in correct location)"
echo "  • RadarService.swift (copied from iOS)"
echo "  • RegionalWeatherService.swift (copied from iOS)"
echo "  • DirectionalCityService.swift (copied from iOS)"
echo "  • HistoricalWeatherCache.swift (copied from iOS)"
echo ""

echo "📁 FastWeatherMac/Models/"
echo "  ✓ HistoricalWeather.swift (already created in correct location)"
echo "  • Settings.swift (copied from iOS)"
echo ""

echo "📁 FastWeatherMac/Views/"
echo "  ✓ TableView.swift (already created in correct location)"
echo "  ✓ ListView.swift (already created in correct location)"
echo "  ✓ FlatView.swift (already created in correct location)"
echo "  • RadarView.swift (copied from iOS)"
echo "  • WeatherAroundMeView.swift (copied from iOS)"
echo "  • HistoricalWeatherView.swift (copied from iOS)"
echo "  • DeveloperSettingsView.swift (copied from iOS)"
echo ""

echo "✓ = Already in Xcode-friendly location"
echo "• = Needs to be added to Xcode project"
echo ""
echo "📝 To add files to Xcode:"
echo "1. Open FastWeatherMac.xcodeproj in Xcode"
echo "2. For each folder (Services, Models, Views):"
echo "   - Right-click on the folder in Project Navigator"
echo "   - Choose 'Add Files to FastWeatherMac...'"
echo "   - Navigate to the folder and select all files marked with •"
echo "   - Ensure 'Copy items if needed' is UNchecked (files are already in place)"
echo "   - Click 'Add'"
echo ""
echo "🔍 Verify all files appear in Project Navigator before building"
echo ""

# List all Swift files in the project
echo "📋 All Swift files in FastWeatherMac/:"
find /Users/kellyford/Documents/GitHub/FastWeather/FastWeatherMac/FastWeatherMac -name "*.swift" -type f | sed 's|/Users/kellyford/Documents/GitHub/FastWeather/FastWeatherMac/FastWeatherMac/||' | sort

echo ""
echo "✅ Ready for Xcode integration!"
