//
//  SatelliteListViewMiddleware.swift
//  SatelliteForcast
//
//  Created by Ben Lu on 6/5/21.
//

import Foundation
import os
import Combine
import CombineRex
import SatelliteKit

fileprivate let logger = Logger(subsystem: "io.djben.satelliteListView", category: "middleware")

extension EffectMiddleware where
    InputActionType == SatelliteListViewAction,
    OutputActionType == AppAction,
    StateType == AppState,
    Dependencies == Void {

    /// A middeware that listens to `SatelliteListViewAction`.
    /// - `onAppear`: It bootstraps the flow with some side effects including loading the TLEs and requesting core location authorization.
    /// - `selectSatellite(noradIndex)`: It asynchronously does two things:
    ///   - Generate a coarse ephemeris of the satellite over a long future period.
    ///   - Find all the passes in the same period, and generate a fine ephemeris during each pass.
    ///
    ///   Thus this effect will have two action outputs before it completes.
    static var satelliteListView: EffectMiddleware<SatelliteListViewAction, AppAction, AppState, Void> {
        EffectMiddleware<SatelliteListViewAction, AppAction, AppState, Void>
            .onAction { (action, _, getState) -> Effect<Void, AppAction> in
                switch action {
                case .onAppear:
                    return .sequence(
                        .coreLocationInput(.requestAuthorization),
                        .tleLoaderInput(.loadTLECategory(.brightest100))
                    )
                case let .selectSatellite(noradIndex):
                    return Effect { context -> AnyPublisher<DispatchedAction<AppAction>, Never> in
                        let state = getState()

                        // Precondition: TLE must be ready
                        guard let noradIndex = noradIndex, let tle = state.tleLoaderState.tle(noradIndex: noradIndex) else {
                            logger.fault("TLE not ready when selecting satellites")
                            return Empty().eraseToAnyPublisher()
                        }

                        // Precondition: An observer coordinate must exist
                        guard let observerCoordinate = state.coreLocationState.location.map(LatLonAlt.init) else {
                            logger.info("Will not generate satellite \(noradIndex) ephemerides: lack of user coordinate")
                            return Empty().eraseToAnyPublisher()
                        }

                        // Only populate satellite ephemerides if empty or outdated by more than 30 mins.
                        guard state.currentSatelliteSnapshots.isEmpty || state.dateRange.lowerBound.timeIntervalSince(state.currentSatelliteSnapshots.first!.date) > 30 * 60 else {
                            logger.debug("Ephemeride of \(noradIndex) are already generated. Skipping.")
                            return Empty().eraseToAnyPublisher()
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

                            let passInformation = satellite
                                .findPasses(
                                    observer: observerCoordinate,
                                    param: .existingSnapshots(snapshots)
                                )

                            subject.send(
                                DispatchedAction<AppAction>(
                                    .tlePropagator(
                                        .foundPasses(
                                            passInformation,
                                            searchDateRange: state.dateRange,
                                            noradIndex: noradIndex
                                        )
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
