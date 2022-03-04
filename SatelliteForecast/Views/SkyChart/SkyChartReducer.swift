//
//  skyChartOutputReducer.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/7/21.
//

import Foundation
import BTree
import SwiftRex

extension Reducer where ActionType == SkyChartOutput, StateType == SkyChartResources {
    static let skyChartOutputReducer = Reducer.reduce { action, state in
        switch action {
        case let .rasterizedSatellitePath(image, quality, pass):
            switch quality {
            case .full:
                state.rasterizedSatellitePaths[pass] = image
            case .preview:
                state.previewSatellitePaths[pass] = image
            }
        }
    }

    func lift() -> Reducer<AppAction, AppState> {
        lift(
            actionGetter: \.skyChartOutput,
            stateGetter: \AppState.skyChartResources,
            stateSetter: { appState, state in
                appState.skyChartResources = state
            }
        )
    }
}
