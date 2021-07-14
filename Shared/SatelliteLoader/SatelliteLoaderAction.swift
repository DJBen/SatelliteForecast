//
//  SatelliteLoaderAction.swift
//  SatelliteForcast
//
//  Created by Ben Lu on 6/4/21.
//

import BTree
import Foundation
import SatelliteForcastCore

enum SatelliteLoaderInputAction {
    case loadSatelliteCategory((SatelliteCategory))
}

enum SatelliteLoaderOutputAction {
    case loadedSatelliteInfo(SatelliteCategory, Map<Int, SatelliteInfo>)
    case failedLoadingTLEFile(SatelliteCategory, SatelliteLoaderError)
}

extension SatelliteLoaderOutputAction {

}
