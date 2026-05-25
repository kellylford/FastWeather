#!/usr/bin/env ruby
# Adds the FastWeatherWidget extension target to FastWeather.xcodeproj.
# Run from the iOS/ directory:  ruby add_widget_target.rb

require 'xcodeproj'

PROJECT_PATH       = 'FastWeather.xcodeproj'
WIDGET_NAME        = 'FastWeatherWidget'
WIDGET_BUNDLE_ID   = 'com.weatherfast.app.widget'
DEPLOYMENT_TARGET  = '17.0'

project    = Xcodeproj::Project.open(PROJECT_PATH)
main_target = project.targets.find { |t| t.name == 'FastWeather' }
abort '❌  Could not find FastWeather target' unless main_target

# ── Guard: skip if widget target already exists ─────────────────────────────
if project.targets.any? { |t| t.name == WIDGET_NAME }
  puts "ℹ️  #{WIDGET_NAME} target already exists — nothing to do."
  exit 0
end

# ── 1. Create the widget extension target ───────────────────────────────────
widget_target = project.new_target(:app_extension, WIDGET_NAME, :ios, DEPLOYMENT_TARGET)

# ── 2. Build settings ────────────────────────────────────────────────────────
dev_team = main_target.build_configurations.first
            .build_settings.fetch('DEVELOPMENT_TEAM', '')

widget_target.build_configurations.each do |cfg|
  cfg.build_settings.merge!(
    'PRODUCT_BUNDLE_IDENTIFIER'           => WIDGET_BUNDLE_ID,
    'INFOPLIST_FILE'                      => "#{WIDGET_NAME}/Info.plist",
    'CODE_SIGN_ENTITLEMENTS'              => "#{WIDGET_NAME}/#{WIDGET_NAME}.entitlements",
    'CODE_SIGN_STYLE'                     => 'Automatic',
    'CODE_SIGN_IDENTITY'                  => 'Apple Development',
    'DEVELOPMENT_TEAM'                    => dev_team,
    'SWIFT_VERSION'                       => '5.0',
    'IPHONEOS_DEPLOYMENT_TARGET'          => DEPLOYMENT_TARGET,
    'TARGETED_DEVICE_FAMILY'             => '1,2',
    'SKIP_INSTALL'                        => 'YES',
    'ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES' => 'NO',
    'LD_RUNPATH_SEARCH_PATHS'            => ['$(inherited)', '@executable_path/../../Frameworks'],
    'ENABLE_APP_SANDBOX'                  => 'NO',
    'DEFINES_MODULE'                      => 'YES',
  )
end

# ── 3. Create the group and add widget source files ──────────────────────────
widget_group = project.main_group.new_group(WIDGET_NAME, WIDGET_NAME)

%w[
  FastWeatherWidget.swift
  WidgetWeatherFetcher.swift
  WidgetViews.swift
].each do |filename|
  ref = widget_group.new_file(filename)
  widget_target.add_file_references([ref])
end

# Add entitlements + Info.plist to the group (not compiled)
widget_group.new_file("#{WIDGET_NAME}.entitlements")
widget_group.new_file('Info.plist')

# ── 4. Add AppGroup.swift (shared constant) to the widget target ─────────────
app_group_ref = project.main_group.find_subpath('FastWeather/Services/AppGroup.swift', false)
if app_group_ref
  widget_target.source_build_phase.add_file_reference(app_group_ref)
  puts '✅  Added AppGroup.swift to widget compile sources'
else
  puts '⚠️   Could not find AppGroup.swift — add it manually to the widget target'
end

# ── 5. Link required system frameworks ──────────────────────────────────────
%w[WidgetKit SwiftUI AppIntents].each do |fw|
  ref = project.frameworks_group.new_reference("#{fw}.framework")
  ref.source_tree         = 'SDKROOT'
  ref.last_known_file_type = 'wrapper.framework'
  widget_target.frameworks_build_phase.add_file_reference(ref)
end

# ── 6. Add widget as a dependency of the main app ───────────────────────────
main_target.add_dependency(widget_target)

# ── 7. Embed widget extension in the main app ────────────────────────────────
embed_phase = main_target.new_copy_files_build_phase('Embed Foundation Extensions')
embed_phase.dst_subfolder_spec = '13'  # PlugIns
build_file = embed_phase.add_file_reference(widget_target.product_reference)
build_file.settings = { 'ATTRIBUTES' => %w[CodeSignOnCopy RemoveHeadersOnCopy] }

# ── 8. Save ──────────────────────────────────────────────────────────────────
project.save
puts "✅  #{WIDGET_NAME} target added to #{PROJECT_PATH}"
puts ''
puts 'Next steps in Xcode:'
puts '  1. Open FastWeather.xcodeproj'
puts '  2. Select the FastWeather target → Signing & Capabilities'
puts '     → confirm "App Groups" shows group.com.weatherfast.app'
puts '  3. Select the FastWeatherWidget target → Signing & Capabilities'
puts '     → add "App Groups" capability and enable group.com.weatherfast.app'
puts '  4. Build (Cmd+B) — both targets should compile cleanly'
