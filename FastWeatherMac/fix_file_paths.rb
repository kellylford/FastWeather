#!/usr/bin/env ruby
require 'xcodeproj'

PROJECT_PATH = 'FastWeatherMac.xcodeproj'
TARGET_NAME = 'FastWeatherMac'

puts "🔧 Fixing file paths in Xcode project..."

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

fixed_count = 0

FILES_TO_FIX = {
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

FILES_TO_FIX.each do |group_name, filenames|
  subgroup = main_group[group_name]
  next unless subgroup
  
  puts "\n#{group_name}:"
  
  filenames.each do |filename|
    # Find the file reference
    file_ref = subgroup.files.find { |f| File.basename(f.path || '') == filename }
    
    if file_ref
      old_path = file_ref.path
      
      # Fix the path to be relative to the group
      # Should be just the filename, not FastWeatherMac/Services/filename
      if old_path&.include?('FastWeatherMac/')
        file_ref.path = filename
        file_ref.source_tree = '<group>'
        puts "  ✅ Fixed: #{old_path} → #{filename}"
        fixed_count += 1
      else
        puts "  ⏭️  Already correct: #{filename}"
      end
    else
      puts "  ⚠️  Not found: #{filename}"
    end
  end
end

# Save the project
project.save
puts "\n✅ Fixed #{fixed_count} file path(s)!"
puts "📝 Ready to build..."
