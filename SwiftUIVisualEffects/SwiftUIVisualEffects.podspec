Pod::Spec.new do |s|
  s.name             = 'SwiftUIVisualEffects'
  s.version          = '1.0.0.LOCAL'
  s.summary          = 'Swift UI visual effects.'

  s.homepage         = 'https://github.com/DJBen'
  s.license          = { :type => 'Proprietary', :text => '© 2021 DJBen' }
  s.author           = { 'Ben Lu' => 'sihao@squareup.com' }
  s.source           = { :git => 'Not Published', :tag => s.version.to_s }

  s.ios.deployment_target = '15.0'

  s.swift_version = ['5.4']
  s.source_files = 'Sources/**/*.swift'

  s.test_spec 'Tests' do |test_spec|
    test_spec.source_files = 'Tests/**/*.swift'

    test_spec.framework = 'XCTest'
  end
end
