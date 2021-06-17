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
                    return Effect { context -> AnyPublisher<DispatchedAction<SkyChartAction>, Never> in
                        let subject = PassthroughSubject<DispatchedAction<SkyChartAction>, Never>()

                        if getState().stars.count > 0 && getState().constellations.count > 0 {
                            subject.send(completion: .finished)
                            return subject.eraseToAnyPublisher()
                        }

                        DispatchQueue.global(qos: .userInitiated).async {

//                            let stars = Star.magitudeLessThan(4.5)
//                            let constellations = Constellation.all
//                            logger.info("Loaded background stars and constellations from DB")
//
//                            subject.send(DispatchedAction<SkyChartAction>(.loadedBackgroundSky(stars: stars, constellations: constellations)))

                            subject.send(completion: .finished)
                        }

                        return subject.eraseToAnyPublisher()
                    }
                case .loadedBackgroundSky(stars: _, constellations: _):
                    return .doNothing
                case .rasterizedSatellitePath(_, pass: _):
                    return .doNothing
                }
            }
    }
}
