Pod::Spec.new do |s|
  s.name             = 'SatelliteCatalogImpl_SQLite'
  s.version          = '1.0.0.LOCAL'
  s.summary          = 'A database for all satellites.'

  s.homepage         = 'https://github.com/DJBen/'
  s.license          = { :type => 'Proprietary', :text => '© 2021 DJBen' }
  s.author           = { 'Sihao Lu' => 'lsh32768@gmail.com' }
  s.source           = { :git => 'Not Published', :tag => s.version.to_s }

  s.ios.deployment_target = '16.0'

  s.swift_version = ['5.5']
  s.source_files = 'Sources/**/*.swift'
  
  s.resource_bundles = {
    'SatelliteCatalogImpl_SQLiteResources' => ['Assets/*.*']
  }

  s.dependency 'SatelliteCatalog', '1.0.0.LOCAL'
  s.dependency 'SQLite.swift', '~> 0.12.2'

  s.test_spec 'Tests' do |test_spec|
    test_spec.source_files = 'Tests/**/*.swift'

    test_spec.framework = 'XCTest'
  end
end
