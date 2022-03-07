//
//  TLELoaderAction.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/4/21.
//

import BTree
import Foundation
import SatelliteForecastCore
import SatelliteKit

public struct SelectNoradIndexParam {
    let noradIndex: Int
    let dateRange: ClosedRange<Double>
    let observer: LatLonAlt
}

public struct TLELoaderCalculatePassParam {
    let noradID: Int
    let dateRange: ClosedRange<Double>
    let observer: LatLonAlt
}

public enum TLELoaderAction {
    /// Load a category of satellite TLEs
    case loadSatelliteTLEs(
        category: SatelliteCategory,
        selectSpecialNoradIndex: SelectNoradIndexParam? = nil,
        selectNoradIndex: SelectNoradIndexParam? = nil,
        calculatePass: TLELoaderCalculatePassParam? = nil
    )
}

public enum TLELoaderOutput {
    /// Successfully loaded a cateogy of satellite TLEs
    case loadedSatelliteTLEs(
        category: SatelliteCategory,
        satelliteInfo: Map<Int, SatelliteInfo>,
        selectSpecialNoradIndex: SelectNoradIndexParam? = nil,
        selectNoradIndex: SelectNoradIndexParam? = nil,
        calculatePass: TLELoaderCalculatePassParam? = nil
    )
    case failedLoadingTLEFile(
        category: SatelliteCategory,
        error: TLELoaderError
    )
}
