#!/usr/bin/env ruby
# Script to add LocationService.swift to Xcode project

require 'xcodeproj'

project_path = 'FastWeather.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the Services group
services_group = project.main_group.groups.find { |g| g.path == 'FastWeather' }
                        &.groups&.find { |g| g.path == 'Services' }

if services_group.nil?
  puts "❌ Could not find Services group"
  exit 1
end

# Add LocationService.swift
file_path = 'FastWeather/Services/LocationService.swift'
file_ref = services_group.new_file(file_path)

# Add to target
target = project.targets.find { |t| t.name == 'FastWeather' }
if target
  target.add_file_references([file_ref])
  puts "✅ Added LocationService.swift to FastWeather target"
else
  puts "❌ Could not find FastWeather target"
  exit 1
end

# Save project
project.save

puts "✅ Successfully added LocationService.swift to Xcode project"
