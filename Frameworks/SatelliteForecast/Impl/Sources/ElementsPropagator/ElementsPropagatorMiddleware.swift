//
//  ElementsPropagatorMiddleware.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 4/4/22.
//

import Combine
@preconcurrency import CombineRex
import os
import SatelliteForecast
@preconcurrency import SatelliteKit

fileprivate let logger = Logger(subsystem: "io.djben.elementsPropagator", category: "middleware")

extension EffectMiddleware where InputActionType == ElementsPropagatorAction, OutputActionType == ElementsPropagatorOutput, StateType == ElementsPropagatorResources, Dependencies == Void {
    public static var elementsPropagator: EffectMiddleware<ElementsPropagatorAction, ElementsPropagatorOutput, ElementsPropagatorResources, Void> {
        EffectMiddleware.onAction { action, _, getState in
            switch action {
            case .calculatePasses(let params):
                return Effect { context -> AnyPublisher<DispatchedAction<ElementsPropagatorOutput>, Never> in
                    let state = getState()
                    let (info, noradIndex, observer, julianDateRange) = (
                        params.satelliteInfo,
                        params.selectedNoradIndex,
                        params.observer,
                        params.julianDateRange
                    )

                    // Loads satellite passes
                    let subject = PassthroughSubject<DispatchedAction<ElementsPropagatorOutput>, Never>()

                    DispatchQueue.global(qos: .userInitiated).async {
                        // Use cached satellite ephemerides if calculated within the last hour.
                        if let satelliteState = state.satelliteTrails[noradIndex],
                           abs(julianDateRange.lowerBound - satelliteState.snapshots.first!.julianDate) < TimeConstants.hrs2day,
                           let _ = satelliteState.passSnapshots {
                            logger.debug("Ephemeride of \(noradIndex) are already generated. Skipping.")
                        } else {
                            logger.debug("Calculating pass within date range \(julianDateRange) for \(String(describing: observer)) at interval of 30s")

                            do {
                                let snapshots = try info.generateSnapshots(
                                    observer: observer,
                                    julianDateRange: julianDateRange,
                                    interval: 30
                                )

                                subject.send(
                                    DispatchedAction<ElementsPropagatorOutput>(
                                        .propagatedSnapshots(
                                            snapshots,
                                            noradIndex: noradIndex,
                                            observer: observer
                                        )
                                    )
                                )

                                let passSnapshots = try info.findPasses(
                                    observer: observer,
                                    coarseSnapshots: snapshots,
                                    qsMag: info.qsMag,
                                    crossSectionArea: info.satCat?.rcs
                                )

                                subject.send(
                                    DispatchedAction<ElementsPropagatorOutput>(
                                        .foundPassesAndSnapshots(
                                            passSnapshots,
                                            noradIndex: noradIndex,
                                            observer: observer
                                        )
                                    )
                                )
                                logger.debug("Generated emphemerides and passes of \(noradIndex).")
                            } catch {
                                print("Failed to propagate \(noradIndex): \(error)")
                            }
                        }

                        subject.send(completion: .finished)
                    }
                    return subject
                        .eraseToAnyPublisher()
                }
            case .recalculatePasses(/*let params*/_):
                return .doNothing
            case .purgePassesAndSnapshots:
                return .doNothing
            }
        }
    }
}

extension EffectMiddleware where InputActionType == ElementsPropagatorAction, OutputActionType == ElementsPropagatorAction, StateType == ElementsPropagatorResources, Dependencies == Void {
    /// This middleware triggers other `ElementsPropagatorAction`s.
    public static var elementsPropagatorChainer: EffectMiddleware<ElementsPropagatorAction, ElementsPropagatorAction, ElementsPropagatorResources, Void> {
        EffectMiddleware.onAction { action, _, getState in
            switch action {
            case .recalculatePasses(let params):
                return .sequence([
                    .purgePassesAndSnapshots,
                    .calculatePasses(params)
                ])
            case .purgePassesAndSnapshots:
                return .doNothing
            case .calculatePasses(_):
                return .doNothing
            }
        }
    }
}
