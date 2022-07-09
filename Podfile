platform :ios, '15.2'
inhibit_all_warnings!

target 'SatelliteForecastApp' do  
  use_frameworks!

  pod "BTree", "~> 4.1.0"
  pod "CombineRex", "~> 0.8.12"
  pod "CombineRextensions"
  pod "FlagKit"
  pod "SwiftRex", "~> 0.8.12"
  pod "ActivityView", :path => 'Frameworks/ActivityView/Public'
  pod "CombineUtils", :path => 'Frameworks/CombineUtils'
  pod "CombineRexUtils", :path => 'Frameworks/CombineRexUtils'
  pod 'QSMag', :path => 'Frameworks/QSMag'
  pod "SatelliteKit", :path => 'Frameworks/SatelliteKit'
  pod "StarryNight", :path => 'Frameworks/StarryNight'
  pod "SatelliteCatalog", :path => 'Frameworks/SatelliteCatalog/Public'
  pod "SatelliteCatalogImpl_SQLite", :path => 'Frameworks/SatelliteCatalog/Impl_SQLite'
  pod "SatelliteForecast", :path => 'Frameworks/SatelliteForecast/Public'
  pod "SatelliteForecastImpl", :path => 'Frameworks/SatelliteForecast/Impl'
  pod 'SecondaryTabView', :path => 'Frameworks/SecondaryTabView'
  pod "SolarSystem", :path => 'Frameworks/SolarSystem'
  pod "SwiftUIVisualEffects", :path => 'Frameworks/SwiftUIVisualEffects'

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
