//
//  RealtimeSkyViewMiddleware.swift
//  RealtimeSkyView
//
//  Created by Ben Lu on 3/2/22.
//

import BTree
import Combine
import CombineRex
import Foundation
import SatelliteForecast
import SatelliteKit

extension EffectMiddleware where InputActionType == RealtimeSkyViewAction, OutputActionType == RealtimeSkyViewOutput, StateType == RealtimeSkyViewResources, Dependencies == Void {
    public static var realtimeSky: EffectMiddleware<RealtimeSkyViewAction, RealtimeSkyViewOutput, RealtimeSkyViewResources, Void> {
        EffectMiddleware.onAction { action, dispatcher, getState in
            switch action {
            case .loadElements:
                // See `RealtimeSkyViewMiddleware+ElementsLoader` that redirects this action.
                return .doNothing
            case .purgeElements:
                return .doNothing
            case .propagateCurrentEphemerides(let satellites, let observer, let julianDate):
                return Effect<Void, RealtimeSkyViewOutput> { context in
                    Future<DispatchedAction<RealtimeSkyViewOutput>, Never> { completion in
                        DispatchQueue.global(qos: .userInitiated).async {
                            var partialFailures: [Error] = []

                            let satellitesToCheck: [SatelliteInfo]
                            if getState().results.isEmpty {
                                satellitesToCheck = satellites
                            } else {
                                satellitesToCheck = Array(getState().results.prefix(
                                    upTo: julianDate
                                ).map(\.1.satelliteInfo))
                            }

                            let results = satellitesToCheck.compactMap { satelliteInfo -> RealtimePropagationResult? in
                                do {
                                    let snapshot = try SatelliteSnapshot(
                                        satelliteInfo: satelliteInfo,
                                        julianDate: julianDate,
                                        observer: observer
                                    )

                                    return RealtimePropagationResult(
                                        noradIndex: satelliteInfo.elements.noradIndex,
                                        snapshot: snapshot,
                                        satelliteInfo: satelliteInfo,
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
                            .reduce(into: BTree<Double, RealtimePropagationResult>(), { $0.insert(($1.nextCheckJulianDate, $1)) })

                            completion(
                                .success(
                                    DispatchedAction<RealtimeSkyViewOutput>(
                                        .propagatedCurrentEphemerides(
                                            results: results,
                                            satellites: satellites,
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
                }
            case .setRealtimeSkyViewActive(_):
                return .doNothing
            }
        }
    }
}
