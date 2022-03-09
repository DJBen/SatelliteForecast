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
    let noradIndex: UInt
    let dateRange: ClosedRange<Double>
    let observer: LatLonAlt
}

public struct TLELoaderCalculatePassParam {
    let noradIndex: UInt
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
        satelliteInfo: Map<UInt, SatelliteInfo>,
        selectSpecialNoradIndex: SelectNoradIndexParam? = nil,
        selectNoradIndex: SelectNoradIndexParam? = nil,
        calculatePass: TLELoaderCalculatePassParam? = nil
    )
    case failedLoadingTLEFile(
        category: SatelliteCategory,
        error: TLELoaderError
    )
}
