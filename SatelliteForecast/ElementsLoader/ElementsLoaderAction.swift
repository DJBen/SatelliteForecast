//
//  ElementsLoaderAction.swift
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

public struct ElementsLoaderCalculatePassParam {
    let noradIndex: UInt
    let dateRange: ClosedRange<Double>
    let observer: LatLonAlt
}

public enum ElementsLoaderAction {
    /// Load a category of satellite elements
    case loadElements(
        category: SatelliteCategory,
        selectSpecialNoradIndex: SelectNoradIndexParam? = nil,
        selectNoradIndex: SelectNoradIndexParam? = nil,
        calculatePass: ElementsLoaderCalculatePassParam? = nil
    )
}

public enum ElementsLoaderOutput {
    /// Successfully loaded a cateogy of satellite elements
    case loadedSatelliteElements(
        category: SatelliteCategory,
        satelliteInfo: Map<UInt, SatelliteInfo>,
        selectSpecialNoradIndex: SelectNoradIndexParam? = nil,
        selectNoradIndex: SelectNoradIndexParam? = nil,
        calculatePass: ElementsLoaderCalculatePassParam? = nil
    )
    case failedLoadingElements(
        category: SatelliteCategory,
        error: ElementsLoaderError
    )
}
