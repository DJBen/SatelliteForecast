//
//  BackgroundSkyReducer.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 3/3/22.
//

import Foundation
import BTree
@preconcurrency import SwiftRex
import SatelliteForecast

extension Reducer where ActionType == BackgroundSkyViewOutput, StateType == BackgroundSkyResources {
    public static let backgroundSkyReducer = Reducer.reduce { action, state in
        switch action {
        case .rasterizedBackgroundSky(
            let image,
            quality: let quality,
            julianDate: let julianDate,
            key: let key
        ):
            switch quality {
            case .detailed:
                if var existingSkies = state.detailedBackgroundSkies[key] {
                    existingSkies[julianDate] = image
                    state.detailedBackgroundSkies[key] = existingSkies
                } else {
                    state.detailedBackgroundSkies[key] = [julianDate: image]
                }
            case .full:
                if var existingSkies = state.rasterizedBackgroundSky[key] {
                    existingSkies[julianDate] = image
                    state.rasterizedBackgroundSky[key] = existingSkies
                } else {
                    state.rasterizedBackgroundSky[key] = [julianDate: image]
                }
            case .preview:
                if var existingSkies = state.previewBackgroundSkies[key] {
                    existingSkies[julianDate] = image
                    state.previewBackgroundSkies[key] = existingSkies
                } else {
                    state.previewBackgroundSkies[key] = [julianDate: image]
                }
            }
        }
    }
}
