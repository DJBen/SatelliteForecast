platform :ios, '15.2'
inhibit_all_warnings!

target 'SatelliteForecastApp' do  
  use_frameworks!

  pod "BTree", "~> 4.1.0"
  pod "CombineRex", "0.8.9"
  pod "CombineRextensions"
  pod "FlagKit"
  pod 'QSMag', :path => './QSMag'
  pod "SwiftRex", "0.8.9"
  pod "CombineUtils", :path => './CombineUtils'
  pod "CombineRexUtils", :path => './CombineRexUtils'
  pod "SatelliteKit", :path => './SatelliteKit'
  pod "StarryNight", :path => './StarryNight'
  pod "SatelliteCatalog", :path => './SatelliteCatalog'
  pod "SatelliteCatalogImpl_SQLite", :path => './SatelliteCatalogImpl_SQLite'
  pod "SatelliteForecast", :path => './SatelliteForecast'
  pod "SatelliteForecastImpl", :path => './SatelliteForecastImpl'
  pod "SolarSystem", :path => './SolarSystem'
  pod "SwiftUIVisualEffects", :path => './SwiftUIVisualEffects'
  pod "VSOP87", :path => './VSOP87'

  target 'SatelliteForecastTests' do
    inherit! :complete

    pod "TestingExtensions", '~> 0.2.11'
  end
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings.delete 'IPHONEOS_DEPLOYMENT_TARGET'
    end
  end
end

