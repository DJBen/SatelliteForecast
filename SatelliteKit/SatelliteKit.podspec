#
# Be sure to run `pod lib lint SatelliteKit.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'SatelliteKit'
  s.version          = '1.0.0.LOCAL'
  s.summary          = 'A copy of SatelliteKit'

  s.homepage         = 'https://github.com/DJBen'
  s.license          = { :type => 'Proprietary', :text => '© 2021 DJBen' }
  s.author           = { 'Sihao Lu' => 'lsh32768@gmail.com' }
  s.source           = { :git => 'Not Published', :tag => s.version.to_s }

  s.ios.deployment_target = '15.0'

  s.swift_version = ['5.4']
  s.source_files = 'Classes/**/*.swift'
  
  s.resource_bundles = {
    'SatelliteKitResources' => ['Assets/*.*']
  }

  s.test_spec 'Tests' do |test_spec|
    test_spec.source_files = 'Tests/**/*.swift'
    test_spec.resources = 'Tests/Resources/**/*'

    test_spec.framework = 'XCTest'
  end
end

