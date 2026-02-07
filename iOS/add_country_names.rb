#!/user/bin/env ruby
require 'xcodeproj'

# Open the Xcode project
project_path = 'FastWeather.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main target
target = project.targets.first

# Find or create the Utilities group under FastWeather group
fastweather_group = project.main_group.groups.find { |g| g.path == 'FastWeather' }

if fastweather_group.nil?
  puts "❌ Could not find FastWeather group"
  exit 1
end

utils_group = fastweather_group.groups.find { |g| g.path == 'Utilities' }

if utils_group.nil?
  puts "Creating Utilities group..."
  utils_group = fastweather_group.new_group('Utilities', 'Utilities')
end

# Add CountryNames.swift file with correct relative path from the group
file_ref = utils_group.new_file('CountryNames.swift')

# Add to target using add_file_references
target.add_file_references([file_ref])

# Save the project
project.save

puts "✅ Successfully added CountryNames.swift to Xcode project"
