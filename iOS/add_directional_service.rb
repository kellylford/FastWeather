#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'FastWeather.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the Services group
services_group = project.main_group['FastWeather']['Services']

# Add DirectionalCityService.swift
file_ref = services_group.new_reference('DirectionalCityService.swift')
file_ref.source_tree = '<group>'

# Add to target
target = project.targets.first
target.source_build_phase.add_file_reference(file_ref)

project.save

puts "✅ Added DirectionalCityService.swift to project"
puts "File reference count: #{services_group.files.count { |f| f.path == 'DirectionalCityService.swift' }}"

