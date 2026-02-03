#!/usr/bin/env python3
import re

# Read the project file
with open('FastWeather.xcodeproj/project.pbxproj', 'r') as f:
    lines = f.readlines()

# Track which duplicates we've seen and removed
seen_build_files = {}
output_lines = []
removed_count = 0

for line in lines:
    # Check if this is a PBXBuildFile line for one of our problematic files
    if 'HistoricalWeather.swift in Sources' in line or \
       'HistoricalWeatherCache.swift in Sources' in line or \
       'HistoricalWeatherView.swift in Sources' in line:
        
        # Extract the build file ID
        match = re.search(r'^\s+([A-F0-9]+) /\*', line)
        if match:
            build_id = match.group(1)
            file_type = 'Historical'  # Generic marker
            
            if 'HistoricalWeather.swift' in line and 'Cache' not in line and 'View' not in line:
                file_type = 'HistoricalWeather.swift'
            elif 'HistoricalWeatherCache.swift' in line:
                file_type = 'HistoricalWeatherCache.swift'
            elif 'HistoricalWeatherView.swift' in line:
                file_type = 'HistoricalWeatherView.swift'
            
            # If we've seen this file type before, skip this duplicate
            if file_type in seen_build_files:
                print(f"Removing duplicate: {build_id} for {file_type}")
                removed_count += 1
                continue  # Skip this line
            else:
                seen_build_files[file_type] = build_id
                print(f"Keeping: {build_id} for {file_type}")
    
    output_lines.append(line)

# Write back
with open('FastWeather.xcodeproj/project.pbxproj', 'w') as f:
    f.writelines(output_lines)

print(f"\nRemoved {removed_count} duplicate file references")
print("Done! Build warnings should be gone now.")
