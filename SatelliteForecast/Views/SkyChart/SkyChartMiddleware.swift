//
//  SkyChartMiddleware.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/7/21.
//

import Foundation
import os
import Combine
import CombineRex
import SatelliteForecastCore
import SatelliteKit
import StarryNight

fileprivate let logger = Logger(subsystem: "io.djben.skyChart", category: "middleware")

extension EffectMiddleware where
    InputActionType == SkyChartAction,
    OutputActionType == SkyChartAction,
    StateType == AppState,
    Dependencies == Void {

    static var skyChart: SimpleEffectMiddleware<SkyChartAction, AppState> {
        SimpleEffectMiddleware<SkyChartAction, AppState>.onAction { action, _, getState in
            switch action {
            case .rasterizedSatellitePath(_, quality: _, pass: _):
                return .doNothing
            case let .requestRasterizedSatellitePath(size, quality, pass, traitCollection):
                return .promise(token: "") { context, sink in
                    DispatchQueue.global(qos: .userInitiated).async {
                        let state = getState()
                        let dataSource = quality == .full ? state.skyChartState.rasterizedSatellitePaths : state.skyChartState.previewSatellitePaths
                        // Skip if image already generated.
                        if let _ = dataSource[pass] {
//                            logger.debug("\(pass.noradIndex)'s pass \(pass.rise.julianDate)->\(pass.set.julianDate) already rasterized, skipping.")
                            return
                        }

                        guard let passSnapshots = state.satelliteTrails[pass.noradIndex]?.passSnapshots?.first(
                            where: { $0.pass == pass }
                        ) else {
//                            logger.debug("\(pass.noradIndex)'s pass \(pass.rise.julianDate)->\(pass.set.julianDate) lacks snapshots: rasterization on hold")
                            return
                        }

                        traitCollection.performAsCurrent {
                            // Rasterize satellite paths in sky charts
                            let image = SkyChart.rasterizedSatellitePassPath(
                                params: SatellitePassPathRenderParams(
                                    rect: CGRect(origin: .zero, size: size),
                                    snapshotsDuringPass: passSnapshots.snapshots,
                                    illuminatedColor: UIColor(named: "satellitePath_illuminated")!,
                                    unlitColor: UIColor(named: "satellitePath_notIlluminated")!,
                                    arrowSize: quality == .preview ? 8 : 16
                                )
                            )
//                                logger.debug("Rasterized \(pass.noradIndex)'s pass \(pass.rise.julianDate)->\(pass.set.julianDate).")

                            sink(
                                .rasterizedSatellitePath(
                                    image,
                                    quality: quality,
                                    pass: pass
                                )
                            )
                        }
                    }
                }
            }
        }
    }
}
