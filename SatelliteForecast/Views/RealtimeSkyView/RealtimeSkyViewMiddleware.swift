//
//  RealtimeSkyViewMiddleware.swift
//  RealtimeSkyView
//
//  Created by Ben Lu on 3/2/22.
//

import Combine
import CombineRex
import SatelliteForecastCore
import SatelliteKit

extension EffectMiddleware where InputActionType == RealtimeSkyViewAction, OutputActionType == RealtimeSkyViewOutput, StateType == RealtimeSkyViewResources, Dependencies == Void {
    static var realtimeSky: EffectMiddleware<RealtimeSkyViewAction, RealtimeSkyViewOutput, RealtimeSkyViewResources, Void> {
        EffectMiddleware.onAction { action, dispatcher, getState in
            switch action {
            case .propagateCurrentEphemerides(let tles, let observer, let julianDate):
                return Effect<Void, RealtimeSkyViewOutput> { context in
                    Future<DispatchedAction<RealtimeSkyViewOutput>, Never> { completion in
                        var partialFailures: [Error] = []
                        let results = tles.filter { tle in
                            // If next check date exceeds the current date, do not check
                            if let nextCheck = getState().results[tle.noradIndex]?.nextCheckJulianDate,
                               nextCheck > julianDate {
                                return false
                            }
                            return true
                        }
                        .flatMap { tle -> RealtimePropagationResult? in
                            do {
                                let snapshot = try SatelliteSnapshot(
                                    tle: tle,
                                    julianDate: julianDate,
                                    observer: observer
                                )

                                return RealtimePropagationResult(
                                    noradIndex: tle.noradIndex,
                                    snapshot: snapshot,
                                    tle: tle,
                                    nextCheckJulianDate: {
                                        let delay: Double = {
                                            if snapshot.position.elev < -30 {
                                                return 300
                                            } else if snapshot.position.elev < -15 {
                                                return 120
                                            } else if snapshot.position.elev < -5 {
                                                return 60
                                            } else if snapshot.position.elev < 0 {
                                                return 30
                                            } else if snapshot.position.elev < 5 {
                                                return 5
                                            } else if snapshot.position.elev < 10 {
                                                return 3
                                            } else if snapshot.position.elev < 15 {
                                                return 2
                                            } else if snapshot.position.elev < 45 {
                                                return 1
                                            } else {
                                                return 0.5
                                            }
                                        }()
                                        return julianDate + delay * TimeConstants.sec2day
                                    }()
                                )
                            } catch {
                                partialFailures.append(error)
                                return nil
                            }
                        }
                        .reduce(into: [UInt: RealtimePropagationResult](), { $0[$1.noradIndex] = $1 })

                        completion(
                            .success(
                                DispatchedAction<RealtimeSkyViewOutput>(
                                    .propagatedCurrentEphemerides(
                                        results: results,
                                        tles: tles,
                                        partialErrors: partialFailures,
                                        observer: observer,
                                        julianDate: julianDate
                                    ),
                                    dispatcher: dispatcher
                                )
                            )
                        )
                    }
                }
            case .setRealtimeSkyViewActive(_):
                return .doNothing
            }
        }
    }
}
