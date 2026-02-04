#!/usr/bin/env ruby
# Add FastWeatherTests target to Xcode project

require 'xcodeproj'

project_path = 'FastWeather.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main target
main_target = project.targets.find { |t| t.name == 'FastWeather' }

if main_target.nil?
  puts "❌ Error: Could not find FastWeather target"
  exit 1
end

# Check if test target already exists
existing_test_target = project.targets.find { |t| t.name == 'FastWeatherTests' }

if existing_test_target
  puts "✅ FastWeatherTests target already exists"
  test_target = existing_test_target
else
  # Create test target
  puts "Creating FastWeatherTests target..."
  test_target = project.new_target(:unit_test_bundle, 'FastWeatherTests', :ios, '17.0')
  
  # Set product name
  test_target.build_configurations.each do |config|
    config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.fastweather.FastWeatherTests'
    config.build_settings['SWIFT_VERSION'] = '5.0'
    config.build_settings['TARGETED_DEVICE_FAMILY'] = '1,2'
    config.build_settings['TEST_HOST'] = '$(BUILT_PRODUCTS_DIR)/FastWeather.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/FastWeather'
    config.build_settings['BUNDLE_LOADER'] = '$(TEST_HOST)'
  end
  
  # Add dependency on main target
  test_target.add_dependency(main_target)
  
  puts "✅ Created FastWeatherTests target"
end

# Get or create FastWeatherTests group
tests_group = project.main_group.find_subpath('FastWeatherTests', true)
tests_group.set_source_tree('SOURCE_ROOT')

# Add test files
test_files = [
  'FastWeatherTests/DateParserTests.swift',
  'FastWeatherTests/FormatHelperTests.swift',
  'FastWeatherTests/Info.plist'
]

test_files.each do |file_path|
  # Check if file already exists in group
  existing_file = tests_group.files.find { |f| f.path == File.basename(file_path) }
  
  if existing_file
    puts "  File already in project: #{file_path}"
  else
    if File.exist?(file_path)
      file_ref = tests_group.new_reference(file_path)
      file_ref.last_known_file_type = case File.extname(file_path)
        when '.swift' then 'sourcecode.swift'
        when '.plist' then 'text.plist.xml'
        else 'text'
      end
      
      # Add .swift files to compile sources phase
      if file_path.end_with?('.swift')
        test_target.source_build_phase.add_file_reference(file_ref)
      end
      
      puts "  ✅ Added: #{file_path}"
    else
      puts "  ⚠️  File not found: #{file_path}"
    end
  end
end

# Ensure main target has "Defines Module" set to YES
main_target.build_configurations.each do |config|
  config.build_settings['DEFINES_MODULE'] = 'YES'
end

puts "\nSaving project..."
project.save

puts "\n✅ Test target setup complete!"
puts "\n📋 Next steps:"
puts "1. Open FastWeather.xcodeproj in Xcode"
puts "2. Select the FastWeather scheme"
puts "3. Press Cmd+U to run tests"
puts "\n💡 Tests will validate DateParser and FormatHelper functionality"
