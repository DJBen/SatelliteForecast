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
        case let .rasterizedSatellitePath(image, key):
            state.rasterizedSatellitePaths[key] = image
        case .requestRasterizedSatellitePath(_, traitCollection: _):
            break
        }
    }
}
