platform :ios, '15.0'

target 'SatelliteForcast' do
  pod "BTree", "~> 4.1.0"
  pod "CombineRex", "~> 0.8.4"
  pod "CombineRextensions", :git => 'https://github.com/DJBen/CombineRextensions.git'
  pod "FlagKit"
  pod "SwiftRex", :git => 'https://github.com/DJBen/SwiftRex.git', :branch => 'sihao/enable-testability'
  pod "SatelliteKit", :path => './SatelliteKit'
  pod "StarryNight", :path => './StarryNight'
  pod "SatelliteCatalog", :path => './SatelliteCatalog'
  pod "SatelliteForcastCore", :path => './SatelliteForcastCore'
  pod "SwiftUIVisualEffects", :path => './SwiftUIVisualEffects'

  target 'Tests iOS' do
    pod "TestingExtensions", :path => './TestingExtensions'
  end
end

post_install do |installer|
  installer.aggregate_targets.each do |target|
    copy_pods_resources_path = "Pods/Target Support Files/#{target.name}/#{target.name}-resources.sh"
    string_to_replace = '--compile "${BUILT_PRODUCTS_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"'
    assets_compile_with_app_icon_arguments = '--compile "${BUILT_PRODUCTS_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}" --app-icon "${ASSETCATALOG_COMPILER_APPICON_NAME}" --output-partial-info-plist "${BUILD_DIR}/assetcatalog_generated_info.plist"'
    text = File.read(copy_pods_resources_path)
    new_contents = text.gsub(string_to_replace, assets_compile_with_app_icon_arguments)
    File.open(copy_pods_resources_path, "w") {|file| file.puts new_contents }
  end
end