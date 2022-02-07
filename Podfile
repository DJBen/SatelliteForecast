platform :ios, '15.0'
inhibit_all_warnings!

target 'SatelliteForecast' do
  use_frameworks!
  
  pod "BTree", "~> 4.1.0"
  pod "CombineRex", "~> 0.8.6"
  pod "CombineRextensions"
  pod "FlagKit"
  pod 'SwiftDate', '~> 5.0'
  pod "SwiftRex", "~> 0.8.6"
  pod "SatelliteKit", :path => './SatelliteKit'
  pod "StarryNight", :path => './StarryNight'
  pod "SatelliteCatalog", :path => './SatelliteCatalog'
  pod "SatelliteCatalogImpl_SQLite", :path => './SatelliteCatalogImpl_SQLite'
  pod "SatelliteForecastCore", :path => './SatelliteForecastCore'
  pod "SwiftUIVisualEffects", :path => './SwiftUIVisualEffects'

  target 'SatelliteForecastTests' do
    pod "TestingExtensions"
  end
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings.delete 'IPHONEOS_DEPLOYMENT_TARGET'
    end
  end
end

