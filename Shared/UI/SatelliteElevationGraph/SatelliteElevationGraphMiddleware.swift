//
//  SatelliteElevationGraphMiddleware.swift
//  SatelliteForcast (iOS)
//
//  Created by Ben Lu on 6/19/21.
//

import Foundation
import os
import Combine
import CombineRex
import SatelliteKit

fileprivate let logger = Logger(subsystem: "io.djben.satelliteElevationGraph", category: "middleware")

extension EffectMiddleware where
    InputActionType == SatelliteElevationGraphAction,
    OutputActionType == SatelliteElevationGraphAction,
    StateType == AppState,
    Dependencies == Void {

    static var satelliteElevationGraph: SimpleEffectMiddleware<SatelliteElevationGraphAction, AppState> {
        SimpleEffectMiddleware<SatelliteElevationGraphAction, AppState>
            .onAction { action, _, getState in
                switch action {
                case let .requestRasterizeElevationGraph(size, noradIndex, julianDateRange, traitCollection):
                    return .promise(token: "") { context, sink in
                        DispatchQueue.global(qos: .userInitiated).async {
                            let state = getState()
                            // Skip if image already generated.
                            // Reuses the image if the previously calculated date range is within 10 mins away from current requested date range
                            if let rangeImage = state.satelliteElevationGraphResources.rasterizedElevationGraphs[noradIndex],
                               abs(rangeImage.julianDateRange.lowerBound - state.julianDateRange.lowerBound) < 10 * TimeConstants.min2day && abs(rangeImage.julianDateRange.upperBound - state.julianDateRange.upperBound) < 10 * TimeConstants.min2day {
                                logger.debug("Elevation graph already rasterized for \(noradIndex) with range \(julianDateRange), skipping.")
                                return
                            }

                            guard let snapshots = getState().selectedSatelliteTrails?.snapshots else {
                                return
                            }

                            let image = SatelliteElevationGraph.rasterizedSatelliteElevationPath(
                                rect: CGRect(origin: .zero, size: size),
                                snapshotsSplitByIllumination: snapshots
                                    .split(
                                        inclusivity: .includesSecondElementsInPreviousGroup,
                                        shouldSplit: { (s1, s2) -> Bool in
                                            return s1.1.isIlluminated != s2.1.isIlluminated
                                        }
                                    )
                                    .map { ($0.first!.1.isIlluminated, $0) },
                                julianDateRange: julianDateRange,
                                traitCollection: traitCollection
                            )

                            logger.debug("Rasterized elevation graph for \(noradIndex) with range \(julianDateRange), size \(String(describing: size)).")

                            sink(.rasterizedElevationGraph(image, size: size, noradIndex: noradIndex, julianDateRange: julianDateRange))
                        }
                    }
                case .rasterizedElevationGraph(_, size: _, noradIndex: _, julianDateRange: _):
                    return .doNothing
                }
            }
    }
}
