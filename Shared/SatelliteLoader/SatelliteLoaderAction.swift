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

enum SatelliteLoaderInputAction {
    case loadSatelliteCategory((SatelliteCategory))
}

enum SatelliteLoaderOutputAction {
    case loadedSatelliteInfo(SatelliteCategory, [SatelliteInfo])
    case failedLoadingTLEFile(SatelliteCategory, SatelliteLoaderError)
}

extension SatelliteLoaderOutputAction {

}
