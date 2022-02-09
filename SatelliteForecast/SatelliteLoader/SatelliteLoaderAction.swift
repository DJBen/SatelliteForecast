//
//  SatelliteLoaderAction.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/4/21.
//

import BTree
import Foundation
import SatelliteForecastCore
import SatelliteKit

struct SatelliteLoaderCalculatePassParam {
    let noradID: Int
    let dateRange: Range<Double>
    let observer: LatLonAlt
}

enum SatelliteLoaderAction {
    case loadSatelliteCategory(
        SatelliteCategory,
        calculatePass: SatelliteLoaderCalculatePassParam? = nil
    )
}

enum SatelliteLoaderOutput {
    case loadedSatelliteInfo(
        SatelliteCategory,
        Map<Int, SatelliteInfo>,
        calculatePass: SatelliteLoaderCalculatePassParam? = nil
    )
    case failedLoadingTLEFile(
        SatelliteCategory,
        SatelliteLoaderError
    )
}
