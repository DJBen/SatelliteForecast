//
//  SatelliteElevationGraphReducer.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/19/21.
//

import Foundation
import SwiftRex

extension Reducer where ActionType == SatelliteElevationGraphAction, StateType == SatelliteElevationGraphResources {
    static let satelliteElevationGraphReducer = Reducer.reduce { action, state in
        switch action {
        case let .rasterizedElevationGraph(image, size, noradIndex, julianDateRange):
            state.rasterizedElevationGraphs[noradIndex] = .init(julianDateRange: julianDateRange, image: image)
        case .requestRasterizeElevationGraph(size: _, noradIndex: _, julianDateRange: _, traitCollection: _):
            break
        }
    }
}
