#!/usr/bin/env ruby
# Adds AuroWatch source files to the watchOS target and WatchBridge to Runner target.
# Run from: ios/ directory
# Usage: ruby setup_watch_target.rb

require 'xcodeproj'
require 'fileutils'

PROJECT_PATH = File.join(__dir__, 'Runner.xcodeproj')
WATCH_APP_DIR = File.join(__dir__, 'AuroWatch Watch App')
WATCH_BRIDGE_DIR = File.join(__dir__, 'Runner', 'WatchBridge')

puts "Opening project: #{PROJECT_PATH}"
project = Xcodeproj::Project.open(PROJECT_PATH)

# Find targets
watch_target = project.targets.find { |t| t.name.include?('AuroWatch') }
runner_target = project.targets.find { |t| t.name == 'Runner' }

unless watch_target
  puts "ERROR: AuroWatch target not found. Available targets:"
  project.targets.each { |t| puts "  - #{t.name}" }
  exit 1
end

puts "Found watch target: #{watch_target.name}"
puts "Found phone target: #{runner_target.name}"

# Find or create the AuroWatch group in the project
watch_group = project.main_group.groups.find { |g| g.name == 'AuroWatch Watch App' || g.display_name == 'AuroWatch Watch App' }
unless watch_group
  watch_group = project.main_group.groups.find { |g| g.name == 'AuroWatch' || g.display_name == 'AuroWatch' }
end

unless watch_group
  puts "Creating AuroWatch Watch App group..."
  watch_group = project.main_group.new_group('AuroWatch Watch App', 'AuroWatch Watch App')
end

puts "Using group: #{watch_group.name}"

# Clear existing file references in the watch group (Xcode boilerplate)
watch_group.clear

# Helper: recursively add files to a group and target
def add_files_recursive(dir, group, target, project)
  Dir.entries(dir).sort.each do |entry|
    next if entry.start_with?('.')
    next if entry == 'SETUP.md'  # skip docs
    next if entry == 'Preview Content'  # skip preview

    full_path = File.join(dir, entry)

    if File.directory?(full_path)
      # Create subgroup
      subgroup = group.new_group(entry, entry)
      add_files_recursive(full_path, subgroup, target, project)
    else
      # Add file reference
      file_ref = group.new_file(entry)

      # Add .swift files to target's compile sources
      if entry.end_with?('.swift')
        target.source_build_phase.add_file_reference(file_ref)
        puts "  + #{entry} (compile)"
      elsif entry.end_with?('.json') || entry == 'Contents.json'
        # Asset catalog contents — handled by xcassets reference
      elsif entry == 'Info.plist'
        puts "  + #{entry} (info plist)"
      elsif entry == 'AuroWatch.entitlements'
        puts "  + #{entry} (entitlements)"
      end

      # Add xcassets to resources
      if entry.end_with?('.xcassets')
        target.resources_build_phase.add_file_reference(file_ref)
        puts "  + #{entry} (resource)"
      end
    end
  end
end

# Handle Assets.xcassets specially — add as a single resource, not individual files
puts "\n--- Adding AuroWatch files ---"

Dir.entries(WATCH_APP_DIR).sort.each do |entry|
  next if entry.start_with?('.')
  next if entry == 'SETUP.md'
  next if entry == 'Preview Content'

  full_path = File.join(WATCH_APP_DIR, entry)

  if entry == 'Assets.xcassets'
    # Add xcassets as a folder reference (Xcode handles internals)
    ref = watch_group.new_file(entry)
    target.resources_build_phase.add_file_reference(ref) rescue nil
    puts "  + Assets.xcassets (resource)"
  elsif File.directory?(full_path)
    subgroup = watch_group.new_group(entry, entry)
    add_files_recursive(full_path, subgroup, watch_target, project)
  else
    file_ref = watch_group.new_file(entry)
    if entry.end_with?('.swift')
      watch_target.source_build_phase.add_file_reference(file_ref)
      puts "  + #{entry} (compile)"
    elsif entry == 'Info.plist'
      puts "  + #{entry} (info plist — set in build settings)"
    elsif entry == 'AuroWatch.entitlements'
      puts "  + #{entry} (entitlements — set in build settings)"
    end
  end
end

# Now add WatchBridge to Runner target
puts "\n--- Adding WatchBridge to Runner ---"
runner_group = project.main_group.groups.find { |g| g.name == 'Runner' }
if runner_group
  bridge_group = runner_group.new_group('WatchBridge', 'WatchBridge')
  Dir.entries(WATCH_BRIDGE_DIR).sort.each do |entry|
    next if entry.start_with?('.')
    next unless entry.end_with?('.swift')

    full_path = File.join(WATCH_BRIDGE_DIR, entry)
    file_ref = bridge_group.new_file(entry)
    runner_target.source_build_phase.add_file_reference(file_ref)
    puts "  + #{entry} (compile → Runner)"
  end
end

# Set build settings for watch target
puts "\n--- Configuring build settings ---"
watch_target.build_configurations.each do |config|
  config.build_settings['INFOPLIST_FILE'] = 'AuroWatch Watch App/Info.plist'
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'AuroWatch Watch App/AuroWatch.entitlements'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['WATCHOS_DEPLOYMENT_TARGET'] ||= '10.0'
  puts "  Configured: #{config.name}"
end

# Save
project.save
puts "\n✅ Project saved successfully!"
puts "   Watch target: #{watch_target.source_build_phase.files.count} source files"
puts "   Open Xcode and build the AuroWatch scheme."
