#!/usr/bin/env ruby
# Add HistoricalWeatherCache.swift back to project

require 'xcodeproj'

project_path = 'FastWeather.xcodeproj'
project = Xcodeproj::Project.open(project_path)

main_target = project.targets.find { |t| t.name == 'FastWeather' }
services_group = project.main_group.find_subpath('FastWeather/Services', false)

# Add HistoricalWeatherCache.swift
file_ref = services_group.new_file('HistoricalWeatherCache.swift')
main_target.source_build_phase.add_file_reference(file_ref)

puts "✅ Added HistoricalWeatherCache.swift"

project.save
