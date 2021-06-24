Pod::Spec.new do |s|
  s.name             = 'SatelliteCatalog'
  s.version          = '1.0.0.LOCAL'
  s.summary          = 'A database for all satellites.'

  s.homepage         = 'https://github.com/DJBen/'
  s.license          = { :type => 'Proprietary', :text => '© 2021 DJBen' }
  s.author           = { 'Ben Lu' => 'sihao@squareup.com' }
  s.source           = { :git => 'Not Published', :tag => s.version.to_s }

  s.ios.deployment_target = '14.5'

  s.swift_version = ['5.4']
  s.source_files = 'Sources/**/*.swift'
  
  s.resource_bundles = {
    'SatelliteCatalogResources' => ['Assets/*.*']
  }

  s.dependency 'SatelliteKit', '1.0.0.LOCAL'
  s.dependency 'SQLite.swift', '~> 0.12.2'

  s.test_spec 'Tests' do |test_spec|
    test_spec.source_files = 'Tests/**/*.swift'

    test_spec.framework = 'XCTest'
  end
end
