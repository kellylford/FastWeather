#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'FastWeatherMac.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target = project.targets.first
models_group = project.main_group['FastWeatherMac']['Models']

# Add Settings.swift to the project
file_path = 'FastWeatherMac/Models/Settings.swift'
file_ref = models_group.new_file(file_path)
target.add_file_references([file_ref])

project.save
puts "✅ Added Settings.swift to Xcode project!"
