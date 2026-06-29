#!/usr/bin/env ruby
# Adds an "Embed Watch Content" build phase to the iPhone Runner target so the
# AuroWatch Watch App.app product is copied into Runner.app/Watch/. Without this,
# iOS reports the watch app as "not installed" and WatchConnectivity transfers
# (in either direction) silently fail.
#
# Idempotent: re-running detects an existing embed phase and exits cleanly.

require 'xcodeproj'

PROJECT_PATH = File.expand_path('../Runner.xcodeproj', __dir__)
RUNNER_NAME = 'Runner'
WATCH_TARGET_NAME = 'AuroWatch Watch App'

project = Xcodeproj::Project.open(PROJECT_PATH)

runner = project.targets.find { |t| t.name == RUNNER_NAME }
watch  = project.targets.find { |t| t.name == WATCH_TARGET_NAME }

abort "Target '#{RUNNER_NAME}' not found"        unless runner
abort "Target '#{WATCH_TARGET_NAME}' not found"  unless watch

watch_product = watch.product_reference
abort "Watch product reference not found" unless watch_product

existing_embed = runner.copy_files_build_phases.find do |phase|
  phase.name == 'Embed Watch Content' ||
    phase.dst_path == '$(CONTENTS_FOLDER_PATH)/Watch'
end

if existing_embed
  puts "Embed Watch Content build phase already exists; ensuring it contains the watch product."
  embed_phase = existing_embed
else
  puts "Adding 'Embed Watch Content' build phase to #{RUNNER_NAME}."
  embed_phase = runner.new_copy_files_build_phase('Embed Watch Content')
  embed_phase.dst_subfolder_spec = '16'
  embed_phase.dst_path = '$(CONTENTS_FOLDER_PATH)/Watch'
end

already_present = embed_phase.files_references.any? { |ref| ref == watch_product }
if already_present
  puts "Watch app product already embedded; nothing to add."
else
  puts "Embedding '#{watch_product.path}' into Runner.app/Watch/."
  build_file = embed_phase.add_file_reference(watch_product, true)
  build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
end

unless runner.dependencies.any? { |d| d.target == watch }
  puts "Adding target dependency: #{RUNNER_NAME} -> #{WATCH_TARGET_NAME}."
  runner.add_dependency(watch)
end

# Reorder build phases so 'Embed Watch Content' runs BEFORE 'Thin Binary' and
# the Pods/Crashlytics scripts. The Thin Binary script declares Runner.app/
# Info.plist as an input, so any later phase writing inside Runner.app/ (such
# as Embed Watch Content writing to Runner.app/Watch/) creates a build cycle.
thin_binary_index = runner.build_phases.find_index do |phase|
  phase.respond_to?(:name) && phase.name == 'Thin Binary'
end
embed_index = runner.build_phases.find_index(embed_phase)

if thin_binary_index && embed_index && embed_index > thin_binary_index
  puts "Reordering: moving 'Embed Watch Content' before 'Thin Binary'."
  runner.build_phases.delete(embed_phase)
  runner.build_phases.insert(thin_binary_index, embed_phase)
end

project.save

puts "Done. project.pbxproj updated."
