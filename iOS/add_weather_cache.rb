#!/usr/bin/env ruby
# Add WeatherCache.swift to Xcode project

require 'xcodeproj'

project_path = 'FastWeather.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main target
main_target = project.targets.find { |t| t.name == 'FastWeather' }

if main_target.nil?
  puts "❌ Error: Could not find FastWeather target"
  exit 1
end

# Find the Services group
services_group = project.main_group.find_subpath('FastWeather/Services', true)

if services_group.nil?
  puts "❌ Error: Could not find FastWeather/Services group"
  exit 1
end

# Add WeatherCache.swift
file_path = 'FastWeather/Services/WeatherCache.swift'
existing_file = services_group.files.find { |f| f.path == 'WeatherCache.swift' }

if existing_file
  puts "✅ WeatherCache.swift already in project, removing duplicate..."
  existing_file.remove_from_project
end

if File.exist?(file_path)
  file_ref = services_group.new_file('WeatherCache.swift')
  main_target.source_build_phase.add_file_reference(file_ref)
  puts "✅ Added: #{file_path}"
else
  puts "⚠️  File not found: #{file_path}"
  exit 1
end

puts "Saving project..."
project.save

puts "✅ WeatherCache.swift added to project"
