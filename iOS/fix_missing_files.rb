#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'FastWeather.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target = project.targets.find { |t| t.name == 'FastWeather' }

# Files to ensure are in the project
files_to_add = [
  'FastWeather/Models/HistoricalWeather.swift',
  'FastWeather/Services/HistoricalWeatherCache.swift',
  'FastWeather/Views/HistoricalWeatherView.swift'
]

files_to_add.each do |file_path|
  full_path = File.join(Dir.pwd, file_path)
  
  if !File.exist?(full_path)
    puts "❌ File not found: #{file_path}"
    next
  end
  
  # Check if already in compile sources
  compile_phase = target.source_build_phase
  already_exists = compile_phase.files.any? do |build_file|
    build_file.file_ref&.real_path&.to_s == full_path
  end
  
  if already_exists
    puts "✅ Already in project: #{file_path}"
    next
  end
  
  # Find or create the file reference
  file_ref = project.files.find { |f| f.real_path.to_s == full_path }
  
  if file_ref.nil?
    # Need to add to project groups first
    group_path = File.dirname(file_path).split('/')
    group = project.main_group
    
    group_path.each do |group_name|
      next if group_name == '.'
      subgroup = group[group_name]
      if subgroup.nil?
        subgroup = group.new_group(group_name)
      end
      group = subgroup
    end
    
    file_ref = group.new_file(full_path)
  end
  
  # Add to compile sources
  compile_phase.add_file_reference(file_ref)
  puts "✨ Added to compile sources: #{file_path}"
end

project.save
puts "\n💾 Project saved"
