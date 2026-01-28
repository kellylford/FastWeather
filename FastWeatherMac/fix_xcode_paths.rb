#!/usr/bin/env ruby
require 'xcodeproj'

PROJECT_PATH = 'FastWeatherMac.xcodeproj'
TARGET_NAME = 'FastWeatherMac'

puts "🔧 Fixing file paths in #{PROJECT_PATH}..."

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

# Remove incorrectly referenced files
puts "\n🗑️  Removing incorrect file references..."
removed_count = 0

['Services', 'Models', 'Views'].each do |group_name|
  subgroup = main_group[group_name]
  next unless subgroup
  
  files_to_remove = []
  subgroup.files.each do |file|
    if file.path&.include?('FastWeatherMac/FastWeatherMac/')
      puts "  Removing: #{file.path}"
      files_to_remove << file
      removed_count += 1
    end
  end
  
  files_to_remove.each do |file|
    target.source_build_phase.remove_file_reference(file)
    file.remove_from_project
  end
end

puts "✅ Removed #{removed_count} incorrect references"

# Now add files with correct paths
FILES_TO_ADD = {
  'Services' => [
    'RadarService.swift',
    'RegionalWeatherService.swift',
    'DirectionalCityService.swift',
    'HistoricalWeatherCache.swift'
  ],
  'Models' => [
    'Settings.swift'
  ],
  'Views' => [
    'RadarView.swift',
    'WeatherAroundMeView.swift',
    'HistoricalWeatherView.swift',
    'DeveloperSettingsView.swift'
  ]
}

puts "\n➕ Adding files with correct paths..."
added_count = 0

FILES_TO_ADD.each do |group_name, files|
  puts "\n#{group_name}:"
  
  subgroup = main_group[group_name]
  unless subgroup
    puts "  ❌ Group '#{group_name}' not found"
    next
  end
  
  files.each do |filename|
    # Check if file exists in the group's directory
    group_path = File.join('FastWeatherMac', group_name, filename)
    
    unless File.exist?(group_path)
      puts "  ⚠️  File not found: #{group_path}"
      next
    end
    
    # Check if already correctly added
    existing = subgroup.files.find { |f| f.path == filename && !f.path.include?('FastWeatherMac/FastWeatherMac/') }
    if existing
      puts "  ⏭️  Already correct: #{filename}"
      next
    end
    
    # Add the file with just the filename (relative to the group)
    file_ref = subgroup.new_reference(filename)
    file_ref.source_tree = '<group>'
    target.source_build_phase.add_file_reference(file_ref)
    puts "  ✅ Added: #{filename}"
    added_count += 1
  end
end

# Save the project
project.save
puts "\n✅ Fixed #{removed_count} incorrect paths and added #{added_count} correct references!"
puts "📝 Ready to build..."
