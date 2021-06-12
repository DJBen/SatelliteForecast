#
# Be sure to run `pod lib lint SatelliteForcastCore.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'SatelliteForcastCore'
  s.version          = '1.0.0.LOCAL'
  s.summary          = 'A library that offers access to star and constellation data.'

  s.homepage         = 'https://github.com/DJBen'
  s.license          = { :type => 'Proprietary', :text => '© 2021 DJBen' }
  s.author           = { 'Ben Lu' => 'sihao@squareup.com' }
  s.source           = { :git => 'Not Published', :tag => s.version.to_s }

  s.ios.deployment_target = '14.5'

  s.swift_version = ['5.4']
  s.source_files = 'Sources/**/*.swift'

  s.dependency 'SatelliteKit', '1.0.0.LOCAL'
  s.dependency 'BTree', '~> 4.1.0'

  s.test_spec 'Tests' do |test_spec|
    test_spec.source_files = 'Tests/**/*.swift'

    test_spec.framework = 'XCTest'
  end
end
