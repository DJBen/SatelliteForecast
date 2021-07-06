//
//  SatelliteLoaderAction.swift
//  SatelliteForcast
//
//  Created by Ben Lu on 6/4/21.
//

import Foundation
import SatelliteForcastCore
import SatelliteKit

enum SatelliteLoaderError: Error {
    case tle(SatKitError)
    case other(Error)
}

extension SatelliteLoaderError: Equatable {
    static func == (lhs: SatelliteLoaderError, rhs: SatelliteLoaderError) -> Bool {
        switch (lhs, rhs) {
        case let (.tle(e1), .tle(e2)):
            return e1 == e2
        case let (.other(e1), .other(e2)):
            return String(describing: e1) == String(describing: e2)
        default:
            return false
        }
    }
}

enum SatelliteLoaderInputAction {
    case loadSatelliteCategory((SatelliteCategory))
}

enum SatelliteLoaderOutputAction {
    case loadedSatelliteInfo(SatelliteCategory, [SatelliteInfo])
    case failedLoadingTLEFile(SatelliteCategory, SatelliteLoaderError)
}

extension SatelliteLoaderOutputAction {

}
