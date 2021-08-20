//
//  AllPassesViewMiddleware.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/7/21.
//

import BTree
import Foundation
import os
import Combine
import CombineRex
import SatelliteKit
import SatelliteForecastCore
import UserNotifications

fileprivate let logger = Logger(subsystem: "io.djben.allPassesView", category: "middleware")

extension EffectMiddleware where
    InputActionType == AllPassesViewAction,
    OutputActionType == AppAction,
    StateType == AppState,
    Dependencies == Void {

    static var allPassesView: EffectMiddleware<AllPassesViewAction, AppAction, AppState, Void> {
        EffectMiddleware<AllPassesViewAction, AppAction, AppState, Void>
            .onAction { (action, _, getState) -> Effect<Void, AppAction> in
                switch action {
                case .recalculatePasses:
                    return .sequence([
                        .tlePropagator(.purgePassesAndSnapshots),
                        .allPassesView(.calculatePasses)
                    ])
                case .calculatePasses:
                    return Effect { context -> AnyPublisher<DispatchedAction<AppAction>, Never> in
                        let state = getState()

                        // Precondition: TLE must be ready
                        guard let noradIndex = state.navigationState.selectedSatelliteNoradIndex, let info = state.satelliteLoaderState[noradIndex] else {
                            logger.fault("TLE not ready for the selected satellite when calculating passes")
                            return Empty().eraseToAnyPublisher()
                        }

                        // Precondition: An observer coordinate must exist
                        // Freeze the coordinate during the pass viewing workflow, so the coordinate
                        // stays the same.
                        guard let observer = state.locationState.location.map(LatLonAlt.init) else {
                           logger.info("Will not generate satellite \(noradIndex) ephemerides: lack of core location coordinate")
                            return Empty().eraseToAnyPublisher()
                        }

                        guard let julianDateRange = state.julianDateRange else {
                            logger.warning("Will not generate satellite \(noradIndex) ephemerides: missing julian date range")
                            return Empty().eraseToAnyPublisher()
                        }

                        // Loads satellite passes
                        let subject = PassthroughSubject<DispatchedAction<AppAction>, Never>()

                        DispatchQueue.global(qos: .userInitiated).async {
                            let passes: [Pass]
                            let fineSnapshots: BTree<Double, SatelliteSnapshot>

                            // Use cached satellite ephemerides if calculated within the last hour.
                            if let satelliteState = state.selectedSatelliteTrails,
                               julianDateRange.lowerBound - satelliteState.snapshots.first!.1.julianDate < TimeConstants.hrs2day,
                               let existingPasses = satelliteState.passes {
                                passes = existingPasses
                                fineSnapshots = satelliteState.snapshots
                                logger.debug("Ephemeride of \(noradIndex) are already generated. Skipping.")
                            } else {
                                let satellite = info.satellite
                                logger.debug("Calculating pass within date range \(julianDateRange) for \(String(describing: observer)) at interval of 30s")

                                let snapshots = satellite
                                    .snapshots(
                                        observer: observer,
                                        julianDateRange: julianDateRange,
                                        interval: 30
                                    )

                                subject.send(
                                    DispatchedAction<AppAction>(
                                        .tlePropagator(
                                            .propagatedSnapshots(
                                                snapshots,
                                                noradIndex: noradIndex,
                                                observer: observer
                                            )
                                        )
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
                                                noradIndex: noradIndex,
                                                observer: observer
                                            )
                                        )
                                    )
                                )
                                logger.debug("Generated emphemerides and passes of \(noradIndex).")
                            }

                            subject.send(completion: .finished)
                        }
                        return subject
                            .eraseToAnyPublisher()
                    }

                case .selectPass:
                    return .doNothing
                    
                case let .scheduleNotification(passNotification):
                    return .just(.notification(.requestNotificationAuthorization(pendingNotification: passNotification)))
                    
                case let .unscheduleNotification(id):
                    return .just(.notification(.cancelNotifications(ids: [id])))
                }
            }
    }
}
