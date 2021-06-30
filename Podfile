platform :ios, '14.5'

target 'SatelliteForcast (iOS)' do
  use_frameworks!

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
