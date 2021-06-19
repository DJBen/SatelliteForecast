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
                case .rasterizedSatellitePath(_, size: _, pass: _):
                    return .doNothing
                case let .requestRasterizedSatellitePath(size, pass, traitCollection):
                    return .promise(token: "") { context, sink in
                        let state = getState()
                        // Skip if image already generated.
                        if let _ = state.skyChartState.rasterizedSatellitePaths[pass]?[size] {
                            logger.debug("\(pass.noradIndex)'s pass \(pass.rise.julianDate)->\(pass.set.julianDate) already rasterized, skipping.")
                            return
                        }

                        guard let snapshots = state.satellites[pass.noradIndex]?.snapshots else {
                            logger.debug("\(pass.noradIndex)'s pass \(pass.rise.julianDate)->\(pass.set.julianDate) lacks snapshots: rasterization on hold")
                            return
                        }

                        let snapshotsDuringPass = snapshots.submap(from: pass.rise.julianDate, through: pass.set.julianDate)

                        // Rasterize satellite paths in sky charts
                        let image = SkyChart.rasterizedPath(
                            rect: CGRect(origin: .zero, size: size),
                            snapshotsDuringPass: snapshotsDuringPass,
                            illuminatedColor: UIColor(named: "satellitePath_illuminated", in: nil, compatibleWith: traitCollection)!,
                            unlitColor: UIColor(named: "satellitePath_notIlluminated", in: nil, compatibleWith: traitCollection)!
                        )
                        logger.debug("Rasterized \(pass.noradIndex)'s pass \(pass.rise.julianDate)->\(pass.set.julianDate).")

                        sink(
                            .rasterizedSatellitePath(
                                image,
                                size: size,
                                pass: pass
                            )
                        )
                    }
                }
            }
    }
}
