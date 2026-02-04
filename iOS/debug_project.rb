#!/usr/bin/env ruby
# Debug project structure

require 'xcodeproj'

project_path = 'FastWeather.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find Services group
services_group = project.main_group.find_subpath('FastWeather/Services', false)

if services_group
  puts "Services group found:"
  puts "  Name: #{services_group.name}"
  puts "  Path: #{services_group.path}"
  puts "  Real path: #{services_group.real_path}"
  puts "  Source tree: #{services_group.source_tree}"
  
  puts "\n  Files in group:"
  services_group.files.each do |file|
    puts "    - #{file.path} (real: #{file.real_path})"
  end
else
  puts "Services group not found"
end
