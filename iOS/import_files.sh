#!/bin/bash
# Use ruby to manipulate the Xcode project file safely
gem install xcodeproj --user-install 2>/dev/null || true

ruby << 'RUBY'
require 'xcodeproj'

project_path = 'FastWeather.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main target
target = project.targets.first

# Find the Models and Views groups
models_group = project.main_group.find_subpath('FastWeather/Models')
views_group = project.main_group.find_subpath('FastWeather/Views')

# Add WeatherAlert.swift to Models group
weather_alert_file = models_group.new_file('WeatherAlert.swift')
target.add_file_references([weather_alert_file])

# Add AlertDetailView.swift to Views group  
alert_detail_file = views_group.new_file('AlertDetailView.swift')
target.add_file_references([alert_detail_file])

# Save the project
project.save

puts "✅ Successfully added files to Xcode project!"
RUBY
