//
//  AllPassesViewMiddleware.swift
//  SatelliteForcast (iOS)
//
//  Created by Ben Lu on 6/7/21.
//

import Foundation
import os
import Combine
import CombineRex
import SatelliteKit

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
                case let .onAppear(colorScheme):
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
                        guard state.currentSatelliteSnapshots.isEmpty || state.julianDateRange.lowerBound - state.currentSatelliteSnapshots.first!.1.julianDate > TimeConstants.hrs2day else {
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
                                    julianDateRange: state.julianDateRange,
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

                            let traitCollection = UITraitCollection(userInterfaceStyle: UIUserInterfaceStyle(colorScheme))

                            for pass in passes {
                                let snapshotsDuringPass = fineSnapshots.submap(from: pass.rise.julianDate, through: pass.set.julianDate)

                                // Rasterize satellite paths in sky charts
                                if let image = SkyChart.rasterizedPath(
                                    rect: CGRect(origin: .zero, size: CGSize(width: 100, height: 100)),
                                    snapshotsDuringPass: snapshotsDuringPass,
                                    illuminatedColor: UIColor(named: "satellitePath_illuminated", in: nil, compatibleWith: traitCollection)!,
                                    unlitColor: UIColor(named: "satellitePath_notIlluminated", in: nil, compatibleWith: traitCollection)!
                                ) {
                                    subject.send(
                                        DispatchedAction<AppAction>(
                                            .skyChart(
                                                .rasterizedSatellitePath(
                                                    image,
                                                    pass: pass
                                                )
                                            )
                                        )
                                    )
                                }
                            }

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

                case .selectPass:
                    return .doNothing
                }
            }
    }
}
