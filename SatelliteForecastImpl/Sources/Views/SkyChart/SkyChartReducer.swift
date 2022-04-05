//
//  skyChartOutputReducer.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/7/21.
//

import Foundation
import BTree
import SwiftRex

extension Reducer where ActionType == SkyChartOutput, StateType == SkyChartViewState {
    public static let skyChartOutputReducer = Reducer.reduce { action, state in
        switch action {
        case let .rasterizedSatellitePath(image, quality, pass):
            switch quality {
            case .full:
                state.resources.rasterizedSatellitePaths[pass] = image
            case .preview:
                state.resources.previewSatellitePaths[pass] = image
            }
        }
    }
}
