//
//  SkyChartReducer.swift
//  SatelliteForcast
//
//  Created by Ben Lu on 6/7/21.
//

import Foundation
import BTree
import SwiftRex

extension Reducer where ActionType == SkyChartAction, StateType == SkyChartResources {
    static let skyChartReducer = Reducer.reduce { action, state in
        switch action {
        case .onAppear:
            break
        case let .rasterizedBackgroundSky(image, quality, julianDate, key):
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
        case let .rasterizedSatellitePath(image, quality, pass):
            switch quality {
            case .full:
                state.rasterizedSatellitePaths[pass] = image
            case .preview:
                state.previewSatellitePaths[pass] = image
            }
        case .requestRasterizedBackgroundSky(size: _, quality: _, julianDate: _, key: _, traitCollection: _):
            break
        case .requestRasterizedSatellitePath(size: _, quality: _, pass: _, traitCollection: _):
            break
        }
    }
}
