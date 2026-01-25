#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'FastWeather.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target = project.targets.first
services_group = project.main_group['FastWeather']['Services']

# Step 1: Remove from build phase
puts "Cleaning build phases..."
target.source_build_phase.files.select { |build_file| 
  build_file.file_ref && build_file.file_ref.path&.include?('DirectionalCityService')
}.each do |build_file|
  puts "  Removing build file: #{build_file.file_ref.path}"
  target.source_build_phase.files.delete(build_file)
end

# Step 2: Remove file references from Services group
puts "Cleaning Services group..."
services_group.files.select { |f| 
  f.path&.include?('DirectionalCityService')
}.each do |ref|
  puts "  Removing file ref: #{ref.path}"
  ref.remove_from_project
end

# Step 3: Clean any orphaned references in the entire project
puts "Cleaning orphaned references..."
project.files.select { |f| 
  f.path&.include?('DirectionalCityService')
}.each do |ref|
  puts "  Removing orphaned ref: #{ref.path}"
  ref.remove_from_project
end

project.save
puts "✅ Cleanup complete - all DirectionalCityService references removed"
