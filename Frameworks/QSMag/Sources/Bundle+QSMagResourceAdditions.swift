//
//  Bundle+QSMagResourceAdditions.swift
//  QSMag
//
//  Created by Ben Lu on 6/6/21.
//

import Foundation

fileprivate final class QSMagResourcesBundleFinderClass {
    fileprivate static let bundleFinderBundle: Bundle = {
        Bundle(for: QSMagResourcesBundleFinderClass.self)
    }()
}


internal extension Bundle {
    static var qsMagResourcesBundle: Bundle {
        let mainBundle = QSMagResourcesBundleFinderClass.bundleFinderBundle

        guard let bundleURL = mainBundle.url(forResource: "QSMagResources", withExtension: "bundle"),
              let bundle = Bundle(url: bundleURL)
        else {
            fatalError("Could not find resource bundle for QSMag within main application bundle.")
        }

        return bundle
    }
}
