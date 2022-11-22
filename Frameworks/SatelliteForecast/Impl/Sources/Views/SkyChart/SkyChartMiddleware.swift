//
//  SkyChartMiddleware.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 6/7/21.
//

import Foundation
import os
import Combine
import CombineRex
import SatelliteForecast
import SatelliteKit
import StarryNight

fileprivate let logger = Logger(subsystem: "io.djben.skyChart", category: "middleware")

extension EffectMiddleware where
    InputActionType == SkyChartAction,
    OutputActionType == SkyChartOutput,
    StateType == SkyChartViewState,
    Dependencies == Void {

    public static var skyChart: EffectMiddleware<SkyChartAction, SkyChartOutput, SkyChartViewState, Void> {
        EffectMiddleware<SkyChartAction, SkyChartOutput, SkyChartViewState, Void>.onAction { action, _, getState in
            switch action {
            case let .requestRasterizedSatellitePath(size, quality, pass, traitCollection):
                return .promise(token: "") { context, sink in
                    satellitePathRasterizationQueue.async {
                        let state = getState()
                        let dataSource = state.resources.dataSource(for: quality)
                        // Skip if image already generated.
                        if let _ = dataSource[pass] {
//                            logger.debug("\(pass.noradIndex)'s pass \(pass.rise.julianDate)->\(pass.set.julianDate) already rasterized, skipping.")
                            return
                        }

                        guard let passSnapshots = state.elementsPropagatorResources.satelliteTrails[pass.noradIndex]?.passSnapshots?.first(
                            where: { $0.pass == pass }
                        ) else {
//                            logger.debug("\(pass.noradIndex)'s pass \(pass.rise.julianDate)->\(pass.set.julianDate) lacks snapshots: rasterization on hold")
                            return
                        }

                        traitCollection.performAsCurrent {
                            // Rasterize satellite paths in sky charts
                            let image = SkyChartUtils.rasterizedSatellitePassPath(
                                params: SatellitePassPathRenderParams(
                                    rect: CGRect(origin: .zero, size: size),
                                    snapshotsDuringPass: passSnapshots.snapshots,
                                    illuminatedColor: UIColor(
                                        named: "satellitePath_illuminated",
                                        in: .satelliteForecastImplResourcesBundle,
                                        compatibleWith: nil
                                    )!,
                                    unlitColor: UIColor(
                                        named: "satellitePath_notIlluminated",
                                        in: .satelliteForecastImplResourcesBundle,
                                        compatibleWith: nil
                                    )!,
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
