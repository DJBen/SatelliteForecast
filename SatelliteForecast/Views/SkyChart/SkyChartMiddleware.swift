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
        SimpleEffectMiddleware<SkyChartAction, AppState>
            .onAction { action, _, getState in
                switch action {
                case .rasterizedBackgroundSky(_, quality: _, julianDate: _, key: _):
                    return .doNothing
                case .rasterizedSatellitePath(_, quality: _, pass: _):
                    return .doNothing
                case let .requestRasterizedBackgroundSky(size, quality, julianDate, key, traitCollection):
                    return .promise(token: "") { context, sink in
                        DispatchQueue.global(qos: .userInitiated).async {
                            let state = getState()
                            let dataSource = quality == .full ? state.skyChartState.rasterizedBackgroundSky : state.skyChartState.previewBackgroundSkies
                            // Skip if image already generated within the last minute.
                            if let _ = dataSource[key]?.value(closestTo: julianDate, within: TimeConstants.sec2day) {
                                return
                            }

                            let image = SkyChart.rasterizedBackgroundSkyPath(
                                params: BackgroundSkyRenderParams(
                                    rect: CGRect(origin: .zero, size: size),
                                    stars: {
                                        switch key.configs.stars {
                                        case .none:
                                            return []
                                        case let .limitedMagnitude(mag):
                                            return Star.magitudeLessThan(mag)
                                        }
                                    }(),
                                    constellations: key.configs.showConstellationLines ? Constellation.all : [],
                                    observer: key.observer,
                                    julianDate: julianDate,
                                    starColor: UIColor(named: "star", in: nil, compatibleWith: traitCollection)!,
                                    constellationLineColor: UIColor(named: "constellationLine", in: nil, compatibleWith: traitCollection)!,
                                    magToRadius: key.configs.starMagToDisplayRadiusMappingFunction.apply
                                )
                            )

//                            logger.debug("Rasterized background sky at observer coodinate \(String(describing: key.observer)) @ JD \(julianDate).")

                            sink(
                                .rasterizedBackgroundSky(image, quality: quality, julianDate: julianDate, key: key)
                            )
                        }
                    }
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

                            guard let passSnapshots = state.satelliteTrails[pass.noradIndex]?.passSnapshots?.first(where: { $0.pass == pass }) else {
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
