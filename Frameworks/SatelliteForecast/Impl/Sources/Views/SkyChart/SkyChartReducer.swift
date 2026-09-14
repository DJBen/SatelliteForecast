//
//  skyChartOutputReducer.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 6/7/21.
//

import Foundation
import BTree
@preconcurrency import SwiftRex
import SatelliteForecast

extension Reducer where ActionType == SkyChartOutput, StateType == SkyChartViewState {
    public static let skyChartOutputReducer = Reducer.reduce { action, state in
        switch action {
        case let .rasterizedSatellitePath(image, quality, key):
            switch quality {
            case .detailed:
                state.resources.detailedSatellitePaths[key] = image
            case .full:
                state.resources.rasterizedSatellitePaths[key] = image
            case .preview:
                state.resources.previewSatellitePaths[key] = image
            case .onboarding:
                state.resources.onboardingSatellitePaths[key] = image
            }
        }
    }
}
