#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'FastWeather.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target = project.targets.find { |t| t.name == 'FastWeather' }

# Get the compile sources build phase
compile_phase = target.source_build_phase

# Track seen file paths
seen_files = {}
duplicates_removed = 0

# Iterate through build files and remove duplicates
compile_phase.files.to_a.each do |build_file|
  file_ref = build_file.file_ref
  next unless file_ref
  
  file_path = file_ref.real_path.to_s
  
  if seen_files[file_path]
    puts "🗑️  Removing duplicate: #{file_ref.path}"
    compile_phase.files.delete(build_file)
    duplicates_removed += 1
  else
    seen_files[file_path] = true
    puts "✅ Keeping: #{file_ref.path}"
  end
end

if duplicates_removed > 0
  project.save
  puts "\n✨ Removed #{duplicates_removed} duplicate file references"
  puts "💾 Project saved"
else
  puts "\n✅ No duplicates found"
end
