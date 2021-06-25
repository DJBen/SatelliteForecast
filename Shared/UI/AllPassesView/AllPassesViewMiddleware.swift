//
//  AllPassesViewMiddleware.swift
//  SatelliteForcast (iOS)
//
//  Created by Ben Lu on 6/7/21.
//

import BTree
import Foundation
import os
import Combine
import CombineRex
import SatelliteKit
import SatelliteForcastCore

fileprivate let logger = Logger(subsystem: "io.djben.allPassesView", category: "middleware")

extension EffectMiddleware where
    InputActionType == AllPassesViewAction,
    OutputActionType == AppAction,
    StateType == AppState,
    Dependencies == Void {

    /// A middeware that listens to `AllPassesViewAction`.
    /// - `onAppear`:
    ///   - Generate a coarse ephemeris of the satellite over a long future period.
    ///   - Find all the passes in the same period, and generate a fine ephemeris during each pass.
    ///   - Rasterize all the satellite passes.
    ///   - Select the first visible pass (if any).
    ///
    ///   Thus this effect will have multiple action outputs before it completes.
    static var allPassesView: EffectMiddleware<AllPassesViewAction, AppAction, AppState, Void> {
        EffectMiddleware<AllPassesViewAction, AppAction, AppState, Void>
            .onAction { (action, _, getState) -> Effect<Void, AppAction> in
                switch action {
                case .onAppear:
                    return Effect { context -> AnyPublisher<DispatchedAction<AppAction>, Never> in
                        let state = getState()

                        // Precondition: TLE must be ready
                        guard let noradIndex = state.selectedSatelliteNoradIndex, let info = state.satelliteLoaderState.info(noradIndex: noradIndex) else {
                            logger.fault("TLE not ready when selecting satellites")
                            return Empty().eraseToAnyPublisher()
                        }

                        // Precondition: An observer coordinate must exist
                        // Freeze the coordinate during the pass viewing workflow, so the coordinate
                        // stays the same.
                        guard let observer = state.coreLocationState.location.map(LatLonAlt.init) else {
                           logger.info("Will not generate satellite \(noradIndex) ephemerides: lack of core location coordinate")
                            return Empty().eraseToAnyPublisher()
                        }

                        // Loads satellite passes
                        let subject = PassthroughSubject<DispatchedAction<AppAction>, Never>()

                        DispatchQueue.global(qos: .userInitiated).async {
                            let passes: [Pass]
                            let fineSnapshots: BTree<Double, SatelliteSnapshot>

                            // Use cached satellite ephemerides if calculated within the last hour.
                            if let satelliteState = state.selectedSatelliteState,
                               state.julianDateRange.lowerBound - satelliteState.snapshots.first!.1.julianDate < TimeConstants.hrs2day,
                               let existingPasses = satelliteState.passes {
                                passes = existingPasses
                                fineSnapshots = satelliteState.snapshots
                                logger.debug("Ephemeride of \(noradIndex) are already generated. Skipping.")
                            } else {
                                let satellite = info.satellite
                                let snapshots = satellite
                                    .snapshots(
                                        observer: observer,
                                        julianDateRange: state.julianDateRange,
                                        interval: 30
                                    )

                                subject.send(
                                    DispatchedAction<AppAction>(
                                        .tlePropagator(.propagatedSnapshots(snapshots, noradIndex: noradIndex))
                                    )
                                )

                                (passes, fineSnapshots) = satellite
                                    .findPasses(
                                        noradIndex: Int(satellite.noradIdent)!,
                                        observer: observer,
                                        coarseSnapshots: snapshots
                                    )

                                subject.send(
                                    DispatchedAction<AppAction>(
                                        .tlePropagator(
                                            .foundPasses(
                                                passes,
                                                fineSnapshots: fineSnapshots,
                                                noradIndex: noradIndex
                                            )
                                        )
                                    )
                                )
                                logger.debug("Generated emphemerides and passes of \(noradIndex).")
                            }

                            subject.send(completion: .finished)
                        }
                        return subject
                            .receive(on: OperationQueue.main)
                            .eraseToAnyPublisher()
                    }

                case .selectPass:
                    return .doNothing
                case .backToList:
                    return .doNothing
                }
            }
    }
}
