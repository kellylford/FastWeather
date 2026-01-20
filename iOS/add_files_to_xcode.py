#!/usr/bin/env python3
import re
import uuid

# Read the project file
with open('FastWeather.xcodeproj/project.pbxproj', 'r') as f:
    content = f.read()

# Generate UUIDs for the new files (use simple sequential IDs to avoid conflicts)
historical_weather_uuid = 'A1000HIST1'
historical_cache_uuid = 'A1000HIST2'
historical_view_uuid = 'A1000HIST3'
historical_weather_build_uuid = 'A1000HISTB1'
historical_cache_build_uuid = 'A1000HISTB2'
historical_view_build_uuid = 'A1000HISTB3'

# Find the PBXBuildFile section and add new build files
pattern = r'(\/\* Begin PBXBuildFile section \*\/)(.*?)(\/\* End PBXBuildFile section \*\/)'
match = re.search(pattern, content, re.DOTALL)
if match:
    new_entries = f"""		{historical_weather_build_uuid} /* HistoricalWeather.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {historical_weather_uuid} /* HistoricalWeather.swift */; }};
		{historical_cache_build_uuid} /* HistoricalWeatherCache.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {historical_cache_uuid} /* HistoricalWeatherCache.swift */; }};
		{historical_view_build_uuid} /* HistoricalWeatherView.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {historical_view_uuid} /* HistoricalWeatherView.swift */; }};
"""
    content = content[:match.end(2)] + new_entries + content[match.end(2):]
    print("✅ Added to PBXBuildFile section")

# Find the PBXFileReference section and add new file references  
pattern = r'(\/\* Begin PBXFileReference section \*\/)(.*?)(\/\* End PBXFileReference section \*\/)'
match = re.search(pattern, content, re.DOTALL)
if match:
    new_entries = f"""		{historical_weather_uuid} /* HistoricalWeather.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = HistoricalWeather.swift; sourceTree = "<group>"; }};
		{historical_cache_uuid} /* HistoricalWeatherCache.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = HistoricalWeatherCache.swift; sourceTree = "<group>"; }};
		{historical_view_uuid} /* HistoricalWeatherView.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = HistoricalWeatherView.swift; sourceTree = "<group>"; }};
"""
    content = content[:match.end(2)] + new_entries + content[match.end(2):]
    print("✅ Added to PBXFileReference section")

# Find Models group
pattern = r'(\/\* Models \*\/ = \{[^}]*children = \([^)]*)(A10000006 \/\* Weather\.swift \*\/,)'
match = re.search(pattern, content, re.DOTALL)
if match:
    new_entry = f"\n				{historical_weather_uuid} /* HistoricalWeather.swift */,"
    content = content[:match.end(2)] + new_entry + content[match.end(2):]
    print("✅ Added to Models group")

# Find Services group
pattern = r'(\/\* Services \*\/ = \{[^}]*children = \([^)]*)(A10000009 \/\* SettingsManager\.swift \*\/,)'
match = re.search(pattern, content, re.DOTALL)
if match:
    new_entry = f"\n				{historical_cache_uuid} /* HistoricalWeatherCache.swift */,"
    content = content[:match.end(2)] + new_entry + content[match.end(2):]
    print("✅ Added to Services group")

# Find Views group
pattern = r'(\/\* Views \*\/ = \{[^}]*children = \([^)]*)(A1000000F \/\* SettingsView\.swift \*\/,)'
match = re.search(pattern, content, re.DOTALL)
if match:
    new_entry = f"\n				{historical_view_uuid} /* HistoricalWeatherView.swift */,"
    content = content[:match.end(2)] + new_entry + content[match.end(2):]
    print("✅ Added to Views group")

# Find PBXSourcesBuildPhase and add build file references
pattern = r'(\/\* Sources \*\/ = \{[^}]*files = \([^)]*)(A1000001F \/\* SettingsView\.swift in Sources \*\/,)'
match = re.search(pattern, content, re.DOTALL)
if match:
    new_entries = f"\n				{historical_weather_build_uuid} /* HistoricalWeather.swift in Sources */,\n				{historical_cache_build_uuid} /* HistoricalWeatherCache.swift in Sources */,\n				{historical_view_build_uuid} /* HistoricalWeatherView.swift in Sources */,"
    content = content[:match.end(2)] + new_entries + content[match.end(2):]
    print("✅ Added to PBXSourcesBuildPhase")

# Write back
with open('FastWeather.xcodeproj/project.pbxproj', 'w') as f:
    f.write(content)

print("\n✅ Successfully added all files to Xcode project!")
