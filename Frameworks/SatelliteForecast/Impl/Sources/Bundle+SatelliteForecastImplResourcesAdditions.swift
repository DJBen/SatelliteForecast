//
//  Bundle+SatelliteForecastImplResourcesAdditions.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 4/3/22.
//

import Foundation

fileprivate final class SatelliteForecastImplResourcesBundleFinderClass {
    fileprivate static let bundleFinderBundle: Bundle = {
        Bundle(for: SatelliteForecastImplResourcesBundleFinderClass.self)
    }()
}

internal extension Bundle {
    static var satelliteForecastImplResourcesBundle: Bundle {
        let mainBundle = SatelliteForecastImplResourcesBundleFinderClass.bundleFinderBundle

        guard let bundleURL = mainBundle.url(forResource: "SatelliteForecastImplResources", withExtension: "bundle"),
              let bundle = Bundle(url: bundleURL)
        else {
            fatalError("Could not find resource bundle for SatelliteForecastImplResources within main application bundle.")
        }

        return bundle
    }
}
