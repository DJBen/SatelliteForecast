//
//  SkyChartReducer.swift
//  SatelliteForcast (iOS)
//
//  Created by Ben Lu on 6/7/21.
//

import Foundation
import SwiftRex

extension Reducer where ActionType == SkyChartAction, StateType == SkyChartResources {
    static let skyChartReducer = Reducer.reduce { action, state in
        switch action {
        case .onAppear:
            break
        case let .rasterizedBackgroundSky(image):
            // TODO: process rasterized background sky
            break
        case let .rasterizedSatellitePath(image, size, pass):
            if let _ = state.rasterizedSatellitePaths[pass] {
                state.rasterizedSatellitePaths[pass]![size] = image
            } else {
                state.rasterizedSatellitePaths[pass] = [size: image]
            }
        case .requestRasterizedSatellitePath(_, _, traitCollection: _):
            break
        }
    }
}
