#!/usr/bin/env ruby

require 'fileutils'

# Fix Xcode project build issues
pbxproj_path = 'FastWeather.xcodeproj/project.pbxproj'

puts "🔧 Fixing Xcode project build errors..."

# Read the project file
content = File.read(pbxproj_path)

# 1. Remove duplicate HistoricalWeather.swift references
puts "  ⚙️  Removing duplicate HistoricalWeather.swift references..."
lines = content.split("\n")
hist_ref_count = 0
cleaned_lines = lines.reject do |line|
  if line.include?('A1000HIST1 /* HistoricalWeather.swift */')
    hist_ref_count += 1
    hist_ref_count > 1  # Keep first, remove duplicates
  else
    false
  end
end

content = cleaned_lines.join("\n")

# 2. Add HistoricalWeather.swift to build phase if not present
puts "  ⚙️  Adding HistoricalWeather.swift to build phase..."
unless content.include?('A1000HIST1 /* HistoricalWeather.swift in Sources */')
  # Find the build phase section and add after HistoricalWeatherCache.swift
  content.gsub!(
    /(\s+A1000HISTB2 \/\* HistoricalWeatherCache\.swift in Sources \*\/,)/,
    "\\1\n\t\t\t\tA1000HIST1 /* HistoricalWeather.swift in Sources */,"
  )
  puts "    ✅ Added to build phase"
else
  puts "    ℹ️  Already in build phase"
end

# Write the fixed project file
File.write(pbxproj_path, content)

puts "✅ Xcode project file fixed"
puts "\n🔧 Fixing LocationService concurrency issue..."

# Fix LocationService CLLocationManagerDelegate conformance
location_service_path = 'FastWeather/Services/LocationService.swift'
location_content = File.read(location_service_path)

# Add @MainActor to the extension
location_content.gsub!(
  /^extension LocationService: CLLocationManagerDelegate \{/,
  '@MainActor
extension LocationService: CLLocationManagerDelegate {'
)

File.write(location_service_path, location_content)

puts "✅ LocationService concurrency fixed"

puts "\n✅ All build errors fixed!"
puts "   Run: cd iOS && xcodebuild -project FastWeather.xcodeproj -scheme FastWeather -configuration Debug build"
