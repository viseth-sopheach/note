require 'xcodeproj'

BUNDLE_ID = ENV.fetch('BUNDLE_ID')
APP_GROUP = ENV.fetch('APP_GROUP', 'group.com.viset.visethnote')
DEPLOYMENT_TARGET = '15.0'

proj = Xcodeproj::Project.open('ios/Runner.xcodeproj')

# This project previously linked Flutter's generated SPM plugin package.
# CocoaPods is required for ML Kit; remove that package from the project so
# plugins are not linked twice when CocoaPods is installed.
spm_packages = proj.root_object.package_references.select do |reference|
  reference.respond_to?(:relative_path) &&
    reference.relative_path.to_s.include?('FlutterGeneratedPluginSwiftPackage')
end
unless spm_packages.empty?
  products = proj.objects.select do |object|
    object.isa == 'XCSwiftPackageProductDependency' &&
      object.product_name == 'FlutterGeneratedPluginSwiftPackage'
  end
  proj.targets.each do |target|
    target.package_product_dependencies.delete_if { |dependency| products.include?(dependency) }
    target.build_phases.each do |phase|
      next unless phase.respond_to?(:files)
      phase.files.delete_if { |file| products.include?(file.product_ref) }
    end
  end
  spm_packages.each do |package|
    proj.objects.select { |object| object.isa == 'PBXFileReference' && object.path.to_s.include?('FlutterGeneratedPluginSwiftPackage') }.each do |file|
      proj.groups.each { |group| group.children.delete(file) }
      proj.objects.delete(file)
    end
    proj.root_object.package_references.delete(package)
    proj.objects.delete(package)
  end
  products.each { |product| proj.objects.delete(product) }
end

runner = proj.targets.find { |t| t.name == 'Runner' }
ext = proj.targets.find { |t| t.name == 'ShareExtension' }
unless ext
  ext = proj.new_target(:app_extension, 'ShareExtension', :ios, DEPLOYMENT_TARGET)
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
  s['IPHONEOS_DEPLOYMENT_TARGET'] = DEPLOYMENT_TARGET
  s['TARGETED_DEVICE_FAMILY'] = '1,2'
  s['LD_RUNPATH_SEARCH_PATHS'] = '$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks'
end

runner.add_dependency(ext) unless runner.dependencies.any? { |dependency| dependency.target == ext }
embed = runner.copy_files_build_phases.find { |phase| phase.dst_subfolder_spec == '13' }
unless embed
  embed = runner.new_copy_files_build_phase('Embed App Extensions')
  embed.dst_subfolder_spec = :plug_ins
end
unless embed.files_references.include?(ext.product_reference)
  bf = embed.add_file_reference(ext.product_reference)
  bf.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
end

proj.save
