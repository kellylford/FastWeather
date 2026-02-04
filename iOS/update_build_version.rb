#!/usr/bin/env ruby
# Update build version to 18 in Xcode project settings

require 'xcodeproj'

project_path = 'FastWeather.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main target
main_target = project.targets.find { |t| t.name == 'FastWeather' }

if main_target.nil?
  puts "❌ Error: Could not find FastWeather target"
  exit 1
end

# Update CURRENT_PROJECT_VERSION in all build configurations
main_target.build_configurations.each do |config|
  old_version = config.build_settings['CURRENT_PROJECT_VERSION']
  config.build_settings['CURRENT_PROJECT_VERSION'] = '18'
  puts "#{config.name}: Updated CURRENT_PROJECT_VERSION from #{old_version} to 18"
end

project.save

puts "✅ Build version updated to 18"
puts "\nRebuild the project to see the change in Settings → About"
