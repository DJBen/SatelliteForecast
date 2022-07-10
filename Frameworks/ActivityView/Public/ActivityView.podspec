#
# Be sure to run `pod lib lint ActivityView.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'ActivityView'
  s.version          = '1.0.0.LOCAL'
  s.summary          = 'A SwiftUI view that enables you to properly present a UIActivityViewController.'

  s.homepage         = 'https://github.com/hologramxyz/hologram-ios'
  s.license          = { :type => 'Proprietary', :text => '© 2022 Hologram Inc.' }
  s.author           = { 'Sihao Lu' => 'lsh32768@gmail.com' }
  s.source           = { :git => 'Not Published', :tag => s.version.to_s }

  s.ios.deployment_target = '15.0'

  s.swift_version = ['5.4']
  s.source_files = 'Sources/**/*.{h,m,mm,swift}'
end
