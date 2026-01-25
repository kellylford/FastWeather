#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'FastWeather.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Remove all UserGuideView references
target = project.targets.first
views_group = project.main_group['FastWeather']['Views']

# Remove existing file references
views_group.files.select { |f| f.display_name == 'UserGuideView.swift' }.each(&:remove_from_project)

# Remove from build phases
target.source_build_phase.files.select { |f| f.display_name == 'UserGuideView.swift' }.each do |f|
  target.source_build_phase.files.delete(f)
end

# Now add it correctly (relative to Views group)
file_ref = views_group.new_reference('UserGuideView.swift')
target.add_file_references([file_ref])

project.save
puts "✅ Fixed UserGuideView.swift in project"
