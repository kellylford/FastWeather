#!/usr/bin/env python3
"""Add WeatherAlert.swift and AlertDetailView.swift to Xcode project"""
import re
import uuid

# Read project file
with open('FastWeather.xcodeproj/project.pbxproj', 'r') as f:
    content = f.read()

# Generate unique IDs (using consistent format like existing IDs)
weather_alert_file_id = f'A{uuid.uuid4().hex[:6].upper()}01'
weather_alert_build_id = f'A{uuid.uuid4().hex[:6].upper()}02'
alert_detail_file_id = f'A{uuid.uuid4().hex[:6].upper()}03'
alert_detail_build_id = f'A{uuid.uuid4().hex[:6].upper()}04'

print(f"Generated IDs:")
print(f"  WeatherAlert file: {weather_alert_file_id}, build: {weather_alert_build_id}")
print(f"  AlertDetailView file: {alert_detail_file_id}, build: {alert_detail_build_id}")

# 1. Add to PBXBuildFile section
build_section = re.search(r'\/\* Begin PBXBuildFile section \*\/', content)
if build_section:
    insert_pos = build_section.end()
    entries = f'\n\t\t{weather_alert_build_id} /* WeatherAlert.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {weather_alert_file_id} /* WeatherAlert.swift */; }};'
    entries += f'\n\t\t{alert_detail_build_id} /* AlertDetailView.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {alert_detail_file_id} /* AlertDetailView.swift */; }};'
    content = content[:insert_pos] + entries + content[insert_pos:]
    print("✅ Added to PBXBuildFile section")

# 2. Add to PBXFileReference section
file_section = re.search(r'\/\* Begin PBXFileReference section \*\/', content)
if file_section:
    insert_pos = file_section.end()
    entries = f'\n\t\t{weather_alert_file_id} /* WeatherAlert.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = WeatherAlert.swift; sourceTree = "<group>"; }};'
    entries += f'\n\t\t{alert_detail_file_id} /* AlertDetailView.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = AlertDetailView.swift; sourceTree = "<group>"; }};'
    content = content[:insert_pos] + entries + content[insert_pos:]
    print("✅ Added to PBXFileReference section")

# 3. Add WeatherAlert.swift to Models group (after Weather.swift)
models_pattern = r'(A10000006 \/\* Weather\.swift \*\/,)'
models_match = re.search(models_pattern, content)
if models_match:
    insert_pos = models_match.end()
    content = content[:insert_pos] + f'\n\t\t\t\t{weather_alert_file_id} /* WeatherAlert.swift */,' + content[insert_pos:]
    print("✅ Added WeatherAlert.swift to Models group")
else:
    print("⚠️  Could not find Models group anchor (Weather.swift)")

# 4. Add AlertDetailView.swift to Views group (after AddCitySearchView.swift)
views_pattern = r'(A10000011 \/\* AddCitySearchView\.swift \*\/,)'
views_match = re.search(views_pattern, content)
if views_match:
    insert_pos = views_match.end()
    content = content[:insert_pos] + f'\n\t\t\t\t{alert_detail_file_id} /* AlertDetailView.swift */,' + content[insert_pos:]
    print("✅ Added AlertDetailView.swift to Views group")
else:
    print("⚠️  Could not find Views group anchor (AddCitySearchView.swift)")

# 5. Add to PBXSourcesBuildPhase (after SettingsView.swift in Sources)
sources_pattern = r'(A1000001F \/\* SettingsView\.swift in Sources \*\/,)'
sources_match = re.search(sources_pattern, content)
if sources_match:
    insert_pos = sources_match.end()
    content = content[:insert_pos] + f'\n\t\t\t\t{weather_alert_build_id} /* WeatherAlert.swift in Sources */,'
    content = content[:insert_pos + len(f'\n\t\t\t\t{weather_alert_build_id} /* WeatherAlert.swift in Sources */,')] + f'\n\t\t\t\t{alert_detail_build_id} /* AlertDetailView.swift in Sources */,' + content[insert_pos + len(f'\n\t\t\t\t{weather_alert_build_id} /* WeatherAlert.swift in Sources */,'):]
    print("✅ Added to PBXSourcesBuildPhase")
else:
    print("⚠️  Could not find PBXSourcesBuildPhase anchor (SettingsView.swift)")

# Write back to project file
with open('FastWeather.xcodeproj/project.pbxproj', 'w') as f:
    f.write(content)

print("\n✅ Successfully added WeatherAlert.swift and AlertDetailView.swift to Xcode project!")
print("You can now build the project.")
