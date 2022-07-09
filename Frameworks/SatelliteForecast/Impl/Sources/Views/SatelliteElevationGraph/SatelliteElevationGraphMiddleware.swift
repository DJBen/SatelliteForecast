//
//  SatelliteElevationGraphMiddleware.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 6/19/21.
//

import Foundation
import os
import Combine
import CombineRex
import SatelliteKit
import SatelliteForecast

fileprivate let logger = Logger(subsystem: "io.djben.satelliteElevationGraph", category: "middleware")

extension EffectMiddleware where
    InputActionType == SatelliteElevationGraphAction,
    OutputActionType == SatelliteElevationGraphAction,
    StateType == SatelliteElevationGraphState,
    Dependencies == Void {

    public static var satelliteElevationGraph: SimpleEffectMiddleware<SatelliteElevationGraphAction, SatelliteElevationGraphState> {
        SimpleEffectMiddleware<SatelliteElevationGraphAction, SatelliteElevationGraphState>.onAction { action, _, getState in
            switch action {
            case let .requestRasterizeElevationGraph(size, noradIndex, julianDateRange, traitCollection):
                return .promise(token: "") { context, sink in
                    DispatchQueue.global(qos: .userInitiated).async {
                        let state = getState()

                        // Skip if image already generated.
                        // Reuses the image if the previously calculated date range is within 10 mins away from current requested date range
                        if let _ = state.satelliteElevationGraphResources.rasterizedElevationGraph(noradIndex: noradIndex, size: size, julianDateRange: julianDateRange, tolerance: TimeConstants.min2day) {
                            logger.debug("Elevation graph already rasterized for \(noradIndex) with range \(julianDateRange), skipping.")
                            return
                        }

                        guard let snapshots = state.selectedNoradIndex.flatMap({ state.elementsPropagatorResources.satelliteTrails[$0] })?.snapshots else {
                            return
                        }

                        let image = SatelliteElevationGraph.rasterizedSatelliteElevationPath(
                            rect: CGRect(origin: .zero, size: size),
                            snapshotsSplitByIllumination: snapshots
                                .split(
                                    inclusivity: .includesSecondElementsInPreviousGroup,
                                    shouldSplit: { (s1, s2) -> Bool in
                                        return s1.isIlluminated != s2.isIlluminated
                                    }
                                )
                                .map { ($0.first!.isIlluminated, $0) },
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
