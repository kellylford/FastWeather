#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'FastWeather.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main target
target = project.targets.first

# Find the Services and Views groups  
services_group = project.main_group.find_subpath('FastWeather/Services')
views_group = project.main_group.find_subpath('FastWeather/Views')

# Add FeatureFlags.swift to Services group
feature_flags_file = services_group.new_file('FeatureFlags.swift')
target.add_file_references([feature_flags_file])

# Add RadarService.swift to Services group
radar_service_file = services_group.new_file('RadarService.swift')
target.add_file_references([radar_service_file])

# Add RadarView.swift to Views group
radar_view_file = views_group.new_file('RadarView.swift')
target.add_file_references([radar_view_file])

# Add DeveloperSettingsView.swift to Views group
dev_settings_file = views_group.new_file('DeveloperSettingsView.swift')
target.add_file_references([dev_settings_file])

# Save the project
project.save

puts "✅ Successfully added radar files to Xcode project!"
