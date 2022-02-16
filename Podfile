target 'SatelliteForecast' do
  platform :ios, '15.0'
  inhibit_all_warnings!
  use_frameworks!
  
  pod "BTree", "~> 4.1.0"
  pod "CombineRex", "0.8.9"
  pod "CombineRextensions"
  pod "FlagKit"
  pod 'SwiftDate', '~> 5.0'
  pod "SwiftRex", "0.8.9"
  pod "SatelliteKit", :path => './SatelliteKit'
  pod "StarryNight", :path => './StarryNight'
  pod "SatelliteCatalog", :path => './SatelliteCatalog'
  pod "SatelliteCatalogImpl_SQLite", :path => './SatelliteCatalogImpl_SQLite'
  pod "SatelliteForecastCore", :path => './SatelliteForecastCore'
  pod "SwiftUIVisualEffects", :path => './SwiftUIVisualEffects'

  target 'SatelliteForecastTests' do
    inherit! :complete

    pod "TestingExtensions", "~> 0.2.9"
  end
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings.delete 'IPHONEOS_DEPLOYMENT_TARGET'
    end
  end
end

