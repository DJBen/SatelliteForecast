//
//  TLELoaderAction.swift
//  SatelliteForcast
//
//  Created by Ben Lu on 6/4/21.
//

import Foundation
import SatelliteKit

enum TLELoaderError: Error {
    case tle(SatKitError)
    case other(Error)
}

enum TLELoaderInputAction {
    case willLoadTLECategory(TLECategory)
    case loadTLECategories
}

enum TLELoaderOutputAction {
    case loadedTLEFile(TLECategory, [TLE])
    case failedLoadingTLEFile(TLECategory, TLELoaderError)
}

extension TLELoaderOutputAction {

}
