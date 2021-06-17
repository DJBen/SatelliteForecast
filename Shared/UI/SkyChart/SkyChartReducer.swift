//
//  SkyChartReducer.swift
//  SatelliteForcast (iOS)
//
//  Created by Ben Lu on 6/7/21.
//

import Foundation
import SwiftRex

extension Reducer where ActionType == SkyChartAction, StateType == SkyChartRootState {
    static let skyChartReducer = Reducer.reduce { action, state in
        switch action {
        case .onAppear:
            break
        case let .loadedBackgroundSky(stars, constellations):
            state.stars = stars
            state.constellations = constellations

        case let .rasterizedSatellitePath(image, pass: pass):
            state.rasterizedSatellitePaths[pass] = image
        }
    }
}
