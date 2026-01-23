#!/usr/bin/env python3
import re

# Read the project file
with open('FastWeather.xcodeproj/project.pbxproj', 'r') as f:
    content = f.read()

# Generate UUIDs for the new files (use simple sequential IDs to avoid conflicts)
weather_alert_uuid = 'A1000ALERT1'
alert_detail_uuid = 'A1000ALERT2'
weather_alert_build_uuid = 'A1000ALERTB1'
alert_detail_build_uuid = 'A1000ALERTB2'

# Find the PBXBuildFile section and add new build files
pattern = r'(\/\* Begin PBXBuildFile section \*\/)(.*?)(\/\* End PBXBuildFile section \*\/)'
match = re.search(pattern, content, re.DOTALL)
if match:
    new_entries = f"""		{weather_alert_build_uuid} /* WeatherAlert.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {weather_alert_uuid} /* WeatherAlert.swift */; }};
		{alert_detail_build_uuid} /* AlertDetailView.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {alert_detail_uuid} /* AlertDetailView.swift */; }};
"""
    content = content[:match.end(2)] + new_entries + content[match.end(2):]
    print("✅ Added to PBXBuildFile section")

# Find the PBXFileReference section and add new file references  
pattern = r'(\/\* Begin PBXFileReference section \*\/)(.*?)(\/\* End PBXFileReference section \*\/)'
match = re.search(pattern, content, re.DOTALL)
if match:
    new_entries = f"""		{weather_alert_uuid} /* WeatherAlert.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = WeatherAlert.swift; sourceTree = "<group>"; }};
		{alert_detail_uuid} /* AlertDetailView.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = AlertDetailView.swift; sourceTree = "<group>"; }};
"""
    content = content[:match.end(2)] + new_entries + content[match.end(2):]
    print("✅ Added to PBXFileReference section")

# Find Models group - add after Weather.swift
pattern = r'(\/\* Models \*\/ = \{[^}]*children = \([^)]*)(A10000006 \/\* Weather\.swift \*\/,)'
match = re.search(pattern, content, re.DOTALL)
if match:
    new_entry = f"\n				{weather_alert_uuid} /* WeatherAlert.swift */,"
    content = content[:match.end(2)] + new_entry + content[match.end(2):]
    print("✅ Added WeatherAlert.swift to Models group")

# Find Views group - add after SettingsView.swift
pattern = r'(\/\* Views \*\/ = \{[^}]*children = \([^)]*)(A1000000F \/\* SettingsView\.swift \*\/,)'
match = re.search(pattern, content, re.DOTALL)
if match:
    new_entry = f"\n				{alert_detail_uuid} /* AlertDetailView.swift */,"
    content = content[:match.end(2)] + new_entry + content[match.end(2):]
    print("✅ Added AlertDetailView.swift to Views group")

# Find PBXSourcesBuildPhase and add build file references - add after SettingsView.swift in Sources
pattern = r'(\/\* Sources \*\/ = \{[^}]*files = \([^)]*)(A1000001F \/\* SettingsView\.swift in Sources \*\/,)'
match = re.search(pattern, content, re.DOTALL)
if match:
    new_entries = f"\n				{weather_alert_build_uuid} /* WeatherAlert.swift in Sources */,\n				{alert_detail_build_uuid} /* AlertDetailView.swift in Sources */,"
    content = content[:match.end(2)] + new_entries + content[match.end(2):]
    print("✅ Added to PBXSourcesBuildPhase")

# Write back
with open('FastWeather.xcodeproj/project.pbxproj', 'w') as f:
    f.write(content)

print("\n✅ Successfully added WeatherAlert.swift and AlertDetailView.swift to Xcode project!")
