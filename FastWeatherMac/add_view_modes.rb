#!/usr/bin/env ruby
require 'xcodeproj'

PROJECT_PATH = 'FastWeatherMac.xcodeproj'
TARGET_NAME = 'FastWeatherMac'

puts "➕ Adding view mode files to Xcode project..."

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

# Get Views group
views_group = main_group['Views']
unless views_group
  puts "❌ Group 'Views' not found"
  exit 1
end

FILES_TO_ADD = ['TableView.swift', 'ListView.swift', 'FlatView.swift']

added_count = 0

puts "\nViews:"
FILES_TO_ADD.each do |filename|
  # Check if already added
  existing = views_group.files.find { |f| File.basename(f.path || '') == filename }
  if existing
    puts "  ⏭️  Already exists: #{filename}"
    next
  end
  
  # Add the file
  file_ref = views_group.new_reference(filename)
  file_ref.source_tree = '<group>'
  target.source_build_phase.add_file_reference(file_ref)
  puts "  ✅ Added: #{filename}"
  added_count += 1
end

# Save the project
project.save
puts "\n✅ Added #{added_count} view mode file(s)!"
puts "📝 Ready to build..."
