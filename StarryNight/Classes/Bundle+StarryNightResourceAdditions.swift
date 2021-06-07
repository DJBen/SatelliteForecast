//
//  Bundle+StarryNightResourceAdditions.swift
//  StarryNight
//
//  Created by Ben Lu on 6/6/21.
//

import Foundation

fileprivate final class StarryNightResourcesBundleFinderClass {
    fileprivate static let bundleFinderBundle: Bundle = {
        Bundle(for: StarryNightResourcesBundleFinderClass.self)
    }()
}


internal extension Bundle {
    static var starryNightResourcesBundle: Bundle {
        let mainBundle = StarryNightResourcesBundleFinderClass.bundleFinderBundle

        guard let bundleURL = mainBundle.url(forResource: "StarryNightResources", withExtension: "bundle"),
            let bundle = Bundle(url: bundleURL)
        else {
            fatalError("Could not find resource bundle for StarryNight within main application bundle.")
        }

        return bundle
    }
}
