#!/usr/bin/env python3
import re
import uuid

# Read the project file
with open('FastWeather.xcodeproj/project.pbxproj', 'r') as f:
    content = f.read()

# Generate UUIDs for the new files
weather_around_me_view_uuid = 'A1000WARM1'
regional_weather_service_uuid = 'A1000WARM2'
weather_around_me_view_build_uuid = 'A1000WARMB1'
regional_weather_service_build_uuid = 'A1000WARMB2'

# Find the PBXBuildFile section and add new build files
pattern = r'(\/\* Begin PBXBuildFile section \*\/)(.*?)(\/\* End PBXBuildFile section \*\/)'
match = re.search(pattern, content, re.DOTALL)
if match:
    new_entries = f"""		{weather_around_me_view_build_uuid} /* WeatherAroundMeView.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {weather_around_me_view_uuid} /* WeatherAroundMeView.swift */; }};
		{regional_weather_service_build_uuid} /* RegionalWeatherService.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {regional_weather_service_uuid} /* RegionalWeatherService.swift */; }};
"""
    content = content[:match.end(2)] + new_entries + content[match.end(2):]
    print("✅ Added to PBXBuildFile section")

# Find the PBXFileReference section and add new file references  
pattern = r'(\/\* Begin PBXFileReference section \*\/)(.*?)(\/\* End PBXFileReference section \*\/)'
match = re.search(pattern, content, re.DOTALL)
if match:
    new_entries = f"""		{weather_around_me_view_uuid} /* WeatherAroundMeView.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = WeatherAroundMeView.swift; sourceTree = "<group>"; }};
		{regional_weather_service_uuid} /* RegionalWeatherService.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = RegionalWeatherService.swift; sourceTree = "<group>"; }};
"""
    content = content[:match.end(2)] + new_entries + content[match.end(2):]
    print("✅ Added to PBXFileReference section")

# Find Views group - add WeatherAroundMeView.swift
pattern = r'(\/\* Views \*\/ = \{[^}]*children = \([^)]*)(A10000010 \/\* SettingsView\.swift \*\/,)'
match = re.search(pattern, content, re.DOTALL)
if match:
    new_entry = f"\n				{weather_around_me_view_uuid} /* WeatherAroundMeView.swift */,"
    content = content[:match.end(2)] + new_entry + content[match.end(2):]
    print("✅ Added WeatherAroundMeView to Views group")

# Find Services group - add RegionalWeatherService.swift
pattern = r'(\/\* Services \*\/ = \{[^}]*children = \([^)]*)(A10000009 \/\* SettingsManager\.swift \*\/,)'
match = re.search(pattern, content, re.DOTALL)
if match:
    new_entry = f"\n				{regional_weather_service_uuid} /* RegionalWeatherService.swift */,"
    content = content[:match.end(2)] + new_entry + content[match.end(2):]
    print("✅ Added RegionalWeatherService to Services group")

# Find PBXSourcesBuildPhase section and add the build files
pattern = r'(\/\* Begin PBXSourcesBuildPhase section \*\/.*?files = \([^)]*)(A10000005 \/\* City\.swift in Sources \*\/,)'
match = re.search(pattern, content, re.DOTALL)
if match:
    new_entries = f"""\n				{weather_around_me_view_build_uuid} /* WeatherAroundMeView.swift in Sources */,
				{regional_weather_service_build_uuid} /* RegionalWeatherService.swift in Sources */,"""
    content = content[:match.end(2)] + new_entries + content[match.end(2):]
    print("✅ Added to PBXSourcesBuildPhase section")

# Write the modified content
with open('FastWeather.xcodeproj/project.pbxproj', 'w') as f:
    f.write(content)

print("\n✅ Successfully added WeatherAroundMeView.swift and RegionalWeatherService.swift to Xcode project!")
print("Files added:")
print("  - Views/WeatherAroundMeView.swift")
print("  - Services/RegionalWeatherService.swift")
