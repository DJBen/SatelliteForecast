//
//  PassViewMiddleware.swift
//  SatelliteForcast (iOS)
//
//  Created by Ben Lu on 6/7/21.
//

import Foundation
import os
import Combine
import CombineRex
import SatelliteKit

fileprivate let logger = Logger(subsystem: "io.djben.passView", category: "middleware")

extension EffectMiddleware where
    InputActionType == PassViewAction,
    OutputActionType == AppAction,
    StateType == AppState,
    Dependencies == Void {

    /// A middeware that listens to `PassViewAction`.
    /// - `onAppear`:
    ///   - Generate a coarse ephemeris of the satellite over a long future period.
    ///   - Find all the passes in the same period, and generate a fine ephemeris during each pass.
    ///
    ///   Thus this effect will have two action outputs before it completes.
    static var passView: EffectMiddleware<PassViewAction, AppAction, AppState, Void> {
        EffectMiddleware<PassViewAction, AppAction, AppState, Void>
            .onAction { (action, _, getState) -> Effect<Void, AppAction> in
                switch action {
                case .onAppear:
                    return Effect { context -> AnyPublisher<DispatchedAction<AppAction>, Never> in
                        let state = getState()

                        // Precondition: TLE must be ready
                        guard let noradIndex = state.selectedSatelliteNoradIndex, let tle = state.tleLoaderState.tle(noradIndex: noradIndex) else {
                            logger.fault("TLE not ready when selecting satellites")
                            return Empty().eraseToAnyPublisher()
                        }

                        // Precondition: An observer coordinate must exist
                        guard let observerCoordinate = state.coreLocationState.location.map(LatLonAlt.init) else {
                            logger.info("Will not generate satellite \(noradIndex) ephemerides: lack of user coordinate")
                            return Empty().eraseToAnyPublisher()
                        }

                        // Only populate satellite ephemerides if empty or outdated by more than 1 hour.
                        guard state.currentSatelliteSnapshots.isEmpty || state.dateRange.lowerBound.timeIntervalSince(state.currentSatelliteSnapshots.first!.1.date) > 60 * 60 else {
                            logger.debug("Ephemeride of \(noradIndex) are already generated. Skipping.")
                            return Just(
                                DispatchedAction<AppAction>(
                                    .tlePropagator(
                                        .selectVisiblePass
                                    )
                                )
                            )
                            .eraseToAnyPublisher()
                        }

                        // Loads satellite passes
                        let subject = PassthroughSubject<DispatchedAction<AppAction>, Never>()

                        DispatchQueue.global(qos: .userInitiated).async {
                            let satellite = Satellite(withTLE: tle)
                            let snapshots = satellite
                                .snapshots(
                                    observer: observerCoordinate,
                                    dateRange: state.dateRange,
                                    interval: 30
                                )
                            subject.send(
                                DispatchedAction<AppAction>(
                                    .tlePropagator(.propagatedSnapshots(snapshots, noradIndex: noradIndex))
                                )
                            )

                            let (passes, fineSnapshots) = satellite
                                .findPasses(
                                    observer: observerCoordinate,
                                    param: .existingSnapshots(snapshots)
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

                            subject.send(
                                DispatchedAction<AppAction>(
                                    .tlePropagator(
                                        .selectVisiblePass
                                    )
                                )
                            )

                            subject.send(completion: .finished)
                        }
                        return subject
                            .receive(on: OperationQueue.main)
                            .eraseToAnyPublisher()
                    }
                }
            }
    }
}
