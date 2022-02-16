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

struct SelectNoradIndexParam {
    let noradIndex: Int
    let dateRange: Range<Double>
    let observer: LatLonAlt
}

struct SatelliteLoaderCalculatePassParam {
    let noradID: Int
    let dateRange: Range<Double>
    let observer: LatLonAlt
}

enum SatelliteLoaderAction {
    case loadSatelliteCategory(
        SatelliteCategory,
        selectSpecialNoradIndex: SelectNoradIndexParam? = nil,
        selectNoradIndex: SelectNoradIndexParam? = nil,
        calculatePass: SatelliteLoaderCalculatePassParam? = nil
    )
}

enum SatelliteLoaderOutput {
    case loadedSatelliteInfo(
        SatelliteCategory,
        satelliteInfo: Map<Int, SatelliteInfo>,
        selectSpecialNoradIndex: SelectNoradIndexParam? = nil,
        selectNoradIndex: SelectNoradIndexParam? = nil,
        calculatePass: SatelliteLoaderCalculatePassParam? = nil
    )
    case failedLoadingTLEFile(
        SatelliteCategory,
        SatelliteLoaderError
    )
}
