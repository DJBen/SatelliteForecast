platform :ios, '15.0'

target 'SatelliteForcast' do
  use_frameworks!
  
  pod "BTree", "~> 4.1.0"
  pod "CombineRex", "~> 0.8.6"
  pod "CombineRextensions", :git => 'https://github.com/DJBen/CombineRextensions.git', :branch => 'add-podspec'
  pod "FlagKit"
  pod "SwiftRex", "~> 0.8.6"
  pod "SatelliteKit", :path => './SatelliteKit'
  pod "StarryNight", :path => './StarryNight'
  pod "SatelliteCatalog", :path => './SatelliteCatalog'
  pod "SatelliteForcastCore", :path => './SatelliteForcastCore'
  pod "SwiftUIVisualEffects", :path => './SwiftUIVisualEffects'

  target 'Tests iOS' do
    pod "TestingExtensions", :git => 'https://github.com/DJBen/TestingExtensions.git', :branch => 'add-podspec'
  end
end
