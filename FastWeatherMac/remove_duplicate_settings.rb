#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'FastWeatherMac.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find all file references named Settings.swift
settings_refs = project.files.select { |f| f.path && f.path.include?('Settings.swift') }

puts "Found #{settings_refs.count} Settings.swift file reference(s):"
settings_refs.each_with_index do |ref, i|
  puts "  #{i+1}. #{ref.path} (UUID: #{ref.uuid})"
end

if settings_refs.count > 1
  puts "\n⚠️  Multiple Settings.swift references found! Removing duplicates..."
  
  # Keep the first one, remove the rest
  to_keep = settings_refs.first
  to_remove = settings_refs[1..-1]
  
  to_remove.each do |ref|
    ref.remove_from_project
    puts "  ✅ Removed duplicate: #{ref.path}"
  end
  
  project.save
  puts "\n✅ Project saved with duplicates removed!"
else
  puts "\n✅ No duplicates found."
end
