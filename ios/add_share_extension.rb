require 'xcodeproj'
require 'pathname'

BUNDLE_ID = ENV.fetch('BUNDLE_ID')
APP_GROUP = ENV.fetch('APP_GROUP', 'group.com.viset.visethnote')
DEPLOYMENT_TARGET = '15.5'

proj = Xcodeproj::Project.open('ios/Runner.xcodeproj')
runner = proj.targets.find { |t| t.name == 'Runner' }
abort 'Runner target not found' unless runner

runner.build_configurations.each do |configuration|
  configuration.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = BUNDLE_ID
end

def configure_manual_signing(target, team_id, profile_name)
  target.build_configurations.each do |configuration|
    settings = configuration.build_settings
    settings['CODE_SIGN_STYLE'] = 'Manual'
    settings['DEVELOPMENT_TEAM'] = team_id
    settings['PROVISIONING_PROFILE_SPECIFIER'] = profile_name
    settings['CODE_SIGN_IDENTITY'] = 'Apple Distribution'
  end
end

team_id = ENV['TEAM_ID']
app_profile_name = ENV['IOS_APP_PROFILE_NAME']
extension_profile_name = ENV['IOS_EXTENSION_PROFILE_NAME']
signing_enabled = ENV['IOS_SIGNING_ENABLED'] == 'true'

if signing_enabled
  abort 'Manual signing requires TEAM_ID, IOS_APP_PROFILE_NAME, and IOS_EXTENSION_PROFILE_NAME' unless
    [team_id, app_profile_name, extension_profile_name].all? { |value| value && !value.empty? }
  configure_manual_signing(runner, team_id, app_profile_name)
else
  puts 'Apple signing assets are unavailable; leaving manual signing disabled for the unsigned IPA build.'
end

%w[Runner/Runner.entitlements ShareExtension/ShareExtension.entitlements].each do |path|
  abort "Missing entitlements file: ios/#{path}" unless File.file?(File.join('ios', path))
  entitlement_contents = File.read(File.join('ios', path))
  abort "#{path} must contain App Group #{APP_GROUP}" unless entitlement_contents.include?(APP_GROUP)
end

deployment = DEPLOYMENT_TARGET
proj.targets.each do |target|
  target.build_configurations.each do |configuration|
    configuration.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = deployment
  end
end

ext = proj.targets.find { |target| target.name == 'ShareExtension' }
unless ext
  ext = proj.new_target(:app_extension, 'ShareExtension', :ios, deployment)
end

share_group = proj.main_group.groups.find do |group|
  group.name == 'ShareExtension' || group.path == 'ShareExtension'
end
share_group ||= proj.main_group.new_group('ShareExtension', 'ShareExtension')
source_file = share_group.files.find { |file| file.path == 'ShareViewController.swift' }
source_file ||= share_group.new_file('ShareViewController.swift')
share_group.files.find { |file| file.path == 'Info.plist' } || share_group.new_file('Info.plist')
share_group.files.find { |file| file.path == 'ShareExtension.entitlements' } || share_group.new_file('ShareExtension.entitlements')

# Ensure the Swift implementation is compiled even if this script is rerun on
# a project where the ShareExtension target already existed.
unless ext.source_build_phase.files_references.include?(source_file)
  ext.source_build_phase.add_file_reference(source_file)
end

ext.build_configurations.each do |c|
  s = c.build_settings
  runner_configuration = runner.build_configurations.find { |configuration| configuration.name == c.name }
  abort "Runner build configuration not found: #{c.name}" unless runner_configuration
  runner_settings = runner_configuration.build_settings

  # The Runner xcconfig chain includes Flutter's Generated.xcconfig, which
  # supplies FLUTTER_BUILD_NAME and FLUTTER_BUILD_NUMBER from pubspec.yaml.
  # The dynamically-created extension target must load the matching config too
  # or its Info.plist version placeholders remain unresolved.
  c.base_configuration_reference = runner_configuration.base_configuration_reference
  s['PRODUCT_BUNDLE_IDENTIFIER'] = "#{BUNDLE_ID}.ShareExtension"
  s['INFOPLIST_FILE'] = 'ShareExtension/Info.plist'
  s['CODE_SIGN_ENTITLEMENTS'] = 'ShareExtension/ShareExtension.entitlements'
  s['CURRENT_PROJECT_VERSION'] = runner_settings.fetch('CURRENT_PROJECT_VERSION', '$(FLUTTER_BUILD_NUMBER)')
  s['MARKETING_VERSION'] = runner_settings.fetch('MARKETING_VERSION', '$(FLUTTER_BUILD_NAME)')
  s['PRODUCT_NAME'] = 'ShareExtension'
  s['EXECUTABLE_NAME'] = '$(PRODUCT_NAME)'
  s['GENERATE_INFOPLIST_FILE'] = 'NO'
  s['SWIFT_VERSION'] = '5.0'
  s['IPHONEOS_DEPLOYMENT_TARGET'] = deployment
  s['TARGETED_DEVICE_FAMILY'] = '1,2'
  s['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
  s['SKIP_INSTALL'] = 'YES'
  s['LD_RUNPATH_SEARCH_PATHS'] = '$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks'
end

if signing_enabled
  configure_manual_signing(ext, team_id, extension_profile_name)
end

# Flutter 3.50 creates this versioned plugin symlink during `flutter pub get`.
plugin_package = Dir.glob('ios/Flutter/ephemeral/Packages/.packages/receive_sharing_intent-*').find do |path|
  File.file?(File.join(path, 'Package.swift'))
end
abort 'receive_sharing_intent Swift package was not generated; enable SPM before flutter pub get' unless plugin_package

plugin_relative_path = Pathname.new(plugin_package).relative_path_from(Pathname.new('ios')).to_s
package_reference = proj.root_object.package_references.find do |reference|
  reference.respond_to?(:relative_path) && reference.relative_path.to_s == plugin_relative_path
end
unless package_reference
  package_reference = proj.new(Xcodeproj::Project::Object::XCLocalSwiftPackageReference)
  package_reference.relative_path = plugin_relative_path
  proj.root_object.package_references << package_reference
end

product_dependency = ext.package_product_dependencies.find do |dependency|
  dependency.product_name == 'receive-sharing-intent'
end
unless product_dependency
  product_dependency = proj.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  product_dependency.product_name = 'receive-sharing-intent'
  product_dependency.package = package_reference
  ext.package_product_dependencies << product_dependency
end
unless ext.frameworks_build_phase.files.any? { |file| file.product_ref == product_dependency }
  build_file = proj.new(Xcodeproj::Project::Object::PBXBuildFile)
  build_file.product_ref = product_dependency
  ext.frameworks_build_phase.files << build_file
end

runner.add_dependency(ext) unless runner.dependencies.any? { |dependency| dependency.target == ext }
phase = runner.copy_files_build_phases.find { |build_phase| build_phase.name == 'Embed Foundation Extensions' }
unless phase
  phase = runner.new_copy_files_build_phase('Embed Foundation Extensions')
end
phase.name = 'Embed Foundation Extensions'
phase.dst_subfolder_spec = '13'
phase.dst_path = ''
unless phase.files_references.include?(ext.product_reference)
  build_file = phase.add_file_reference(ext.product_reference)
  build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
end

# Embed the extension before Flutter's Thin Binary phase as required by the
# plugin's SPM integration.
runner.build_phases.delete(phase)
thin_binary = runner.shell_script_build_phases.find { |build_phase| build_phase.name == 'Thin Binary' }
insert_at = thin_binary ? runner.build_phases.index(thin_binary) : runner.build_phases.length
runner.build_phases.insert(insert_at, phase)

proj.save
