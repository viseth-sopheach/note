require 'xcodeproj'

BUNDLE_ID = ENV.fetch('BUNDLE_ID')
APP_GROUP = ENV.fetch('APP_GROUP', 'group.com.viset.visethnote')
DEPLOYMENT_TARGET = '15.0'

proj = Xcodeproj::Project.open('ios/Runner.xcodeproj')
exit if proj.targets.any? { |t| t.name == 'ShareExtension' }

runner = proj.targets.find { |t| t.name == 'Runner' }
ext = proj.new_target(:app_extension, 'ShareExtension', :ios, DEPLOYMENT_TARGET)
group = proj.main_group.new_group('ShareExtension', 'ShareExtension')
src = group.new_file('ShareViewController.swift')
group.new_file('Info.plist')
group.new_file('ShareExtension.entitlements')
ext.add_file_references([src])

# --- Link FlutterGeneratedPluginSwiftPackage so RSIShareViewController
# --- (from receive_sharing_intent) is available at link time.
pkg = proj.root_object.package_references.find do |r|
  r.respond_to?(:relative_path) &&
    r.relative_path.to_s.include?('FlutterGeneratedPluginSwiftPackage')
end
if pkg.nil?
  warn 'FlutterGeneratedPluginSwiftPackage not found in project. Did `flutter pub get` run?'
else
  dep = proj.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  dep.product_name = 'FlutterGeneratedPluginSwiftPackage'
  dep.package = pkg
  ext.package_product_dependencies << dep

  bf2 = proj.new(Xcodeproj::Project::Object::PBXBuildFile)
  bf2.product_ref = dep
  ext.frameworks_build_phase.files << bf2
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

runner.add_dependency(ext)
embed = runner.new_copy_files_build_phase('Embed Foundation Extensions')
embed.symbol_dst_subfolder_spec = :plug_ins
bf = embed.add_file_reference(ext.product_reference)
bf.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }

proj.save