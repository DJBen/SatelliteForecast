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
        case let .rasterizedBackgroundSky(image, usage, key):
            if let _ = state.rasterizedBackgroundSky[key] {
                state.rasterizedBackgroundSky[key]![usage] = image
            } else {
                state.rasterizedBackgroundSky[key] = [usage: image]
            }
        case let .rasterizedSatellitePath(image, usage, pass):
            if let _ = state.rasterizedSatellitePaths[pass] {
                state.rasterizedSatellitePaths[pass]![usage] = image
            } else {
                state.rasterizedSatellitePaths[pass] = [usage: image]
            }
        case .requestRasterizedBackgroundSky(_, _, _, _, traitCollection: _):
            break
        case .requestRasterizedSatellitePath(_, _, _, traitCollection: _):
            break
        }
    }
}
