require 'xcodeproj'
require 'pathname'

BUNDLE_ID = ENV.fetch('BUNDLE_ID')
APP_GROUP = ENV.fetch('APP_GROUP', 'group.com.viset.visethnote')
DEPLOYMENT_TARGET = '15.5'

proj = Xcodeproj::Project.open('ios/Runner.xcodeproj')
runner = proj.targets.find { |t| t.name == 'Runner' }
abort 'Runner target not found' unless runner

deployment = DEPLOYMENT_TARGET
proj.targets.each do |target|
  target.build_configurations.each do |configuration|
    configuration.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = deployment
  end
end

ext = proj.targets.find { |target| target.name == 'ShareExtension' }
unless ext
  ext = proj.new_target(:app_extension, 'ShareExtension', :ios, deployment)
  group = proj.main_group.new_group('ShareExtension', 'ShareExtension')
  src = group.new_file('ShareViewController.swift')
  group.new_file('Info.plist')
  group.new_file('ShareExtension.entitlements')
  ext.add_file_references([src])
end

ext.build_configurations.each do |c|
  s = c.build_settings
  s['PRODUCT_BUNDLE_IDENTIFIER'] = "#{BUNDLE_ID}.ShareExtension"
  s['INFOPLIST_FILE'] = 'ShareExtension/Info.plist'
  s['CODE_SIGN_ENTITLEMENTS'] = 'ShareExtension/ShareExtension.entitlements'
  s['PRODUCT_NAME'] = '$(TARGET_NAME)'
  s['SWIFT_VERSION'] = '5.0'
  s['IPHONEOS_DEPLOYMENT_TARGET'] = deployment
  s['TARGETED_DEVICE_FAMILY'] = '1,2'
  s['LD_RUNPATH_SEARCH_PATHS'] = '$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks'
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
