//
//  Bundle+SatelliteCatalogResourceAdditions.swift
//  SatelliteCatalog
//
//  Created by Ben Lu on 6/6/21.
//

import Foundation

fileprivate final class SatelliteCatalogImpl_SQLiteResourcesBundleFinderClass {
    fileprivate static let bundleFinderBundle: Bundle = {
        Bundle(for: SatelliteCatalogImpl_SQLiteResourcesBundleFinderClass.self)
    }()
}


internal extension Bundle {
    static var SatelliteCatalogImpl_SQLiteResourcesBundle: Bundle {
        let mainBundle = SatelliteCatalogImpl_SQLiteResourcesBundleFinderClass.bundleFinderBundle

        guard let bundleURL = mainBundle.url(forResource: "SatelliteCatalogImpl_SQLiteResources", withExtension: "bundle"),
            let bundle = Bundle(url: bundleURL)
        else {
            fatalError("Could not find resource bundle for SatelliteCatalogImpl_SQLite within main application bundle.")
        }

        return bundle
    }
}
