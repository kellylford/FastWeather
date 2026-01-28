#!/usr/bin/env ruby
require 'xcodeproj'

PROJECT_PATH = 'FastWeatherMac.xcodeproj'
TARGET_NAME = 'FastWeatherMac'

puts "➕ Adding missing files to Xcode project..."

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

# Files to add
FILES_TO_ADD = {
  'Services' => ['FeatureFlags.swift', 'SettingsManager.swift'],
  'Models' => ['HistoricalWeather.swift']
}

added_count = 0

FILES_TO_ADD.each do |group_name, filenames|
  subgroup = main_group[group_name]
  unless subgroup
    puts "❌ Group '#{group_name}' not found"
    next
  end
  
  puts "\n#{group_name}:"
  
  filenames.each do |filename|
    # Check if already added
    existing = subgroup.files.find { |f| File.basename(f.path || '') == filename }
    if existing
      puts "  ⏭️  Already exists: #{filename}"
      next
    end
    
    # Add the file
    file_ref = subgroup.new_reference(filename)
    file_ref.source_tree = '<group>'
    target.source_build_phase.add_file_reference(file_ref)
    puts "  ✅ Added: #{filename}"
    added_count += 1
  end
end

# Save the project
project.save
puts "\n✅ Added #{added_count} file(s)!"
puts "📝 Ready to build..."
