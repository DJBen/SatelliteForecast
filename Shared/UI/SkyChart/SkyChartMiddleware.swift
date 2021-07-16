//
//  SkyChartMiddleware.swift
//  SatelliteForcast
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
                case .rasterizedBackgroundSky(_, usage: _, key: _):
                    return .doNothing
                case .rasterizedSatellitePath(_, usage: _, pass: _):
                    return .doNothing
                case let .requestRasterizedBackgroundSky(usage, size, key, configs, traitCollection):
                    return .promise(token: "") { context, sink in
                        DispatchQueue.global(qos: .userInitiated).async {
                            let state = getState()
                            // Skip if image already generated.
                            if let _ = state.skyChartState.rasterizedBackgroundSky[key]?[usage] {
                                return
                            }

                            let image = SkyChart.rasterizedBackgroundSkyPath(
                                rect: CGRect(origin: .zero, size: size),
                                stars: {
                                    switch configs.stars {
                                    case .none:
                                        return []
                                    case let .limitedMagnitude(mag):
                                        return Star.magitudeLessThan(mag)
                                    }
                                }(),
                                constellations: configs.showConstellationLines ? Constellation.all : [],
                                observer: key.observer,
                                julianDate: key.julianDate,
                                starColor: UIColor(named: "star", in: nil, compatibleWith: traitCollection)!,
                                constellationLineColor: UIColor(named: "constellationLine", in: nil, compatibleWith: traitCollection)!,
                                magToRadius: configs.starMagToDisplayRadius
                            )
                            logger.debug("Rasterized background sky at observer coodinate \(String(describing: key.observer)) @ JD \(key.julianDate).")

                            sink(
                                .rasterizedBackgroundSky(image, usage: usage, key: key)
                            )
                        }
                    }
                case let .requestRasterizedSatellitePath(usage, size, pass, traitCollection):
                    return .promise(token: "") { context, sink in
                        DispatchQueue.global(qos: .userInitiated).async {
                            let state = getState()
                            // Skip if image already generated.
                            if let _ = state.skyChartState.rasterizedSatellitePaths[pass]?[usage] {
    //                            logger.debug("\(pass.noradIndex)'s pass \(pass.rise.julianDate)->\(pass.set.julianDate) already rasterized, skipping.")
                                return
                            }

                            guard let snapshots = state.satellites[pass.noradIndex]?.snapshots else {
    //                            logger.debug("\(pass.noradIndex)'s pass \(pass.rise.julianDate)->\(pass.set.julianDate) lacks snapshots: rasterization on hold")
                                return
                            }

                            let snapshotsDuringPass = snapshots.subtree(from: pass.rise.julianDate, through: pass.set.julianDate)

                            traitCollection.performAsCurrent {
                                // Rasterize satellite paths in sky charts
                                let image = SkyChart.rasterizedSatellitePassPath(
                                    rect: CGRect(origin: .zero, size: size),
                                    snapshotsDuringPass: snapshotsDuringPass,
                                    illuminatedColor: UIColor(named: "satellitePath_illuminated")!,
                                    unlitColor: UIColor(named: "satellitePath_notIlluminated")!,
                                    arrowSize: usage == .preview ? 8 : 16
                                )
                                logger.debug("Rasterized \(pass.noradIndex)'s pass \(pass.rise.julianDate)->\(pass.set.julianDate).")

                                sink(
                                    .rasterizedSatellitePath(
                                        image,
                                        usage: usage,
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
