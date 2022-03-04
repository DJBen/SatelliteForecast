//
//  SkyChartReducer.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/7/21.
//

import Foundation
import BTree
import SwiftRex

extension Reducer where ActionType == SkyChartAction, StateType == SkyChartResources {
    static let skyChartReducer = Reducer.reduce { action, state in
        switch action {
        case let .rasterizedSatellitePath(image, quality, pass):
            switch quality {
            case .full:
                state.rasterizedSatellitePaths[pass] = image
            case .preview:
                state.previewSatellitePaths[pass] = image
            }
        case .requestRasterizedSatellitePath(size: _, quality: _, pass: _, traitCollection: _):
            break
        }
    }
}
