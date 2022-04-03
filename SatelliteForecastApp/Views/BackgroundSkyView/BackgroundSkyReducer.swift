//
//  BackgroundSkyReducer.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/3/22.
//

import Foundation
import BTree
import SwiftRex

extension Reducer where ActionType == BackgroundSkyViewOutput, StateType == BackgroundSkyResources {
    static let backgroundSkyReducer = Reducer.reduce { action, state in
        switch action {
        case .rasterizedBackgroundSky(
            let image,
            quality: let quality,
            julianDate: let julianDate,
            key: let key
        ):
            switch quality {
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
