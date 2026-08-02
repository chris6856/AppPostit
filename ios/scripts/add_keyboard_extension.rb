#!/usr/bin/env ruby
# Adds the AppPostItKeyboard custom-keyboard extension as a second target
# in Runner.xcodeproj, since that's normally done through Xcode's "New
# Target" GUI wizard and this project is maintained without local Xcode
# access. Run on any machine with Ruby + the xcodeproj gem (Codemagic's
# macOS build image has both) -- see codemagic.yaml, which runs this as a
# pre_build script before `flutter build ipa`.
#
# Idempotent: safe to run on every build. If the target already exists,
# only its file list and build settings are re-synced (in case source
# files were added/changed), the target itself isn't recreated.

require 'xcodeproj'

PROJECT_PATH = File.expand_path('../Runner.xcodeproj', __dir__)
EXTENSION_NAME = 'AppPostItKeyboard'
EXTENSION_BUNDLE_ID = 'com.apppostit.apppostit.keyboard'
EXTENSION_DIR = File.expand_path('../AppPostItKeyboard', __dir__)
APP_GROUP_ID = 'group.com.apppostit.apppostit'

project = Xcodeproj::Project.open(PROJECT_PATH)

runner_target = project.targets.find { |t| t.name == 'Runner' }
raise "Runner target not found in #{PROJECT_PATH}" unless runner_target

deployment_target = runner_target.build_configurations.first
  .build_settings['IPHONEOS_DEPLOYMENT_TARGET']

# --- Runner: point it at its own entitlements file (App Group) ---------
runner_target.build_configurations.each do |config|
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements'
end

# --- Keyboard extension target: create if missing -----------------------
keyboard_target = project.targets.find { |t| t.name == EXTENSION_NAME }

if keyboard_target.nil?
  keyboard_target = project.new_target(
    :app_extension,
    EXTENSION_NAME,
    :ios,
    deployment_target,
    project.main_group,
    :swift
  )

  runner_target.add_dependency(keyboard_target)

  embed_phase = runner_target.copy_files_build_phases.find { |p| p.name == 'Embed App Extensions' } ||
    runner_target.new_copy_files_build_phase('Embed App Extensions')
  embed_phase.dst_subfolder_spec = '13' # PlugIns
  embed_phase.symbol_dst_subfolder_spec = :plug_ins
  unless embed_phase.files.any? { |f| f.file_ref == keyboard_target.product_reference }
    build_file = embed_phase.add_file_reference(keyboard_target.product_reference)
    build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
  end

  # libsqlite3 for SqliteReader.swift's raw C API usage.
  sqlite_ref = project.frameworks_group.new_reference(
    'usr/lib/libsqlite3.tbd'
  )
  sqlite_ref.source_tree = 'SDKROOT'
  keyboard_target.frameworks_build_phase.add_file_reference(sqlite_ref)
end

# --- Source files: sync every time in case files were added -------------
group = project.main_group[EXTENSION_NAME] || project.main_group.new_group(EXTENSION_NAME, EXTENSION_DIR)

swift_files = Dir.glob(File.join(EXTENSION_DIR, '*.swift')).sort
swift_files.each do |path|
  basename = File.basename(path)
  next if group[basename]

  file_ref = group.new_reference(path)
  keyboard_target.source_build_phase.add_file_reference(file_ref)
end

# --- Build settings -------------------------------------------------------
keyboard_target.build_configurations.each do |config|
  settings = config.build_settings
  settings['PRODUCT_BUNDLE_IDENTIFIER'] = EXTENSION_BUNDLE_ID
  settings['PRODUCT_NAME'] = EXTENSION_NAME
  settings['INFOPLIST_FILE'] = "#{EXTENSION_NAME}/Info.plist"
  settings['CODE_SIGN_ENTITLEMENTS'] = "#{EXTENSION_NAME}/#{EXTENSION_NAME}.entitlements"
  settings['SWIFT_VERSION'] = '5.0'
  settings['IPHONEOS_DEPLOYMENT_TARGET'] = deployment_target
  settings['TARGETED_DEVICE_FAMILY'] = runner_target.build_configurations.first
    .build_settings['TARGETED_DEVICE_FAMILY']
  settings['CODE_SIGN_STYLE'] = 'Automatic'
  settings['CURRENT_PROJECT_VERSION'] = '$(FLUTTER_BUILD_NUMBER)'
  settings['MARKETING_VERSION'] = '$(FLUTTER_BUILD_NAME)'
  settings['SKIP_INSTALL'] = 'YES'
end

runner_target.build_configurations.each do |config|
  config.build_settings['CODE_SIGN_STYLE'] ||= 'Automatic'
end

project.save

puts "#{EXTENSION_NAME} target ready (bundle id #{EXTENSION_BUNDLE_ID}, " \
  "app group #{APP_GROUP_ID})."
