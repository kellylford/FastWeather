#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'FastWeather.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the Views group
target = project.targets.first
views_group = project.main_group['FastWeather']['Views']

# Add UserGuideView.swift
file_path = 'FastWeather/Views/UserGuideView.swift'
file_ref = views_group.new_file(file_path)
target.add_file_references([file_ref])

project.save
puts "✅ Added UserGuideView.swift to Xcode project"
