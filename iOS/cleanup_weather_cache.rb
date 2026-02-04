#!/usr/bin/env ruby
# Remove duplicate WeatherCache.swift references

require 'xcodeproj'

project_path = 'FastWeather.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main target
main_target = project.targets.find { |t| t.name == 'FastWeather' }

if main_target.nil?
  puts "❌ Error: Could not find FastWeather target"
  exit 1
end

# Remove all references to WeatherCache.swift
removed_count = 0

project.files.each do |file|
  if file.path.to_s.include?('WeatherCache.swift')
    puts "Found reference: #{file.path} (realpath: #{file.real_path})"
    # Remove from build phase
    main_target.source_build_phase.files.each do |build_file|
      if build_file.file_ref == file
        build_file.remove_from_project
        removed_count += 1
        puts "  Removed from build phase"
      end
    end
    # Remove file reference
    file.remove_from_project
    removed_count += 1
    puts "  Removed file reference"
  end
end

puts "Removed #{removed_count} references"
puts "Saving project..."
project.save

puts "✅ Cleaned up duplicate references"
puts "\nNow run add_weather_cache.rb to add the file correctly"
