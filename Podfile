platform :ios, '14.5'

target 'SatelliteForcast (iOS)' do
  use_frameworks!

  pod "CombineRex", "~> 0.8.4"
  pod "SwiftRex", :git => 'https://github.com/DJBen/SwiftRex.git', :branch => 'sihao/enable-testability'
  pod "SatelliteKit", :path => './SatelliteKit'
  pod "StarryNight", :path => './StarryNight'
  pod "CombineRextensions", :git => 'https://github.com/DJBen/CombineRextensions.git'

  target 'Tests iOS' do
    pod "TestingExtensions", :path => './TestingExtensions'
  end
end

target 'SatelliteForcastCore' do
  platform :ios, '14.5'
  use_frameworks!

  pod "SatelliteKit", :path => './SatelliteKit'

  # target 'SatelliteForcastCoreTests' do
  # end
end
