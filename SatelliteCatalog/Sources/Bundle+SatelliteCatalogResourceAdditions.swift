//
//  Bundle+SatelliteCatalogResourceAdditions.swift
//  SatelliteCatalog
//
//  Created by Ben Lu on 6/6/21.
//

import Foundation

fileprivate final class SatelliteCatalogResourcesBundleFinderClass {
    fileprivate static let bundleFinderBundle: Bundle = {
        Bundle(for: SatelliteCatalogResourcesBundleFinderClass.self)
    }()
}


internal extension Bundle {
    static var SatelliteCatalogResourcesBundle: Bundle {
        let mainBundle = SatelliteCatalogResourcesBundleFinderClass.bundleFinderBundle

        guard let bundleURL = mainBundle.url(forResource: "SatelliteCatalogResources", withExtension: "bundle"),
            let bundle = Bundle(url: bundleURL)
        else {
            fatalError("Could not find resource bundle for SatelliteCatalog within main application bundle.")
        }

        return bundle
    }
}
