//
//  SatelliteLoaderAction.swift
//  SatelliteForcast
//
//  Created by Ben Lu on 6/4/21.
//

import BTree
import Foundation
import SatelliteForcastCore

enum SatelliteLoaderAction {
    // Input
    case loadSatelliteCategory(SatelliteCategory)

    // Output
    case loadedSatelliteInfo(SatelliteCategory, Map<Int, SatelliteInfo>)
    case failedLoadingTLEFile(SatelliteCategory, SatelliteLoaderError)
}

extension SatelliteLoaderAction {

}
