#
# Be sure to run `pod lib lint TestingExtensions.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'TestingExtensions'
  s.version          = '1.0.0.LOCAL'
  s.summary          = 'A copy of TestingExtensions.'

  s.homepage         = 'https://github.com/DJBen'
  s.license          = { :type => 'Proprietary', :text => '© 2021 DJBen' }
  s.author           = { 'Ben Lu' => 'sihao@squareup.com' }
  s.source           = { :git => 'Not Published', :tag => s.version.to_s }

  s.ios.deployment_target = '14.5'

  s.swift_version = ['5.4']
  s.source_files = 'Sources/**/*.swift'
  s.weak_frameworks = 'XCTest'

  s.dependency 'CombineRex', '~> 0.8.4'
  s.dependency 'SwiftRex', '~> 0.8.4'
  s.dependency 'SnapshotTesting', '~> 1.8.2'
end
    