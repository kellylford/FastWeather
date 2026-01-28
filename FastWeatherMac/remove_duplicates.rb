#!/usr/bin/env ruby
require 'xcodeproj'

PROJECT_PATH = 'FastWeatherMac.xcodeproj'
TARGET_NAME = 'FastWeatherMac'

puts "🔍 Finding and removing duplicate file references..."

# Open the project
project = Xcodeproj::Project.open(PROJECT_PATH)
target = project.targets.find { |t| t.name == TARGET_NAME }

unless target
  puts "❌ Target '#{TARGET_NAME}' not found"
  exit 1
end

# Get the main group
main_group = project.main_group['FastWeatherMac']
unless main_group
  puts "❌ Group 'FastWeatherMac' not found"
  exit 1
end

removed_count = 0

['Services', 'Models', 'Views'].each do |group_name|
  subgroup = main_group[group_name]
  next unless subgroup
  
  # Track filenames we've seen
  seen_files = {}
  files_to_remove = []
  
  puts "\n#{group_name}:"
  subgroup.files.each do |file|
    filename = File.basename(file.path || '')
    
    if seen_files[filename]
      puts "  🗑️  Duplicate: #{filename}"
      files_to_remove << file
      removed_count += 1
    else
      seen_files[filename] = true
      puts "  ✅ Keeping: #{filename}"
    end
  end
  
  # Remove duplicates
  files_to_remove.each do |file|
    target.source_build_phase.remove_file_reference(file)
    file.remove_from_project
  end
end

# Save the project
project.save
puts "\n✅ Removed #{removed_count} duplicate file references!"
puts "📝 Ready to build..."
