#!/usr/bin/env ruby
require 'xcodeproj'

# Open the Xcode project
project_path = 'FastWeather.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main target
target = project.targets.first

# Files to check for duplicates
files_to_check = [
  'HistoricalWeather.swift',
  'HistoricalWeatherView.swift',
  'HistoricalWeatherCache.swift'
]

# Remove duplicate file references from build phase
build_phase = target.source_build_phase
files_to_check.each do |filename|
  matching_files = build_phase.files.select { |f| 
    f.file_ref && f.file_ref.path && f.file_ref.path.include?(filename)
  }
  
  if matching_files.count > 1
    puts "Found #{matching_files.count} references to #{filename}, keeping first, removing duplicates..."
    matching_files[1..-1].each do |duplicate|
      build_phase.files.delete(duplicate)
      puts "  Removed duplicate: #{duplicate}"
    end
  end
end

# Save the project
project.save

puts "✅ Successfully removed duplicate file references"
