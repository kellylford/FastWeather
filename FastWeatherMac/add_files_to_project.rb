#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'FastWeatherMac.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main target
target = project.targets.first

# Get the main group
main_group = project.main_group

# Find or create groups
services_group = main_group['FastWeatherMac']['Services'] || main_group['FastWeatherMac'].new_group('Services')
models_group = main_group['FastWeatherMac']['Models'] || main_group['FastWeatherMac'].new_group('Models')
views_group = main_group['FastWeatherMac']['Views'] || main_group['FastWeatherMac'].new_group('Views')

# Files to add
services_files = [
  'FastWeatherMac/Services/RadarService.swift',
  'FastWeatherMac/Services/RegionalWeatherService.swift',
  'FastWeatherMac/Services/DirectionalCityService.swift',
  'FastWeatherMac/Services/HistoricalWeatherCache.swift'
]

models_files = [
  'FastWeatherMac/Models/Settings.swift'
]

views_files = [
  'FastWeatherMac/Views/RadarView.swift',
  'FastWeatherMac/Views/WeatherAroundMeView.swift',
  'FastWeatherMac/Views/HistoricalWeatherView.swift',
  'FastWeatherMac/Views/DeveloperSettingsView.swift'
]

# Helper function to add file if not already in project
def add_file_if_needed(group, file_path, target, project)
  file_name = File.basename(file_path)
  
  # Check if file already exists in group
  existing_file = group.files.find { |f| f.path == file_name }
  return if existing_file
  
  # Check if file exists on disk
  unless File.exist?(file_path)
    puts "⚠️  File not found: #{file_path}"
    return
  end
  
  # Add file reference
  file_ref = group.new_reference(file_path)
  
  # Add to target
  target.add_file_references([file_ref])
  
  puts "✅ Added: #{file_name}"
end

puts "📦 Adding files to FastWeatherMac.xcodeproj..."
puts ""

# Add services
puts "Services:"
services_files.each do |file|
  add_file_if_needed(services_group, file, target, project)
end

puts ""
puts "Models:"
models_files.each do |file|
  add_file_if_needed(models_group, file, target, project)
end

puts ""
puts "Views:"
views_files.each do |file|
  add_file_if_needed(views_group, file, target, project)
end

# Save project
project.save

puts ""
puts "✅ Project updated successfully!"
puts "📝 Now building project..."
