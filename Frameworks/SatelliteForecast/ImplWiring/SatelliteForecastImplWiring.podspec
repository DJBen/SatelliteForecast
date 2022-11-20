#
# Be sure to run `pod lib lint SatelliteForecastImplWiring.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'SatelliteForecastImplWiring'
  s.version          = '1.0.0.LOCAL'
  s.summary          = 'The ImplWiring module of SatelliteForecast app.'

  s.homepage         = 'https://github.com/DJBen'
  s.license          = { :type => 'Proprietary', :text => '© 2021 DJBen' }
  s.author           = { 'Sihao Lu' => 'lsh32768@gmail.com' }
  s.source           = { :git => 'Not Published', :tag => s.version.to_s }

  s.ios.deployment_target = '16.0'

  s.swift_version = ['5.5']
  s.source_files = 'Sources/**/*.swift'

  s.dependency 'BTree', "~> 4.1.0"
  s.dependency 'SwiftRex', '0.8.12'
  s.dependency 'CombineRex', "0.8.12"
  s.dependency 'CombineRextensions'
  s.dependency 'SatelliteForecast', '1.0.0.LOCAL'
  s.dependency 'SatelliteForecastImpl', '1.0.0.LOCAL'

  s.test_spec 'Tests' do |test_spec|
    test_spec.source_files = 'Tests/**/*.swift'
    test_spec.framework = 'XCTest'
    test_spec.dependency 'TestingExtensions', '~> 0.2.11'
  end
end
