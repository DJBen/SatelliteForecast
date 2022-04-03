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
            let newImage = SatelliteElevationGraphResources.RangeImage(julianDateRange: julianDateRange, image: image)
            if let rangeImages = state.rasterizedElevationGraphs[noradIndex] {
                state.rasterizedElevationGraphs[noradIndex] = rangeImages + [newImage]
            } else {
                state.rasterizedElevationGraphs[noradIndex] = [newImage]
            }

        case .requestRasterizeElevationGraph(size: _, noradIndex: _, julianDateRange: _, traitCollection: _):
            break
        }
    }
}
