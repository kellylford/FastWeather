#!/usr/bin/env ruby
# Script to fix LocationService.swift path in Xcode project

require 'xcodeproj'

project_path = 'FastWeather.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find and remove incorrect file reference
project.files.each do |file|
  if file.path&.include?('FastWeather/Services/LocationService.swift')
    puts "Found file reference: #{file.path}"
    file.remove_from_project
    puts "✅ Removed incorrect reference"
  end
end

# Find the Services group
services_group = project.main_group.groups.find { |g| g.path == 'FastWeather' }
                        &.groups&.find { |g| g.path == 'Services' }

if services_group.nil?
  puts "❌ Could not find Services group"
  exit 1
end

# Add LocationService.swift with correct path
file_ref = services_group.new_reference('LocationService.swift')

# Add to target
target = project.targets.find { |t| t.name == 'FastWeather' }
if target
  target.add_file_references([file_ref])
  puts "✅ Added LocationService.swift to FastWeather target with correct path"
else
  puts "❌ Could not find FastWeather target"
  exit 1
end

# Save project
project.save

puts "✅ Successfully fixed LocationService.swift path in Xcode project"
