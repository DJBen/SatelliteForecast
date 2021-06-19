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
    StateType == AppState,
    Dependencies == Void {

    static var skyChart: SimpleEffectMiddleware<SkyChartAction, AppState> {
        SimpleEffectMiddleware<SkyChartAction, AppState>
            .onAction { action, _, getState in
                switch action {
                case .onAppear:
                    return .doNothing
                case .rasterizedBackgroundSky(_):
                    return .doNothing
                case .rasterizedSatellitePath(_, key: _):
                    return .doNothing
                case let .requestRasterizedSatellitePath(key, traitCollection):
                    return .promise(token: "") { context, sink in
                        let state = getState()
                        let (pass, size) = (key.pass, key.size)
                        // Skip if image already generated.
                        if let _ = state.skyChartState.rasterizedSatellitePaths[key] {
                            logger.debug("\(pass.noradIndex)'s pass \(pass.rise.julianDate)->\(pass.set.julianDate) already rasterized, skipping.")
                            return
                        }

                        guard let snapshots = state.satellites[pass.noradIndex]?.snapshots else {
                            return
                        }

                        let snapshotsDuringPass = snapshots.submap(from: pass.rise.julianDate, through: pass.set.julianDate)

                        // Rasterize satellite paths in sky charts
                        if let image = SkyChart.rasterizedPath(
                            rect: CGRect(origin: .zero, size: size),
                            snapshotsDuringPass: snapshotsDuringPass,
                            illuminatedColor: UIColor(named: "satellitePath_illuminated", in: nil, compatibleWith: traitCollection)!,
                            unlitColor: UIColor(named: "satellitePath_notIlluminated", in: nil, compatibleWith: traitCollection)!
                        ) {
                            logger.debug("Rasterized \(pass.noradIndex)'s pass \(pass.rise.julianDate)->\(pass.set.julianDate).")

                            sink(
                                .rasterizedSatellitePath(
                                    image,
                                    key: key
                                )
                            )
                        }
                    }
                }
            }
    }
}
