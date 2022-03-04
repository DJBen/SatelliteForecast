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
                if state.rasterizedBackgroundSky[key] == nil {
                    state.rasterizedBackgroundSky[key] = BTree()
                }

                state.rasterizedBackgroundSky[key]!.insert((julianDate, image))
            case .preview:
                if state.previewBackgroundSkies[key] == nil {
                    state.previewBackgroundSkies[key] = BTree()
                }

                state.previewBackgroundSkies[key]!.insert((julianDate, image))
            }
        }
    }
}
