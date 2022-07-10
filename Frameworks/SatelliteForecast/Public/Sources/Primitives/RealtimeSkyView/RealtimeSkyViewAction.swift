//
//  RealtimeSkyViewAction.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 4/20/22.
//

import BTree
import SatelliteKit

public enum RealtimeSkyViewAction {
    case propagateCurrentEphemerides([SatelliteInfo], observer: LatLonAlt, julianDate: Double)
    case setRealtimeSkyViewActive(Bool)
    case loadElements
    case purgeElements
}

extension RealtimeSkyViewAction: Equatable {}

public enum RealtimeSkyViewOutput {
    case propagatedCurrentEphemerides(
        results: BTree<Double, RealtimePropagationResult>,
        satellites: [SatelliteInfo],
        partialErrors: [Error],
        observer: LatLonAlt,
        julianDate: Double
    )

    case failedToPropagateCurrentEphemerides(
        error: Error,
        observer: LatLonAlt,
        julianDate: Double
    )
}
