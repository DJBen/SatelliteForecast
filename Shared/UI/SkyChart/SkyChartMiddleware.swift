//
//  SkyChartMiddleware.swift
//  SatelliteForcast (iOS)
//
//  Created by Ben Lu on 6/7/21.
//

import Foundation
import os
import Combine
import CombineRex
import SatelliteKit
import StarryNight

fileprivate let logger = Logger(subsystem: "io.djben.skyChart", category: "middleware")

extension EffectMiddleware where
    InputActionType == SkyChartAction,
    OutputActionType == SkyChartAction,
    StateType == SkyChartRootState,
    Dependencies == Void {

    static var skyChart: SimpleEffectMiddleware<SkyChartAction, SkyChartRootState> {
        SimpleEffectMiddleware<SkyChartAction, SkyChartRootState>
            .onAction { action, _, getState in
                switch action {
                case .onAppear:
                    if getState().stars.count > 0 && getState().constellations.count > 0 {
                        return .doNothing
                    }
                    return .promise(token: "loadBackgroundSky") { context, sink in
                        DispatchQueue.global(qos: .userInitiated).async {
                            let stars = Star.magitudeLessThan(4.5)
                            let constellations = Constellation.all
                            logger.info("Loaded background stars and constellations from DB")
                            sink(.loadedBackgroundSky(stars: stars, constellations: constellations))
                        }
                    }
                case .loadedBackgroundSky(stars: _, constellations: _):
                    return .doNothing
                }
            }
    }
}
