//
//  RealtimeSkyViewAction.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 4/20/22.
//

import BTree
@preconcurrency import SatelliteKit

public enum RealtimeSkyViewAction {
    case propagateCurrentEphemerides([SatelliteInfo], observer: LatLonAlt, julianDate: Double)
    case setRealtimeSkyViewActive(Bool)
    case loadElements
    case purgeElements
}

extension RealtimeSkyViewAction: Equatable {}
